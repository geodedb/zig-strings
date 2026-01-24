// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String manipulation operations.
//!
//! This module provides functions for manipulating strings including
//! split, join, trim, pad, repeat, reverse, and replace operations.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const utf8 = @import("utf8");
const iter_mod = @import("iterator");
const grapheme = @import("grapheme");
const categories = @import("categories");

pub const Codepoint = types.Codepoint;
pub const StringError = types.StringError;
pub const TrimOptions = types.TrimOptions;
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

    // Calculate total length
    var total_len: usize = 0;
    for (parts) |part| {
        total_len += part.len;
    }
    total_len += separator.len * (parts.len - 1);

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

/// Trims whitespace from both ends
pub fn trim(str: []const u8) []const u8 {
    return trimRight(trimLeft(str));
}

/// Trims whitespace from the left
pub fn trimLeft(str: []const u8) []const u8 {
    var iter = utf8.iterator(str);

    while (iter.nextWithIndex()) |result| {
        if (!categories.isWhitespace(result.cp)) {
            return str[result.index..];
        }
    }

    return str[str.len..];
}

/// Trims whitespace from the right
pub fn trimRight(str: []const u8) []const u8 {
    var iter = iter_mod.codepointsReverse(str);
    var end = str.len;

    while (iter.next()) |cp| {
        if (!categories.isWhitespace(cp)) {
            return str[0..end];
        }
        // Find the start of this code point
        while (end > 0) {
            end -= 1;
            if (!utf8.isContinuationByte(str[end])) {
                break;
            }
        }
    }

    return str[0..0];
}

/// Trims specified characters from both ends
pub fn trimChars(str: []const u8, chars: []const u8) []const u8 {
    return trimRightChars(trimLeftChars(str, chars), chars);
}

/// Trims specified characters from the left
pub fn trimLeftChars(str: []const u8, chars: []const u8) []const u8 {
    var iter = utf8.iterator(str);

    while (iter.nextWithIndex()) |result| {
        // Check if this code point is in chars
        var found = false;
        var char_iter = utf8.iterator(chars);
        while (char_iter.next()) |char_cp| {
            if (result.cp == char_cp) {
                found = true;
                break;
            }
        }
        if (!found) {
            return str[result.index..];
        }
    }

    return str[str.len..];
}

/// Trims specified characters from the right
pub fn trimRightChars(str: []const u8, chars: []const u8) []const u8 {
    if (str.len == 0) return str;

    var end = str.len;
    var iter = iter_mod.codepointsReverse(str);

    while (iter.next()) |cp| {
        // Check if this code point is in chars
        var found = false;
        var char_iter = utf8.iterator(chars);
        while (char_iter.next()) |char_cp| {
            if (cp == char_cp) {
                found = true;
                break;
            }
        }
        if (!found) {
            return str[0..end];
        }
        // Move to start of this code point
        while (end > 0) {
            end -= 1;
            if (!utf8.isContinuationByte(str[end])) {
                break;
            }
        }
    }

    return str[0..0];
}

/// Pads a string on the left to reach the target width (in graphemes)
pub fn padLeft(allocator: std.mem.Allocator, str: []const u8, width: usize, pad_char: []const u8) ![]u8 {
    const current_width = grapheme.count(str);
    if (current_width >= width) {
        const result = try allocator.alloc(u8, str.len);
        @memcpy(result, str);
        return result;
    }

    const pad_count = width - current_width;
    const total_len = str.len + (pad_count * pad_char.len);
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
    const total_len = str.len + (pad_count * pad_char.len);
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

    const total_len = str.len * n;
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

    // Collect grapheme clusters
    var clusters: std.ArrayList([]const u8) = .empty;
    defer clusters.deinit(allocator);

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

/// Replaces up to n occurrences of a substring (0 = unlimited)
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

    // Calculate new size
    const size_diff = @as(isize, @intCast(new.len)) - @as(isize, @intCast(old.len));
    const new_len = @as(usize, @intCast(@as(isize, @intCast(str.len)) + size_diff * @as(isize, @intCast(count))));

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
        total_len += s.len;
    }

    var result = try allocator.alloc(u8, total_len);
    var pos: usize = 0;

    for (strings) |s| {
        @memcpy(result[pos..][0..s.len], s);
        pos += s.len;
    }

    return result;
}

// ============================================================================
// Go-style string functions
// ============================================================================

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

/// Returns str without the provided leading prefix.
/// If str doesn't start with prefix, returns null.
pub fn cutPrefix(str: []const u8, prefix: []const u8) ?[]const u8 {
    if (std.mem.startsWith(u8, str, prefix)) {
        return str[prefix.len..];
    }
    return null;
}

/// Returns str without the provided trailing suffix.
/// If str doesn't end with suffix, returns null.
pub fn cutSuffix(str: []const u8, suffix: []const u8) ?[]const u8 {
    if (std.mem.endsWith(u8, str, suffix)) {
        return str[0 .. str.len - suffix.len];
    }
    return null;
}

