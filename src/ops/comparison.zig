// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String comparison operations.
//!
//! This module provides functions for comparing strings with various
//! options including case sensitivity, normalization, and collation.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const utf8 = @import("utf8");
const case = @import("case");
const normalization = @import("normalization");
const collation = @import("collation");

pub const Codepoint = types.Codepoint;
pub const CompareOptions = types.CompareOptions;
pub const NormalizationForm = types.NormalizationForm;

/// Compares two strings lexicographically
pub fn compare(a: []const u8, b: []const u8) std.math.Order {
    return std.mem.order(u8, a, b);
}

/// Checks if two strings are equal
pub fn equals(a: []const u8, b: []const u8) bool {
    return std.mem.eql(u8, a, b);
}

/// Compares two strings case-insensitively
pub fn compareIgnoreCase(a: []const u8, b: []const u8) std.math.Order {
    return case.compareIgnoreCase(a, b);
}

/// Checks if two strings are equal case-insensitively
pub fn equalsIgnoreCase(a: []const u8, b: []const u8) bool {
    return case.equalsIgnoreCase(a, b);
}

/// Compares two strings with options
pub fn compareWithOptions(a: []const u8, b: []const u8, options: CompareOptions) std.math.Order {
    if (options.collation) {
        return collation.compare(a, b, .{
            .strength = if (options.case_insensitive) .secondary else .tertiary,
            .normalize = options.normalize != null,
        });
    }

    if (options.case_insensitive) {
        return compareIgnoreCase(a, b);
    }

    return compare(a, b);
}

/// Checks if two strings are equal with options
pub fn equalsWithOptions(a: []const u8, b: []const u8, options: CompareOptions) bool {
    return compareWithOptions(a, b, options) == .eq;
}

/// Compares two strings code point by code point
pub fn compareCodepoints(a: []const u8, b: []const u8) std.math.Order {
    var iter_a = utf8.iterator(a);
    var iter_b = utf8.iterator(b);

    while (true) {
        const cp_a = iter_a.next();
        const cp_b = iter_b.next();

        if (cp_a == null and cp_b == null) return .eq;
        if (cp_a == null) return .lt;
        if (cp_b == null) return .gt;

        if (cp_a.? < cp_b.?) return .lt;
        if (cp_a.? > cp_b.?) return .gt;
    }
}

/// Checks if a string starts with a prefix (case-insensitive option)
pub fn startsWithIgnoreCase(haystack: []const u8, prefix: []const u8) bool {
    if (prefix.len > haystack.len) return false;

    var iter_h = utf8.iterator(haystack);
    var iter_p = utf8.iterator(prefix);

    while (iter_p.next()) |cp_p| {
        const cp_h = iter_h.next() orelse return false;
        if (!case.equalsCaseFold(cp_h, cp_p)) return false;
    }

    return true;
}

/// Checks if a string ends with a suffix (case-insensitive option)
pub fn endsWithIgnoreCase(haystack: []const u8, suffix: []const u8) bool {
    if (suffix.len > haystack.len) return false;

    // Count code points in suffix
    const suffix_cp_count = utf8.countCodepoints(suffix) orelse return false;
    const haystack_cp_count = utf8.countCodepoints(haystack) orelse return false;

    if (suffix_cp_count > haystack_cp_count) return false;

    // Find starting position in haystack
    var iter_h = utf8.iterator(haystack);
    var skip = haystack_cp_count - suffix_cp_count;
    while (skip > 0) : (skip -= 1) {
        _ = iter_h.next();
    }

    var iter_s = utf8.iterator(suffix);
    while (iter_s.next()) |cp_s| {
        const cp_h = iter_h.next() orelse return false;
        if (!case.equalsCaseFold(cp_h, cp_s)) return false;
    }

    return true;
}

/// Checks if a string contains another (case-insensitive)
pub fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;

    // Simple sliding window approach
    var h_iter = utf8.iterator(haystack);
    var h_index: usize = 0;

    while (h_iter.nextWithIndex()) |h_result| {
        // Try to match needle starting from this position
        var match = true;
        var h_check = utf8.iterator(haystack[h_result.index..]);
        var n_check = utf8.iterator(needle);

        while (n_check.next()) |n_cp| {
            const h_cp = h_check.next();
            if (h_cp == null or !case.equalsCaseFold(h_cp.?, n_cp)) {
                match = false;
                break;
            }
        }

        if (match) return true;
        h_index += 1;
    }

    return false;
}

