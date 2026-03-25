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
    /// Stub for spice.Future when spice is disabled.
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

/// Get the global spice thread pool, initializing if needed.
///
/// Thread-safe: This function is safe to call concurrently from multiple
/// threads. Initialization is protected by an internal mutex, ensuring
/// the pool is created exactly once (lazy singleton pattern).
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
///
/// Thread-safe: This function is safe to call concurrently with `getPool()`
/// (protected by the same internal mutex). However, it is NOT safe to call
/// while parallel operations are in-flight -- all operations must have
/// completed before calling this function. Violating this invariant causes
/// undefined behavior.
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

/// Context for parallel count operations.
/// This type holds read-only input slices and is safe to share across threads.
pub fn CountContext(comptime T: type) type {
    return struct {
        haystack: []const T,
        needle: []const T,
    };
}

/// Parallel count of non-overlapping occurrences of needle in haystack.
///
/// Thread-safe: This function is safe to call concurrently from multiple
/// threads. Each invocation operates on its own input slices and internal
/// state. The shared global thread pool is accessed through the
/// mutex-protected `getPool()`.
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
        /// Spice fork/join task: recursively counts needle occurrences in haystack.
        pub fn task(t: *spice.Task, ctx: Ctx) usize {
            const haystack = ctx.haystack;
            const needle = ctx.needle;

            // Base case - use sequential
            if (haystack.len < 2048) {
                return sequentialCount(T, haystack, needle);
            }

            // Fork/join - split haystack at midpoint with no overlap.
            // Each half is counted independently, then a small boundary
            // reconciliation corrects for matches straddling the split.
            const mid = haystack.len / 2;

            const left_ctx = Ctx{ .haystack = haystack[0..mid], .needle = needle };
            const right_ctx = Ctx{ .haystack = haystack[mid..], .needle = needle };

            var fut = spice.Future(Ctx, usize).init();
            fut.fork(t, task, right_ctx);

            const left_count = t.call(usize, task, left_ctx);
            const right_count = if (fut.join(t)) |val| val else t.call(usize, task, right_ctx);

            return reconcileBoundaryCounts(T, haystack, needle, mid, left_count, right_count);
        }
    };
}

/// Reconcile independently-computed left and right counts at a split boundary.
///
/// When a haystack is split at `mid` into [0..mid] and [mid..], each half counts
/// non-overlapping matches independently. The greedy non-overlapping counting is
/// order-dependent: the left half's last match may affect which matches are valid
/// near the boundary. This function corrects for that by:
///
/// 1. Finding the left half's resume position (where its scan stopped)
/// 2. Scanning for straddling matches (starting before mid, ending after mid)
/// 3. If a straddling match is found, re-counting the right portion from after
///    the straddling match instead of using the independently-computed right_count
fn reconcileBoundaryCounts(
    comptime T: type,
    haystack: []const T,
    needle: []const T,
    mid: usize,
    left_count: usize,
    right_count: usize,
) usize {
    if (needle.len <= 1) {
        // Single-element needles can't straddle a split point.
        return left_count + right_count;
    }

    // Find where the left half's sequential scan would resume.
    const left_resume = sequentialCountResume(T, haystack[0..mid], needle);

    // Scan for straddling matches: those starting at left_resume..mid-1
    // that extend past mid (and thus were missed by both halves).
    var straddling: usize = 0;
    var scan_pos = left_resume;
    var last_end = left_resume;

    while (scan_pos < mid and scan_pos + needle.len <= haystack.len) {
        if (std.mem.eql(T, haystack[scan_pos..][0..needle.len], needle)) {
            straddling += 1;
            scan_pos += needle.len;
            last_end = scan_pos;
        } else {
            scan_pos += 1;
        }
    }

    if (last_end > mid) {
        // A straddling match consumed bytes past mid. The right half's
        // independent count may include matches that overlap with the
        // straddling match. Re-count from where the straddling scan ended.
        return left_count + straddling + sequentialCount(T, haystack[last_end..], needle);
    }

    return left_count + straddling + right_count;
}

/// Returns the position where a sequential non-overlapping scan would resume
/// (i.e., the first position not yet consumed after the last match or the
/// position after the last checked byte).
fn sequentialCountResume(comptime T: type, haystack: []const T, needle: []const T) usize {
    if (needle.len == 0 or haystack.len < needle.len) return 0;
    var i: usize = 0;
    while (i <= haystack.len - needle.len) {
        if (std.mem.eql(T, haystack[i..][0..needle.len], needle)) {
            i += needle.len;
        } else {
            i += 1;
        }
    }
    return i;
}

