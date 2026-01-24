// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String search operations.
//!
//! This module provides functions for searching within strings,
//! including find, contains, indexOf, lastIndexOf, and pattern matching.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const utf8 = @import("utf8");
const iterator = @import("iterator");

pub const Codepoint = types.Codepoint;

/// Finds the first occurrence of a substring
pub fn indexOf(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return 0;
    if (needle.len > haystack.len) return null;

    return std.mem.indexOf(u8, haystack, needle);
}

/// Finds the last occurrence of a substring
pub fn lastIndexOf(haystack: []const u8, needle: []const u8) ?usize {
    if (needle.len == 0) return haystack.len;
    if (needle.len > haystack.len) return null;

    return std.mem.lastIndexOf(u8, haystack, needle);
}

/// Checks if a string contains a substring
pub fn contains(haystack: []const u8, needle: []const u8) bool {
    return indexOf(haystack, needle) != null;
}

/// Finds the first occurrence of a code point
pub fn indexOfCodepoint(haystack: []const u8, cp: Codepoint) ?usize {
    var buf: [4]u8 = undefined;
    const encoded = codepoint_mod.encodeUtf8(cp, &buf);
    return indexOf(haystack, encoded);
}

/// Finds the last occurrence of a code point
pub fn lastIndexOfCodepoint(haystack: []const u8, cp: Codepoint) ?usize {
    var buf: [4]u8 = undefined;
    const encoded = codepoint_mod.encodeUtf8(cp, &buf);
    return lastIndexOf(haystack, encoded);
}

/// Checks if a string contains a code point
pub fn containsCodepoint(haystack: []const u8, cp: Codepoint) bool {
    return indexOfCodepoint(haystack, cp) != null;
}

/// Finds the byte index of the nth code point
pub fn indexOfNthCodepoint(bytes: []const u8, n: usize) ?usize {
    var iter = utf8.iterator(bytes);
    var cp_count: usize = 0;

    while (iter.nextWithIndex()) |result| {
        if (cp_count == n) {
            return result.index;
        }
        cp_count += 1;
    }

    return null;
}

/// Finds the first occurrence of any of the given code points
pub fn indexOfAny(haystack: []const u8, codepoints: []const Codepoint) ?usize {
    var iter = utf8.iterator(haystack);

    while (iter.nextWithIndex()) |result| {
        for (codepoints) |cp| {
            if (result.cp == cp) {
                return result.index;
            }
        }
    }

    return null;
}

/// Finds the first occurrence of any byte in the set
pub fn indexOfAnyByte(haystack: []const u8, bytes: []const u8) ?usize {
    return std.mem.indexOfAny(u8, haystack, bytes);
}

/// Finds the first byte NOT in the set
pub fn indexOfNoneByte(haystack: []const u8, bytes: []const u8) ?usize {
    for (haystack, 0..) |b, i| {
        var found = false;
        for (bytes) |target| {
            if (b == target) {
                found = true;
                break;
            }
        }
        if (!found) return i;
    }
    return null;
}

/// Counts occurrences of a substring
pub fn count(haystack: []const u8, needle: []const u8) usize {
    if (needle.len == 0) return 0;

    var n: usize = 0;
    var pos: usize = 0;

    while (indexOf(haystack[pos..], needle)) |idx| {
        n += 1;
        pos += idx + needle.len;
    }

    return n;
}

/// Counts occurrences of a code point
pub fn countCodepoint(haystack: []const u8, cp: Codepoint) usize {
    var buf: [4]u8 = undefined;
    const encoded = codepoint_mod.encodeUtf8(cp, &buf);
    return count(haystack, encoded);
}

/// Checks if a string starts with a prefix
pub fn startsWith(haystack: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, haystack, prefix);
}

/// Checks if a string ends with a suffix
pub fn endsWith(haystack: []const u8, suffix: []const u8) bool {
    return std.mem.endsWith(u8, haystack, suffix);
}

/// Checks if a string starts with a code point
pub fn startsWithCodepoint(haystack: []const u8, cp: Codepoint) bool {
    if (haystack.len == 0) return false;

    const result = utf8.decode(haystack) catch return false;
    return result.value == cp;
}

