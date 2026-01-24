// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode case mapping and folding (UAX #29, SpecialCasing.txt).
//!
//! This module provides Unicode-aware case conversion operations
//! including uppercase, lowercase, titlecase, and case folding.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const categories = @import("categories");

pub const Codepoint = types.Codepoint;
pub const CaseType = types.CaseType;
pub const StringError = types.StringError;

/// Gets the case type of a code point
pub fn getCaseType(cp: Codepoint) CaseType {
    const cat = categories.getCategory(cp);
    return switch (cat) {
        .Lu => .upper,
        .Ll => .lower,
        .Lt => .title,
        else => .none,
    };
}

/// Converts a code point to lowercase
pub fn toLower(cp: Codepoint) Codepoint {
    // ASCII optimization
    if (cp >= 'A' and cp <= 'Z') {
        return cp + ('a' - 'A');
    }

    // Latin-1 uppercase
    if (cp >= 0x00C0 and cp <= 0x00D6) {
        return cp + 0x20;
    }
    if (cp >= 0x00D8 and cp <= 0x00DE) {
        return cp + 0x20;
    }

    // Latin Extended-A (pairs)
    if (cp >= 0x0100 and cp <= 0x012F and cp % 2 == 0) {
        return cp + 1;
    }
    if (cp >= 0x0132 and cp <= 0x0137 and cp % 2 == 0) {
        return cp + 1;
    }
    if (cp >= 0x0139 and cp <= 0x0148 and cp % 2 == 1) {
        return cp + 1;
    }
    if (cp >= 0x014A and cp <= 0x0177 and cp % 2 == 0) {
        return cp + 1;
    }

    // Greek uppercase
    if (cp >= 0x0391 and cp <= 0x03A1) {
        return cp + 0x20;
    }
    if (cp >= 0x03A3 and cp <= 0x03AB) {
        return cp + 0x20;
    }

    // Cyrillic uppercase
    if (cp >= 0x0410 and cp <= 0x042F) {
        return cp + 0x20;
    }

    // Fullwidth Latin
    if (cp >= 0xFF21 and cp <= 0xFF3A) {
        return cp + 0x20;
    }

    return cp;
}

/// Converts a code point to uppercase
pub fn toUpper(cp: Codepoint) Codepoint {
    // ASCII optimization
    if (cp >= 'a' and cp <= 'z') {
        return cp - ('a' - 'A');
    }

    // Latin-1 lowercase
    if (cp >= 0x00E0 and cp <= 0x00F6) {
        return cp - 0x20;
    }
    if (cp >= 0x00F8 and cp <= 0x00FE) {
        return cp - 0x20;
    }

    // Latin Extended-A (pairs)
    if (cp >= 0x0101 and cp <= 0x012F and cp % 2 == 1) {
        return cp - 1;
    }
    if (cp >= 0x0133 and cp <= 0x0137 and cp % 2 == 1) {
        return cp - 1;
    }
    if (cp >= 0x013A and cp <= 0x0148 and cp % 2 == 0) {
        return cp - 1;
    }
    if (cp >= 0x014B and cp <= 0x0177 and cp % 2 == 1) {
        return cp - 1;
    }

    // Greek lowercase
    if (cp >= 0x03B1 and cp <= 0x03C1) {
        return cp - 0x20;
    }
    if (cp >= 0x03C3 and cp <= 0x03CB) {
        return cp - 0x20;
    }

    // Cyrillic lowercase
    if (cp >= 0x0430 and cp <= 0x044F) {
        return cp - 0x20;
    }

    // Fullwidth Latin
    if (cp >= 0xFF41 and cp <= 0xFF5A) {
        return cp - 0x20;
    }

    // Special: German sharp s -> SS (returns just S, full case needs special handling)
    if (cp == 0x00DF) {
        return 'S';
    }

    return cp;
}

/// Converts a code point to titlecase
pub fn toTitle(cp: Codepoint) Codepoint {
    // Most titlecase mappings are the same as uppercase
    // Except for some special characters like ligatures

    // Latin letter DZ/Dz/dz
    if (cp == 0x01C6 or cp == 0x01C5) return 0x01C5;
    if (cp == 0x01C4) return 0x01C5;

    // Latin letter LJ/Lj/lj
    if (cp == 0x01C9 or cp == 0x01C8) return 0x01C8;
    if (cp == 0x01C7) return 0x01C8;

    // Latin letter NJ/Nj/nj
    if (cp == 0x01CC or cp == 0x01CB) return 0x01CB;
    if (cp == 0x01CA) return 0x01CB;

    // Otherwise same as uppercase
    return toUpper(cp);
}

/// Case folds a code point for case-insensitive comparison
pub fn caseFold(cp: Codepoint) Codepoint {
    // Simple case folding is mostly the same as toLower with some exceptions

    // ASCII optimization
    if (cp >= 'A' and cp <= 'Z') {
        return cp + ('a' - 'A');
    }

    // Special case foldings
    return switch (cp) {
        // German sharp s folds to ss (simplified to s for single char)
        0x00DF => 0x0073,
        // Kelvin sign folds to k
        0x212A => 0x006B,
        // Angstrom sign folds to å
        0x212B => 0x00E5,
        else => toLower(cp),
    };
}

/// Checks if two code points are equal when case-folded
pub fn equalsCaseFold(a: Codepoint, b: Codepoint) bool {
    return caseFold(a) == caseFold(b);
}