fn sequentialCount(comptime T: type, haystack: []const T, needle: []const T) usize {
    if (needle.len == 0 or haystack.len < needle.len) return 0;

    // SIMD fast-path: single-element needles can use vectorized byte counting
    // instead of the byte-by-byte comparison loop.
    if (needle.len == 1) {
        return countScalar(T, haystack, needle[0]);
    }

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

/// SIMD-accelerated count of scalar occurrences using platform-preferred vector width.
/// Falls back to a simple loop when SIMD is unavailable or the input is too short.
fn countScalar(comptime T: type, haystack: []const T, needle: T) usize {
    // Use the platform's preferred vector width if available.
    if (comptime std.simd.suggestVectorLength(T)) |vec_len| {
        if (!@inComptime() and haystack.len >= vec_len) {
            return countScalarSimd(T, vec_len, haystack, needle);
        }
    }

    var count: usize = 0;
    for (haystack) |elem| {
        if (elem == needle) count += 1;
    }
    return count;
}

/// Inner SIMD loop for countScalar. Processes vec_len elements per iteration.
fn countScalarSimd(comptime T: type, comptime vec_len: comptime_int, haystack: []const T, needle: T) usize {
    const Vec = @Vector(vec_len, T);
    const needle_vec: Vec = @splat(needle);
    const MaskInt = std.meta.Int(.unsigned, vec_len);

    var count: usize = 0;
    var i: usize = 0;

    while (i + vec_len <= haystack.len) {
        const chunk: Vec = haystack[i..][0..vec_len].*;
        const matches = chunk == needle_vec;
        count += @popCount(@as(MaskInt, @bitCast(matches)));
        i += vec_len;
    }

    // Handle remaining elements
    while (i < haystack.len) {
        if (haystack[i] == needle) count += 1;
        i += 1;
    }

    return count;
}

// ============================================================================
// Parallel Map Operations (apply function to each byte/codepoint)
// ============================================================================

/// Context for parallel map operations.
/// Each task operates on a disjoint sub-range of the input/output slices,
/// so concurrent access within a single `parallelMap` call is safe.
pub fn MapContext(comptime T: type) type {
    return struct {
        input: []const T,
        output: []T,
    };
}

/// Parallel map - apply a function to each element.
///
/// Thread-safe: This function is safe to call concurrently from multiple
/// threads provided each call uses distinct `input` and `output` slices.
/// The caller must ensure `output` does not alias with any other
/// concurrently written memory. The shared global thread pool is accessed
/// through the mutex-protected `getPool()`.
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
        /// Spice fork/join task: recursively applies mapFn to each element.
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

/// Context for batch edit distance.
/// Each task operates on a disjoint sub-range of the targets/results slices,
/// so concurrent access within a single `parallelEditDistanceBatch` call is safe.
pub const EditDistanceBatchContext = struct {
    source: []const u8,
    targets: []const []const u8,
    results: []usize,
};

/// Compute edit distance for multiple targets in parallel.
///
/// Thread-safe: This function is safe to call concurrently from multiple
/// threads provided each call uses distinct `results` slices. The `source`
/// and `targets` slices are read-only and may be shared. The shared global
/// thread pool is accessed through the mutex-protected `getPool()`.
///
/// Note: In the parallel execution path (when spice is enabled and input
/// exceeds the parallel threshold), individual computation failures are
/// represented as `std.math.maxInt(usize)` in the results array rather
/// than propagating errors. The sequential path propagates errors normally
/// via `try`.
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
        /// Spice fork/join task: recursively computes edit distance for target batches.
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

/// Context for fuzzy search.
/// Each task operates on a disjoint sub-range of the candidates/results slices,
/// so concurrent access within a single `parallelFuzzySearch` call is safe.
pub const FuzzySearchContext = struct {
    query: []const u8,
    candidates: []const []const u8,
    results: []FuzzyResult,
};

/// Parallel fuzzy search - find best matches from candidates.
///
/// Thread-safe: This function is safe to call concurrently from multiple
/// threads provided each call uses distinct `results` slices. The `query`
/// and `candidates` slices are read-only and may be shared. The shared
/// global thread pool is accessed through the mutex-protected `getPool()`.
///
/// Note: In the parallel execution path (when spice is enabled and input
/// exceeds the parallel threshold), individual computation failures are
/// represented as `std.math.maxInt(usize)` in the results array rather
/// than propagating errors. The sequential path propagates errors normally
/// via `try`.
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
        /// Spice fork/join task: recursively scores fuzzy search candidates.
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
    try builder.ensureTotalCapacity(allocator, repetitions * (filler.len + pattern.len));

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

// ============================================================================
// Tests exercising actual parallel execution paths (above thresholds)
// ============================================================================

test "parallelCount above threshold matches sequential" {
    // Threshold is 4096 bytes. Build input > 4096 bytes with known needle count.
    if (!build_options.enable_spice) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const needle = "FIND";
    // Build a haystack of ~10000 bytes with needles placed every 100 bytes.
    const size = 10_000;
    var buf = try allocator.alloc(u8, size);
    defer allocator.free(buf);

    // Fill with dots
    @memset(buf, '.');

    // Place needles at known positions (non-overlapping, every 100 bytes)
    var expected: usize = 0;
    var pos: usize = 0;
    while (pos + needle.len <= size) : (pos += 100) {
        @memcpy(buf[pos..][0..needle.len], needle);
        expected += 1;
    }

    // Verify input exceeds the parallel threshold
    try std.testing.expect(buf.len >= 4096);

    const parallel_result = parallelCount(u8, buf, needle);
    const sequential_result = sequentialCount(u8, buf, needle);

    try std.testing.expectEqual(sequential_result, parallel_result);
    try std.testing.expectEqual(expected, parallel_result);
}

test "parallelEditDistanceBatch above threshold" {
    // Threshold is 8 targets. Use 10 targets to exercise the parallel path.
    if (!build_options.enable_spice) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const source = "kitten";
    const target_count = 10;
    const targets = [target_count][]const u8{
        "kitten", // 0
        "sitting", // 3
        "mitten", // 1
        "bitten", // 1
        "kittens", // 1
        "kitchen", // 2
        "written", // 2
        "hidden", // 3
        "kitten", // 0
        "butter", // 4
    };
    var results: [target_count]usize = undefined;

    // Verify we exceed the threshold
    try std.testing.expect(target_count >= 8);

    try parallelEditDistanceBatch(source, &targets, &results, allocator);

    // Compute expected via sequential path for comparison
    var expected: [target_count]usize = undefined;
    for (targets, 0..) |target, i| {
        expected[i] = try editDistance(source, target, allocator);
    }

    for (0..target_count) |i| {
        try std.testing.expectEqual(expected[i], results[i]);
    }

    // Also verify some known values
    try std.testing.expectEqual(@as(usize, 0), results[0]); // kitten -> kitten
    try std.testing.expectEqual(@as(usize, 3), results[1]); // kitten -> sitting
    try std.testing.expectEqual(@as(usize, 1), results[2]); // kitten -> mitten
    try std.testing.expectEqual(@as(usize, 0), results[8]); // kitten -> kitten
}

test "parallelFuzzySearch above threshold" {
    // Threshold is 16 candidates. Use 20 candidates to exercise the parallel path.
    if (!build_options.enable_spice) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    const query = "hello";
    const candidate_count = 20;
    const candidates = [candidate_count][]const u8{
        "hello", // 0 - exact
        "hallo", // 1
        "world", // 4
        "help", // 2
        "shell", // 3
        "yellow", // 2
        "below", // 3
        "mellow", // 2
        "fellow", // 3
        "cello", // 1
        "jello", // 1
        "helloo", // 1
        "hell", // 1
        "he", // 3
        "hero", // 2
        "heron", // 3
        "melon", // 3
        "hilly", // 2
        "holly", // 2
        "hullo", // 1
    };
    var results: [candidate_count]FuzzyResult = undefined;

    // Verify we exceed the threshold
    try std.testing.expect(candidate_count >= 16);

    try parallelFuzzySearch(query, &candidates, &results, allocator);

    // Compute expected via sequential edit distance for comparison
    var expected_scores: [candidate_count]usize = undefined;
    for (candidates, 0..) |candidate, i| {
        expected_scores[i] = try editDistance(query, candidate, allocator);
    }

    for (0..candidate_count) |i| {
        try std.testing.expectEqual(expected_scores[i], results[i].score);
        try std.testing.expectEqual(i, results[i].index);
    }

    // Verify the exact match
    try std.testing.expectEqual(@as(usize, 0), results[0].score);
}

test "parallelMap sequential fallback with small input" {
    // parallelMap threshold is 10MB. A small input exercises the sequential fallback.
    // This test verifies correctness of the sequential path.
    const input = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    var output: [26]u8 = undefined;

    try parallelMap(u8, input, &output, struct {
        fn toLower(c: u8) u8 {
            return if (c >= 'A' and c <= 'Z') c + 32 else c;
        }
    }.toLower);

    try std.testing.expectEqualStrings("abcdefghijklmnopqrstuvwxyz", &output);
}

test "parallelCount empty needle returns zero" {
    const haystack = "hello world";
    try std.testing.expectEqual(@as(usize, 0), parallelCount(u8, haystack, ""));
}

test "parallelCount haystack shorter than needle returns zero" {
    const haystack = "hi";
    try std.testing.expectEqual(@as(usize, 0), parallelCount(u8, haystack, "hello"));
}

test "sequentialCount boundary reconciliation with dense repeating pattern" {
    // Regression test for S25: when a repeating needle pattern spans the split
    // midpoint, the old overlap-deduction approach could double-count because
    // the greedy non-overlapping scan consumed bytes differently in each half.
    //
    // Example: "AAAAA" with needle "AAA" and mid=2:
    //   Old left [0..4]="AAAA" -> 1, old right [2..]="AAA" -> 1, overlap=0 -> 2 (WRONG, expected 1)
    //
    // The fix uses clean splits with boundary reconciliation.

    // Dense "AAA" in all-A buffer at various sizes
    const allocator = std.testing.allocator;
    const test_sizes = [_]usize{ 5, 8, 11, 14, 17, 20, 50, 100 };

    for (test_sizes) |size| {
        const buf = try allocator.alloc(u8, size);
        defer allocator.free(buf);
        @memset(buf, 'A');

        const expected = size / 3; // "AAA" non-overlapping in all-A string
        const mid = size / 2;
        const left_count = sequentialCount(u8, buf[0..mid], "AAA");
        const right_count = sequentialCount(u8, buf[mid..], "AAA");
        const reconciled = reconcileBoundaryCounts(u8, buf, "AAA", mid, left_count, right_count);
        try std.testing.expectEqual(expected, reconciled);
    }

    // Dense "AA" pattern
    for (test_sizes) |size| {
        if (size < 4) continue;
        const buf = try allocator.alloc(u8, size);
        defer allocator.free(buf);
        @memset(buf, 'A');

        const expected = size / 2; // "AA" non-overlapping in all-A string
        const mid = size / 2;
        const left_count = sequentialCount(u8, buf[0..mid], "AA");
        const right_count = sequentialCount(u8, buf[mid..], "AA");
        const reconciled = reconcileBoundaryCounts(u8, buf, "AA", mid, left_count, right_count);
        try std.testing.expectEqual(expected, reconciled);
    }
}

test "reconcileBoundaryCounts with alternating pattern" {
    // "ABABABABABAB..." with needle "ABAB" -- tests periodic patterns
    const allocator = std.testing.allocator;
    const test_sizes = [_]usize{ 10, 11, 18, 19, 26, 50, 100 };

    for (test_sizes) |size| {
        const buf = try allocator.alloc(u8, size);
        defer allocator.free(buf);
        for (buf, 0..) |*c, i| {
            c.* = if (i % 2 == 0) 'A' else 'B';
        }

        const expected = sequentialCount(u8, buf, "ABAB");
        const mid = size / 2;
        const left_count = sequentialCount(u8, buf[0..mid], "ABAB");
        const right_count = sequentialCount(u8, buf[mid..], "ABAB");
        const reconciled = reconcileBoundaryCounts(u8, buf, "ABAB", mid, left_count, right_count);
        try std.testing.expectEqual(expected, reconciled);
    }
}

test "countScalar SIMD fast-path for single-byte needle" {
    // Verifies that the SIMD-accelerated countScalar produces correct results
    // for various input sizes, including sizes below, at, and above typical
    // vector widths (16, 32, 64 bytes).
    const allocator = std.testing.allocator;

    // Small input (below any vector width)
    try std.testing.expectEqual(@as(usize, 2), countScalar(u8, "hello", 'l'));
    try std.testing.expectEqual(@as(usize, 0), countScalar(u8, "hello", 'x'));
    try std.testing.expectEqual(@as(usize, 1), countScalar(u8, "a", 'a'));
    try std.testing.expectEqual(@as(usize, 0), countScalar(u8, "", 'a'));

    // Exactly 16 bytes (SSE2 vector width)
    try std.testing.expectEqual(@as(usize, 16), countScalar(u8, "aaaaaaaaaaaaaaaa", 'a'));

    // Large input exercising SIMD loop + remainder
    const sizes = [_]usize{ 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 255, 256, 500, 1000 };
    for (sizes) |size| {
        const buf = try allocator.alloc(u8, size);
        defer allocator.free(buf);

        // Fill with alternating pattern: every 3rd byte is the target
        for (buf, 0..) |*c, i| {
            c.* = if (i % 3 == 0) 'X' else '.';
        }
        const expected = (size + 2) / 3; // ceil(size/3)
        try std.testing.expectEqual(expected, countScalar(u8, buf, 'X'));
    }
}

test "sequentialCount uses countScalar for single-byte needle" {
    // Verify that sequentialCount correctly dispatches to countScalar
    // for single-byte needles and produces correct results.
    try std.testing.expectEqual(@as(usize, 4), sequentialCount(u8, "aabaa", "a"));
    try std.testing.expectEqual(@as(usize, 0), sequentialCount(u8, "hello", "x"));
    try std.testing.expectEqual(@as(usize, 5), sequentialCount(u8, "aaaaa", "a"));

    // Verify multi-byte still works
    try std.testing.expectEqual(@as(usize, 2), sequentialCount(u8, "abab", "ab"));
    try std.testing.expectEqual(@as(usize, 1), sequentialCount(u8, "aaa", "aa"));
}
