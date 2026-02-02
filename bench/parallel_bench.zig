//! ZigStr Parallel Operations Benchmark
//!
//! Compares sequential vs spice-parallel string operations.

const std = @import("std");
const parallel = @import("parallel");

const WARMUP_RUNS = 3;
const BENCH_RUNS = 5;

const BenchResult = struct {
    seq_ns: u64,
    par_ns: u64,

    fn speedup(self: BenchResult) f64 {
        if (self.par_ns == 0) return 0;
        return @as(f64, @floatFromInt(self.seq_ns)) / @as(f64, @floatFromInt(self.par_ns));
    }

    fn seqMs(self: BenchResult) f64 {
        return @as(f64, @floatFromInt(self.seq_ns)) / 1_000_000.0;
    }

    fn parMs(self: BenchResult) f64 {
        return @as(f64, @floatFromInt(self.par_ns)) / 1_000_000.0;
    }
};

// Sequential implementations for comparison
fn sequentialCount(haystack: []const u8, needle: []const u8) usize {
    if (needle.len == 0 or haystack.len < needle.len) return 0;

    var count: usize = 0;
    var i: usize = 0;
    while (i <= haystack.len - needle.len) {
        if (std.mem.eql(u8, haystack[i..][0..needle.len], needle)) {
            count += 1;
            i += needle.len;
        } else {
            i += 1;
        }
    }
    return count;
}

fn sequentialMap(input: []const u8, output: []u8, comptime mapFn: fn (u8) u8) void {
    for (input, 0..) |c, i| output[i] = mapFn(c);
}

