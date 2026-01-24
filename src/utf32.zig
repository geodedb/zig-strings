// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! UTF-32 encoding and decoding operations.
//!
//! UTF-32 is a fixed-width character encoding that uses 4 bytes per code point.
//! Each code point is stored directly as a 32-bit integer.

const std = @import("std");
const types = @import("types");
const codepoint = @import("codepoint");

pub const Codepoint = types.Codepoint;
pub const StringError = types.StringError;
pub const Utf32Unit = types.Utf32Unit;

/// Decodes a single UTF-32 code point.
/// Validates that the value is a valid Unicode code point.
pub fn decode(units: []const u32) StringError!types.DecodeResult(Codepoint) {
    if (units.len == 0) {
        return StringError.TruncatedSequence;
    }

    const value = units[0];

    // Check for surrogates and out-of-range
    if (value > types.max_codepoint or types.surrogate.isSurrogate(@truncate(value))) {
        return StringError.InvalidCodepoint;
    }

    return .{
        .value = @truncate(value),
        .bytes_consumed = 1,
    };
}

/// Encodes a code point as UTF-32.
/// Returns the number of code units written (always 1).
pub fn encode(cp: Codepoint, buf: []u32) StringError!usize {
    if (!codepoint.isValid(cp)) {
        return StringError.InvalidCodepoint;
    }

    if (buf.len < 1) {
        return StringError.BufferTooSmall;
    }

    buf[0] = cp;
    return 1;
}

/// Validates a UTF-32 sequence.
pub fn isValid(units: []const u32) bool {
    for (units) |unit| {
        if (unit > types.max_codepoint or types.surrogate.isSurrogate(@truncate(unit))) {
            return false;
        }
    }
    return true;
}

/// Counts the number of code points (equals the number of units for valid UTF-32).
pub fn countCodepoints(units: []const u32) ?usize {
    if (!isValid(units)) return null;
    return units.len;
}

/// Iterator over UTF-32 code points
pub const Iterator = struct {
    units: []const u32,
    index: usize,

    pub fn init(units: []const u32) Iterator {
        return .{ .units = units, .index = 0 };
    }

    /// Returns the next code point, or null at end.
    pub fn next(self: *Iterator) ?Codepoint {
        if (self.index >= self.units.len) {
            return null;
        }

        const unit = self.units[self.index];
        self.index += 1;

        // Return replacement character for invalid values
        if (unit > types.max_codepoint or types.surrogate.isSurrogate(@truncate(unit))) {
            return types.replacement_character;
        }

        return @truncate(unit);
    }

    /// Peek at the next code point without advancing
    pub fn peek(self: *const Iterator) ?Codepoint {
        if (self.index >= self.units.len) {
            return null;
        }

        const unit = self.units[self.index];

        if (unit > types.max_codepoint or types.surrogate.isSurrogate(@truncate(unit))) {
            return types.replacement_character;
        }

        return @truncate(unit);
    }

    /// Reset the iterator
    pub fn reset(self: *Iterator) void {
        self.index = 0;
    }
};

/// Creates an iterator over UTF-32 code points
pub fn iterator(units: []const u32) Iterator {
    return Iterator.init(units);
}

/// Converts UTF-32 to UTF-8, writing to the provided buffer.
pub fn toUtf8(units: []const u32, utf8_buf: []u8) StringError!usize {
    var iter = iterator(units);
    var utf8_index: usize = 0;

    while (iter.next()) |cp| {
        const len = codepoint.utf8Length(cp);
        if (utf8_index + len > utf8_buf.len) {
            return StringError.BufferTooSmall;
        }

        var tmp: [4]u8 = undefined;
        const encoded = codepoint.encodeUtf8(cp, &tmp);
        @memcpy(utf8_buf[utf8_index..][0..len], encoded);
        utf8_index += len;
    }

    return utf8_index;
}

/// Converts UTF-32 to UTF-16, writing to the provided buffer.
pub fn toUtf16(units: []const u32, utf16_buf: []u16) StringError!usize {
    var iter = iterator(units);
    var utf16_index: usize = 0;

    while (iter.next()) |cp| {
        const len = codepoint.utf16Length(cp);
        if (utf16_index + len > utf16_buf.len) {
            return StringError.BufferTooSmall;
        }

        var tmp: [2]u16 = undefined;
        const encoded = codepoint.encodeUtf16(cp, &tmp);
        for (encoded, 0..) |unit, i| {
            utf16_buf[utf16_index + i] = unit;
        }
        utf16_index += len;
    }

    return utf16_index;
}

