// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Incremental scale benchmark for strings.
//!
//! Runs the same battery of string operations at progressively larger input
//! sizes and emits structured JSON to stdout for tracking over time.
//! A human-readable summary table is printed to stderr via std.debug.print.
//!
//! Run via: zig build scale-bench
//! Save:   zig build scale-bench 2>/dev/null > results.json

const std = @import("std");
const builtin = @import("builtin");
const utf8_mod = @import("utf8");
const normalization = @import("normalization");
const grapheme = @import("grapheme");
const case = @import("case");
const search = @import("search");

const print = std.debug.print;

// ---------------------------------------------------------------------------
// Scale tier definitions
// ---------------------------------------------------------------------------

const Tier = struct {
    name: []const u8,
    target_bytes: usize,
    iterations: usize,
};

const tiers = [_]Tier{
    .{ .name = "1KB", .target_bytes = 1_024, .iterations = 10_000 },
    .{ .name = "10KB", .target_bytes = 10_240, .iterations = 1_000 },
    .{ .name = "100KB", .target_bytes = 102_400, .iterations = 100 },
    .{ .name = "1MB", .target_bytes = 1_048_576, .iterations = 10 },
    .{ .name = "10MB", .target_bytes = 10_485_760, .iterations = 3 },
};

const TierResult = struct {
    name: []const u8,
    input_bytes: u64,
    utf8_validate_mb_s: f64 = 0,
    normalize_nfc_mb_s: f64 = 0,
    normalize_nfd_mb_s: f64 = 0,
    case_lower_mb_s: f64 = 0,
    case_upper_mb_s: f64 = 0,
    grapheme_count_mb_s: f64 = 0,
    count_mb_s: f64 = 0,
    search_mb_s: f64 = 0,
    skipped: bool = false,
    skip_reason: ?[]const u8 = null,
};

/// Maximum wall-clock time for a single tier (5 minutes in ns).
const TIER_TIMEOUT_NS: u64 = 5 * 60 * std.time.ns_per_s;

// ---------------------------------------------------------------------------
// Input data generation
// ---------------------------------------------------------------------------

/// Base pattern: mix of ASCII, Latin accented (2-byte), CJK (3-byte),
/// emoji (4-byte), and NFD combining marks — exercises all Unicode paths.
const base_pattern =
    "The quick brown fox jumps over the lazy dog. " ++
    "Caf\xC3\xA9 r\xC3\xA9sum\xC3\xA9 na\xC3\xAFve \xC3\xBCber stra\xC3\x9Fe " ++
    "\xE4\xB8\xAD\xE6\x96\x87\xE6\x97\xA5\xE6\x9C\xAC\xE8\xAA\x9E\xED\x95\x9C\xEA\xB5\xAD\xEC\x96\xB4 " ++
    "\xF0\x9F\x98\x80\xF0\x9F\x8E\x89\xF0\x9F\x9A\x80\xF0\x9F\x92\xBB " ++
    "e\xCC\x81a\xCC\x80o\xCC\x82u\xCC\x88 ";

/// Needle for count/search benchmarks
const bench_needle = "the";

fn generateInput(allocator: std.mem.Allocator, target_bytes: usize) ![]u8 {
    const buf = try allocator.alloc(u8, target_bytes);
    var offset: usize = 0;
    while (offset < target_bytes) {
        const remaining = target_bytes - offset;
        const chunk = @min(remaining, base_pattern.len);
        @memcpy(buf[offset..][0..chunk], base_pattern[0..chunk]);
        offset += chunk;
    }
    return buf;
}

// ---------------------------------------------------------------------------
// Throughput calculation
// ---------------------------------------------------------------------------

fn calcThroughputMbS(bytes: usize, iterations: usize, elapsed_ns: u64) f64 {
    if (elapsed_ns == 0) return 0;
    const total_bytes: f64 = @floatFromInt(bytes * iterations);
    const seconds = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
    return total_bytes / seconds / (1024.0 * 1024.0);
}

// ---------------------------------------------------------------------------
// Individual benchmark functions
// ---------------------------------------------------------------------------

fn benchUtf8Validate(input: []const u8, iterations: usize) f64 {
    var timer = std.time.Timer.start() catch return 0;
    for (0..iterations) |_| {
        std.mem.doNotOptimizeAway(utf8_mod.isValid(input));
    }
    return calcThroughputMbS(input.len, iterations, timer.read());
}