fn toLower(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn benchParallelCount(allocator: std.mem.Allocator, size: usize) !BenchResult {
    // Create haystack with repeated pattern
    const pattern = "needle";
    const filler = "haystack ";
    const unit_len = pattern.len + filler.len;

    const haystack = try allocator.alloc(u8, size);
    defer allocator.free(haystack);

    var pos: usize = 0;
    while (pos + unit_len <= size) {
        @memcpy(haystack[pos..][0..filler.len], filler);
        pos += filler.len;
        @memcpy(haystack[pos..][0..pattern.len], pattern);
        pos += pattern.len;
    }
    // Fill remainder
    for (haystack[pos..]) |*c| c.* = 'x';

    // Warmup
    for (0..WARMUP_RUNS) |_| {
        _ = sequentialCount(haystack, pattern);
        _ = parallel.parallelCount(u8, haystack, pattern);
    }

    // Benchmark sequential
    var seq_total: u64 = 0;
    for (0..BENCH_RUNS) |_| {
        var timer = try std.time.Timer.start();
        const result = sequentialCount(haystack, pattern);
        seq_total += timer.read();
        std.mem.doNotOptimizeAway(&result);
    }

    // Benchmark parallel
    var par_total: u64 = 0;
    for (0..BENCH_RUNS) |_| {
        var timer = try std.time.Timer.start();
        const result = parallel.parallelCount(u8, haystack, pattern);
        par_total += timer.read();
        std.mem.doNotOptimizeAway(&result);
    }

    return .{ .seq_ns = seq_total / BENCH_RUNS, .par_ns = par_total / BENCH_RUNS };
}

fn benchParallelMap(allocator: std.mem.Allocator, size: usize) !BenchResult {
    const input = try allocator.alloc(u8, size);
    defer allocator.free(input);
    const output_seq = try allocator.alloc(u8, size);
    defer allocator.free(output_seq);
    const output_par = try allocator.alloc(u8, size);
    defer allocator.free(output_par);

    // Fill with uppercase ASCII
    for (input, 0..) |*c, i| {
        c.* = @intCast('A' + @mod(i, 26));
    }

    // Warmup
    for (0..WARMUP_RUNS) |_| {
        sequentialMap(input, output_seq, toLower);
        parallel.parallelMap(u8, input, output_par, toLower);
    }

    // Benchmark sequential
    var seq_total: u64 = 0;
    for (0..BENCH_RUNS) |_| {
        var timer = try std.time.Timer.start();
        sequentialMap(input, output_seq, toLower);
        seq_total += timer.read();
        std.mem.doNotOptimizeAway(output_seq.ptr);
    }

    // Benchmark parallel
    var par_total: u64 = 0;
    for (0..BENCH_RUNS) |_| {
        var timer = try std.time.Timer.start();
        parallel.parallelMap(u8, input, output_par, toLower);
        par_total += timer.read();
        std.mem.doNotOptimizeAway(output_par.ptr);
    }

    return .{ .seq_ns = seq_total / BENCH_RUNS, .par_ns = par_total / BENCH_RUNS };
}

fn benchEditDistanceBatch(allocator: std.mem.Allocator, num_targets: usize) !BenchResult {
    const source = "hello world this is a test string for edit distance";

    // Create targets with slight variations
    const targets = try allocator.alloc([]const u8, num_targets);
    defer allocator.free(targets);

    var target_storage = try allocator.alloc(u8, num_targets * 60);
    defer allocator.free(target_storage);

    for (targets, 0..) |*t, i| {
        const start = i * 60;
        const end = @min(start + 55, target_storage.len);
        const slice = target_storage[start..end];
        @memcpy(slice[0..@min(source.len, slice.len)], source[0..@min(source.len, slice.len)]);
        // Add variation
        if (slice.len > 5) slice[5] = @intCast('a' + @mod(i, 26));
        t.* = slice;
    }

    var results = try allocator.alloc(usize, num_targets);
    defer allocator.free(results);

    // Sequential edit distance
    var seq_total: u64 = 0;
    for (0..BENCH_RUNS) |_| {
        var timer = try std.time.Timer.start();
        for (targets, 0..) |target, i| {
            results[i] = editDistanceSimple(source, target);
        }
        seq_total += timer.read();
        std.mem.doNotOptimizeAway(results.ptr);
    }

    // Parallel would use parallelEditDistanceBatch - but it requires allocator
    // For now, use the same sequential as baseline
    var par_total: u64 = 0;
    for (0..BENCH_RUNS) |_| {
        var timer = try std.time.Timer.start();
        parallel.parallelEditDistanceBatch(source, targets, results, allocator) catch {
            // Fallback to sequential on error
            for (targets, 0..) |target, i| {
                results[i] = editDistanceSimple(source, target);
            }
        };
        par_total += timer.read();
        std.mem.doNotOptimizeAway(results.ptr);
    }

    return .{ .seq_ns = seq_total / BENCH_RUNS, .par_ns = par_total / BENCH_RUNS };
}

fn editDistanceSimple(a: []const u8, b: []const u8) usize {
    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;

    // Simple O(mn) implementation
    var prev = std.heap.page_allocator.alloc(usize, b.len + 1) catch return 0;
    defer std.heap.page_allocator.free(prev);
    var curr = std.heap.page_allocator.alloc(usize, b.len + 1) catch return 0;
    defer std.heap.page_allocator.free(curr);

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

fn printBenchResult(name: []const u8, size: usize, result: BenchResult) void {
    const speedup = result.speedup();
    const indicator: []const u8 = if (speedup >= 1.5) " [FAST]" else if (speedup >= 1.0) " [OK]" else " [SLOW]";
    std.debug.print("{s:<15} {d:>10} {d:>10.3} ms {d:>10.3} ms {d:>8.2}x{s}\n", .{
        name,
        size,
        result.seqMs(),
        result.parMs(),
        speedup,
        indicator,
    });
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n", .{});
    std.debug.print("========================================================================\n", .{});
    std.debug.print("        Strings Library - Spice Parallel Operations Benchmark          \n", .{});
    std.debug.print("========================================================================\n", .{});
    std.debug.print("\n", .{});
    std.debug.print("Warmup: {d} runs, Benchmark: {d} runs (averaged)\n", .{ WARMUP_RUNS, BENCH_RUNS });
    std.debug.print("Legend: [FAST] = >1.5x speedup, [OK] = faster, [SLOW] = slower\n\n", .{});

    std.debug.print("{s:<15} {s:>10} {s:>12} {s:>12} {s:>10}\n", .{ "Operation", "Size", "Sequential", "Parallel", "Speedup" });
    std.debug.print("{s:->15} {s:->10} {s:->12} {s:->12} {s:->10}\n", .{ "", "", "", "", "" });

    // Count benchmark
    const count_sizes = [_]usize{ 10_000, 100_000, 500_000, 1_000_000 };
    for (count_sizes) |size| {
        const result = try benchParallelCount(allocator, size);
        printBenchResult("Count", size, result);
    }
    std.debug.print("\n", .{});

    // Map benchmark
    const map_sizes = [_]usize{ 10_000, 100_000, 1_000_000, 10_000_000 };
    for (map_sizes) |size| {
        const result = try benchParallelMap(allocator, size);
        printBenchResult("Map (toLower)", size, result);
    }
    std.debug.print("\n", .{});

    // Edit distance batch benchmark
    const batch_sizes = [_]usize{ 10, 50, 100, 500 };
    for (batch_sizes) |size| {
        const result = try benchEditDistanceBatch(allocator, size);
        printBenchResult("EditDist Batch", size, result);
    }

    std.debug.print("\n", .{});
}
