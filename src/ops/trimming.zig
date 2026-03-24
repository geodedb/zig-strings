// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String trimming and character membership operations.
//!
//! This module provides functions for trimming whitespace and specified
//! characters from strings, as well as character membership predicates.

const std = @import("std");
const types = @import("types");
const utf8 = @import("utf8");
const iter_mod = @import("iterator");
const categories = @import("categories");

pub const Codepoint = types.Codepoint;

/// Builds a 256-element boolean lookup table from a UTF-8 encoded character set.
/// Only ASCII codepoints (< 128) are indexed in the table. Returns the table and
/// a flag indicating whether all codepoints in the set were ASCII (i.e. the table
/// is a complete representation of the set).
///
/// NOTE: Similar lookup-table builders exist in search.zig (buildCodepointLookup,
/// buildByteLookup). This variant differs by accepting UTF-8 input and decoding
/// codepoints, whereas search.zig operates on raw bytes or pre-decoded codepoints.
/// Deduplication would require adding a cross-module dependency or a shared utility
/// module; the ~15 lines of duplication do not justify that coupling.
pub fn buildAsciiLookup(chars: []const u8) struct { table: [256]bool, all_ascii: bool } {
    var table = [_]bool{false} ** 256;
    var all_ascii = true;
    var iter = utf8.iterator(chars);
    while (iter.next()) |cp| {
        if (cp < 128) {
            table[@intCast(cp)] = true;
        } else {
            all_ascii = false;
        }
    }
    return .{ .table = table, .all_ascii = all_ascii };
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

/// Trims specified characters from the left.
/// Uses a 256-element lookup table for O(1) ASCII membership testing,
/// falling back to linear scan only for non-ASCII codepoints in the set.
pub fn trimLeftChars(str: []const u8, chars: []const u8) []const u8 {
    const lookup = buildAsciiLookup(chars);
    var iter = utf8.iterator(str);

    while (iter.nextWithIndex()) |result| {
        if (result.cp < 128) {
            // ASCII fast-path: O(1) lookup
            if (!lookup.table[@intCast(result.cp)]) {
                return str[result.index..];
            }
        } else if (lookup.all_ascii) {
            // Non-ASCII codepoint but the char set is all ASCII -- not a match
            return str[result.index..];
        } else {
            // Non-ASCII codepoint with non-ASCII chars in set: linear scan
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
    }

    return str[str.len..];
}

/// Trims specified characters from the right.
/// Uses a 256-element lookup table for O(1) ASCII membership testing,
/// falling back to linear scan only for non-ASCII codepoints in the set.
pub fn trimRightChars(str: []const u8, chars: []const u8) []const u8 {
    if (str.len == 0) return str;

    const lookup = buildAsciiLookup(chars);
    var end = str.len;
    var iter = iter_mod.codepointsReverse(str);

    while (iter.next()) |cp| {
        const found = if (cp < 128)
            // ASCII fast-path: O(1) lookup
            lookup.table[@intCast(cp)]
        else if (lookup.all_ascii)
            // Non-ASCII codepoint but the char set is all ASCII -- not a match
            false
        else blk: {
            // Non-ASCII codepoint with non-ASCII chars in set: linear scan
            var char_iter = utf8.iterator(chars);
            while (char_iter.next()) |char_cp| {
                if (cp == char_cp) break :blk true;
            }
            break :blk false;
        };

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

/// Checks if a string contains any of the specified characters.
/// Uses a 256-element lookup table for O(1) ASCII membership testing,
/// falling back to linear scan only for non-ASCII codepoints in the set.
pub fn containsAny(str: []const u8, chars: []const u8) bool {
    const lookup = buildAsciiLookup(chars);
    var str_iter = utf8.iterator(str);
    while (str_iter.next()) |cp| {
        if (cp < 128) {
            // ASCII fast-path: O(1) lookup
            if (lookup.table[@intCast(cp)]) {
                return true;
            }
        } else if (!lookup.all_ascii) {
            // Non-ASCII codepoint with non-ASCII chars in set: linear scan
            var char_iter = utf8.iterator(chars);
            while (char_iter.next()) |char_cp| {
                if (cp == char_cp) {
                    return true;
                }
            }
        }
        // If lookup.all_ascii and cp >= 128, no match possible -- skip
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

test "trimFunc" {
    const testing = std.testing;

    const isX = struct {
        fn f(cp: Codepoint) bool {
            return cp == 'x';
        }
    }.f;

    try testing.expectEqualSlices(u8, "hello", trimFunc("xxxhelloxxx", isX));
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

// ============================================================================
// Bitset lookup optimization tests (P2-8)
// ============================================================================

test "containsAny with large ASCII char set uses O(1) lookup" {
    const testing = std.testing;

    // All lowercase vowels -- tests ASCII fast-path
    try testing.expect(containsAny("xyz hello", "aeiou"));
    try testing.expect(!containsAny("xyz", "aeiou"));

    // Large char set: all digits and punctuation
    try testing.expect(containsAny("abc123", "0123456789!@#$%^&*()"));
    try testing.expect(!containsAny("abcdef", "0123456789!@#$%^&*()"));
}

test "containsAny with non-ASCII chars" {
    const testing = std.testing;

    // Non-ASCII in char set: e-acute (U+00E9, "\xC3\xA9")
    try testing.expect(containsAny("caf\xC3\xA9", "\xC3\xA9"));
    try testing.expect(!containsAny("cafe", "\xC3\xA9"));
}

test "containsAny with mixed ASCII and non-ASCII char set" {
    const testing = std.testing;

    // Mixed set: 'a', 'b', and U+00E9
    // "hello" does not contain 'a', 'b', or e-acute
    try testing.expect(!containsAny("hello", "ab\xC3\xA9"));
    // "hat" contains 'a'
    try testing.expect(containsAny("hat", "ab\xC3\xA9"));
    // "caf\xC3\xA9" contains both 'a' and e-acute
    try testing.expect(containsAny("caf\xC3\xA9", "ab\xC3\xA9"));
    try testing.expect(!containsAny("xyz", "ab\xC3\xA9"));
}

test "trimChars with large ASCII char set" {
    const testing = std.testing;

    // Trim many different ASCII chars
    try testing.expectEqualSlices(u8, "hello", trimChars(".-=hello=-.", ".-="));
    try testing.expectEqualSlices(u8, "", trimChars(".-=", ".-="));
}

test "trimChars with non-ASCII chars" {
    const testing = std.testing;

    // Trim non-ASCII: e-acute
    try testing.expectEqualSlices(u8, "hello", trimChars("\xC3\xA9hello\xC3\xA9", "\xC3\xA9"));
}

test "trimChars with mixed ASCII and non-ASCII set" {
    const testing = std.testing;

    // Mixed: trim dots and e-acute
    try testing.expectEqualSlices(u8, "hello", trimChars(".\xC3\xA9hello\xC3\xA9.", ".\xC3\xA9"));
}

test "trimLeftChars with empty string" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "", trimLeftChars("", "abc"));
}

test "trimRightChars with empty string" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "", trimRightChars("", "abc"));
}
