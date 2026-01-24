//! Benchmarking infrastructure for ZigStr
//!
//! Provides timing utilities and benchmark harness for measuring
//! string operation performance.

const std = @import("std");
const builtin = @import("builtin");

/// Benchmark result for a single operation
pub const BenchResult = struct {
    name: []const u8,
    iterations: u64,
    total_ns: u64,
    min_ns: u64,
    max_ns: u64,
    mean_ns: u64,
    throughput_mb_s: ?f64,

    pub fn print(self: BenchResult) void {
        std.debug.print("{s:<40} ", .{self.name});
        std.debug.print("{d:>10.2} ns/op  ", .{@as(f64, @floatFromInt(self.mean_ns))});

        if (self.throughput_mb_s) |tp| {
            std.debug.print("{d:>8.2} MB/s  ", .{tp});
        } else {
            std.debug.print("{s:>11}  ", .{""});
        }

        std.debug.print("(min: {d:.0}, max: {d:.0}, n={d})\n", .{
            @as(f64, @floatFromInt(self.min_ns)),
            @as(f64, @floatFromInt(self.max_ns)),
            self.iterations,
        });
    }
};

/// Benchmark configuration
pub const Config = struct {
    /// Minimum time to run each benchmark (nanoseconds)
    min_time_ns: u64 = 100_000_000, // 100ms

    /// Maximum iterations per benchmark
    max_iterations: u64 = 10_000_000,

    /// Minimum iterations per benchmark
    min_iterations: u64 = 10,

    /// Warmup iterations before timing
    warmup_iterations: u64 = 3,
};

/// Run a benchmark function and return results
pub fn runBenchmark(
    comptime name: []const u8,
    comptime func: fn () void,
    bytes_per_iter: ?u64,
    config: Config,
) BenchResult {
    // Warmup
    var warmup_i: u64 = 0;
    while (warmup_i < config.warmup_iterations) : (warmup_i += 1) {
        func();
    }

    // Estimate iterations needed
    var iterations: u64 = config.min_iterations;
    var timer = std.time.Timer.start() catch @panic("Timer unavailable");

    // Quick probe to estimate iteration count
    const probe_start = timer.read();
    var probe_i: u64 = 0;
    while (probe_i < 10) : (probe_i += 1) {
        func();
    }
    const probe_time = timer.read() - probe_start;

    if (probe_time > 0) {
        const estimated = (config.min_time_ns * 10) / probe_time;
        iterations = @max(config.min_iterations, @min(estimated, config.max_iterations));
    }

    // Run benchmark
    var total_ns: u64 = 0;
    var min_ns: u64 = std.math.maxInt(u64);
    var max_ns: u64 = 0;

    var i: u64 = 0;
    while (i < iterations) : (i += 1) {
        const start = timer.read();
        func();
        const elapsed = timer.read() - start;

        total_ns += elapsed;
        min_ns = @min(min_ns, elapsed);
        max_ns = @max(max_ns, elapsed);
    }

    const mean_ns = total_ns / iterations;

    var throughput: ?f64 = null;
    if (bytes_per_iter) |bytes| {
        const bytes_total = bytes * iterations;
        const seconds = @as(f64, @floatFromInt(total_ns)) / 1_000_000_000.0;
        throughput = @as(f64, @floatFromInt(bytes_total)) / seconds / (1024.0 * 1024.0);
    }

    return .{
        .name = name,
        .iterations = iterations,
        .total_ns = total_ns,
        .min_ns = min_ns,
        .max_ns = max_ns,
        .mean_ns = mean_ns,
        .throughput_mb_s = throughput,
    };
}

/// Print a benchmark suite header
pub fn printHeader(name: []const u8) void {
    std.debug.print("\n=== {s} ===\n\n", .{name});
    std.debug.print("{s:<40} {s:>13}  {s:>11}  {s}\n", .{ "Benchmark", "Time", "Throughput", "Stats" });
    std.debug.print("{s}\n", .{"-" ** 85});
}

/// Pre-generated test data for benchmarks
pub const TestData = struct {
    /// ASCII text (~1KB)
    pub const ascii_1kb = "The quick brown fox jumps over the lazy dog. " ** 23;

    /// UTF-8 with 2-byte chars (Latin extended)
    pub const latin_extended = "Cafe resume naive " ** 60;

    /// UTF-8 with 3-byte chars (CJK)
    pub const cjk = "中文日本語한국어" ** 128;

    /// UTF-8 with 4-byte chars (Emoji)
    pub const emoji = "😀🎉🚀💻🌍🔥" ** 170;

    /// Mixed UTF-8 content
    pub const mixed_utf8 = "Hello World! " ** 50;

    /// Text for normalization (with combining marks)
    pub const nfd_text = "e\xCC\x81a\xCC\x80o\xCC\x82u\xCC\x88" ** 256; // NFD: e + combining acute, etc.

    /// Pre-composed text (NFC)
    pub const nfc_text = "\xC3\xA9\xC3\xA0\xC3\xB4\xC3\xBC" ** 256; // NFC: é à ô ü
};

/// Get system info for benchmark reports
pub fn printSystemInfo() void {
    std.debug.print("\n=== System Information ===\n", .{});
    std.debug.print("Architecture: {s}\n", .{@tagName(builtin.cpu.arch)});
    std.debug.print("OS: {s}\n", .{@tagName(builtin.os.tag)});
    std.debug.print("Build mode: {s}\n", .{@tagName(builtin.mode)});

    // CPU features
    if (builtin.cpu.arch == .x86_64) {
        const features = builtin.cpu.features;
        std.debug.print("CPU Features: ", .{});
        if (std.Target.x86.featureSetHas(features, .sse2)) std.debug.print("SSE2 ", .{});
        if (std.Target.x86.featureSetHas(features, .sse4_2)) std.debug.print("SSE4.2 ", .{});
        if (std.Target.x86.featureSetHas(features, .avx)) std.debug.print("AVX ", .{});
        if (std.Target.x86.featureSetHas(features, .avx2)) std.debug.print("AVX2 ", .{});
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

test "benchmark infrastructure" {
    const result = runBenchmark("test_add", struct {
        fn f() void {
            var s: u64 = 0;
            for (0..100) |i| {
                s +%= i;
            }
            std.mem.doNotOptimizeAway(s);
        }
    }.f, null, .{ .min_time_ns = 1_000_000, .min_iterations = 10 });

    const testing = std.testing;
    try testing.expect(result.iterations >= 10);
    try testing.expect(result.mean_ns > 0);
}
