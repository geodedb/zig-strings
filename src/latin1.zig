// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Latin-1 (ISO-8859-1) operations.
//!
//! Latin-1 is an 8-bit single-byte coded character set that extends ASCII
//! with characters from Western European languages. Code points 0x00-0xFF
//! map directly to Unicode code points U+0000-U+00FF.

const std = @import("std");
const types = @import("types");
const codepoint = @import("codepoint");

pub const Codepoint = types.Codepoint;
pub const StringError = types.StringError;

/// Checks if a code point can be represented in Latin-1 (0x00-0xFF)
pub fn canEncode(cp: u21) bool {
    return cp <= 0xFF;
}

/// Checks if all code points in the string can be encoded as Latin-1
pub fn canEncodeAll(utf8_bytes: []const u8) bool {
    var i: usize = 0;
    while (i < utf8_bytes.len) {
        const len = std.unicode.utf8ByteSequenceLength(utf8_bytes[i]) catch return false;
        const cp = std.unicode.utf8Decode(utf8_bytes[i..][0..len]) catch return false;
        if (!canEncode(cp)) return false;
        i += len;
    }
    return true;
}

/// Decodes a Latin-1 byte as a Unicode code point
pub fn decode(byte: u8) Codepoint {
    return byte;
}

/// Encodes a code point as Latin-1
/// Returns null if the code point cannot be encoded
pub fn encode(cp: u21) ?u8 {
    if (cp <= 0xFF) {
        return @truncate(cp);
    }
    return null;
}

/// Encodes a code point as Latin-1, using a replacement for unencodable characters
pub fn encodeWithReplacement(cp: u21, replacement: u8) u8 {
    return encode(cp) orelse replacement;
}

