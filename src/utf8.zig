// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! UTF-8 encoding and decoding operations (RFC 3629).
//!
//! UTF-8 is a variable-width character encoding that uses 1-4 bytes per code point.
//! This module provides functions for encoding, decoding, and validating UTF-8 sequences.

const std = @import("std");
const types = @import("types");
const codepoint = @import("codepoint");

pub const Codepoint = types.Codepoint;
pub const StringError = types.StringError;

/// UTF-8 sequence length based on the first byte
pub fn sequenceLength(first_byte: u8) ?u3 {
    return switch (first_byte) {
        0x00...0x7F => 1,
        0xC2...0xDF => 2,
        0xE0...0xEF => 3,
        0xF0...0xF4 => 4,
        else => null, // Invalid start byte (0x80-0xBF, 0xC0-0xC1, 0xF5-0xFF)
    };
}

/// Checks if a byte is a UTF-8 continuation byte (0x80-0xBF)
pub fn isContinuationByte(byte: u8) bool {
    return byte & 0xC0 == 0x80;
}

/// Decodes a single UTF-8 code point from a byte slice.
/// Returns the decoded code point and the number of bytes consumed.
pub fn decode(bytes: []const u8) StringError!types.DecodeResult(Codepoint) {
    if (bytes.len == 0) {
        return StringError.TruncatedSequence;
    }

    const len = sequenceLength(bytes[0]) orelse return StringError.InvalidUtf8;

    if (bytes.len < len) {
        return StringError.TruncatedSequence;
    }

    // Validate continuation bytes
    for (bytes[1..len]) |b| {
        if (!isContinuationByte(b)) {
            return StringError.InvalidUtf8;
        }
    }

    const cp: Codepoint = switch (len) {
        1 => bytes[0],
        2 => (@as(Codepoint, bytes[0] & 0x1F) << 6) |
            @as(Codepoint, bytes[1] & 0x3F),
        3 => (@as(Codepoint, bytes[0] & 0x0F) << 12) |
            (@as(Codepoint, bytes[1] & 0x3F) << 6) |
            @as(Codepoint, bytes[2] & 0x3F),
        4 => (@as(Codepoint, bytes[0] & 0x07) << 18) |
            (@as(Codepoint, bytes[1] & 0x3F) << 12) |
            (@as(Codepoint, bytes[2] & 0x3F) << 6) |
            @as(Codepoint, bytes[3] & 0x3F),
        else => unreachable,
    };

    // Check for overlong encodings
    if (codepoint.utf8Length(cp) != len) {
        return StringError.InvalidUtf8;
    }

    // Check for surrogates and out-of-range values
    if (types.surrogate.isSurrogate(cp) or cp > types.max_codepoint) {
        return StringError.InvalidCodepoint;
    }

    return .{
        .value = cp,
        .bytes_consumed = len,
    };
}

/// Encodes a code point as UTF-8.
/// Returns the number of bytes written.
pub fn encode(cp: Codepoint, buf: []u8) StringError!usize {
    if (!codepoint.isValid(cp)) {
        return StringError.InvalidCodepoint;
    }

    const len = codepoint.utf8Length(cp);
    if (buf.len < len) {
        return StringError.BufferTooSmall;
    }

    var tmp: [4]u8 = undefined;
    const encoded = codepoint.encodeUtf8(cp, &tmp);
    @memcpy(buf[0..len], encoded);

    return len;
}

/// Validates a UTF-8 byte sequence.
/// Returns true if the entire sequence is valid UTF-8.
pub fn isValid(bytes: []const u8) bool {
    var i: usize = 0;
    while (i < bytes.len) {
        const result = decode(bytes[i..]) catch return false;
        i += result.bytes_consumed;
    }
    return true;
}

/// Counts the number of code points in a valid UTF-8 string.
/// Returns null if the string contains invalid UTF-8.
pub fn countCodepoints(bytes: []const u8) ?usize {
    var count: usize = 0;
    var i: usize = 0;
    while (i < bytes.len) {
        const result = decode(bytes[i..]) catch return null;
        i += result.bytes_consumed;
        count += 1;
    }
    return count;
}

