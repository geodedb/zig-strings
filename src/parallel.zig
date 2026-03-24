// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Parallel string operations using spice heartbeat scheduling.
//!
//! Provides low-overhead parallelism for compute-intensive string operations
//! using the fork/join pattern with sub-nanosecond overhead.
//!
//! ## Pool Lifecycle
//!
//! This module maintains a lazily-initialized global thread pool. The pool is
//! created on first use (via `getPool()`) and is **never freed** unless
//! `deinitPool()` is explicitly called by the caller. Callers must ensure that
//! all parallel operations have completed before calling `deinitPool()`;
//! calling it while operations are in-flight causes undefined behavior.

const std = @import("std");
const build_options = @import("build_options");
const spice = if (build_options.enable_spice) @import("spice") else struct {
    pub const ThreadPool = void;
    pub const Task = void;
    pub fn Future(comptime I: type, comptime O: type) type {
        _ = I;
        _ = O;
        return void;
    }
};

// ============================================================================
// Global Spice Thread Pool
// ============================================================================

var global_pool: if (build_options.enable_spice) ?spice.ThreadPool else void = if (build_options.enable_spice) null else {};
var pool_mutex: std.Thread.Mutex = .{};

/// Get the global spice thread pool, initializing if needed
pub fn getPool() if (build_options.enable_spice) *spice.ThreadPool else void {
    if (!build_options.enable_spice) return;

    pool_mutex.lock();
    defer pool_mutex.unlock();

    if (global_pool == null) {
        global_pool = spice.ThreadPool.init(std.heap.page_allocator);
        global_pool.?.start(.{});
    }
    return &global_pool.?;
}

/// Deinitializes the global thread pool.
/// SAFETY: Must only be called after all parallel operations have completed.
/// Calling this while operations are in-flight causes undefined behavior.
pub fn deinitPool() void {
    if (!build_options.enable_spice) return;

    pool_mutex.lock();
    defer pool_mutex.unlock();

    if (global_pool) |*pool| {
        pool.deinit();
        global_pool = null;
    }
}

// ============================================================================
// Parallel Search Operations
// ============================================================================

/// Context for parallel count operations
pub fn CountContext(comptime T: type) type {
    return struct {
        haystack: []const T,
        needle: []const T,
    };
}

/// Parallel count of non-overlapping occurrences of needle in haystack
pub fn parallelCount(comptime T: type, haystack: []const T, needle: []const T) usize {
    if (needle.len == 0) return 0;
    if (haystack.len < needle.len) return 0;

    // Use sequential for small inputs or when spice is disabled
    if (!build_options.enable_spice or haystack.len < 4096) {
        return sequentialCount(T, haystack, needle);
    }

    const pool = getPool();
    const Ctx = CountContext(T);
    return pool.call(usize, ParallelCountTask(T).task, Ctx{ .haystack = haystack, .needle = needle });
}

fn ParallelCountTask(comptime T: type) type {
    const Ctx = CountContext(T);
    return struct {
        pub fn task(t: *spice.Task, ctx: Ctx) usize {
            const haystack = ctx.haystack;
            const needle = ctx.needle;

            // Base case - use sequential
            if (haystack.len < 2048) {
                return sequentialCount(T, haystack, needle);
            }

            // Fork/join - split haystack
            const mid = haystack.len / 2;
            // Ensure we don't miss matches at the split point
            const overlap = needle.len - 1;
            const left_end = @min(mid + overlap, haystack.len);

            const left_ctx = Ctx{ .haystack = haystack[0..left_end], .needle = needle };
            const right_ctx = Ctx{ .haystack = haystack[mid..], .needle = needle };

            var fut = spice.Future(Ctx, usize).init();
            fut.fork(t, task, right_ctx);

            const left_count = t.call(usize, task, left_ctx);
            const right_count = if (fut.join(t)) |val| val else t.call(usize, task, right_ctx);

            // Subtract matches in overlapping region to avoid double counting
            const overlap_count = if (overlap > 0 and mid > 0)
                sequentialCount(T, haystack[mid..@min(mid + overlap, haystack.len)], needle)
            else
                0;

            return left_count + right_count - overlap_count;
        }
    };
}

