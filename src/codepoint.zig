// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode code point operations.
//!
//! This module provides functions for working with Unicode code points,
//! including validation, classification, and basic transformations.

const std = @import("std");
const types = @import("types");

pub const Codepoint = types.Codepoint;
pub const max_codepoint = types.max_codepoint;
pub const replacement_character = types.replacement_character;

/// Validates whether a value is a valid Unicode code point.
/// Valid code points are in the range U+0000 to U+10FFFF, excluding surrogates.
pub fn isValid(cp: u21) bool {
    return cp <= max_codepoint and !types.surrogate.isSurrogate(cp);
}

/// Returns true if the code point is in the ASCII range (0x00-0x7F)
pub fn isAscii(cp: u21) bool {
    return cp <= 0x7F;
}

/// Returns true if the code point is in the Basic Multilingual Plane (BMP)
pub fn isBmp(cp: u21) bool {
    return cp <= 0xFFFF;
}

/// Returns true if the code point requires a surrogate pair in UTF-16
pub fn requiresSurrogatePair(cp: u21) bool {
    return cp > 0xFFFF and cp <= max_codepoint;
}

/// Returns the number of UTF-8 bytes required to encode this code point
pub fn utf8Length(cp: u21) u3 {
    if (cp <= 0x7F) return 1;
    if (cp <= 0x7FF) return 2;
    if (cp <= 0xFFFF) return 3;
    return 4;
}

/// Returns the number of UTF-16 code units required to encode this code point
pub fn utf16Length(cp: u21) u2 {
    if (cp <= 0xFFFF) return 1;
    return 2;
}

/// Checks if the code point is a control character (C0 or C1)
pub fn isControl(cp: u21) bool {
    return cp <= 0x1F or (cp >= 0x7F and cp <= 0x9F);
}

/// Checks if the code point is an ASCII digit (0-9)
pub fn isAsciiDigit(cp: u21) bool {
    return cp >= '0' and cp <= '9';
}

/// Checks if the code point is an ASCII letter (a-z, A-Z)
pub fn isAsciiAlpha(cp: u21) bool {
    return (cp >= 'a' and cp <= 'z') or (cp >= 'A' and cp <= 'Z');
}

/// Checks if the code point is ASCII alphanumeric
pub fn isAsciiAlphanumeric(cp: u21) bool {
    return isAsciiDigit(cp) or isAsciiAlpha(cp);
}

/// Checks if the code point is ASCII whitespace
pub fn isAsciiWhitespace(cp: u21) bool {
    return switch (cp) {
        ' ', '\t', '\n', '\r', 0x0B, 0x0C => true,
        else => false,
    };
}

/// Checks if the code point is any Unicode whitespace
pub fn isWhitespace(cp: u21) bool {
    return switch (cp) {
        // ASCII whitespace
        ' ', '\t', '\n', '\r', 0x0B, 0x0C => true,
        // Unicode whitespace
        0x0085, // Next Line
        0x00A0, // No-Break Space
        0x1680, // Ogham Space Mark
        0x2000...0x200A, // Various spaces
        0x2028, // Line Separator
        0x2029, // Paragraph Separator
        0x202F, // Narrow No-Break Space
        0x205F, // Medium Mathematical Space
        0x3000, // Ideographic Space
        => true,
        else => false,
    };
}

/// Convert ASCII uppercase to lowercase
pub fn toAsciiLower(cp: u21) u21 {
    if (cp >= 'A' and cp <= 'Z') {
        return cp + ('a' - 'A');
    }
    return cp;
}

/// Convert ASCII lowercase to uppercase
pub fn toAsciiUpper(cp: u21) u21 {
    if (cp >= 'a' and cp <= 'z') {
        return cp - ('a' - 'A');
    }
    return cp;
}

/// Returns the plane number (0-16) for this code point
pub fn plane(cp: u21) u5 {
    return @truncate(cp >> 16);
}

/// Encodes a code point to UTF-8, returning the bytes written
pub fn encodeUtf8(cp: u21, buf: *[4]u8) []u8 {
    const len = utf8Length(cp);
    switch (len) {
        1 => {
            buf[0] = @truncate(cp);
        },
        2 => {
            buf[0] = @truncate(0xC0 | (cp >> 6));
            buf[1] = @truncate(0x80 | (cp & 0x3F));
        },
        3 => {
            buf[0] = @truncate(0xE0 | (cp >> 12));
            buf[1] = @truncate(0x80 | ((cp >> 6) & 0x3F));
            buf[2] = @truncate(0x80 | (cp & 0x3F));
        },
        4 => {
            buf[0] = @truncate(0xF0 | (cp >> 18));
            buf[1] = @truncate(0x80 | ((cp >> 12) & 0x3F));
            buf[2] = @truncate(0x80 | ((cp >> 6) & 0x3F));
            buf[3] = @truncate(0x80 | (cp & 0x3F));
        },
        else => unreachable,
    }
    return buf[0..len];
}