/// Iterator over UTF-8 code points
pub const Iterator = struct {
    bytes: []const u8,
    index: usize,

    pub fn init(bytes: []const u8) Iterator {
        return .{ .bytes = bytes, .index = 0 };
    }

    /// Returns the next code point, or null at end of string.
    /// Returns replacement character for invalid sequences.
    pub fn next(self: *Iterator) ?Codepoint {
        if (self.index >= self.bytes.len) {
            return null;
        }

        const result = decode(self.bytes[self.index..]) catch {
            // Skip one byte on error and return replacement character
            self.index += 1;
            return types.replacement_character;
        };

        self.index += result.bytes_consumed;
        return result.value;
    }

    /// Returns the next code point along with its byte position.
    pub fn nextWithIndex(self: *Iterator) ?struct { cp: Codepoint, index: usize } {
        if (self.index >= self.bytes.len) {
            return null;
        }

        const start = self.index;
        const result = decode(self.bytes[self.index..]) catch {
            self.index += 1;
            return .{ .cp = types.replacement_character, .index = start };
        };

        self.index += result.bytes_consumed;
        return .{ .cp = result.value, .index = start };
    }

    /// Peek at the next code point without advancing
    pub fn peek(self: *const Iterator) ?Codepoint {
        if (self.index >= self.bytes.len) {
            return null;
        }

        const result = decode(self.bytes[self.index..]) catch {
            return types.replacement_character;
        };

        return result.value;
    }

    /// Reset the iterator to the beginning
    pub fn reset(self: *Iterator) void {
        self.index = 0;
    }

    /// Returns remaining bytes
    pub fn rest(self: *const Iterator) []const u8 {
        return self.bytes[self.index..];
    }
};

/// Creates an iterator over UTF-8 code points
pub fn iterator(bytes: []const u8) Iterator {
    return Iterator.init(bytes);
}

/// Converts UTF-8 to UTF-16, writing to the provided buffer.
/// Returns the number of UTF-16 code units written.
pub fn toUtf16(utf8_bytes: []const u8, utf16_buf: []u16) StringError!usize {
    var utf8_iter = iterator(utf8_bytes);
    var utf16_index: usize = 0;

    while (utf8_iter.next()) |cp| {
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

/// Calculates the UTF-16 length of a UTF-8 string.
pub fn utf16Length(utf8_bytes: []const u8) ?usize {
    var len: usize = 0;
    var iter = iterator(utf8_bytes);
    while (iter.next()) |cp| {
        len += codepoint.utf16Length(cp);
    }
    return len;
}

test "sequenceLength" {
    const testing = std.testing;

    try testing.expectEqual(@as(?u3, 1), sequenceLength('A'));
    try testing.expectEqual(@as(?u3, 2), sequenceLength(0xC2));
    try testing.expectEqual(@as(?u3, 3), sequenceLength(0xE0));
    try testing.expectEqual(@as(?u3, 4), sequenceLength(0xF0));

    // Invalid start bytes
    try testing.expectEqual(@as(?u3, null), sequenceLength(0x80));
    try testing.expectEqual(@as(?u3, null), sequenceLength(0xC0));
    try testing.expectEqual(@as(?u3, null), sequenceLength(0xF5));
}

test "decode valid sequences" {
    const testing = std.testing;

    // ASCII
    const ascii = try decode("A");
    try testing.expectEqual(@as(Codepoint, 'A'), ascii.value);
    try testing.expectEqual(@as(usize, 1), ascii.bytes_consumed);

    // 2-byte sequence (é)
    const two_byte = try decode("\xC3\xA9");
    try testing.expectEqual(@as(Codepoint, 0x00E9), two_byte.value);
    try testing.expectEqual(@as(usize, 2), two_byte.bytes_consumed);

    // 3-byte sequence (中)
    const three_byte = try decode("\xE4\xB8\xAD");
    try testing.expectEqual(@as(Codepoint, 0x4E2D), three_byte.value);
    try testing.expectEqual(@as(usize, 3), three_byte.bytes_consumed);

    // 4-byte sequence (emoji)
    const four_byte = try decode("\xF0\x9F\x98\x80");
    try testing.expectEqual(@as(Codepoint, 0x1F600), four_byte.value);
    try testing.expectEqual(@as(usize, 4), four_byte.bytes_consumed);
}

test "decode invalid sequences" {
    const testing = std.testing;

    // Invalid start byte
    try testing.expectError(StringError.InvalidUtf8, decode("\x80"));
    try testing.expectError(StringError.InvalidUtf8, decode("\xFF"));

    // Truncated sequence
    try testing.expectError(StringError.TruncatedSequence, decode("\xC3"));
    try testing.expectError(StringError.TruncatedSequence, decode("\xE4\xB8"));

    // Overlong encoding (2-byte encoding of ASCII)
    try testing.expectError(StringError.InvalidUtf8, decode("\xC0\x80"));

    // Encoded surrogate
    try testing.expectError(StringError.InvalidCodepoint, decode("\xED\xA0\x80"));
}

test "isValid" {
    const testing = std.testing;

    try testing.expect(isValid("Hello, World!"));
    try testing.expect(isValid("Bonjour \xC3\xA0 tous")); // "Bonjour à tous"
    try testing.expect(isValid("\xE4\xB8\xAD\xE6\x96\x87")); // "中文"
    try testing.expect(isValid("\xF0\x9F\x98\x80")); // emoji

    try testing.expect(!isValid("\xFF"));
    try testing.expect(!isValid("\xC3")); // truncated
    try testing.expect(!isValid("hello\x80world")); // invalid continuation
}

test "countCodepoints" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 5), countCodepoints("hello"));
    try testing.expectEqual(@as(?usize, 2), countCodepoints("\xE4\xB8\xAD\xE6\x96\x87")); // "中文"
    try testing.expectEqual(@as(?usize, 1), countCodepoints("\xF0\x9F\x98\x80")); // emoji
    try testing.expectEqual(@as(?usize, null), countCodepoints("\xFF")); // invalid
}