/// Checks if a string ends with a code point
pub fn endsWithCodepoint(haystack: []const u8, cp: Codepoint) bool {
    if (haystack.len == 0) return false;

    // Scan backwards to find start of last code point
    var i = haystack.len;
    while (i > 0) {
        i -= 1;
        if (!utf8.isContinuationByte(haystack[i])) {
            break;
        }
    }

    const result = utf8.decode(haystack[i..]) catch return false;
    return result.value == cp;
}

/// Find all occurrences of a substring (returns byte indices)
pub fn findAll(allocator: std.mem.Allocator, haystack: []const u8, needle: []const u8) ![]usize {
    var indices: std.ArrayList(usize) = .empty;
    errdefer indices.deinit(allocator);

    if (needle.len == 0) return indices.toOwnedSlice(allocator);

    var pos: usize = 0;
    while (indexOf(haystack[pos..], needle)) |idx| {
        try indices.append(allocator, pos + idx);
        pos += idx + needle.len;
    }

    return indices.toOwnedSlice(allocator);
}

/// Iterator that yields all match positions
pub const FindIterator = struct {
    haystack: []const u8,
    needle: []const u8,
    pos: usize,

    pub fn init(haystack: []const u8, needle: []const u8) FindIterator {
        return .{
            .haystack = haystack,
            .needle = needle,
            .pos = 0,
        };
    }

    pub fn next(self: *FindIterator) ?usize {
        if (self.needle.len == 0 or self.pos >= self.haystack.len) {
            return null;
        }

        if (indexOf(self.haystack[self.pos..], self.needle)) |idx| {
            const result = self.pos + idx;
            self.pos = result + self.needle.len;
            return result;
        }

        return null;
    }
};

/// Creates a find iterator
pub fn findIter(haystack: []const u8, needle: []const u8) FindIterator {
    return FindIterator.init(haystack, needle);
}

// ============================================================================
// Go-style search functions
// ============================================================================

/// Finds the first occurrence of a byte
pub fn indexByte(haystack: []const u8, byte: u8) ?usize {
    return std.mem.indexOfScalar(u8, haystack, byte);
}

/// Finds the last occurrence of a byte
pub fn lastIndexByte(haystack: []const u8, byte: u8) ?usize {
    return std.mem.lastIndexOfScalar(u8, haystack, byte);
}

/// Finds the first occurrence of any byte in chars
pub fn indexAny(haystack: []const u8, chars: []const u8) ?usize {
    return std.mem.indexOfAny(u8, haystack, chars);
}

/// Finds the last occurrence of any byte in chars
pub fn lastIndexAny(haystack: []const u8, chars: []const u8) ?usize {
    return std.mem.lastIndexOfAny(u8, haystack, chars);
}

/// Finds the first code point that satisfies the predicate
pub fn indexFunc(haystack: []const u8, predicate: *const fn (Codepoint) bool) ?usize {
    var iter = utf8.iterator(haystack);
    while (iter.nextWithIndex()) |result| {
        if (predicate(result.cp)) {
            return result.index;
        }
    }
    return null;
}

/// Finds the last code point that satisfies the predicate
pub fn lastIndexFunc(haystack: []const u8, predicate: *const fn (Codepoint) bool) ?usize {
    if (haystack.len == 0) return null;

    var last_match: ?usize = null;
    var iter = utf8.iterator(haystack);

    while (iter.nextWithIndex()) |result| {
        if (predicate(result.cp)) {
            last_match = result.index;
        }
    }

    return last_match;
}

/// Finds the first occurrence of any code point in chars (Unicode-aware)
pub fn indexOfAnyCodepoint(haystack: []const u8, chars: []const Codepoint) ?usize {
    var iter = utf8.iterator(haystack);
    while (iter.nextWithIndex()) |result| {
        for (chars) |cp| {
            if (result.cp == cp) {
                return result.index;
            }
        }
    }
    return null;
}

/// Finds the last occurrence of any code point in chars (Unicode-aware)
pub fn lastIndexOfAnyCodepoint(haystack: []const u8, chars: []const Codepoint) ?usize {
    if (haystack.len == 0) return null;

    var last_match: ?usize = null;
    var iter = utf8.iterator(haystack);

    while (iter.nextWithIndex()) |result| {
        for (chars) |cp| {
            if (result.cp == cp) {
                last_match = result.index;
                break;
            }
        }
    }

    return last_match;
}

// ============================================================================
// Tests
// ============================================================================