fn benchNormalizeNfc(allocator: std.mem.Allocator, input: []const u8, iterations: usize) f64 {
    var timer = std.time.Timer.start() catch return 0;
    for (0..iterations) |_| {
        const result = normalization.normalize(allocator, input, .nfc) catch return 0;
        allocator.free(result);
    }
    return calcThroughputMbS(input.len, iterations, timer.read());
}

fn benchNormalizeNfd(allocator: std.mem.Allocator, input: []const u8, iterations: usize) f64 {
    var timer = std.time.Timer.start() catch return 0;
    for (0..iterations) |_| {
        const result = normalization.normalize(allocator, input, .nfd) catch return 0;
        allocator.free(result);
    }
    return calcThroughputMbS(input.len, iterations, timer.read());
}

fn benchCaseLower(allocator: std.mem.Allocator, input: []const u8, iterations: usize) f64 {
    var timer = std.time.Timer.start() catch return 0;
    for (0..iterations) |_| {
        const result = case.toLowerString(allocator, input) catch return 0;
        allocator.free(result);
    }
    return calcThroughputMbS(input.len, iterations, timer.read());
}

fn benchCaseUpper(allocator: std.mem.Allocator, input: []const u8, iterations: usize) f64 {
    var timer = std.time.Timer.start() catch return 0;
    for (0..iterations) |_| {
        const result = case.toUpperString(allocator, input) catch return 0;
        allocator.free(result);
    }
    return calcThroughputMbS(input.len, iterations, timer.read());
}

fn benchGraphemeCount(input: []const u8, iterations: usize) f64 {
    var timer = std.time.Timer.start() catch return 0;
    for (0..iterations) |_| {
        std.mem.doNotOptimizeAway(grapheme.count(input));
    }
    return calcThroughputMbS(input.len, iterations, timer.read());
}

fn benchCount(input: []const u8, iterations: usize) f64 {
    var timer = std.time.Timer.start() catch return 0;
    for (0..iterations) |_| {
        std.mem.doNotOptimizeAway(search.count(input, bench_needle));
    }
    return calcThroughputMbS(input.len, iterations, timer.read());
}

fn benchSearch(input: []const u8, iterations: usize) f64 {
    var timer = std.time.Timer.start() catch return 0;
    for (0..iterations) |_| {
        std.mem.doNotOptimizeAway(search.contains(input, bench_needle));
    }
    return calcThroughputMbS(input.len, iterations, timer.read());
}

// ---------------------------------------------------------------------------
// Tier execution
// ---------------------------------------------------------------------------

fn checkTimeout(tier_start: u64, timer: *std.time.Timer) bool {
    return (timer.read() - tier_start) > TIER_TIMEOUT_NS;
}

fn runTier(tier: Tier, allocator: std.mem.Allocator) TierResult {
    var result = TierResult{
        .name = tier.name,
        .input_bytes = @intCast(tier.target_bytes),
    };

    const input = generateInput(allocator, tier.target_bytes) catch {
        result.skipped = true;
        result.skip_reason = "allocation failed";
        return result;
    };
    defer allocator.free(input);

    var timer = std.time.Timer.start() catch {
        result.skipped = true;
        result.skip_reason = "timer unavailable";
        return result;
    };
    const tier_start = timer.read();
    const iters = tier.iterations;

    print("  Running tier {s} ({d} bytes, {d} iterations)...\n", .{ tier.name, tier.target_bytes, iters });

    // UTF-8 validation
    result.utf8_validate_mb_s = benchUtf8Validate(input, iters);
    print("    utf8_validate:    {d:>10.1} MB/s\n", .{result.utf8_validate_mb_s});
    if (checkTimeout(tier_start, &timer)) {
        result.skipped = true;
        result.skip_reason = "timeout";
        return result;
    }

    // NFC normalization
    result.normalize_nfc_mb_s = benchNormalizeNfc(allocator, input, iters);
    print("    normalize_nfc:    {d:>10.1} MB/s\n", .{result.normalize_nfc_mb_s});
    if (checkTimeout(tier_start, &timer)) {
        result.skipped = true;
        result.skip_reason = "timeout";
        return result;
    }

    // NFD normalization
    result.normalize_nfd_mb_s = benchNormalizeNfd(allocator, input, iters);
    print("    normalize_nfd:    {d:>10.1} MB/s\n", .{result.normalize_nfd_mb_s});
    if (checkTimeout(tier_start, &timer)) {
        result.skipped = true;
        result.skip_reason = "timeout";
        return result;
    }

    // Case lower
    result.case_lower_mb_s = benchCaseLower(allocator, input, iters);
    print("    case_lower:       {d:>10.1} MB/s\n", .{result.case_lower_mb_s});
    if (checkTimeout(tier_start, &timer)) {
        result.skipped = true;
        result.skip_reason = "timeout";
        return result;
    }

    // Case upper
    result.case_upper_mb_s = benchCaseUpper(allocator, input, iters);
    print("    case_upper:       {d:>10.1} MB/s\n", .{result.case_upper_mb_s});
    if (checkTimeout(tier_start, &timer)) {
        result.skipped = true;
        result.skip_reason = "timeout";
        return result;
    }

    // Grapheme counting
    result.grapheme_count_mb_s = benchGraphemeCount(input, iters);
    print("    grapheme_count:   {d:>10.1} MB/s\n", .{result.grapheme_count_mb_s});
    if (checkTimeout(tier_start, &timer)) {
        result.skipped = true;
        result.skip_reason = "timeout";
        return result;
    }

    // Count
    result.count_mb_s = benchCount(input, iters);
    print("    count:            {d:>10.1} MB/s\n", .{result.count_mb_s});
    if (checkTimeout(tier_start, &timer)) {
        result.skipped = true;
        result.skip_reason = "timeout";
        return result;
    }

    // Search
    result.search_mb_s = benchSearch(input, iters);
    print("    search:           {d:>10.1} MB/s\n", .{result.search_mb_s});

    return result;
}

