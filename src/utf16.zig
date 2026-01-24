// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! UTF-16 encoding and decoding operations (RFC 2781).
//!
//! UTF-16 is a variable-width character encoding that uses 2 or 4 bytes per code point.
//! Code points in the BMP (U+0000 to U+FFFF) use one 16-bit code unit.
//! Code points outside the BMP (U+10000 to U+10FFFF) use surrogate pairs.

const std = @import("std");
const types = @import("types");
const codepoint = @import("codepoint");

pub const Codepoint = types.Codepoint;
pub const StringError = types.StringError;
pub const Utf16Unit = types.Utf16Unit;

/// Decodes a single UTF-16 code point from a slice of code units.
/// Handles surrogate pairs for code points outside the BMP.
pub fn decode(units: []const u16) StringError!types.DecodeResult(Codepoint) {
    if (units.len == 0) {
        return StringError.TruncatedSequence;
    }

    const first = units[0];

    // Check for surrogate
    if (types.surrogate.isHighSurrogate(first)) {
        if (units.len < 2) {
            return StringError.TruncatedSequence;
        }
        const second = units[1];
        if (!types.surrogate.isLowSurrogate(second)) {
            return StringError.InvalidUtf16;
        }
        const cp = codepoint.decodeSurrogatePair(first, second) orelse
            return StringError.InvalidUtf16;
        return .{
            .value = cp,
            .bytes_consumed = 2,
        };
    }

    // Lone low surrogate is invalid
    if (types.surrogate.isLowSurrogate(first)) {
        return StringError.InvalidUtf16;
    }

    // BMP code point
    return .{
        .value = first,
        .bytes_consumed = 1,
    };
}

/// Encodes a code point as UTF-16.
/// Returns the number of code units written.
pub fn encode(cp: Codepoint, buf: []u16) StringError!usize {
    if (!codepoint.isValid(cp)) {
        return StringError.InvalidCodepoint;
    }

    const len = codepoint.utf16Length(cp);
    if (buf.len < len) {
        return StringError.BufferTooSmall;
    }

    var tmp: [2]u16 = undefined;
    const encoded = codepoint.encodeUtf16(cp, &tmp);
    for (encoded, 0..) |unit, i| {
        buf[i] = unit;
    }

    return len;
}

/// Validates a UTF-16 code unit sequence.
pub fn isValid(units: []const u16) bool {
    var i: usize = 0;
    while (i < units.len) {
        const result = decode(units[i..]) catch return false;
        i += result.bytes_consumed;
    }
    return true;
}

/// Counts the number of code points in a UTF-16 string.
pub fn countCodepoints(units: []const u16) ?usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < units.len) {
        const result = decode(units[i..]) catch return null;
        i += result.bytes_consumed;
        count += 1;
    }
    return count;
}

/// Iterator over UTF-16 code points
pub const Iterator = struct {
    units: []const u16,
    index: usize,

    pub fn init(units: []const u16) Iterator {
        return .{ .units = units, .index = 0 };
    }

    /// Returns the next code point, or null at end of string.
    pub fn next(self: *Iterator) ?Codepoint {
        if (self.index >= self.units.len) {
            return null;
        }

        const result = decode(self.units[self.index..]) catch {
            self.index += 1;
            return types.replacement_character;
        };

        self.index += result.bytes_consumed;
        return result.value;
    }

    /// Peek at the next code point without advancing
    pub fn peek(self: *const Iterator) ?Codepoint {
        if (self.index >= self.units.len) {
            return null;
        }

        const result = decode(self.units[self.index..]) catch {
            return types.replacement_character;
        };

        return result.value;
    }

    /// Reset the iterator
    pub fn reset(self: *Iterator) void {
        self.index = 0;
    }
};

/// Creates an iterator over UTF-16 code points
pub fn iterator(units: []const u16) Iterator {
    return Iterator.init(units);
}

