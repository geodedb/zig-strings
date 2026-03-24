// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String splitting and joining operations.
//!
//! This module provides functions for splitting strings by delimiters,
//! joining string slices, and field-based splitting.

const std = @import("std");
const types = @import("types");
const utf8 = @import("utf8");
const iter_mod = @import("iterator");
const grapheme = @import("grapheme");
const categories = @import("categories");

pub const Codepoint = types.Codepoint;
pub const SplitOptions = types.SplitOptions;

/// Splits a string by a delimiter
pub fn split(allocator: std.mem.Allocator, str: []const u8, delimiter: []const u8) ![][]const u8 {
    return splitWithOptions(allocator, str, delimiter, .{});
}

/// Splits a string with options
pub fn splitWithOptions(
    allocator: std.mem.Allocator,
    str: []const u8,
    delimiter: []const u8,
    options: SplitOptions,
) ![][]const u8 {
    var parts: std.ArrayList([]const u8) = .empty;
    errdefer parts.deinit(allocator);
    // Pre-allocate for a reasonable number of parts; str.len / 4 is a
    // heuristic upper bound (every part is at least 1 byte + delimiter).
    try parts.ensureTotalCapacity(allocator, if (str.len > 0) str.len / 4 + 1 else 1);

    var iter = iter_mod.split(str, delimiter);
    var count: usize = 0;

    while (iter.next()) |part| {
        if (options.max_splits > 0 and count >= options.max_splits) {
            // Add the rest as final part
            if (part.len > 0 or options.keep_empty) {
                const remaining_start = @intFromPtr(part.ptr) - @intFromPtr(str.ptr);
                try parts.append(allocator, str[remaining_start..]);
            }
            break;
        }

        if (part.len > 0 or options.keep_empty) {
            try parts.append(allocator, part);
        }
        count += 1;
    }

    return parts.toOwnedSlice(allocator);
}

/// Joins strings with a separator
pub fn join(allocator: std.mem.Allocator, parts: []const []const u8, separator: []const u8) ![]u8 {
    if (parts.len == 0) {
        return allocator.alloc(u8, 0);
    }

    // Calculate total length with checked arithmetic to prevent overflow
    var total_len: usize = 0;
    for (parts) |part| {
        total_len = std.math.add(usize, total_len, part.len) catch return error.Overflow;
    }
    if (parts.len > 1) {
        const sep_total = std.math.mul(usize, separator.len, parts.len - 1) catch return error.Overflow;
        total_len = std.math.add(usize, total_len, sep_total) catch return error.Overflow;
    }

    var result = try allocator.alloc(u8, total_len);
    var pos: usize = 0;

    for (parts, 0..) |part, i| {
        @memcpy(result[pos..][0..part.len], part);
        pos += part.len;

        if (i < parts.len - 1) {
            @memcpy(result[pos..][0..separator.len], separator);
            pos += separator.len;
        }
    }

    return result;
}

/// Splits the string around runs of whitespace characters.
/// Returns a slice of substrings with no empty strings.
pub fn fields(allocator: std.mem.Allocator, str: []const u8) ![][]const u8 {
    return fieldsFunc(allocator, str, struct {
        fn isSpace(cp: Codepoint) bool {
            return categories.isWhitespace(cp);
        }
    }.isSpace);
}

/// Splits the string at each run of code points satisfying the predicate.
/// Returns a slice of substrings with no empty strings.
pub fn fieldsFunc(
    allocator: std.mem.Allocator,
    str: []const u8,
    predicate: *const fn (Codepoint) bool,
) ![][]const u8 {
    var result: std.ArrayList([]const u8) = .empty;
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, if (str.len > 0) str.len / 4 + 1 else 1);

    var iter = utf8.iterator(str);
    var field_start: ?usize = null;

    while (iter.nextWithIndex()) |item| {
        const in_separator = predicate(item.cp);

        if (in_separator) {
            if (field_start) |start| {
                // End of a field
                try result.append(allocator, str[start..item.index]);
                field_start = null;
            }
        } else {
            if (field_start == null) {
                // Start of a new field
                field_start = item.index;
            }
        }
    }

    // Handle last field
    if (field_start) |start| {
        try result.append(allocator, str[start..]);
    }

    return result.toOwnedSlice(allocator);
}

/// Splits string into at most n substrings.
/// If n < 0, returns all substrings. If n == 0, returns empty slice.
pub fn splitN(allocator: std.mem.Allocator, str: []const u8, sep: []const u8, n: isize) ![][]const u8 {
    if (n == 0) {
        return allocator.alloc([]const u8, 0);
    }
    if (n < 0) {
        return split(allocator, str, sep);
    }
    return splitWithOptions(allocator, str, sep, .{ .max_splits = @intCast(n - 1), .keep_empty = true });
}