// ---------------------------------------------------------------------------
// Stdout writer (buffered, for JSON output)
// ---------------------------------------------------------------------------

const StdoutWriter = struct {
    file: std.fs.File,
    buf: [8192]u8 = undefined,
    writer: ?std.fs.File.Writer = null,

    fn open(self: *StdoutWriter) void {
        self.writer = self.file.writer(&self.buf);
    }

    fn writeAll(self: *StdoutWriter, data: []const u8) !void {
        try self.writer.?.interface.writeAll(data);
    }

    fn writeFmt(self: *StdoutWriter, comptime fmt: []const u8, args: anytype) !void {
        try self.writer.?.interface.print(fmt, args);
    }

    fn flush(self: *StdoutWriter) !void {
        try self.writer.?.interface.flush();
    }
};

// ---------------------------------------------------------------------------
// JSON output to stdout
// ---------------------------------------------------------------------------

fn writeJsonOutput(out: *StdoutWriter, results: []const TierResult) !void {
    try out.writeAll("{\n");
    try out.writeAll("  \"version\": 1,\n");

    // Timestamp
    const ts = std.time.timestamp();
    const epoch_secs: u64 = @intCast(ts);
    const es = std.time.epoch.EpochSeconds{ .secs = epoch_secs };
    const day_secs = es.getDaySeconds();
    const year_day = es.getEpochDay().calculateYearDay();
    const month_day = year_day.calculateMonthDay();

    try out.writeFmt("  \"timestamp\": \"{d:0>4}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}Z\",\n", .{
        year_day.year,
        month_day.month.numeric(),
        month_day.day_index + 1,
        day_secs.getHoursIntoDay(),
        day_secs.getMinutesIntoHour(),
        day_secs.getSecondsIntoMinute(),
    });

    try out.writeAll("  \"git_commit\": \"unknown\",\n");

    // System info
    try out.writeFmt("  \"system\": {{ \"os\": \"{s}\", \"arch\": \"{s}\" }},\n", .{
        @tagName(builtin.os.tag),
        @tagName(builtin.cpu.arch),
    });

    // Tiers
    try out.writeAll("  \"tiers\": [\n");
    for (results, 0..) |r, i| {
        try out.writeAll("    {\n");
        try out.writeFmt("      \"name\": \"{s}\",\n", .{r.name});
        try out.writeFmt("      \"input_bytes\": {d},\n", .{r.input_bytes});
        if (r.skipped) {
            try out.writeAll("      \"skipped\": true,\n");
            if (r.skip_reason) |reason| {
                try out.writeFmt("      \"skip_reason\": \"{s}\",\n", .{reason});
            }
        }
        try out.writeFmt("      \"utf8_validate_mb_s\": {d:.1},\n", .{r.utf8_validate_mb_s});
        try out.writeFmt("      \"normalize_nfc_mb_s\": {d:.1},\n", .{r.normalize_nfc_mb_s});
        try out.writeFmt("      \"normalize_nfd_mb_s\": {d:.1},\n", .{r.normalize_nfd_mb_s});
        try out.writeFmt("      \"case_lower_mb_s\": {d:.1},\n", .{r.case_lower_mb_s});
        try out.writeFmt("      \"case_upper_mb_s\": {d:.1},\n", .{r.case_upper_mb_s});
        try out.writeFmt("      \"grapheme_count_mb_s\": {d:.1},\n", .{r.grapheme_count_mb_s});
        try out.writeFmt("      \"count_mb_s\": {d:.1},\n", .{r.count_mb_s});
        try out.writeFmt("      \"search_mb_s\": {d:.1}\n", .{r.search_mb_s});
        if (i < results.len - 1) {
            try out.writeAll("    },\n");
        } else {
            try out.writeAll("    }\n");
        }
    }
    try out.writeAll("  ]\n");
    try out.writeAll("}\n");
    try out.flush();
}

