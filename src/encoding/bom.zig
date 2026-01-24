// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Byte Order Mark (BOM) handling.
//!
//! This module provides functions for working with BOMs in various encodings.

const std = @import("std");
const types = @import("types");

pub const Encoding = types.Encoding;

/// BOM bytes for each encoding
pub const bom_bytes = struct {
    pub const utf8 = "\xEF\xBB\xBF";
    pub const utf16_le = "\xFF\xFE";
    pub const utf16_be = "\xFE\xFF";
    pub const utf32_le = "\xFF\xFE\x00\x00";
    pub const utf32_be = "\x00\x00\xFE\xFF";
};

/// Gets the BOM bytes for an encoding (or null for encodings without BOM)
pub fn getBytes(encoding: Encoding) ?[]const u8 {
    return switch (encoding) {
        .utf8 => bom_bytes.utf8,
        .utf16_le => bom_bytes.utf16_le,
        .utf16_be => bom_bytes.utf16_be,
        .utf32_le => bom_bytes.utf32_le,
        .utf32_be => bom_bytes.utf32_be,
        .ascii, .latin1 => null,
    };
}

/// Gets the length of the BOM for an encoding
pub fn getLength(encoding: Encoding) usize {
    return switch (encoding) {
        .utf8 => 3,
        .utf16_le, .utf16_be => 2,
        .utf32_le, .utf32_be => 4,
        .ascii, .latin1 => 0,
    };
}

/// Checks if bytes start with a BOM for the specified encoding
pub fn hasForEncoding(bytes: []const u8, encoding: Encoding) bool {
    const bom = getBytes(encoding) orelse return false;
    if (bytes.len < bom.len) return false;
    return std.mem.eql(u8, bytes[0..bom.len], bom);
}

/// Detects which encoding's BOM is present (if any)
pub fn detectEncoding(bytes: []const u8) ?Encoding {
    // Check longer BOMs first
    if (bytes.len >= 4) {
        if (std.mem.eql(u8, bytes[0..4], bom_bytes.utf32_le)) return .utf32_le;
        if (std.mem.eql(u8, bytes[0..4], bom_bytes.utf32_be)) return .utf32_be;
    }
    if (bytes.len >= 3) {
        if (std.mem.eql(u8, bytes[0..3], bom_bytes.utf8)) return .utf8;
    }
    if (bytes.len >= 2) {
        // Note: Check UTF-32 LE before UTF-16 LE since they share prefix
        if (bytes.len < 4 or !std.mem.eql(u8, bytes[0..4], bom_bytes.utf32_le)) {
            if (std.mem.eql(u8, bytes[0..2], bom_bytes.utf16_le)) return .utf16_le;
        }
        if (std.mem.eql(u8, bytes[0..2], bom_bytes.utf16_be)) return .utf16_be;
    }
    return null;
}

/// Strips the BOM from bytes if present and matches the expected encoding
pub fn strip(bytes: []const u8, encoding: Encoding) []const u8 {
    if (hasForEncoding(bytes, encoding)) {
        return bytes[getLength(encoding)..];
    }
    return bytes;
}

/// Strips any BOM from bytes regardless of encoding
pub fn stripAny(bytes: []const u8) []const u8 {
    if (detectEncoding(bytes)) |encoding| {
        return bytes[getLength(encoding)..];
    }
    return bytes;
}

/// Prepends the BOM for the specified encoding
pub fn prepend(allocator: std.mem.Allocator, bytes: []const u8, encoding: Encoding) ![]u8 {
    const bom = getBytes(encoding) orelse {
        const result = try allocator.alloc(u8, bytes.len);
        @memcpy(result, bytes);
        return result;
    };

    const result = try allocator.alloc(u8, bom.len + bytes.len);
    @memcpy(result[0..bom.len], bom);
    @memcpy(result[bom.len..], bytes);
    return result;
}

/// Checks if a BOM is present at the start of bytes
pub fn hasAny(bytes: []const u8) bool {
    return detectEncoding(bytes) != null;
}

/// Writes a BOM to a writer
pub fn write(writer: anytype, encoding: Encoding) !void {
    if (getBytes(encoding)) |bom| {
        try writer.writeAll(bom);
    }
}

test "getBytes" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, bom_bytes.utf8, getBytes(.utf8).?);
    try testing.expectEqualSlices(u8, bom_bytes.utf16_le, getBytes(.utf16_le).?);
    try testing.expect(getBytes(.ascii) == null);
}

test "getLength" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 3), getLength(.utf8));
    try testing.expectEqual(@as(usize, 2), getLength(.utf16_le));
    try testing.expectEqual(@as(usize, 4), getLength(.utf32_be));
    try testing.expectEqual(@as(usize, 0), getLength(.ascii));
}

test "hasForEncoding" {
    const testing = std.testing;

    try testing.expect(hasForEncoding("\xEF\xBB\xBFHello", .utf8));
    try testing.expect(!hasForEncoding("Hello", .utf8));
    try testing.expect(hasForEncoding("\xFF\xFEHe", .utf16_le));
}

test "detectEncoding" {
    const testing = std.testing;

    try testing.expectEqual(Encoding.utf8, detectEncoding("\xEF\xBB\xBF").?);
    try testing.expectEqual(Encoding.utf16_le, detectEncoding("\xFF\xFE").?);
    try testing.expectEqual(Encoding.utf16_be, detectEncoding("\xFE\xFF").?);
    try testing.expectEqual(Encoding.utf32_le, detectEncoding("\xFF\xFE\x00\x00").?);
    try testing.expectEqual(Encoding.utf32_be, detectEncoding("\x00\x00\xFE\xFF").?);
    try testing.expect(detectEncoding("Hello") == null);
}

test "strip" {
    const testing = std.testing;

    const with_bom = "\xEF\xBB\xBFHello";
    try testing.expectEqualSlices(u8, "Hello", strip(with_bom, .utf8));
    try testing.expectEqualSlices(u8, with_bom, strip(with_bom, .utf16_le)); // Wrong encoding
}

test "stripAny" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "Hello", stripAny("\xEF\xBB\xBFHello"));
    try testing.expectEqualSlices(u8, "Hello", stripAny("Hello"));
}

test "prepend" {
    const testing = std.testing;

    const result = try prepend(testing.allocator, "Hello", .utf8);
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "\xEF\xBB\xBFHello", result);
}