/// Encodes a code point to UTF-16, returning the code units written
pub fn encodeUtf16(cp: u21, buf: *[2]u16) []u16 {
    if (cp <= 0xFFFF) {
        buf[0] = @truncate(cp);
        return buf[0..1];
    }
    // Surrogate pair encoding
    const adjusted = cp - 0x10000;
    buf[0] = @truncate(0xD800 + (adjusted >> 10));
    buf[1] = @truncate(0xDC00 + (adjusted & 0x3FF));
    return buf[0..2];
}

/// Decodes a surrogate pair to a code point
pub fn decodeSurrogatePair(high: u16, low: u16) ?u21 {
    if (!types.surrogate.isHighSurrogate(high) or !types.surrogate.isLowSurrogate(low)) {
        return null;
    }
    const h: u21 = high - 0xD800;
    const l: u21 = low - 0xDC00;
    return (h << 10) + l + 0x10000;
}

test "isValid" {
    const testing = std.testing;

    try testing.expect(isValid(0));
    try testing.expect(isValid('A'));
    try testing.expect(isValid(0x10FFFF));

    // Surrogates are not valid code points
    try testing.expect(!isValid(0xD800));
    try testing.expect(!isValid(0xDFFF));

    // Out of range
    try testing.expect(!isValid(0x110000));
}

test "utf8Length" {
    const testing = std.testing;

    try testing.expectEqual(@as(u3, 1), utf8Length('A'));
    try testing.expectEqual(@as(u3, 2), utf8Length(0x00E9)); // é
    try testing.expectEqual(@as(u3, 3), utf8Length(0x4E2D)); // 中
    try testing.expectEqual(@as(u3, 4), utf8Length(0x1F600)); // emoji
}

test "encodeUtf8" {
    const testing = std.testing;

    var buf: [4]u8 = undefined;

    try testing.expectEqualSlices(u8, "A", encodeUtf8('A', &buf));
    try testing.expectEqualSlices(u8, "\xC3\xA9", encodeUtf8(0x00E9, &buf)); // é
    try testing.expectEqualSlices(u8, "\xE4\xB8\xAD", encodeUtf8(0x4E2D, &buf)); // 中
    try testing.expectEqualSlices(u8, "\xF0\x9F\x98\x80", encodeUtf8(0x1F600, &buf)); // emoji
}

test "encodeUtf16" {
    const testing = std.testing;

    var buf: [2]u16 = undefined;

    try testing.expectEqualSlices(u16, &[_]u16{'A'}, encodeUtf16('A', &buf));
    try testing.expectEqualSlices(u16, &[_]u16{0x4E2D}, encodeUtf16(0x4E2D, &buf)); // 中

    // Surrogate pair for emoji
    const emoji = encodeUtf16(0x1F600, &buf);
    try testing.expectEqual(@as(usize, 2), emoji.len);
    try testing.expectEqual(@as(u16, 0xD83D), emoji[0]);
    try testing.expectEqual(@as(u16, 0xDE00), emoji[1]);
}

test "decodeSurrogatePair" {
    const testing = std.testing;

    // Valid surrogate pair
    try testing.expectEqual(@as(?u21, 0x1F600), decodeSurrogatePair(0xD83D, 0xDE00));

    // Invalid pairs
    try testing.expectEqual(@as(?u21, null), decodeSurrogatePair(0xDE00, 0xD83D)); // reversed
    try testing.expectEqual(@as(?u21, null), decodeSurrogatePair(0x0041, 0xDE00)); // not high surrogate
}

test "isWhitespace" {
    const testing = std.testing;

    try testing.expect(isWhitespace(' '));
    try testing.expect(isWhitespace('\t'));
    try testing.expect(isWhitespace('\n'));
    try testing.expect(isWhitespace(0x00A0)); // NBSP
    try testing.expect(isWhitespace(0x2003)); // Em space
    try testing.expect(!isWhitespace('A'));
    try testing.expect(!isWhitespace(0x200B)); // Zero-width space (not whitespace)
}

test "case conversion" {
    const testing = std.testing;

    try testing.expectEqual(@as(u21, 'a'), toAsciiLower('A'));
    try testing.expectEqual(@as(u21, 'z'), toAsciiLower('Z'));
    try testing.expectEqual(@as(u21, 'a'), toAsciiLower('a')); // already lowercase

    try testing.expectEqual(@as(u21, 'A'), toAsciiUpper('a'));
    try testing.expectEqual(@as(u21, 'Z'), toAsciiUpper('z'));
    try testing.expectEqual(@as(u21, 'A'), toAsciiUpper('A')); // already uppercase
}