// ---------------------------------------------------------------------------
// Human-readable summary to stderr (via std.debug.print)
// ---------------------------------------------------------------------------

fn writeSummary(results: []const TierResult) void {
    print("\n", .{});
    print("{s}\n", .{"=" ** 110});
    print("  strings incremental scale benchmark\n", .{});
    print("{s}\n\n", .{"=" ** 110});

    print("  {s:<6} {s:>10} {s:>12} {s:>12} {s:>12} {s:>12} {s:>12} {s:>12} {s:>12} {s:>12}\n", .{
        "Tier",
        "Bytes",
        "UTF8 Valid",
        "NFC",
        "NFD",
        "toLower",
        "toUpper",
        "Grapheme",
        "Count",
        "Search",
    });
    print("  {s:<6} {s:>10} {s:>12} {s:>12} {s:>12} {s:>12} {s:>12} {s:>12} {s:>12} {s:>12}\n", .{
        "-" ** 6,
        "-" ** 10,
        "-" ** 12,
        "-" ** 12,
        "-" ** 12,
        "-" ** 12,
        "-" ** 12,
        "-" ** 12,
        "-" ** 12,
        "-" ** 12,
    });

    for (results) |r| {
        if (r.skipped) {
            print("  {s:<6} {d:>10} SKIPPED", .{ r.name, r.input_bytes });
            if (r.skip_reason) |reason| {
                print(" ({s})", .{reason});
            }
            print("\n", .{});
            continue;
        }

        print("  {s:<6} {d:>10} {d:>10.1}  {d:>10.1}  {d:>10.1}  {d:>10.1}  {d:>10.1}  {d:>10.1}  {d:>10.1}  {d:>10.1}\n", .{
            r.name,
            r.input_bytes,
            r.utf8_validate_mb_s,
            r.normalize_nfc_mb_s,
            r.normalize_nfd_mb_s,
            r.case_lower_mb_s,
            r.case_upper_mb_s,
            r.grapheme_count_mb_s,
            r.count_mb_s,
            r.search_mb_s,
        });
    }

    print("\n  All values in MB/s (higher is better)\n", .{});
    print("{s}\n\n", .{"=" ** 110});
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Parse optional tier limit argument
    var max_tiers: usize = tiers.len;
    var args = std.process.args();
    _ = args.next(); // program name
    if (args.next()) |arg| {
        max_tiers = std.fmt.parseInt(usize, arg, 10) catch tiers.len;
        max_tiers = @min(max_tiers, tiers.len);
    }

    print("\n  strings scale benchmark\n", .{});
    print("  Architecture: {s}, OS: {s}, Build: {s}\n", .{
        @tagName(builtin.cpu.arch),
        @tagName(builtin.os.tag),
        @tagName(builtin.mode),
    });
    print("  Running {d} tiers...\n\n", .{max_tiers});

    var results: [tiers.len]TierResult = undefined;
    for (tiers[0..max_tiers], 0..) |tier, i| {
        results[i] = runTier(tier, allocator);
        print("\n", .{});
    }

    // Fill remaining tiers as skipped
    for (max_tiers..tiers.len) |i| {
        results[i] = TierResult{
            .name = tiers[i].name,
            .input_bytes = @intCast(tiers[i].target_bytes),
            .skipped = true,
            .skip_reason = "tier limit",
        };
    }

    // Write human-readable summary to stderr
    writeSummary(results[0..max_tiers]);

    // Write JSON to stdout
    var out = StdoutWriter{ .file = .{ .handle = std.posix.STDOUT_FILENO } };
    out.open();
    try writeJsonOutput(&out, &results);
}