/// Converts a UTF-8 string to lowercase
pub fn toLowerString(allocator: std.mem.Allocator, utf8: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var iter = std.unicode.Utf8Iterator{ .bytes = utf8, .i = 0 };
    var buf: [4]u8 = undefined;

    while (iter.nextCodepoint()) |cp| {
        const lower = toLower(cp);
        const encoded = codepoint_mod.encodeUtf8(lower, &buf);
        try result.appendSlice(allocator, encoded);
    }

    return result.toOwnedSlice(allocator);
}

/// Converts a UTF-8 string to uppercase
pub fn toUpperString(allocator: std.mem.Allocator, utf8: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var iter = std.unicode.Utf8Iterator{ .bytes = utf8, .i = 0 };
    var buf: [4]u8 = undefined;

    while (iter.nextCodepoint()) |cp| {
        const upper = toUpper(cp);
        const encoded = codepoint_mod.encodeUtf8(upper, &buf);
        try result.appendSlice(allocator, encoded);

        // Special handling for sharp s (ß -> SS)
        if (cp == 0x00DF) {
            try result.append(allocator, 'S');
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Converts a UTF-8 string to titlecase
pub fn toTitleString(allocator: std.mem.Allocator, utf8: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var iter = std.unicode.Utf8Iterator{ .bytes = utf8, .i = 0 };
    var buf: [4]u8 = undefined;
    var at_word_start = true;

    while (iter.nextCodepoint()) |cp| {
        const converted = if (at_word_start and categories.isLetter(cp))
            toTitle(cp)
        else
            toLower(cp);

        const encoded = codepoint_mod.encodeUtf8(converted, &buf);
        try result.appendSlice(allocator, encoded);

        // Update word boundary tracking
        at_word_start = categories.isWhitespace(cp) or categories.isPunctuation(cp);
    }

    return result.toOwnedSlice(allocator);
}

/// Compares two strings case-insensitively
pub fn compareIgnoreCase(a: []const u8, b: []const u8) std.math.Order {
    var iter_a = std.unicode.Utf8Iterator{ .bytes = a, .i = 0 };
    var iter_b = std.unicode.Utf8Iterator{ .bytes = b, .i = 0 };

    while (true) {
        const cp_a = iter_a.nextCodepoint();
        const cp_b = iter_b.nextCodepoint();

        if (cp_a == null and cp_b == null) {
            return .eq;
        }

        if (cp_a == null) return .lt;
        if (cp_b == null) return .gt;

        const folded_a = caseFold(cp_a.?);
        const folded_b = caseFold(cp_b.?);

        if (folded_a < folded_b) return .lt;
        if (folded_a > folded_b) return .gt;
    }
}

/// Checks if two strings are equal when case-folded
pub fn equalsIgnoreCase(a: []const u8, b: []const u8) bool {
    return compareIgnoreCase(a, b) == .eq;
}

test "case type detection" {
    const testing = std.testing;

    try testing.expectEqual(CaseType.upper, getCaseType('A'));
    try testing.expectEqual(CaseType.lower, getCaseType('a'));
    try testing.expectEqual(CaseType.none, getCaseType('5'));
    try testing.expectEqual(CaseType.upper, getCaseType(0x0391)); // Greek Alpha
    try testing.expectEqual(CaseType.lower, getCaseType(0x03B1)); // Greek alpha
}

test "toLower" {
    const testing = std.testing;

    try testing.expectEqual(@as(Codepoint, 'a'), toLower('A'));
    try testing.expectEqual(@as(Codepoint, 'z'), toLower('Z'));
    try testing.expectEqual(@as(Codepoint, 'a'), toLower('a'));
    try testing.expectEqual(@as(Codepoint, 0x00E9), toLower(0x00C9)); // É -> é
    try testing.expectEqual(@as(Codepoint, 0x03B1), toLower(0x0391)); // Greek
}

test "toUpper" {
    const testing = std.testing;

    try testing.expectEqual(@as(Codepoint, 'A'), toUpper('a'));
    try testing.expectEqual(@as(Codepoint, 'Z'), toUpper('z'));
    try testing.expectEqual(@as(Codepoint, 'A'), toUpper('A'));
    try testing.expectEqual(@as(Codepoint, 0x00C9), toUpper(0x00E9)); // é -> É
}

test "caseFold" {
    const testing = std.testing;

    try testing.expectEqual(@as(Codepoint, 'a'), caseFold('A'));
    try testing.expectEqual(@as(Codepoint, 'a'), caseFold('a'));
    try testing.expectEqual(@as(Codepoint, 0x006B), caseFold(0x212A)); // Kelvin -> k
}

test "equalsIgnoreCase" {
    const testing = std.testing;

    try testing.expect(equalsIgnoreCase("Hello", "HELLO"));
    try testing.expect(equalsIgnoreCase("Hello", "hello"));
    try testing.expect(!equalsIgnoreCase("Hello", "World"));
}

test "toLowerString" {
    const testing = std.testing;

    const lower = try toLowerString(testing.allocator, "HELLO");
    defer testing.allocator.free(lower);
    try testing.expectEqualSlices(u8, "hello", lower);
}

test "toUpperString" {
    const testing = std.testing;

    const upper = try toUpperString(testing.allocator, "hello");
    defer testing.allocator.free(upper);
    try testing.expectEqualSlices(u8, "HELLO", upper);
}

test "toTitleString" {
    const testing = std.testing;

    const title = try toTitleString(testing.allocator, "hello world");
    defer testing.allocator.free(title);
    try testing.expectEqualSlices(u8, "Hello World", title);
}