/// Splits after each instance of sep (keeping sep at end of each part).
pub fn splitAfter(allocator: std.mem.Allocator, str: []const u8, sep: []const u8) ![][]const u8 {
    return splitAfterN(allocator, str, sep, -1);
}

/// Splits after each instance of sep, at most n times.
pub fn splitAfterN(allocator: std.mem.Allocator, str: []const u8, sep: []const u8, n: isize) ![][]const u8 {
    if (n == 0) {
        return allocator.alloc([]const u8, 0);
    }
    if (sep.len == 0) {
        // Split after each character (grapheme)
        var result: std.ArrayList([]const u8) = .empty;
        errdefer result.deinit(allocator);
        try result.ensureTotalCapacity(allocator, if (str.len > 0) str.len / 4 + 1 else 1);

        var iter = grapheme.iterator(str);
        var count: isize = 0;
        while (iter.next()) |cluster| {
            if (n > 0 and count >= n - 1) {
                // Last part gets everything remaining
                const remaining_start = @intFromPtr(cluster.ptr) - @intFromPtr(str.ptr);
                try result.append(allocator, str[remaining_start..]);
                break;
            }
            try result.append(allocator, cluster);
            count += 1;
        }
        return result.toOwnedSlice(allocator);
    }

    var result: std.ArrayList([]const u8) = .empty;
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, if (str.len > 0) str.len / 4 + 1 else 1);

    var pos: usize = 0;
    var count: isize = 0;

    while (std.mem.indexOf(u8, str[pos..], sep)) |idx| {
        if (n > 0 and count >= n - 1) {
            break;
        }
        const end = pos + idx + sep.len;
        try result.append(allocator, str[pos..end]);
        pos = end;
        count += 1;
    }

    // Add remaining part
    if (pos < str.len) {
        try result.append(allocator, str[pos..]);
    }

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "split" {
    const testing = std.testing;

    const parts = try split(testing.allocator, "a,b,c", ",");
    defer testing.allocator.free(parts);

    try testing.expectEqual(@as(usize, 3), parts.len);
    try testing.expectEqualSlices(u8, "a", parts[0]);
    try testing.expectEqualSlices(u8, "b", parts[1]);
    try testing.expectEqualSlices(u8, "c", parts[2]);
}

test "join" {
    const testing = std.testing;

    const parts = [_][]const u8{ "a", "b", "c" };
    const joined = try join(testing.allocator, &parts, ", ");
    defer testing.allocator.free(joined);

    try testing.expectEqualSlices(u8, "a, b, c", joined);
}

test "fields" {
    const testing = std.testing;

    const result = try fields(testing.allocator, "  hello   world  ");
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 2), result.len);
    try testing.expectEqualSlices(u8, "hello", result[0]);
    try testing.expectEqualSlices(u8, "world", result[1]);
}

test "splitN" {
    const testing = std.testing;

    const result = try splitN(testing.allocator, "a,b,c,d", ",", 2);
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 2), result.len);
    try testing.expectEqualSlices(u8, "a", result[0]);
    try testing.expectEqualSlices(u8, "b,c,d", result[1]);
}

test "splitAfter" {
    const testing = std.testing;

    const result = try splitAfter(testing.allocator, "a,b,c", ",");
    defer testing.allocator.free(result);

    try testing.expectEqual(@as(usize, 3), result.len);
    try testing.expectEqualSlices(u8, "a,", result[0]);
    try testing.expectEqualSlices(u8, "b,", result[1]);
    try testing.expectEqualSlices(u8, "c", result[2]);
}

// ============================================================================
// Overflow protection tests
// ============================================================================

test "join overflow from part lengths" {
    const testing = std.testing;
    const big_len = std.math.maxInt(usize) / 2 + 1;
    var dummy: [1]u8 = .{0};
    const fake_slice: []const u8 = @as([*]const u8, &dummy)[0..big_len];
    const parts = [_][]const u8{ fake_slice, fake_slice };
    const result = join(testing.allocator, &parts, "");
    try testing.expectError(error.Overflow, result);
}

test "join overflow from separator multiplication" {
    const testing = std.testing;
    const big_sep_len = std.math.maxInt(usize) / 2 + 1;
    var dummy: [1]u8 = .{0};
    const big_sep: []const u8 = @as([*]const u8, &dummy)[0..big_sep_len];
    const parts = [_][]const u8{ "a", "b", "c" };
    const result = join(testing.allocator, &parts, big_sep);
    try testing.expectError(error.Overflow, result);
}