fn sequentialCount(comptime T: type, haystack: []const T, needle: []const T) usize {
    if (needle.len == 0 or haystack.len < needle.len) return 0;

    var count: usize = 0;
    var i: usize = 0;
    while (i <= haystack.len - needle.len) {
        if (std.mem.eql(T, haystack[i..][0..needle.len], needle)) {
            count += 1;
            i += needle.len; // Non-overlapping
        } else {
            i += 1;
        }
    }
    return count;
}

// ============================================================================
// Parallel Map Operations (apply function to each byte/codepoint)
// ============================================================================

/// Context for parallel map operations
pub fn MapContext(comptime T: type) type {
    return struct {
        input: []const T,
        output: []T,
    };
}

/// Parallel map - apply a function to each element
pub fn parallelMap(
    comptime T: type,
    input: []const T,
    output: []T,
    comptime mapFn: fn (T) T,
) error{InvalidArgument}!void {
    if (input.len != output.len) return error.InvalidArgument;

    if (!build_options.enable_spice or input.len < 10_485_760) {
        for (input, 0..) |v, i| output[i] = mapFn(v);
        return;
    }

    const pool = getPool();
    const Ctx = MapContext(T);
    _ = pool.call(void, ParallelMapTask(T, mapFn).task, Ctx{ .input = input, .output = output });
}

fn ParallelMapTask(comptime T: type, comptime mapFn: fn (T) T) type {
    const Ctx = MapContext(T);
    return struct {
        pub fn task(t: *spice.Task, ctx: Ctx) void {
            const input = ctx.input;
            const output = ctx.output;

            if (input.len < 2048) {
                for (input, 0..) |v, i| output[i] = mapFn(v);
                return;
            }

            const mid = input.len / 2;
            const left_ctx = Ctx{ .input = input[0..mid], .output = output[0..mid] };
            const right_ctx = Ctx{ .input = input[mid..], .output = output[mid..] };

            var fut = spice.Future(Ctx, void).init();
            fut.fork(t, task, right_ctx);

            t.call(void, task, left_ctx);
            if (fut.join(t) == null) {
                t.call(void, task, right_ctx);
            }
        }
    };
}

// ============================================================================
// Parallel Edit Distance (Levenshtein) for Batch Operations
// ============================================================================

/// Context for batch edit distance
pub const EditDistanceBatchContext = struct {
    source: []const u8,
    targets: []const []const u8,
    results: []usize,
};

/// Compute edit distance for multiple targets in parallel
pub fn parallelEditDistanceBatch(
    source: []const u8,
    targets: []const []const u8,
    results: []usize,
    allocator: std.mem.Allocator,
) !void {
    if (targets.len != results.len) return error.InvalidArgument;

    if (!build_options.enable_spice or targets.len < 8) {
        for (targets, 0..) |target, i| {
            results[i] = try editDistance(source, target, allocator);
        }
        return;
    }

    const pool = getPool();
    _ = pool.call(void, ParallelEditDistanceBatchTask().task, EditDistanceBatchContext{
        .source = source,
        .targets = targets,
        .results = results,
    });
}

fn ParallelEditDistanceBatchTask() type {
    return struct {
        pub fn task(t: *spice.Task, ctx: EditDistanceBatchContext) void {
            const source = ctx.source;
            const targets = ctx.targets;
            const results = ctx.results;

            if (targets.len < 4) {
                for (targets, 0..) |target, i| {
                    // Use stack-based allocator to avoid mmap/munmap syscalls per call.
                    // 8KB covers edit distance for strings up to ~511 chars;
                    // falls back to page_allocator for longer strings.
                    const needed = 2 * (@max(source.len, target.len) + 1) * @sizeOf(usize);
                    if (needed <= 8192) {
                        var buf: [8192]u8 = undefined;
                        var fba = std.heap.FixedBufferAllocator.init(&buf);
                        results[i] = editDistance(source, target, fba.allocator()) catch std.math.maxInt(usize);
                    } else {
                        results[i] = editDistance(source, target, std.heap.page_allocator) catch std.math.maxInt(usize);
                    }
                }
                return;
            }

            const mid = targets.len / 2;
            const left_ctx = EditDistanceBatchContext{
                .source = source,
                .targets = targets[0..mid],
                .results = results[0..mid],
            };
            const right_ctx = EditDistanceBatchContext{
                .source = source,
                .targets = targets[mid..],
                .results = results[mid..],
            };

            var fut = spice.Future(EditDistanceBatchContext, void).init();
            fut.fork(t, task, right_ctx);

            t.call(void, task, left_ctx);
            if (fut.join(t) == null) {
                t.call(void, task, right_ctx);
            }
        }
    };
}

