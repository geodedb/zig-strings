// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String transformation operations.
//!
//! This module provides functions for padding, repeating, reversing,
//! replacing, slicing, concatenating, mapping, and validating strings.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const utf8 = @import("utf8");
const grapheme = @import("grapheme");

pub const Codepoint = types.Codepoint;

/// Pads a string on the left to reach the target width (in graphemes)
pub fn padLeft(allocator: std.mem.Allocator, str: []const u8, width: usize, pad_char: []const u8) ![]u8 {
    const current_width = grapheme.count(str);
    if (current_width >= width) {
        const result = try allocator.alloc(u8, str.len);
        @memcpy(result, str);
        return result;
    }

    const pad_count = width - current_width;
    const pad_total = std.math.mul(usize, pad_count, pad_char.len) catch return error.Overflow;
    const total_len = std.math.add(usize, str.len, pad_total) catch return error.Overflow;
    var result = try allocator.alloc(u8, total_len);

    var pos: usize = 0;
    var i: usize = 0;
    while (i < pad_count) : (i += 1) {
        @memcpy(result[pos..][0..pad_char.len], pad_char);
        pos += pad_char.len;
    }
    @memcpy(result[pos..], str);

    return result;
}

/// Pads a string on the right to reach the target width (in graphemes)
pub fn padRight(allocator: std.mem.Allocator, str: []const u8, width: usize, pad_char: []const u8) ![]u8 {
    const current_width = grapheme.count(str);
    if (current_width >= width) {
        const result = try allocator.alloc(u8, str.len);
        @memcpy(result, str);
        return result;
    }

    const pad_count = width - current_width;
    const pad_total = std.math.mul(usize, pad_count, pad_char.len) catch return error.Overflow;
    const total_len = std.math.add(usize, str.len, pad_total) catch return error.Overflow;
    var result = try allocator.alloc(u8, total_len);

    @memcpy(result[0..str.len], str);
    var pos: usize = str.len;
    var i: usize = 0;
    while (i < pad_count) : (i += 1) {
        @memcpy(result[pos..][0..pad_char.len], pad_char);
        pos += pad_char.len;
    }

    return result;
}

/// Repeats a string n times
pub fn repeat(allocator: std.mem.Allocator, str: []const u8, n: usize) ![]u8 {
    if (n == 0 or str.len == 0) {
        return allocator.alloc(u8, 0);
    }

    const total_len = std.math.mul(usize, str.len, n) catch return error.Overflow;
    var result = try allocator.alloc(u8, total_len);

    var pos: usize = 0;
    var i: usize = 0;
    while (i < n) : (i += 1) {
        @memcpy(result[pos..][0..str.len], str);
        pos += str.len;
    }

    return result;
}

/// Reverses a string (grapheme-aware)
pub fn reverse(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    if (str.len == 0) {
        return allocator.alloc(u8, 0);
    }

    // Collect grapheme clusters.
    // Capacity hint: str.len / 4 + 1 assumes an average grapheme size of ~4 bytes,
    // which avoids the 16x over-allocation that str.len would cause (each entry is
    // a []const u8 slice = 16 bytes on 64-bit). The ArrayList grows if needed.
    var clusters: std.ArrayList([]const u8) = .empty;
    defer clusters.deinit(allocator);
    try clusters.ensureTotalCapacity(allocator, str.len / 4 + 1);

    var iter = grapheme.iterator(str);
    while (iter.next()) |cluster| {
        try clusters.append(allocator, cluster);
    }

    // Reverse and join
    var result = try allocator.alloc(u8, str.len);
    var pos: usize = 0;

    var i = clusters.items.len;
    while (i > 0) {
        i -= 1;
        const cluster = clusters.items[i];
        @memcpy(result[pos..][0..cluster.len], cluster);
        pos += cluster.len;
    }

    return result;
}

/// Replaces all occurrences of a substring
pub fn replace(allocator: std.mem.Allocator, str: []const u8, old: []const u8, new: []const u8) ![]u8 {
    return replaceN(allocator, str, old, new, 0);
}