test "indexOf" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 0), indexOf("hello", "h"));
    try testing.expectEqual(@as(?usize, 1), indexOf("hello", "ell"));
    try testing.expectEqual(@as(?usize, 4), indexOf("hello", "o"));
    try testing.expectEqual(@as(?usize, null), indexOf("hello", "x"));
    try testing.expectEqual(@as(?usize, 0), indexOf("hello", ""));
}

test "lastIndexOf" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 3), lastIndexOf("hello", "l"));
    try testing.expectEqual(@as(?usize, 0), lastIndexOf("hello", "hello"));
    try testing.expectEqual(@as(?usize, null), lastIndexOf("hello", "x"));
}

test "contains" {
    const testing = std.testing;

    try testing.expect(contains("hello world", "world"));
    try testing.expect(contains("hello", ""));
    try testing.expect(!contains("hello", "x"));
}

test "indexOfCodepoint" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 7), indexOfCodepoint("Hello, \xE4\xB8\xAD", 0x4E2D));
    try testing.expectEqual(@as(?usize, 0), indexOfCodepoint("Hello", 'H'));
}

test "startsWith and endsWith" {
    const testing = std.testing;

    try testing.expect(startsWith("hello", "hel"));
    try testing.expect(!startsWith("hello", "llo"));
    try testing.expect(endsWith("hello", "llo"));
    try testing.expect(!endsWith("hello", "hel"));
}

test "count" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 3), count("ababa", "a"));
    try testing.expectEqual(@as(usize, 1), count("ababa", "aba")); // Non-overlapping matches
    try testing.expectEqual(@as(usize, 0), count("hello", "x"));
}

test "indexOfNthCodepoint" {
    const testing = std.testing;

    const text = "A\xC3\xA9B"; // "AéB"
    try testing.expectEqual(@as(?usize, 0), indexOfNthCodepoint(text, 0)); // A
    try testing.expectEqual(@as(?usize, 1), indexOfNthCodepoint(text, 1)); // é
    try testing.expectEqual(@as(?usize, 3), indexOfNthCodepoint(text, 2)); // B
    try testing.expectEqual(@as(?usize, null), indexOfNthCodepoint(text, 3));
}

test "findAll" {
    const testing = std.testing;

    const indices = try findAll(testing.allocator, "abcabc", "abc");
    defer testing.allocator.free(indices);

    try testing.expectEqual(@as(usize, 2), indices.len);
    try testing.expectEqual(@as(usize, 0), indices[0]);
    try testing.expectEqual(@as(usize, 3), indices[1]);
}

test "findIter" {
    const testing = std.testing;

    var iter = findIter("abcabc", "abc");
    try testing.expectEqual(@as(?usize, 0), iter.next());
    try testing.expectEqual(@as(?usize, 3), iter.next());
    try testing.expectEqual(@as(?usize, null), iter.next());
}

// Go-style search function tests

test "indexByte" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 0), indexByte("hello", 'h'));
    try testing.expectEqual(@as(?usize, 4), indexByte("hello", 'o'));
    try testing.expectEqual(@as(?usize, null), indexByte("hello", 'x'));
}

test "lastIndexByte" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 3), lastIndexByte("hello", 'l'));
    try testing.expectEqual(@as(?usize, 0), lastIndexByte("hello", 'h'));
    try testing.expectEqual(@as(?usize, null), lastIndexByte("hello", 'x'));
}

test "indexAny" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 1), indexAny("hello", "aeiou"));
    try testing.expectEqual(@as(?usize, null), indexAny("hll", "aeiou"));
}

test "lastIndexAny" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 4), lastIndexAny("hello", "aeiou"));
    try testing.expectEqual(@as(?usize, null), lastIndexAny("hll", "aeiou"));
}

test "indexFunc" {
    const testing = std.testing;

    const isDigit = struct {
        fn f(cp: Codepoint) bool {
            return cp >= '0' and cp <= '9';
        }
    }.f;

    try testing.expectEqual(@as(?usize, 5), indexFunc("hello123", isDigit));
    try testing.expectEqual(@as(?usize, null), indexFunc("hello", isDigit));
}

test "lastIndexFunc" {
    const testing = std.testing;

    const isDigit = struct {
        fn f(cp: Codepoint) bool {
            return cp >= '0' and cp <= '9';
        }
    }.f;

    try testing.expectEqual(@as(?usize, 7), lastIndexFunc("hello123", isDigit));
    try testing.expectEqual(@as(?usize, null), lastIndexFunc("hello", isDigit));
}