/// Converts UTF-16 to UTF-8, writing to the provided buffer.
/// Returns the number of bytes written.
pub fn toUtf8(units: []const u16, utf8_buf: []u8) StringError!usize {
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

/// Calculates the UTF-8 length of a UTF-16 string.
pub fn utf8Length(units: []const u16) ?usize {
    var len: usize = 0;
    var iter = iterator(units);
    while (iter.next()) |cp| {
        len += codepoint.utf8Length(cp);
    }
    return len;
}

/// Reads a u16 from bytes with the specified endianness.
pub fn readUnit(bytes: []const u8, endian: std.builtin.Endian) ?u16 {
    if (bytes.len < 2) return null;
    return std.mem.readInt(u16, bytes[0..2], endian);
}

/// Writes a u16 to bytes with the specified endianness.
pub fn writeUnit(buf: []u8, value: u16, endian: std.builtin.Endian) void {
    std.mem.writeInt(u16, buf[0..2], value, endian);
}

/// Decodes UTF-16 from raw bytes with the specified byte order.
pub fn decodeBytes(bytes: []const u8, endian: std.builtin.Endian) StringError!types.DecodeResult(Codepoint) {
    if (bytes.len < 2) {
        return StringError.TruncatedSequence;
    }

    const first = std.mem.readInt(u16, bytes[0..2], endian);

    if (types.surrogate.isHighSurrogate(first)) {
        if (bytes.len < 4) {
            return StringError.TruncatedSequence;
        }
        const second = std.mem.readInt(u16, bytes[2..4], endian);
        if (!types.surrogate.isLowSurrogate(second)) {
            return StringError.InvalidUtf16;
        }
        const cp = codepoint.decodeSurrogatePair(first, second) orelse
            return StringError.InvalidUtf16;
        return .{
            .value = cp,
            .bytes_consumed = 4,
        };
    }

    if (types.surrogate.isLowSurrogate(first)) {
        return StringError.InvalidUtf16;
    }

    return .{
        .value = first,
        .bytes_consumed = 2,
    };
}

test "decode BMP" {
    const testing = std.testing;

    const result = try decode(&[_]u16{ 'A', 'B', 'C' });
    try testing.expectEqual(@as(Codepoint, 'A'), result.value);
    try testing.expectEqual(@as(usize, 1), result.bytes_consumed);

    const chinese = try decode(&[_]u16{0x4E2D});
    try testing.expectEqual(@as(Codepoint, 0x4E2D), chinese.value);
}

test "decode surrogate pair" {
    const testing = std.testing;

    // Emoji U+1F600
    const result = try decode(&[_]u16{ 0xD83D, 0xDE00 });
    try testing.expectEqual(@as(Codepoint, 0x1F600), result.value);
    try testing.expectEqual(@as(usize, 2), result.bytes_consumed);
}

test "decode invalid" {
    const testing = std.testing;

    // Lone high surrogate
    try testing.expectError(StringError.TruncatedSequence, decode(&[_]u16{0xD83D}));

    // Lone low surrogate
    try testing.expectError(StringError.InvalidUtf16, decode(&[_]u16{0xDE00}));

    // High followed by non-low
    try testing.expectError(StringError.InvalidUtf16, decode(&[_]u16{ 0xD83D, 0x0041 }));
}

test "isValid" {
    const testing = std.testing;

    try testing.expect(isValid(&[_]u16{ 'H', 'e', 'l', 'l', 'o' }));
    try testing.expect(isValid(&[_]u16{ 0xD83D, 0xDE00 })); // emoji
    try testing.expect(!isValid(&[_]u16{0xD83D})); // lone high surrogate
    try testing.expect(!isValid(&[_]u16{0xDE00})); // lone low surrogate
}

test "countCodepoints" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 5), countCodepoints(&[_]u16{ 'H', 'e', 'l', 'l', 'o' }));
    try testing.expectEqual(@as(?usize, 1), countCodepoints(&[_]u16{ 0xD83D, 0xDE00 }));
    try testing.expectEqual(@as(?usize, null), countCodepoints(&[_]u16{0xD83D}));
}

test "encode" {
    const testing = std.testing;

    var buf: [2]u16 = undefined;

    const len1 = try encode('A', &buf);
    try testing.expectEqual(@as(usize, 1), len1);
    try testing.expectEqual(@as(u16, 'A'), buf[0]);

    const len2 = try encode(0x1F600, &buf);
    try testing.expectEqual(@as(usize, 2), len2);
    try testing.expectEqual(@as(u16, 0xD83D), buf[0]);
    try testing.expectEqual(@as(u16, 0xDE00), buf[1]);
}

test "toUtf8" {
    const testing = std.testing;

    var buf: [10]u8 = undefined;

    const len1 = try toUtf8(&[_]u16{ 'A', 'B', 'C' }, &buf);
    try testing.expectEqual(@as(usize, 3), len1);
    try testing.expectEqualSlices(u8, "ABC", buf[0..len1]);

    const len2 = try toUtf8(&[_]u16{0x4E2D}, &buf);
    try testing.expectEqual(@as(usize, 3), len2);
    try testing.expectEqualSlices(u8, "\xE4\xB8\xAD", buf[0..len2]);

    const len3 = try toUtf8(&[_]u16{ 0xD83D, 0xDE00 }, &buf);
    try testing.expectEqual(@as(usize, 4), len3);
    try testing.expectEqualSlices(u8, "\xF0\x9F\x98\x80", buf[0..len3]);
}

test "iterator" {
    const testing = std.testing;

    var iter = iterator(&[_]u16{ 'A', 0x4E2D, 0xD83D, 0xDE00 });
    try testing.expectEqual(@as(?Codepoint, 'A'), iter.next());
    try testing.expectEqual(@as(?Codepoint, 0x4E2D), iter.next());
    try testing.expectEqual(@as(?Codepoint, 0x1F600), iter.next());
    try testing.expectEqual(@as(?Codepoint, null), iter.next());
}
