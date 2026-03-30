// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Benchmark comparison tool for strings.
//!
//! Reads two JSON result files (baseline and current), compares each metric
//! at each tier, and prints a table showing delta% and pass/fail.
//!
//! Usage: zig build compare-bench -- baseline.json current.json
//! Optional: zig build compare-bench -- baseline.json current.json 25
//!           (last arg is the regression threshold percentage, default 20)
//!
//! Exit code 0 if all pass, 1 if any regression exceeds threshold.

const std = @import("std");

const print = std.debug.print;

// ---------------------------------------------------------------------------
// JSON parsing types
// ---------------------------------------------------------------------------

const TierData = struct {
    name: []const u8 = "",
    input_bytes: f64 = 0,
    utf8_validate_mb_s: f64 = 0,
    normalize_nfc_mb_s: f64 = 0,
    normalize_nfd_mb_s: f64 = 0,
    case_lower_mb_s: f64 = 0,
    case_upper_mb_s: f64 = 0,
    grapheme_count_mb_s: f64 = 0,
    count_mb_s: f64 = 0,
    search_mb_s: f64 = 0,
    skipped: bool = false,
};

const BenchResult = struct {
    version: f64 = 0,
    tiers: []TierData = &[_]TierData{},
};

// ---------------------------------------------------------------------------
// Metric definitions
// ---------------------------------------------------------------------------

const MetricKind = enum {
    /// Higher is better (throughput metrics). A decrease is a regression.
    higher_is_better,
};

const Metric = struct {
    name: []const u8,
    kind: MetricKind,
    get: *const fn (TierData) f64,
};

fn getUtf8Validate(t: TierData) f64 {
    return t.utf8_validate_mb_s;
}
fn getNormalizeNfc(t: TierData) f64 {
    return t.normalize_nfc_mb_s;
}
fn getNormalizeNfd(t: TierData) f64 {
    return t.normalize_nfd_mb_s;
}
fn getCaseLower(t: TierData) f64 {
    return t.case_lower_mb_s;
}
fn getCaseUpper(t: TierData) f64 {
    return t.case_upper_mb_s;
}
fn getGraphemeCount(t: TierData) f64 {
    return t.grapheme_count_mb_s;
}
fn getCount(t: TierData) f64 {
    return t.count_mb_s;
}
fn getSearch(t: TierData) f64 {
    return t.search_mb_s;
}

const metrics = [_]Metric{
    .{ .name = "utf8_validate_mb_s", .kind = .higher_is_better, .get = getUtf8Validate },
    .{ .name = "normalize_nfc_mb_s", .kind = .higher_is_better, .get = getNormalizeNfc },
    .{ .name = "normalize_nfd_mb_s", .kind = .higher_is_better, .get = getNormalizeNfd },
    .{ .name = "case_lower_mb_s", .kind = .higher_is_better, .get = getCaseLower },
    .{ .name = "case_upper_mb_s", .kind = .higher_is_better, .get = getCaseUpper },
    .{ .name = "grapheme_count_mb_s", .kind = .higher_is_better, .get = getGraphemeCount },
    .{ .name = "count_mb_s", .kind = .higher_is_better, .get = getCount },
    .{ .name = "search_mb_s", .kind = .higher_is_better, .get = getSearch },
};

// ---------------------------------------------------------------------------
// File reading and parsing
// ---------------------------------------------------------------------------

fn readJsonFile(allocator: std.mem.Allocator, path: []const u8) !BenchResult {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        print("Error: cannot open '{s}': {s}\n", .{ path, @errorName(err) });
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(content);

    const parsed = std.json.parseFromSlice(BenchResult, allocator, content, .{
        .ignore_unknown_fields = true,
        .allocate = .alloc_always,
    }) catch |err| {
        print("Error: failed to parse '{s}': {s}\n", .{ path, @errorName(err) });
        return err;
    };
    // Intentionally leak parsed data since the program exits shortly.
    _ = &parsed;

    return parsed.value;
}

// ---------------------------------------------------------------------------
// Comparison
// ---------------------------------------------------------------------------

fn findTier(result: BenchResult, name: []const u8) ?TierData {
    for (result.tiers) |t| {
        if (std.mem.eql(u8, t.name, name)) return t;
    }
    return null;
}

fn computeDeltaPct(baseline_val: f64, current_val: f64) f64 {
    if (baseline_val == 0) return 0;
    return ((current_val - baseline_val) / baseline_val) * 100.0;
}

fn isRegression(delta_pct: f64, kind: MetricKind, threshold: f64) bool {
    return switch (kind) {
        // For throughput (higher_is_better), a drop below -threshold is a regression
        .higher_is_better => delta_pct < -threshold,
    };
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args = std.process.args();
    _ = args.next(); // program name

    const baseline_path = args.next() orelse {
        print("Usage: compare-bench <baseline.json> <current.json> [threshold%]\n", .{});
        std.process.exit(2);
    };
    const current_path = args.next() orelse {
        print("Usage: compare-bench <baseline.json> <current.json> [threshold%]\n", .{});
        std.process.exit(2);
    };

    var threshold: f64 = 20.0;
    if (args.next()) |thr_str| {
        threshold = std.fmt.parseFloat(f64, thr_str) catch 20.0;
    }

    const baseline = readJsonFile(allocator, baseline_path) catch {
        std.process.exit(2);
    };
    const current = readJsonFile(allocator, current_path) catch {
        std.process.exit(2);
    };

    // Print header
    print("\n{s}\n", .{"=" ** 90});
    print("  Benchmark Comparison\n", .{});
    print("  Baseline: {s}\n", .{baseline_path});
    print("  Current:  {s}\n", .{current_path});
    print("  Threshold: {d:.0}%\n", .{threshold});
    print("{s}\n\n", .{"=" ** 90});

    print("  {s:<6} {s:<22} {s:>14} {s:>14} {s:>10} {s:>6}\n", .{
        "Tier", "Metric", "Baseline", "Current", "Delta%", "Status",
    });
    print("  {s:<6} {s:<22} {s:>14} {s:>14} {s:>10} {s:>6}\n", .{
        "-" ** 6, "-" ** 22, "-" ** 14, "-" ** 14, "-" ** 10, "-" ** 6,
    });

    var any_regression = false;

    for (baseline.tiers) |base_tier| {
        if (base_tier.skipped) continue;

        const cur_tier = findTier(current, base_tier.name) orelse continue;
        if (cur_tier.skipped) continue;

        for (metrics) |m| {
            const base_val = m.get(base_tier);
            const cur_val = m.get(cur_tier);
            const delta = computeDeltaPct(base_val, cur_val);
            const regressed = isRegression(delta, m.kind, threshold);

            if (regressed) any_regression = true;

            const status: []const u8 = if (regressed) "FAIL" else "PASS";

            const sign: []const u8 = if (delta >= 0) "+" else "";
            print("  {s:<6} {s:<22} {d:>14.1} {d:>14.1} {s}{d:>8.1}% {s:>6}\n", .{
                base_tier.name,
                m.name,
                base_val,
                cur_val,
                sign,
                delta,
                status,
            });
        }

        print("\n", .{});
    }

    print("{s}\n", .{"=" ** 90});

    if (any_regression) {
        print("  RESULT: FAIL -- regression(s) detected above threshold\n\n", .{});
        std.process.exit(1);
    } else {
        print("  RESULT: PASS -- all metrics within threshold\n\n", .{});
    }
}