/// Calculates the UTF-8 length of a UTF-32 string.
pub fn utf8Length(units: []const u32) ?usize {
    var len: usize = 0;
    var iter = iterator(units);
    while (iter.next()) |cp| {
        len += codepoint.utf8Length(cp);
    }
    return len;
}

/// Calculates the UTF-16 length of a UTF-32 string.
pub fn utf16Length(units: []const u32) ?usize {
    var len: usize = 0;
    var iter = iterator(units);
    while (iter.next()) |cp| {
        len += codepoint.utf16Length(cp);
    }
    return len;
}

/// Reads a u32 from bytes with the specified endianness.
pub fn readUnit(bytes: []const u8, endian: std.builtin.Endian) ?u32 {
    if (bytes.len < 4) return null;
    return std.mem.readInt(u32, bytes[0..4], endian);
}

/// Writes a u32 to bytes with the specified endianness.
pub fn writeUnit(buf: []u8, value: u32, endian: std.builtin.Endian) void {
    std.mem.writeInt(u32, buf[0..4], value, endian);
}

/// Decodes UTF-32 from raw bytes with the specified byte order.
pub fn decodeBytes(bytes: []const u8, endian: std.builtin.Endian) StringError!types.DecodeResult(Codepoint) {
    if (bytes.len < 4) {
        return StringError.TruncatedSequence;
    }

    const value = std.mem.readInt(u32, bytes[0..4], endian);

    if (value > types.max_codepoint or types.surrogate.isSurrogate(@truncate(value))) {
        return StringError.InvalidCodepoint;
    }

    return .{
        .value = @truncate(value),
        .bytes_consumed = 4,
    };
}

test "decode valid" {
    const testing = std.testing;

    const result = try decode(&[_]u32{ 'A', 'B', 'C' });
    try testing.expectEqual(@as(Codepoint, 'A'), result.value);
    try testing.expectEqual(@as(usize, 1), result.bytes_consumed);

    const emoji = try decode(&[_]u32{0x1F600});
    try testing.expectEqual(@as(Codepoint, 0x1F600), emoji.value);
}

test "decode invalid" {
    const testing = std.testing;

    // Surrogate value
    try testing.expectError(StringError.InvalidCodepoint, decode(&[_]u32{0xD800}));

    // Out of range
    try testing.expectError(StringError.InvalidCodepoint, decode(&[_]u32{0x110000}));
}

test "isValid" {
    const testing = std.testing;

    try testing.expect(isValid(&[_]u32{ 'H', 'e', 'l', 'l', 'o' }));
    try testing.expect(isValid(&[_]u32{0x1F600}));
    try testing.expect(!isValid(&[_]u32{0xD800}));
    try testing.expect(!isValid(&[_]u32{0x110000}));
}

test "encode" {
    const testing = std.testing;

    var buf: [1]u32 = undefined;

    const len = try encode('A', &buf);
    try testing.expectEqual(@as(usize, 1), len);
    try testing.expectEqual(@as(u32, 'A'), buf[0]);

    // Invalid code point
    try testing.expectError(StringError.InvalidCodepoint, encode(0xD800, &buf));
}

test "toUtf8" {
    const testing = std.testing;

    var buf: [10]u8 = undefined;

    const len = try toUtf8(&[_]u32{ 'A', 0x4E2D, 0x1F600 }, &buf);
    try testing.expectEqualSlices(u8, "A\xE4\xB8\xAD\xF0\x9F\x98\x80", buf[0..len]);
}

test "toUtf16" {
    const testing = std.testing;

    var buf: [10]u16 = undefined;

    const len = try toUtf16(&[_]u32{ 'A', 0x1F600 }, &buf);
    try testing.expectEqual(@as(usize, 3), len);
    try testing.expectEqualSlices(u16, &[_]u16{ 'A', 0xD83D, 0xDE00 }, buf[0..len]);
}

test "iterator" {
    const testing = std.testing;

    var iter = iterator(&[_]u32{ 'A', 0x4E2D, 0x1F600 });
    try testing.expectEqual(@as(?Codepoint, 'A'), iter.next());
    try testing.expectEqual(@as(?Codepoint, 0x4E2D), iter.next());
    try testing.expectEqual(@as(?Codepoint, 0x1F600), iter.next());
    try testing.expectEqual(@as(?Codepoint, null), iter.next());
}