/// Single edit distance calculation (Levenshtein)
fn editDistance(a: []const u8, b: []const u8, allocator: std.mem.Allocator) !usize {
    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;

    // Use two rows for space optimization
    var prev = try allocator.alloc(usize, b.len + 1);
    defer allocator.free(prev);
    var curr = try allocator.alloc(usize, b.len + 1);
    defer allocator.free(curr);

    // Initialize first row
    for (prev, 0..) |*p, j| p.* = j;

    for (a, 0..) |ca, i| {
        curr[0] = i + 1;
        for (b, 0..) |cb, j| {
            const cost: usize = if (ca == cb) 0 else 1;
            curr[j + 1] = @min(
                @min(prev[j + 1] + 1, curr[j] + 1),
                prev[j] + cost,
            );
        }
        std.mem.swap([]usize, &prev, &curr);
    }

    return prev[b.len];
}

// ============================================================================
// Parallel Fuzzy Search
// ============================================================================

/// Result of a fuzzy search
pub const FuzzyResult = struct {
    index: usize,
    score: usize,
};

/// Context for fuzzy search
pub const FuzzySearchContext = struct {
    query: []const u8,
    candidates: []const []const u8,
    results: []FuzzyResult,
};

/// Parallel fuzzy search - find best matches from candidates
pub fn parallelFuzzySearch(
    query: []const u8,
    candidates: []const []const u8,
    results: []FuzzyResult,
    allocator: std.mem.Allocator,
) !void {
    if (candidates.len != results.len) return error.InvalidArgument;

    if (!build_options.enable_spice or candidates.len < 16) {
        for (candidates, 0..) |candidate, i| {
            results[i] = .{
                .index = i,
                .score = try editDistance(query, candidate, allocator),
            };
        }
        return;
    }

    const pool = getPool();
    _ = pool.call(void, ParallelFuzzySearchTask().task, FuzzySearchContext{
        .query = query,
        .candidates = candidates,
        .results = results,
    });
}

fn ParallelFuzzySearchTask() type {
    return struct {
        pub fn task(t: *spice.Task, ctx: FuzzySearchContext) void {
            const query = ctx.query;
            const candidates = ctx.candidates;
            const results = ctx.results;

            if (candidates.len < 8) {
                for (candidates, 0..) |candidate, i| {
                    // Use stack-based allocator to avoid mmap/munmap syscalls per call.
                    // 8KB covers edit distance for strings up to ~511 chars;
                    // falls back to page_allocator for longer strings.
                    const needed = 2 * (@max(query.len, candidate.len) + 1) * @sizeOf(usize);
                    const score = if (needed <= 8192) blk: {
                        var buf: [8192]u8 = undefined;
                        var fba = std.heap.FixedBufferAllocator.init(&buf);
                        break :blk editDistance(query, candidate, fba.allocator()) catch std.math.maxInt(usize);
                    } else editDistance(query, candidate, std.heap.page_allocator) catch std.math.maxInt(usize);
                    results[i] = .{
                        .index = i,
                        .score = score,
                    };
                }
                return;
            }

            const mid = candidates.len / 2;
            const left_ctx = FuzzySearchContext{
                .query = query,
                .candidates = candidates[0..mid],
                .results = results[0..mid],
            };
            const right_ctx = FuzzySearchContext{
                .query = query,
                .candidates = candidates[mid..],
                .results = results[mid..],
            };

            var fut = spice.Future(FuzzySearchContext, void).init();
            fut.fork(t, task, right_ctx);

            t.call(void, task, left_ctx);
            if (fut.join(t) == null) {
                t.call(void, task, right_ctx);
            }

            // Adjust indices for right half
            for (results[mid..]) |*r| {
                r.index += mid;
            }
        }
    };
}

