// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! ASCII operations and utilities.
//!
//! ASCII (American Standard Code for Information Interchange) is a 7-bit
//! character encoding. This module provides efficient operations for
//! ASCII-only string processing.

const std = @import("std");
const types = @import("types");

pub const StringError = types.StringError;

/// Checks if a byte is valid ASCII (0x00-0x7F)
pub fn isAscii(byte: u8) bool {
    return byte <= 0x7F;
}

/// Checks if all bytes in a slice are valid ASCII
pub fn isValidAscii(bytes: []const u8) bool {
    for (bytes) |b| {
        if (!isAscii(b)) return false;
    }
    return true;
}

/// Checks if a byte is an ASCII control character (0x00-0x1F or 0x7F)
pub fn isControl(byte: u8) bool {
    return byte <= 0x1F or byte == 0x7F;
}

/// Checks if a byte is an ASCII printable character (0x20-0x7E)
pub fn isPrintable(byte: u8) bool {
    return byte >= 0x20 and byte <= 0x7E;
}

/// Checks if a byte is an ASCII digit (0-9)
pub fn isDigit(byte: u8) bool {
    return byte >= '0' and byte <= '9';
}

/// Checks if a byte is an ASCII hex digit (0-9, a-f, A-F)
pub fn isHexDigit(byte: u8) bool {
    return isDigit(byte) or (byte >= 'a' and byte <= 'f') or (byte >= 'A' and byte <= 'F');
}

/// Checks if a byte is an ASCII uppercase letter
pub fn isUpper(byte: u8) bool {
    return byte >= 'A' and byte <= 'Z';
}

/// Checks if a byte is an ASCII lowercase letter
pub fn isLower(byte: u8) bool {
    return byte >= 'a' and byte <= 'z';
}

/// Checks if a byte is an ASCII letter
pub fn isAlpha(byte: u8) bool {
    return isLower(byte) or isUpper(byte);
}

/// Checks if a byte is an ASCII letter or digit
pub fn isAlphanumeric(byte: u8) bool {
    return isAlpha(byte) or isDigit(byte);
}

/// Checks if a byte is ASCII whitespace
pub fn isWhitespace(byte: u8) bool {
    return switch (byte) {
        ' ', '\t', '\n', '\r', 0x0B, 0x0C => true,
        else => false,
    };
}

/// Checks if a byte is a blank (space or tab)
pub fn isBlank(byte: u8) bool {
    return byte == ' ' or byte == '\t';
}

/// Converts an ASCII uppercase letter to lowercase
pub fn toLower(byte: u8) u8 {
    if (isUpper(byte)) {
        return byte + ('a' - 'A');
    }
    return byte;
}

/// Converts an ASCII lowercase letter to uppercase
pub fn toUpper(byte: u8) u8 {
    if (isLower(byte)) {
        return byte - ('a' - 'A');
    }
    return byte;
}

/// Converts all ASCII uppercase letters in a slice to lowercase (in place)
pub fn toLowerInPlace(bytes: []u8) void {
    for (bytes) |*b| {
        b.* = toLower(b.*);
    }
}

/// Converts all ASCII lowercase letters in a slice to uppercase (in place)
pub fn toUpperInPlace(bytes: []u8) void {
    for (bytes) |*b| {
        b.* = toUpper(b.*);
    }
}

/// Converts ASCII hex digit to its numeric value
pub fn hexValue(byte: u8) ?u4 {
    if (byte >= '0' and byte <= '9') {
        return @truncate(byte - '0');
    }
    if (byte >= 'a' and byte <= 'f') {
        return @truncate(byte - 'a' + 10);
    }
    if (byte >= 'A' and byte <= 'F') {
        return @truncate(byte - 'A' + 10);
    }
    return null;
}

/// Converts a numeric value (0-15) to an ASCII hex digit
pub fn toHexDigit(value: u4, uppercase: bool) u8 {
    if (value < 10) {
        return '0' + @as(u8, value);
    }
    return (if (uppercase) @as(u8, 'A') else @as(u8, 'a')) + @as(u8, value - 10);
}

/// Case-insensitive comparison of two ASCII strings
pub fn eqlIgnoreCase(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    for (a, b) |ca, cb| {
        if (toLower(ca) != toLower(cb)) return false;
    }
    return true;
}

/// Trims ASCII whitespace from both ends of a string
pub fn trim(bytes: []const u8) []const u8 {
    return trimRight(trimLeft(bytes));
}

/// Trims ASCII whitespace from the left of a string
pub fn trimLeft(bytes: []const u8) []const u8 {
    var start: usize = 0;
    while (start < bytes.len and isWhitespace(bytes[start])) {
        start += 1;
    }
    return bytes[start..];
}

/// Trims ASCII whitespace from the right of a string
pub fn trimRight(bytes: []const u8) []const u8 {
    var end = bytes.len;
    while (end > 0 and isWhitespace(bytes[end - 1])) {
        end -= 1;
    }
    return bytes[0..end];
}

/// Checks if a string starts with a prefix (case-insensitive)
pub fn startsWithIgnoreCase(haystack: []const u8, prefix: []const u8) bool {
    if (prefix.len > haystack.len) return false;
    return eqlIgnoreCase(haystack[0..prefix.len], prefix);
}

/// Checks if a string ends with a suffix (case-insensitive)
pub fn endsWithIgnoreCase(haystack: []const u8, suffix: []const u8) bool {
    if (suffix.len > haystack.len) return false;
    return eqlIgnoreCase(haystack[haystack.len - suffix.len ..], suffix);
}

