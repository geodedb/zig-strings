// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Parallel string operations using thread-pool flat task submission.
//!
//! Provides low-overhead parallelism for compute-intensive string operations
//! using the submitBatch/WaitGroup pattern.
//!
//! ## Pool Lifecycle
//!
//! This module maintains a lazily-initialized global thread pool. The pool is
//! created on first use (via `getPool()`) and is **never freed** unless
//! `deinitPool()` is explicitly called by the caller. Callers must ensure that
//! all parallel operations have completed before calling `deinitPool()`;
//! calling it while operations are in-flight causes undefined behavior.

const std = @import("std");
const tp = @import("thread_pool");

// ============================================================================
// Global Thread Pool
// ============================================================================

var global_pool: ?tp.ThreadPool = null;
var pool_mutex: std.Io.Mutex = .init;

inline fn io() std.Io {
    return std.Io.Threaded.global_single_threaded.io();
}

/// Get the global thread pool, initializing if needed.
///
/// Thread-safe: This function is safe to call concurrently from multiple
/// threads. Initialization is protected by an internal mutex, ensuring
/// the pool is created exactly once (lazy singleton pattern).
pub fn getPool() *tp.ThreadPool {
    pool_mutex.lockUncancelable(io());
    defer pool_mutex.unlock(io());

    if (global_pool == null) {
        global_pool = tp.ThreadPool.init(std.heap.page_allocator, .{}) catch
            @panic("thread-pool: init failed");
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
    pool_mutex.lockUncancelable(io());
    defer pool_mutex.unlock(io());

    if (global_pool) |*pool| {
        pool.deinit();
        global_pool = null;
    }
}

// ============================================================================
// Error Sentinel
// ============================================================================

/// Sentinel value used in parallel batch results to indicate that an individual
/// computation failed. Parallel execution paths (edit distance, fuzzy search)
/// cannot propagate errors from submitted tasks, so failures are represented as
/// this sentinel value in the results array.
pub const error_sentinel: usize = std.math.maxInt(usize);

/// Returns true if `score` is the error sentinel, indicating a failed computation.
pub fn isErrorSentinel(score: usize) bool {
    return score == error_sentinel;
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

const MAX_CHUNKS = 64;

/// Chunk context for parallelCount.
fn CountChunk(comptime T: type) type {
    return struct {
        haystack: []const T,
        needle: []const T,
        result: usize,
    };
}

fn countChunkTask(comptime T: type) tp.TaskFn {
    return struct {
        fn run(ctx_ptr: *anyopaque, _: *tp.TaskContext) void {
            const chunk: *CountChunk(T) = @ptrCast(@alignCast(ctx_ptr));
            chunk.result = sequentialCount(T, chunk.haystack, chunk.needle);
        }
    }.run;
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

    // Use sequential for small inputs
    if (haystack.len < 4096) {
        return sequentialCount(T, haystack, needle);
    }

    const pool = getPool();
    const chunk_size = @max(2048, haystack.len / MAX_CHUNKS);
    var chunks: [MAX_CHUNKS]CountChunk(T) = undefined;
    var batch: [MAX_CHUNKS]tp.BatchTask = undefined;
    var n: usize = 0;
    var i: usize = 0;
    while (i < haystack.len and n < MAX_CHUNKS) {
        const end = @min(i + chunk_size, haystack.len);
        chunks[n] = .{ .haystack = haystack[i..end], .needle = needle, .result = 0 };
        batch[n] = .{ .task_fn = countChunkTask(T), .ctx = @ptrCast(&chunks[n]) };
        n += 1;
        i = end;
    }

    var wg = pool.waitGroup();
    _ = pool.submitBatch(batch[0..n], .{ .wait_group = &wg }) catch {
        return sequentialCount(T, haystack, needle);
    };
    wg.wait();

    // Sum chunk counts, reconciling boundaries between adjacent chunks.
    // For each boundary at position `mid`, the right chunk counted [mid..chunk_end)
    // independently. If a needle straddles `mid`, neither half counted it and we
    // must correct. When a straddle forces a re-scan, we scan only [last_end..chunk_end)
    // so we don't bleed into future chunks.
    var total: usize = 0;
    var chunk_start: usize = 0;
    for (0..n) |ci| {
        const chunk_end = chunk_start + chunks[ci].haystack.len;
        if (ci == 0) {
            total += chunks[ci].result;
        } else {
            const mid = chunk_start;
            total = reconcileBoundaryCountsBounded(T, haystack, needle, mid, chunk_end, total, chunks[ci].result);
        }
        chunk_start = chunk_end;
    }
    return total;
}

/// Reconcile independently-computed left and right counts at a split boundary.
///
/// `mid` is the split point; the left side covers [0..mid) and the right side
/// covers [mid..right_end). The right side's count was computed independently on
/// [mid..right_end); if a needle straddles `mid`, neither half counted it.
///
/// When a straddle is found, we re-scan [last_end..right_end) sequentially rather
/// than relying on right_count, so we don't bleed into future chunks.
fn reconcileBoundaryCountsBounded(
    comptime T: type,
    haystack: []const T,
    needle: []const T,
    mid: usize,
    right_end: usize,
    left_count: usize,
    right_count: usize,
) usize {
    if (needle.len <= 1) {
        // Single-element needles can't straddle a split point.
        return left_count + right_count;
    }

    // Find where the left half's sequential scan would resume.
    const left_resume = sequentialCountResume(T, haystack[0..mid], needle);

    // Scan for straddling matches: those starting in [left_resume..mid) that
    // extend past mid (and thus were missed by both halves).
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
        // A straddling match consumed bytes past mid. Re-count [last_end..right_end)
        // so we don't bleed counts into future chunks.
        return left_count + straddling + sequentialCount(T, haystack[last_end..right_end], needle);
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

fn MapChunk(comptime T: type, comptime mapFn: fn (T) T) type {
    return struct {
        input: []const T,
        output: []T,

        fn run(ctx_ptr: *anyopaque, _: *tp.TaskContext) void {
            const chunk: *@This() = @ptrCast(@alignCast(ctx_ptr));
            for (chunk.input, 0..) |v, i| chunk.output[i] = mapFn(v);
        }
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

    // Threshold chosen to match parallelCount's scale (~4 KB base, ~64 KB for map).
    // Map applies a simple fn(T) T per element — comparable overhead to counting.
    if (input.len < 65_536) {
        for (input, 0..) |v, i| output[i] = mapFn(v);
        return;
    }

    const pool = getPool();
    const Chunk = MapChunk(T, mapFn);
    const chunk_size = @max(2048, input.len / MAX_CHUNKS);
    var chunks: [MAX_CHUNKS]Chunk = undefined;
    var batch: [MAX_CHUNKS]tp.BatchTask = undefined;
    var n: usize = 0;
    var i: usize = 0;
    while (i < input.len and n < MAX_CHUNKS) {
        const end = @min(i + chunk_size, input.len);
        chunks[n] = .{ .input = input[i..end], .output = output[i..end] };
        batch[n] = .{ .task_fn = &Chunk.run, .ctx = @ptrCast(&chunks[n]) };
        n += 1;
        i = end;
    }

    var wg = pool.waitGroup();
    _ = pool.submitBatch(batch[0..n], .{ .wait_group = &wg }) catch {
        for (input, 0..) |v, j| output[j] = mapFn(v);
        return;
    };
    wg.wait();
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

const EditDistanceChunk = struct {
    source: []const u8,
    targets: []const []const u8,
    results: []usize,

    fn run(ctx_ptr: *anyopaque, _: *tp.TaskContext) void {
        const chunk: *EditDistanceChunk = @ptrCast(@alignCast(ctx_ptr));
        for (chunk.targets, 0..) |target, i| {
            // Use stack-based allocator to avoid mmap/munmap syscalls per call.
            // 8KB covers edit distance for strings up to ~511 chars;
            // falls back to page_allocator for longer strings.
            const needed = 2 * (@max(chunk.source.len, target.len) + 1) * @sizeOf(usize);
            if (needed <= 8192) {
                var buf: [8192]u8 = undefined;
                var fba = std.heap.FixedBufferAllocator.init(&buf);
                chunk.results[i] = editDistance(chunk.source, target, fba.allocator()) catch error_sentinel;
            } else {
                chunk.results[i] = editDistance(chunk.source, target, std.heap.page_allocator) catch error_sentinel;
            }
        }
    }
};

/// Compute edit distance for multiple targets in parallel.
///
/// Thread-safe: This function is safe to call concurrently from multiple
/// threads provided each call uses distinct `results` slices. The `source`
/// and `targets` slices are read-only and may be shared. The shared global
/// thread pool is accessed through the mutex-protected `getPool()`.
///
/// Note: In the parallel execution path, individual computation failures are
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

    if (targets.len < 8) {
        for (targets, 0..) |target, i| {
            results[i] = try editDistance(source, target, allocator);
        }
        return;
    }

    const pool = getPool();
    const chunk_size = @max(4, targets.len / MAX_CHUNKS);
    var chunks: [MAX_CHUNKS]EditDistanceChunk = undefined;
    var batch: [MAX_CHUNKS]tp.BatchTask = undefined;
    var n: usize = 0;
    var i: usize = 0;
    while (i < targets.len and n < MAX_CHUNKS) {
        const end = @min(i + chunk_size, targets.len);
        chunks[n] = .{ .source = source, .targets = targets[i..end], .results = results[i..end] };
        batch[n] = .{ .task_fn = &EditDistanceChunk.run, .ctx = @ptrCast(&chunks[n]) };
        n += 1;
        i = end;
    }

    var wg = pool.waitGroup();
    _ = pool.submitBatch(batch[0..n], .{ .wait_group = &wg }) catch {
        for (targets, 0..) |target, j| {
            results[j] = try editDistance(source, target, allocator);
        }
        return;
    };
    wg.wait();
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

const FuzzySearchChunk = struct {
    query: []const u8,
    candidates: []const []const u8,
    results: []FuzzyResult,
    base_index: usize,

    fn run(ctx_ptr: *anyopaque, _: *tp.TaskContext) void {
        const chunk: *FuzzySearchChunk = @ptrCast(@alignCast(ctx_ptr));
        for (chunk.candidates, 0..) |candidate, i| {
            // Use stack-based allocator to avoid mmap/munmap syscalls per call.
            // 8KB covers edit distance for strings up to ~511 chars;
            // falls back to page_allocator for longer strings.
            const needed = 2 * (@max(chunk.query.len, candidate.len) + 1) * @sizeOf(usize);
            const score = if (needed <= 8192) blk: {
                var buf: [8192]u8 = undefined;
                var fba = std.heap.FixedBufferAllocator.init(&buf);
                break :blk editDistance(chunk.query, candidate, fba.allocator()) catch error_sentinel;
            } else editDistance(chunk.query, candidate, std.heap.page_allocator) catch error_sentinel;
            chunk.results[i] = .{
                .index = chunk.base_index + i,
                .score = score,
            };
        }
    }
};

/// Parallel fuzzy search - find best matches from candidates.
///
/// Thread-safe: This function is safe to call concurrently from multiple
/// threads provided each call uses distinct `results` slices. The `query`
/// and `candidates` slices are read-only and may be shared. The shared global
/// thread pool is accessed through the mutex-protected `getPool()`.
///
/// Note: In the parallel execution path, individual computation failures are
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

    if (candidates.len < 16) {
        for (candidates, 0..) |candidate, i| {
            results[i] = .{
                .index = i,
                .score = try editDistance(query, candidate, allocator),
            };
        }
        return;
    }

    const pool = getPool();
    const chunk_size = @max(8, candidates.len / MAX_CHUNKS);
    var chunks: [MAX_CHUNKS]FuzzySearchChunk = undefined;
    var batch: [MAX_CHUNKS]tp.BatchTask = undefined;
    var n: usize = 0;
    var i: usize = 0;
    while (i < candidates.len and n < MAX_CHUNKS) {
        const end = @min(i + chunk_size, candidates.len);
        chunks[n] = .{
            .query = query,
            .candidates = candidates[i..end],
            .results = results[i..end],
            .base_index = i,
        };
        batch[n] = .{ .task_fn = &FuzzySearchChunk.run, .ctx = @ptrCast(&chunks[n]) };
        n += 1;
        i = end;
    }

    var wg = pool.waitGroup();
    _ = pool.submitBatch(batch[0..n], .{ .wait_group = &wg }) catch {
        for (candidates, 0..) |candidate, j| {
            results[j] = .{
                .index = j,
                .score = try editDistance(query, candidate, allocator),
            };
        }
        return;
    };
    wg.wait();
}

// ============================================================================
// Parallel Normalization (NFC/NFD/NFKC/NFKD)
// ============================================================================

const normalization = @import("normalization");
const case_mod = @import("case");
const types = @import("types");

const NormChunk = struct {
    input: []const u8,
    chunk_start: usize,
    chunk_end: usize,
    result: []u8,
    form_val: types.NormalizationForm,

    fn run(ctx_ptr: *anyopaque, _: *tp.TaskContext) void {
        const chunk: *NormChunk = @ptrCast(@alignCast(ctx_ptr));
        const slice = chunk.input[chunk.chunk_start..chunk.chunk_end];
        chunk.result = normalization.normalize(std.heap.page_allocator, slice, chunk.form_val) catch &.{};
    }
};

/// Parallel Unicode normalization.
///
/// Splits the input at ASCII byte boundaries (which are always normalization-safe
/// since ASCII codepoints have CCC=0 and cannot participate in composition), then
/// normalizes each chunk in parallel and concatenates the results.
///
/// Thread-safe: This function is safe to call concurrently from multiple threads.
/// Each invocation allocates its own intermediate buffers.
///
/// Falls back to sequential normalization for inputs smaller than 64 KB.
pub fn parallelNormalize(
    allocator: std.mem.Allocator,
    utf8: []const u8,
    form: types.NormalizationForm,
) ![]u8 {
    // Sequential fallback for small inputs
    if (utf8.len < 65_536) {
        return normalization.normalize(allocator, utf8, form);
    }

    // Find chunk boundaries at ASCII bytes. We need at least 2 chunks to
    // benefit from parallelism, targeting ~4 chunks for typical workloads.
    const target_chunks: usize = 4;
    const chunk_size = utf8.len / target_chunks;

    var boundaries: [5]usize = undefined; // max 4 chunks = 5 boundary points
    boundaries[0] = 0;
    var n_boundaries: usize = 1;

    var i: usize = 1;
    while (i < target_chunks and n_boundaries < 5) : (i += 1) {
        const target_pos = i * chunk_size;
        // Scan for an ASCII byte near the target position
        if (findAsciiNear(utf8, target_pos, chunk_size / 2)) |pos| {
            // Split right after the ASCII byte
            if (pos + 1 > boundaries[n_boundaries - 1]) {
                boundaries[n_boundaries] = pos + 1;
                n_boundaries += 1;
            }
        }
    }
    boundaries[n_boundaries] = utf8.len;
    n_boundaries += 1;
    const n_chunks = n_boundaries - 1;

    // Need at least 2 chunks for parallelism to be worthwhile
    if (n_chunks < 2) {
        return normalization.normalize(allocator, utf8, form);
    }

    var chunks: [4]NormChunk = undefined;
    var batch: [4]tp.BatchTask = undefined;

    for (0..n_chunks) |ci| {
        chunks[ci] = .{
            .input = utf8,
            .chunk_start = boundaries[ci],
            .chunk_end = boundaries[ci + 1],
            .result = &.{},
            .form_val = form,
        };
        batch[ci] = .{ .task_fn = &NormChunk.run, .ctx = @ptrCast(&chunks[ci]) };
    }

    const pool = getPool();
    var wg = pool.waitGroup();
    _ = pool.submitBatch(batch[0..n_chunks], .{ .wait_group = &wg }) catch {
        return normalization.normalize(allocator, utf8, form);
    };
    wg.wait();

    // Free chunk results on error
    var chunks_initialized: usize = n_chunks;
    errdefer for (chunks[0..chunks_initialized]) |*c| {
        if (c.result.len > 0) std.heap.page_allocator.free(c.result);
    };

    // Calculate total output size and concatenate
    var total_len: usize = 0;
    for (chunks[0..n_chunks]) |c| total_len += c.result.len;

    const result = try allocator.alloc(u8, total_len);
    var off: usize = 0;
    for (chunks[0..n_chunks]) |*c| {
        @memcpy(result[off..][0..c.result.len], c.result);
        off += c.result.len;
        if (c.result.len > 0) std.heap.page_allocator.free(c.result);
        c.result = &.{};
    }
    chunks_initialized = 0;

    return result;
}

/// Find an ASCII byte (< 0x80) near `target_pos` within `radius` bytes.
fn findAsciiNear(utf8: []const u8, target_pos: usize, radius: usize) ?usize {
    const start = if (target_pos > radius) target_pos - radius else 0;
    const end = @min(target_pos + radius, utf8.len);

    // Search outward from target position
    var dist: usize = 0;
    while (dist <= radius) : (dist += 1) {
        if (target_pos + dist < end and utf8[target_pos + dist] < 0x80) {
            return target_pos + dist;
        }
        if (dist > 0 and target_pos >= dist and target_pos - dist >= start) {
            if (utf8[target_pos - dist] < 0x80) {
                return target_pos - dist;
            }
        }
    }
    return null;
}

// ============================================================================
// Parallel Case Conversion
// ============================================================================

/// Case conversion direction
pub const CaseDirection = enum { lower, upper };

const CaseChunk = struct {
    input: []const u8,
    chunk_start: usize,
    chunk_end: usize,
    result: []u8,
    dir: CaseDirection,

    fn run(ctx_ptr: *anyopaque, _: *tp.TaskContext) void {
        const chunk: *CaseChunk = @ptrCast(@alignCast(ctx_ptr));
        const slice = chunk.input[chunk.chunk_start..chunk.chunk_end];
        chunk.result = switch (chunk.dir) {
            .lower => case_mod.toLowerString(std.heap.page_allocator, slice) catch &.{},
            .upper => case_mod.toUpperString(std.heap.page_allocator, slice) catch &.{},
        };
    }
};

/// Parallel case conversion (toLower/toUpper).
///
/// Splits the input at UTF-8 sequence boundaries and converts each chunk in
/// parallel. Case conversion is codepoint-independent (no cross-boundary
/// dependencies), so any UTF-8 sequence boundary is a safe split point.
///
/// Thread-safe: This function is safe to call concurrently from multiple threads.
///
/// Falls back to sequential conversion for inputs smaller than 64 KB.
pub fn parallelCaseConvert(
    allocator: std.mem.Allocator,
    utf8: []const u8,
    direction: CaseDirection,
) ![]u8 {
    // Sequential fallback
    if (utf8.len < 65_536) {
        return switch (direction) {
            .lower => case_mod.toLowerString(allocator, utf8),
            .upper => case_mod.toUpperString(allocator, utf8),
        };
    }

    const target_chunks: usize = 4;
    const chunk_size = utf8.len / target_chunks;

    var boundaries: [5]usize = undefined;
    boundaries[0] = 0;
    var n_boundaries: usize = 1;

    var idx: usize = 1;
    while (idx < target_chunks and n_boundaries < 5) : (idx += 1) {
        var pos = idx * chunk_size;
        // Advance to a UTF-8 sequence boundary (skip continuation bytes 10xxxxxx)
        while (pos < utf8.len and (utf8[pos] & 0xC0) == 0x80) {
            pos += 1;
        }
        if (pos > boundaries[n_boundaries - 1] and pos < utf8.len) {
            boundaries[n_boundaries] = pos;
            n_boundaries += 1;
        }
    }
    boundaries[n_boundaries] = utf8.len;
    n_boundaries += 1;
    const n_chunks = n_boundaries - 1;

    if (n_chunks < 2) {
        return switch (direction) {
            .lower => case_mod.toLowerString(allocator, utf8),
            .upper => case_mod.toUpperString(allocator, utf8),
        };
    }

    var chunks: [4]CaseChunk = undefined;
    var batch: [4]tp.BatchTask = undefined;

    for (0..n_chunks) |ci| {
        chunks[ci] = .{
            .input = utf8,
            .chunk_start = boundaries[ci],
            .chunk_end = boundaries[ci + 1],
            .result = &.{},
            .dir = direction,
        };
        batch[ci] = .{ .task_fn = &CaseChunk.run, .ctx = @ptrCast(&chunks[ci]) };
    }

    const pool = getPool();
    var wg = pool.waitGroup();
    _ = pool.submitBatch(batch[0..n_chunks], .{ .wait_group = &wg }) catch {
        return switch (direction) {
            .lower => case_mod.toLowerString(allocator, utf8),
            .upper => case_mod.toUpperString(allocator, utf8),
        };
    };
    wg.wait();

    var chunks_initialized: usize = n_chunks;
    errdefer for (chunks[0..chunks_initialized]) |*c| {
        if (c.result.len > 0) std.heap.page_allocator.free(c.result);
    };

    var total_len: usize = 0;
    for (chunks[0..n_chunks]) |c| total_len += c.result.len;

    const result = try allocator.alloc(u8, total_len);
    var offset: usize = 0;
    for (chunks[0..n_chunks]) |*c| {
        @memcpy(result[offset..][0..c.result.len], c.result);
        offset += c.result.len;
        if (c.result.len > 0) std.heap.page_allocator.free(c.result);
        c.result = &.{};
    }
    chunks_initialized = 0;

    return result;
}

// ============================================================================
// Tests
// ============================================================================

test "parallel count" {
    const haystack = "hello world hello world hello";
    const count = parallelCount(u8, haystack, "hello");
    try std.testing.expectEqual(@as(usize, 3), count);
}

test "parallel count large" {
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