/// Converts Latin-1 to UTF-8
/// Returns the number of bytes written
pub fn toUtf8(latin1: []const u8, utf8_buf: []u8) StringError!usize {
    var utf8_index: usize = 0;

    for (latin1) |byte| {
        const cp: Codepoint = byte;
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

/// Calculates the UTF-8 length of a Latin-1 string
pub fn utf8Length(latin1: []const u8) usize {
    var len: usize = 0;
    for (latin1) |byte| {
        // 0x00-0x7F: 1 byte, 0x80-0xFF: 2 bytes
        len += if (byte < 0x80) @as(usize, 1) else @as(usize, 2);
    }
    return len;
}

/// Converts UTF-8 to Latin-1
/// Returns error if any code point cannot be encoded
pub fn fromUtf8(utf8_bytes: []const u8, latin1_buf: []u8) StringError!usize {
    var utf8_index: usize = 0;
    var latin1_index: usize = 0;

    while (utf8_index < utf8_bytes.len) {
        const len = std.unicode.utf8ByteSequenceLength(utf8_bytes[utf8_index]) catch
            return StringError.InvalidUtf8;
        if (utf8_index + len > utf8_bytes.len) {
            return StringError.TruncatedSequence;
        }
        const cp = std.unicode.utf8Decode(utf8_bytes[utf8_index..][0..len]) catch
            return StringError.InvalidUtf8;

        if (latin1_index >= latin1_buf.len) {
            return StringError.BufferTooSmall;
        }

        latin1_buf[latin1_index] = encode(cp) orelse
            return StringError.InvalidEncoding;

        utf8_index += len;
        latin1_index += 1;
    }

    return latin1_index;
}

/// Converts UTF-8 to Latin-1 with replacement character for unencodable code points
pub fn fromUtf8WithReplacement(utf8_bytes: []const u8, latin1_buf: []u8, replacement: u8) StringError!usize {
    var utf8_index: usize = 0;
    var latin1_index: usize = 0;

    while (utf8_index < utf8_bytes.len) {
        const len = std.unicode.utf8ByteSequenceLength(utf8_bytes[utf8_index]) catch {
            // Invalid UTF-8, skip one byte and use replacement
            if (latin1_index >= latin1_buf.len) {
                return StringError.BufferTooSmall;
            }
            latin1_buf[latin1_index] = replacement;
            utf8_index += 1;
            latin1_index += 1;
            continue;
        };

        if (utf8_index + len > utf8_bytes.len) {
            // Truncated sequence, use replacement
            if (latin1_index >= latin1_buf.len) {
                return StringError.BufferTooSmall;
            }
            latin1_buf[latin1_index] = replacement;
            break;
        }

        const cp = std.unicode.utf8Decode(utf8_bytes[utf8_index..][0..len]) catch {
            if (latin1_index >= latin1_buf.len) {
                return StringError.BufferTooSmall;
            }
            latin1_buf[latin1_index] = replacement;
            utf8_index += len;
            latin1_index += 1;
            continue;
        };

        if (latin1_index >= latin1_buf.len) {
            return StringError.BufferTooSmall;
        }

        latin1_buf[latin1_index] = encodeWithReplacement(cp, replacement);
        utf8_index += len;
        latin1_index += 1;
    }

    return latin1_index;
}

/// Iterator over Latin-1 as code points
pub const Iterator = struct {
    bytes: []const u8,
    index: usize,

    pub fn init(bytes: []const u8) Iterator {
        return .{ .bytes = bytes, .index = 0 };
    }

    pub fn next(self: *Iterator) ?Codepoint {
        if (self.index >= self.bytes.len) {
            return null;
        }
        const cp = decode(self.bytes[self.index]);
        self.index += 1;
        return cp;
    }

    pub fn peek(self: *const Iterator) ?Codepoint {
        if (self.index >= self.bytes.len) {
            return null;
        }
        return decode(self.bytes[self.index]);
    }

    pub fn reset(self: *Iterator) void {
        self.index = 0;
    }
};

/// Creates an iterator over Latin-1 as code points
pub fn iterator(bytes: []const u8) Iterator {
    return Iterator.init(bytes);
}

// Character classification for Latin-1 extension characters

/// Checks if a Latin-1 character is a letter (including accented)
pub fn isLetter(byte: u8) bool {
    // ASCII letters
    if ((byte >= 'A' and byte <= 'Z') or (byte >= 'a' and byte <= 'z')) {
        return true;
    }
    // Latin-1 supplement letters (0xC0-0xD6, 0xD8-0xF6, 0xF8-0xFF)
    if (byte >= 0xC0) {
        return byte != 0xD7 and byte != 0xF7; // Exclude multiplication and division signs
    }
    return false;
}

/// Checks if a Latin-1 character is uppercase
pub fn isUpper(byte: u8) bool {
    if (byte >= 'A' and byte <= 'Z') return true;
    // Latin-1 uppercase (0xC0-0xD6, 0xD8-0xDE)
    return (byte >= 0xC0 and byte <= 0xD6) or (byte >= 0xD8 and byte <= 0xDE);
}

/// Checks if a Latin-1 character is lowercase
pub fn isLower(byte: u8) bool {
    if (byte >= 'a' and byte <= 'z') return true;
    // Latin-1 lowercase (0xDF-0xF6, 0xF8-0xFF)
    return (byte >= 0xDF and byte <= 0xF6) or (byte >= 0xF8);
}

/// Converts Latin-1 uppercase to lowercase
pub fn toLower(byte: u8) u8 {
    // ASCII uppercase
    if (byte >= 'A' and byte <= 'Z') {
        return byte + ('a' - 'A');
    }
    // Latin-1 uppercase (0xC0-0xD6, 0xD8-0xDE) -> lowercase (+0x20)
    if ((byte >= 0xC0 and byte <= 0xD6) or (byte >= 0xD8 and byte <= 0xDE)) {
        return byte + 0x20;
    }
    return byte;
}

/// Converts Latin-1 lowercase to uppercase
pub fn toUpper(byte: u8) u8 {
    // ASCII lowercase
    if (byte >= 'a' and byte <= 'z') {
        return byte - ('a' - 'A');
    }
    // Latin-1 lowercase (0xE0-0xF6, 0xF8-0xFE) -> uppercase (-0x20)
    // Note: 0xDF (ß) has no uppercase, 0xFF (ÿ) maps to 0x178 (outside Latin-1)
    if ((byte >= 0xE0 and byte <= 0xF6) or (byte >= 0xF8 and byte <= 0xFE)) {
        return byte - 0x20;
    }
    return byte;
}

test "canEncode" {
    const testing = std.testing;

    try testing.expect(canEncode(0x00));
    try testing.expect(canEncode(0xFF));
    try testing.expect(!canEncode(0x100));
    try testing.expect(!canEncode(0x4E2D)); // Chinese character
}

test "encode and decode" {
    const testing = std.testing;

    try testing.expectEqual(@as(Codepoint, 'A'), decode('A'));
    try testing.expectEqual(@as(Codepoint, 0xE9), decode(0xE9)); // é

    try testing.expectEqual(@as(?u8, 'A'), encode('A'));
    try testing.expectEqual(@as(?u8, 0xE9), encode(0xE9));
    try testing.expectEqual(@as(?u8, null), encode(0x100));
}

test "toUtf8" {
    const testing = std.testing;

    var buf: [10]u8 = undefined;

    // ASCII
    const len1 = try toUtf8("ABC", &buf);
    try testing.expectEqualSlices(u8, "ABC", buf[0..len1]);

    // Extended Latin-1 (é = 0xE9)
    const len2 = try toUtf8(&[_]u8{0xE9}, &buf);
    try testing.expectEqualSlices(u8, "\xC3\xA9", buf[0..len2]);
}

test "fromUtf8" {
    const testing = std.testing;

    var buf: [10]u8 = undefined;

    const len1 = try fromUtf8("ABC", &buf);
    try testing.expectEqualSlices(u8, "ABC", buf[0..len1]);

    const len2 = try fromUtf8("\xC3\xA9", &buf); // é
    try testing.expectEqual(@as(usize, 1), len2);
    try testing.expectEqual(@as(u8, 0xE9), buf[0]);

    // Cannot encode Chinese character
    try testing.expectError(StringError.InvalidEncoding, fromUtf8("\xE4\xB8\xAD", &buf));
}

test "case conversion" {
    const testing = std.testing;

    try testing.expectEqual(@as(u8, 'a'), toLower('A'));
    try testing.expectEqual(@as(u8, 0xE9), toLower(0xC9)); // É -> é
    try testing.expectEqual(@as(u8, 'A'), toUpper('a'));
    try testing.expectEqual(@as(u8, 0xC9), toUpper(0xE9)); // é -> É
}

test "isLetter" {
    const testing = std.testing;

    try testing.expect(isLetter('A'));
    try testing.expect(isLetter('z'));
    try testing.expect(isLetter(0xE9)); // é
    try testing.expect(isLetter(0xC9)); // É
    try testing.expect(!isLetter('5'));
    try testing.expect(!isLetter(0xD7)); // multiplication sign
}

test "iterator" {
    const testing = std.testing;

    var iter = iterator(&[_]u8{ 'A', 0xE9, 'B' });
    try testing.expectEqual(@as(?Codepoint, 'A'), iter.next());
    try testing.expectEqual(@as(?Codepoint, 0xE9), iter.next());
    try testing.expectEqual(@as(?Codepoint, 'B'), iter.next());
    try testing.expectEqual(@as(?Codepoint, null), iter.next());
}