// ============================================================================
// Tests
// ============================================================================

test "parallel count" {
    if (!build_options.enable_spice) return error.SkipZigTest;

    const haystack = "hello world hello world hello";
    const count = parallelCount(u8, haystack, "hello");
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "parallel count large" {
    if (!build_options.enable_spice) return error.SkipZigTest;

    // Create a large string with known pattern
    const allocator = std.testing.allocator;
    const pattern = "needle";
    const filler = "haystack ";
    const repetitions = 1000;

    var builder: std.ArrayList(u8) = .empty;
    defer builder.deinit(allocator);

    var expected_count: usize = 0;
    for (0..repetitions) |_| {
        try builder.appendSlice(allocator, filler);
        try builder.appendSlice(allocator, pattern);
        expected_count += 1;
    }

    const count = parallelCount(u8, builder.items, pattern);
    try std.testing.expectEqual(expected_count, count);
}

test "parallel map" {
    if (!build_options.enable_spice) return error.SkipZigTest;

    const input = "HELLO WORLD";
    var output: [11]u8 = undefined;

    try parallelMap(u8, input, &output, struct {
        fn toLower(c: u8) u8 {
            return if (c >= 'A' and c <= 'Z') c + 32 else c;
        }
    }.toLower);

    try std.testing.expectEqualStrings("hello world", &output);
}

test "parallel map returns InvalidArgument on length mismatch" {
    const input = "HELLO WORLD";
    var output: [5]u8 = undefined;

    const result = parallelMap(u8, input, &output, struct {
        fn toLower(c: u8) u8 {
            return if (c >= 'A' and c <= 'Z') c + 32 else c;
        }
    }.toLower);

    try std.testing.expectError(error.InvalidArgument, result);
}

test "parallel edit distance batch returns InvalidArgument on length mismatch" {
    const source = "hello";
    const targets = [_][]const u8{ "world", "hallo" };
    var results: [1]usize = undefined; // wrong length: 1 vs 2 targets

    const result = parallelEditDistanceBatch(source, &targets, &results, std.testing.allocator);

    try std.testing.expectError(error.InvalidArgument, result);
}

test "parallel fuzzy search returns InvalidArgument on length mismatch" {
    const query = "hello";
    const candidates = [_][]const u8{ "world", "hallo" };
    var results: [1]FuzzyResult = undefined; // wrong length: 1 vs 2 candidates

    const result = parallelFuzzySearch(query, &candidates, &results, std.testing.allocator);

    try std.testing.expectError(error.InvalidArgument, result);
}

test "parallel edit distance batch sequential path" {
    // Test the sequential fallback (< 8 targets) which uses FixedBufferAllocator
    const source = "kitten";
    const targets = [_][]const u8{ "sitting", "kitten", "mitten" };
    var results: [3]usize = undefined;

    try parallelEditDistanceBatch(source, &targets, &results, std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), results[0]); // kitten -> sitting = 3
    try std.testing.expectEqual(@as(usize, 0), results[1]); // kitten -> kitten = 0
    try std.testing.expectEqual(@as(usize, 1), results[2]); // kitten -> mitten = 1
}

test "parallel fuzzy search sequential path" {
    // Test the sequential fallback (< 16 candidates) which uses FixedBufferAllocator
    const query = "hello";
    const candidates = [_][]const u8{ "hello", "hallo", "world" };
    var results: [3]FuzzyResult = undefined;

    try parallelFuzzySearch(query, &candidates, &results, std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 0), results[0].score); // exact match
    try std.testing.expectEqual(@as(usize, 0), results[0].index);
    try std.testing.expectEqual(@as(usize, 1), results[1].score); // 1 edit
    try std.testing.expectEqual(@as(usize, 1), results[1].index);
}