/// Returns str without the provided leading prefix.
/// If str doesn't start with prefix, returns str unchanged.
pub fn trimPrefix(str: []const u8, prefix: []const u8) []const u8 {
    return cutPrefix(str, prefix) orelse str;
}

/// Returns str without the provided trailing suffix.
/// If str doesn't end with suffix, returns str unchanged.
pub fn trimSuffix(str: []const u8, suffix: []const u8) []const u8 {
    return cutSuffix(str, suffix) orelse str;
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

    var iter = utf8.iterator(str);
    var field_start: ?usize = null;
    var prev_index: usize = 0;

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
        prev_index = item.index;
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

/// Applies a mapping function to each codepoint and returns the result.
pub fn mapFunc(
    allocator: std.mem.Allocator,
    str: []const u8,
    mapping: *const fn (Codepoint) Codepoint,
) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

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

/// Trims leading code points that satisfy the predicate.
pub fn trimLeftFunc(str: []const u8, predicate: *const fn (Codepoint) bool) []const u8 {
    var iter = utf8.iterator(str);

    while (iter.nextWithIndex()) |item| {
        if (!predicate(item.cp)) {
            return str[item.index..];
        }
    }

    return str[str.len..];
}

/// Trims trailing code points that satisfy the predicate.
pub fn trimRightFunc(str: []const u8, predicate: *const fn (Codepoint) bool) []const u8 {
    if (str.len == 0) return str;

    var end = str.len;
    var iter = iter_mod.codepointsReverse(str);

    while (iter.next()) |cp| {
        if (!predicate(cp)) {
            return str[0..end];
        }
        // Move to start of this code point
        while (end > 0) {
            end -= 1;
            if (!utf8.isContinuationByte(str[end])) {
                break;
            }
        }
    }

    return str[0..0];
}

/// Trims leading and trailing code points that satisfy the predicate.
pub fn trimFunc(str: []const u8, predicate: *const fn (Codepoint) bool) []const u8 {
    return trimRightFunc(trimLeftFunc(str, predicate), predicate);
}

/// Replaces invalid UTF-8 sequences with the replacement string.
pub fn toValidUtf8(allocator: std.mem.Allocator, str: []const u8, replacement: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

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

/// Checks if a string contains any of the specified characters.
pub fn containsAny(str: []const u8, chars: []const u8) bool {
    var str_iter = utf8.iterator(str);
    while (str_iter.next()) |cp| {
        var char_iter = utf8.iterator(chars);
        while (char_iter.next()) |char_cp| {
            if (cp == char_cp) {
                return true;
            }
        }
    }
    return false;
}

/// Checks if a string contains any code point satisfying the predicate.
pub fn containsFunc(str: []const u8, predicate: *const fn (Codepoint) bool) bool {
    var iter = utf8.iterator(str);
    while (iter.next()) |cp| {
        if (predicate(cp)) {
            return true;
        }
    }
    return false;
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

test "trim" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "hello", trim("  hello  "));
    try testing.expectEqualSlices(u8, "hello", trim("\t\nhello\r\n"));
    try testing.expectEqualSlices(u8, "", trim("   "));
}

test "trimChars" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "hello", trimChars("...hello...", "."));
    try testing.expectEqualSlices(u8, "hello", trimChars("xxyhelloxyy", "xy"));
}

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

    const text = "A\xC3\xA9B\xC3\xA9C"; // "AéBéC"
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

// Go-style function tests

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

test "cutPrefix" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "World", cutPrefix("HelloWorld", "Hello").?);
    try testing.expect(cutPrefix("HelloWorld", "Goodbye") == null);
}

test "cutSuffix" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "Hello", cutSuffix("HelloWorld", "World").?);
    try testing.expect(cutSuffix("HelloWorld", "Universe") == null);
}

test "trimPrefix" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "World", trimPrefix("HelloWorld", "Hello"));
    try testing.expectEqualSlices(u8, "HelloWorld", trimPrefix("HelloWorld", "Goodbye"));
}

test "trimSuffix" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "Hello", trimSuffix("HelloWorld", "World"));
    try testing.expectEqualSlices(u8, "HelloWorld", trimSuffix("HelloWorld", "Universe"));
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

test "trimFunc" {
    const testing = std.testing;

    const isX = struct {
        fn f(cp: Codepoint) bool {
            return cp == 'x';
        }
    }.f;

    try testing.expectEqualSlices(u8, "hello", trimFunc("xxxhelloxxx", isX));
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

test "containsAny" {
    const testing = std.testing;

    try testing.expect(containsAny("hello", "aeiou"));
    try testing.expect(!containsAny("hll", "aeiou"));
}

test "containsFunc" {
    const testing = std.testing;

    const isDigit = struct {
        fn f(cp: Codepoint) bool {
            return cp >= '0' and cp <= '9';
        }
    }.f;

    try testing.expect(containsFunc("hello123", isDigit));
    try testing.expect(!containsFunc("hello", isDigit));
}