/// Replaces up to n occurrences of a substring (0 = unlimited).
///
/// Implementation note: This function intentionally scans the string twice.
/// The first pass counts occurrences to compute the exact output size, enabling
/// a single allocation with no reallocations or over-allocation. This avoids
/// the overhead of ArrayList growth (repeated realloc + copy) which would be
/// more expensive than the extra traversal for most workloads. The trade-off
/// is ~1.5x scan cost vs. zero reallocation cost -- a net win in practice.
pub fn replaceN(allocator: std.mem.Allocator, str: []const u8, old: []const u8, new: []const u8, max_replacements: usize) ![]u8 {
    if (old.len == 0) {
        const result = try allocator.alloc(u8, str.len);
        @memcpy(result, str);
        return result;
    }

    // Count occurrences to allocate exact size
    var count: usize = 0;
    var pos: usize = 0;
    while (std.mem.indexOf(u8, str[pos..], old)) |idx| {
        count += 1;
        pos += idx + old.len;
        if (max_replacements > 0 and count >= max_replacements) break;
    }

    if (count == 0) {
        const result = try allocator.alloc(u8, str.len);
        @memcpy(result, str);
        return result;
    }

    // Calculate new size safely with checked arithmetic
    const new_len = blk: {
        if (new.len >= old.len) {
            const extra_per = new.len - old.len;
            const total_extra = std.math.mul(usize, extra_per, count) catch return error.Overflow;
            break :blk std.math.add(usize, str.len, total_extra) catch return error.Overflow;
        } else {
            const less_per = old.len - new.len;
            const total_less = std.math.mul(usize, less_per, count) catch return error.Overflow;
            break :blk str.len - total_less; // Safe: total_less <= str.len since count * old.len <= str.len
        }
    };

    var result = try allocator.alloc(u8, new_len);
    var replacements: usize = 0;
    pos = 0;
    var result_pos: usize = 0;

    while (std.mem.indexOf(u8, str[pos..], old)) |idx| {
        // Copy part before match
        const before = str[pos..][0..idx];
        @memcpy(result[result_pos..][0..before.len], before);
        result_pos += before.len;

        // Copy replacement
        @memcpy(result[result_pos..][0..new.len], new);
        result_pos += new.len;

        pos += idx + old.len;
        replacements += 1;

        if (max_replacements > 0 and replacements >= max_replacements) break;
    }

    // Copy remaining
    const remaining = str[pos..];
    @memcpy(result[result_pos..][0..remaining.len], remaining);

    return result;
}

/// Extracts a substring by code point indices
pub fn substring(str: []const u8, start: usize, end: ?usize) []const u8 {
    var iter = utf8.iterator(str);
    var count: usize = 0;
    var start_byte: usize = 0;
    var end_byte: usize = str.len;

    while (iter.nextWithIndex()) |result| {
        if (count == start) {
            start_byte = result.index;
        }
        if (end) |e| {
            if (count == e) {
                end_byte = result.index;
                break;
            }
        }
        count += 1;
    }

    return str[start_byte..end_byte];
}

/// Concatenates multiple strings
pub fn concat(allocator: std.mem.Allocator, strings: []const []const u8) ![]u8 {
    var total_len: usize = 0;
    for (strings) |s| {
        total_len = std.math.add(usize, total_len, s.len) catch return error.Overflow;
    }

    var result = try allocator.alloc(u8, total_len);
    var pos: usize = 0;

    for (strings) |s| {
        @memcpy(result[pos..][0..s.len], s);
        pos += s.len;
    }

    return result;
}

/// Result of a cut operation
pub const CutResult = struct {
    before: []const u8,
    after: []const u8,
    found: bool,
};

/// Slices str around the first instance of sep, returning the text before and after sep.
/// If sep is not found, returns the original string as 'before' with found=false.
pub fn cut(str: []const u8, sep: []const u8) CutResult {
    if (std.mem.indexOf(u8, str, sep)) |idx| {
        return .{
            .before = str[0..idx],
            .after = str[idx + sep.len ..],
            .found = true,
        };
    }
    return .{
        .before = str,
        .after = "",
        .found = false,
    };
}