test "iterator" {
    const testing = std.testing;

    var iter = iterator("A\xC3\xA9\xE4\xB8\xAD"); // "Aé中"
    try testing.expectEqual(@as(?Codepoint, 'A'), iter.next());
    try testing.expectEqual(@as(?Codepoint, 0x00E9), iter.next());
    try testing.expectEqual(@as(?Codepoint, 0x4E2D), iter.next());
    try testing.expectEqual(@as(?Codepoint, null), iter.next());
}

test "encode" {
    const testing = std.testing;

    var buf: [4]u8 = undefined;

    const len1 = try encode('A', &buf);
    try testing.expectEqual(@as(usize, 1), len1);
    try testing.expectEqualSlices(u8, "A", buf[0..len1]);

    const len2 = try encode(0x00E9, &buf);
    try testing.expectEqual(@as(usize, 2), len2);
    try testing.expectEqualSlices(u8, "\xC3\xA9", buf[0..len2]);

    const len3 = try encode(0x4E2D, &buf);
    try testing.expectEqual(@as(usize, 3), len3);
    try testing.expectEqualSlices(u8, "\xE4\xB8\xAD", buf[0..len3]);

    const len4 = try encode(0x1F600, &buf);
    try testing.expectEqual(@as(usize, 4), len4);
    try testing.expectEqualSlices(u8, "\xF0\x9F\x98\x80", buf[0..len4]);
}

test "toUtf16" {
    const testing = std.testing;

    var buf: [10]u16 = undefined;

    // ASCII
    const len1 = try toUtf16("ABC", &buf);
    try testing.expectEqual(@as(usize, 3), len1);
    try testing.expectEqualSlices(u16, &[_]u16{ 'A', 'B', 'C' }, buf[0..len1]);

    // BMP character
    const len2 = try toUtf16("\xE4\xB8\xAD", &buf);
    try testing.expectEqual(@as(usize, 1), len2);
    try testing.expectEqualSlices(u16, &[_]u16{0x4E2D}, buf[0..len2]);

    // Surrogate pair
    const len3 = try toUtf16("\xF0\x9F\x98\x80", &buf);
    try testing.expectEqual(@as(usize, 2), len3);
    try testing.expectEqualSlices(u16, &[_]u16{ 0xD83D, 0xDE00 }, buf[0..len3]);
}