/// Natural comparison (handles embedded numbers)
pub fn compareNatural(a: []const u8, b: []const u8) std.math.Order {
    var i: usize = 0;
    var j: usize = 0;

    while (i < a.len and j < b.len) {
        // Check if both positions are digits
        const a_digit = a[i] >= '0' and a[i] <= '9';
        const b_digit = b[j] >= '0' and b[j] <= '9';

        if (a_digit and b_digit) {
            // Compare numeric values
            var a_end = i;
            while (a_end < a.len and a[a_end] >= '0' and a[a_end] <= '9') {
                a_end += 1;
            }

            var b_end = j;
            while (b_end < b.len and b[b_end] >= '0' and b[b_end] <= '9') {
                b_end += 1;
            }

            // Skip leading zeros
            var a_start = i;
            while (a_start < a_end - 1 and a[a_start] == '0') {
                a_start += 1;
            }

            var b_start = j;
            while (b_start < b_end - 1 and b[b_start] == '0') {
                b_start += 1;
            }

            const a_num = a[a_start..a_end];
            const b_num = b[b_start..b_end];

            // Compare by length first
            if (a_num.len < b_num.len) return .lt;
            if (a_num.len > b_num.len) return .gt;

            // Same length, compare digits
            const cmp = std.mem.order(u8, a_num, b_num);
            if (cmp != .eq) return cmp;

            i = a_end;
            j = b_end;
        } else {
            // Regular character comparison
            if (a[i] < b[j]) return .lt;
            if (a[i] > b[j]) return .gt;
            i += 1;
            j += 1;
        }
    }

    if (i < a.len) return .gt;
    if (j < b.len) return .lt;
    return .eq;
}

/// Checks if string a is a prefix of string b
pub fn isPrefix(a: []const u8, b: []const u8) bool {
    return std.mem.startsWith(u8, b, a);
}

/// Checks if string a is a suffix of string b
pub fn isSuffix(a: []const u8, b: []const u8) bool {
    return std.mem.endsWith(u8, b, a);
}

/// Computes the Levenshtein edit distance between two strings
pub fn editDistance(allocator: std.mem.Allocator, a: []const u8, b: []const u8) !usize {
    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;

    // Use only two rows for memory efficiency
    var prev_row = try allocator.alloc(usize, b.len + 1);
    defer allocator.free(prev_row);
    var curr_row = try allocator.alloc(usize, b.len + 1);
    defer allocator.free(curr_row);

    // Initialize first row
    for (prev_row, 0..) |*val, i| {
        val.* = i;
    }

    // Fill in the rest
    for (a, 0..) |ca, i| {
        curr_row[0] = i + 1;

        for (b, 0..) |cb, j| {
            const cost: usize = if (ca == cb) 0 else 1;
            curr_row[j + 1] = @min(
                @min(
                    prev_row[j + 1] + 1, // deletion
                    curr_row[j] + 1, // insertion
                ),
                prev_row[j] + cost, // substitution
            );
        }

        // Swap rows
        const tmp = prev_row;
        prev_row = curr_row;
        curr_row = tmp;
    }

    return prev_row[b.len];
}

test "compare" {
    const testing = std.testing;

    try testing.expectEqual(std.math.Order.eq, compare("hello", "hello"));
    try testing.expectEqual(std.math.Order.lt, compare("abc", "abd"));
    try testing.expectEqual(std.math.Order.gt, compare("abd", "abc"));
}

test "equals" {
    const testing = std.testing;

    try testing.expect(equals("hello", "hello"));
    try testing.expect(!equals("hello", "world"));
}

test "compareIgnoreCase" {
    const testing = std.testing;

    try testing.expectEqual(std.math.Order.eq, compareIgnoreCase("Hello", "HELLO"));
    try testing.expectEqual(std.math.Order.eq, compareIgnoreCase("hello", "hElLo"));
}

test "equalsIgnoreCase" {
    const testing = std.testing;

    try testing.expect(equalsIgnoreCase("Hello", "HELLO"));
    try testing.expect(!equalsIgnoreCase("Hello", "World"));
}

test "startsWithIgnoreCase" {
    const testing = std.testing;

    try testing.expect(startsWithIgnoreCase("Hello World", "hello"));
    try testing.expect(!startsWithIgnoreCase("Hello", "world"));
}

test "endsWithIgnoreCase" {
    const testing = std.testing;

    try testing.expect(endsWithIgnoreCase("Hello World", "WORLD"));
    try testing.expect(!endsWithIgnoreCase("Hello", "world"));
}

test "containsIgnoreCase" {
    const testing = std.testing;

    try testing.expect(containsIgnoreCase("Hello World", "LO WO"));
    try testing.expect(!containsIgnoreCase("Hello", "xyz"));
}

test "compareNatural" {
    const testing = std.testing;

    try testing.expectEqual(std.math.Order.lt, compareNatural("file1", "file10"));
    try testing.expectEqual(std.math.Order.lt, compareNatural("file2", "file10"));
    try testing.expectEqual(std.math.Order.eq, compareNatural("file10", "file10"));
    try testing.expectEqual(std.math.Order.gt, compareNatural("file10", "file2"));
}

test "editDistance" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 0), try editDistance(testing.allocator, "hello", "hello"));
    try testing.expectEqual(@as(usize, 1), try editDistance(testing.allocator, "hello", "hallo"));
    try testing.expectEqual(@as(usize, 3), try editDistance(testing.allocator, "kitten", "sitting"));
}