/// Applies a mapping function to each codepoint and returns the result.
pub fn mapFunc(
    allocator: std.mem.Allocator,
    str: []const u8,
    mapping: *const fn (Codepoint) Codepoint,
) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, str.len);

    var iter = utf8.iterator(str);
    while (iter.next()) |cp| {
        const mapped = mapping(cp);
        if (mapped != 0) { // Skip if mapping returns 0 (delete)
            var buf: [4]u8 = undefined;
            const encoded = codepoint_mod.encodeUtf8(mapped, &buf);
            try result.appendSlice(allocator, encoded);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Replaces invalid UTF-8 sequences with the replacement string.
pub fn toValidUtf8(allocator: std.mem.Allocator, str: []const u8, replacement: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, str.len);

    var i: usize = 0;
    while (i < str.len) {
        const len = utf8.sequenceLength(str[i]) orelse {
            // Invalid start byte
            try result.appendSlice(allocator, replacement);
            i += 1;
            continue;
        };

        if (i + len > str.len) {
            // Truncated sequence
            try result.appendSlice(allocator, replacement);
            break;
        }

        // Validate the sequence
        _ = utf8.decode(str[i..][0..len]) catch {
            // Invalid sequence
            try result.appendSlice(allocator, replacement);
            i += 1;
            continue;
        };

        // Valid sequence
        try result.appendSlice(allocator, str[i..][0..len]);
        i += len;
    }

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "padLeft" {
    const testing = std.testing;

    const padded = try padLeft(testing.allocator, "42", 5, "0");
    defer testing.allocator.free(padded);
    try testing.expectEqualSlices(u8, "00042", padded);
}

test "padRight" {
    const testing = std.testing;

    const padded = try padRight(testing.allocator, "hi", 5, "-");
    defer testing.allocator.free(padded);
    try testing.expectEqualSlices(u8, "hi---", padded);
}

test "repeat" {
    const testing = std.testing;

    const repeated = try repeat(testing.allocator, "ab", 3);
    defer testing.allocator.free(repeated);
    try testing.expectEqualSlices(u8, "ababab", repeated);
}

test "reverse" {
    const testing = std.testing;

    const rev = try reverse(testing.allocator, "hello");
    defer testing.allocator.free(rev);
    try testing.expectEqualSlices(u8, "olleh", rev);
}

test "replace" {
    const testing = std.testing;

    const replaced = try replace(testing.allocator, "hello world", "world", "there");
    defer testing.allocator.free(replaced);
    try testing.expectEqualSlices(u8, "hello there", replaced);
}

test "substring" {
    const testing = std.testing;

    const text = "A\xC3\xA9B\xC3\xA9C"; // "AeBeC"
    try testing.expectEqualSlices(u8, "\xC3\xA9B", substring(text, 1, 3));
    try testing.expectEqualSlices(u8, "B\xC3\xA9C", substring(text, 2, null));
}

test "concat" {
    const testing = std.testing;

    const parts = [_][]const u8{ "Hello", " ", "World" };
    const result = try concat(testing.allocator, &parts);
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "Hello World", result);
}

test "cut" {
    const testing = std.testing;

    const result1 = cut("hello,world", ",");
    try testing.expect(result1.found);
    try testing.expectEqualSlices(u8, "hello", result1.before);
    try testing.expectEqualSlices(u8, "world", result1.after);

    const result2 = cut("hello", ",");
    try testing.expect(!result2.found);
    try testing.expectEqualSlices(u8, "hello", result2.before);
    try testing.expectEqualSlices(u8, "", result2.after);
}

test "mapFunc" {
    const testing = std.testing;

    const toUpper = struct {
        fn f(cp: Codepoint) Codepoint {
            if (cp >= 'a' and cp <= 'z') {
                return cp - ('a' - 'A');
            }
            return cp;
        }
    }.f;

    const result = try mapFunc(testing.allocator, "hello", toUpper);
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "HELLO", result);
}

test "toValidUtf8" {
    const testing = std.testing;

    // Valid UTF-8 stays the same
    const valid = try toValidUtf8(testing.allocator, "hello", "?");
    defer testing.allocator.free(valid);
    try testing.expectEqualSlices(u8, "hello", valid);

    // Invalid bytes get replaced
    const invalid = try toValidUtf8(testing.allocator, "hel\xFFlo", "?");
    defer testing.allocator.free(invalid);
    try testing.expectEqualSlices(u8, "hel?lo", invalid);
}

// ============================================================================
// Overflow protection tests
// ============================================================================

test "repeat overflow returns error" {
    const testing = std.testing;
    const result = repeat(testing.allocator, "ab", std.math.maxInt(usize));
    try testing.expectError(error.Overflow, result);
}

test "repeat overflow three-byte string" {
    const testing = std.testing;
    const n = std.math.maxInt(usize) / 2;
    const result = repeat(testing.allocator, "abc", n);
    try testing.expectError(error.Overflow, result);
}

test "replaceN overflow with large replacement" {
    const testing = std.testing;
    var dummy: [1]u8 = .{'x'};
    const big_len = std.math.maxInt(usize) / 2;
    const big_replacement: []const u8 = @as([*]const u8, &dummy)[0..big_len];
    const result = replaceN(testing.allocator, "aaa", "a", big_replacement, 0);
    try testing.expectError(error.Overflow, result);
}

test "padLeft overflow with maxInt width" {
    const testing = std.testing;
    // Use a multi-byte pad character so that pad_count * pad_char.len overflows.
    // "hi" has grapheme count 2, so pad_count = maxInt(usize) - 2, and
    // multiplying by a 2-byte pad character overflows usize.
    const result = padLeft(testing.allocator, "hi", std.math.maxInt(usize), "\xC3\xA9");
    try testing.expectError(error.Overflow, result);
}

test "padRight overflow with maxInt width" {
    const testing = std.testing;
    // Same logic as padLeft overflow test: pad_count * pad_char.len overflows.
    const result = padRight(testing.allocator, "hi", std.math.maxInt(usize), "\xC3\xA9");
    try testing.expectError(error.Overflow, result);
}

test "concat overflow from large slice lengths" {
    const testing = std.testing;
    // Construct two fake slices whose combined .len overflows usize.
    const big_len = std.math.maxInt(usize) / 2 + 1;
    var dummy: [1]u8 = .{0};
    const fake_slice: []const u8 = @as([*]const u8, &dummy)[0..big_len];
    const parts = [_][]const u8{ fake_slice, fake_slice };
    const result = concat(testing.allocator, &parts);
    try testing.expectError(error.Overflow, result);
}