/// Parses an unsigned integer from ASCII decimal digits
pub fn parseUnsigned(comptime T: type, bytes: []const u8) ?T {
    if (bytes.len == 0) return null;

    var result: T = 0;
    for (bytes) |b| {
        if (!isDigit(b)) return null;
        const digit: T = @as(T, b - '0');
        result = result *% 10 +% digit;
    }
    return result;
}

/// Parses a signed integer from ASCII decimal digits (with optional leading sign)
pub fn parseSigned(comptime T: type, bytes: []const u8) ?T {
    if (bytes.len == 0) return null;

    var start: usize = 0;
    var negative = false;

    if (bytes[0] == '-') {
        negative = true;
        start = 1;
    } else if (bytes[0] == '+') {
        start = 1;
    }

    if (start >= bytes.len) return null;

    const UnsignedT = @Type(.{ .int = .{ .signedness = .unsigned, .bits = @typeInfo(T).int.bits } });
    const unsigned = parseUnsigned(UnsignedT, bytes[start..]) orelse return null;

    if (negative) {
        // For negative: max allowed unsigned value is abs(minInt), which equals maxInt + 1 for two's complement
        // minInt = -(maxInt + 1), so |minInt| = maxInt + 1
        const max_negative: UnsignedT = @as(UnsignedT, @intCast(std.math.maxInt(T))) + 1;
        if (unsigned > max_negative) {
            return null; // Overflow
        }
        if (unsigned == max_negative) {
            return std.math.minInt(T);
        }
        return -@as(T, @intCast(unsigned));
    } else {
        if (unsigned > @as(UnsignedT, @intCast(std.math.maxInt(T)))) {
            return null; // Overflow
        }
        return @intCast(unsigned);
    }
}

test "character classification" {
    const testing = std.testing;

    try testing.expect(isAscii('A'));
    try testing.expect(isAscii(0x7F));
    try testing.expect(!isAscii(0x80));

    try testing.expect(isDigit('0'));
    try testing.expect(isDigit('9'));
    try testing.expect(!isDigit('A'));

    try testing.expect(isAlpha('a'));
    try testing.expect(isAlpha('Z'));
    try testing.expect(!isAlpha('5'));

    try testing.expect(isHexDigit('0'));
    try testing.expect(isHexDigit('f'));
    try testing.expect(isHexDigit('F'));
    try testing.expect(!isHexDigit('g'));

    try testing.expect(isWhitespace(' '));
    try testing.expect(isWhitespace('\t'));
    try testing.expect(!isWhitespace('x'));
}

test "case conversion" {
    const testing = std.testing;

    try testing.expectEqual(@as(u8, 'a'), toLower('A'));
    try testing.expectEqual(@as(u8, 'z'), toLower('Z'));
    try testing.expectEqual(@as(u8, 'a'), toLower('a'));
    try testing.expectEqual(@as(u8, '5'), toLower('5'));

    try testing.expectEqual(@as(u8, 'A'), toUpper('a'));
    try testing.expectEqual(@as(u8, 'Z'), toUpper('z'));
    try testing.expectEqual(@as(u8, 'A'), toUpper('A'));

    var buf = "Hello World".*;
    toLowerInPlace(&buf);
    try testing.expectEqualSlices(u8, "hello world", &buf);
}

test "hex conversion" {
    const testing = std.testing;

    try testing.expectEqual(@as(?u4, 0), hexValue('0'));
    try testing.expectEqual(@as(?u4, 9), hexValue('9'));
    try testing.expectEqual(@as(?u4, 10), hexValue('a'));
    try testing.expectEqual(@as(?u4, 15), hexValue('F'));
    try testing.expectEqual(@as(?u4, null), hexValue('g'));

    try testing.expectEqual(@as(u8, '0'), toHexDigit(0, false));
    try testing.expectEqual(@as(u8, 'a'), toHexDigit(10, false));
    try testing.expectEqual(@as(u8, 'F'), toHexDigit(15, true));
}

test "eqlIgnoreCase" {
    const testing = std.testing;

    try testing.expect(eqlIgnoreCase("hello", "HELLO"));
    try testing.expect(eqlIgnoreCase("Hello", "hElLo"));
    try testing.expect(!eqlIgnoreCase("hello", "world"));
    try testing.expect(!eqlIgnoreCase("hello", "hello!"));
}

test "trim" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "hello", trim("  hello  "));
    try testing.expectEqualSlices(u8, "hello", trim("\t\nhello\r\n"));
    try testing.expectEqualSlices(u8, "", trim("   "));
    try testing.expectEqualSlices(u8, "hello", trim("hello"));
}

test "parseUnsigned" {
    const testing = std.testing;

    try testing.expectEqual(@as(?u32, 123), parseUnsigned(u32, "123"));
    try testing.expectEqual(@as(?u32, 0), parseUnsigned(u32, "0"));
    try testing.expectEqual(@as(?u32, null), parseUnsigned(u32, ""));
    try testing.expectEqual(@as(?u32, null), parseUnsigned(u32, "abc"));
}

test "parseSigned" {
    const testing = std.testing;

    try testing.expectEqual(@as(?i32, 123), parseSigned(i32, "123"));
    try testing.expectEqual(@as(?i32, -123), parseSigned(i32, "-123"));
    try testing.expectEqual(@as(?i32, 456), parseSigned(i32, "+456"));
    try testing.expectEqual(@as(?i32, null), parseSigned(i32, ""));
    try testing.expectEqual(@as(?i32, null), parseSigned(i32, "-"));
}
