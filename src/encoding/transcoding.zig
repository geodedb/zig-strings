// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Encoding transcoding utilities.
//!
//! This module provides functions for converting between different
//! character encodings (UTF-8, UTF-16, UTF-32, ASCII, Latin-1).

const std = @import("std");
const types = @import("types");
const utf8_mod = @import("utf8");
const utf16_mod = @import("utf16");
const utf32_mod = @import("utf32");
const ascii_mod = @import("ascii");
const latin1_mod = @import("latin1");
const codepoint_mod = @import("codepoint");

pub const Encoding = types.Encoding;
pub const Codepoint = types.Codepoint;
pub const StringError = types.StringError;

/// Transcoding options
pub const TranscodeOptions = struct {
    /// Replacement character for unencodable code points
    replacement: ?Codepoint = types.replacement_character,
    /// Strip BOM from input
    strip_bom: bool = true,
    /// Add BOM to output
    add_bom: bool = false,
};

/// Converts UTF-8 to UTF-16 with allocator
pub fn utf8ToUtf16(allocator: std.mem.Allocator, utf8: []const u8, endian: std.builtin.Endian) ![]u8 {
    // Calculate output size
    const utf16_len = utf8_mod.utf16Length(utf8) orelse return StringError.InvalidUtf8;
    const byte_len = std.math.mul(usize, utf16_len, 2) catch return error.Overflow;

    var result = try allocator.alloc(u8, byte_len);
    errdefer allocator.free(result);

    var iter = utf8_mod.iterator(utf8);
    var offset: usize = 0;

    while (iter.next()) |cp| {
        var units: [2]u16 = undefined;
        const encoded = codepoint_mod.encodeUtf16(cp, &units);

        for (encoded) |unit| {
            std.mem.writeInt(u16, result[offset..][0..2], unit, endian);
            offset += 2;
        }
    }

    return result;
}

/// Converts UTF-16 to UTF-8 with allocator
pub fn utf16ToUtf8(allocator: std.mem.Allocator, utf16_bytes: []const u8, endian: std.builtin.Endian) ![]u8 {
    if (utf16_bytes.len % 2 != 0) {
        return StringError.TruncatedSequence;
    }

    // First pass: calculate output size
    var utf8_len: usize = 0;
    var i: usize = 0;

    while (i < utf16_bytes.len) {
        const result = utf16_mod.decodeBytes(utf16_bytes[i..], endian) catch |err| switch (err) {
            StringError.InvalidUtf16 => {
                utf8_len += codepoint_mod.utf8Length(types.replacement_character);
                i += 2;
                continue;
            },
            else => return err,
        };
        utf8_len += codepoint_mod.utf8Length(result.value);
        i += result.bytes_consumed;
    }

    // Allocate and convert
    var result = try allocator.alloc(u8, utf8_len);
    errdefer allocator.free(result);

    i = 0;
    var offset: usize = 0;

    while (i < utf16_bytes.len) {
        const decode_result = utf16_mod.decodeBytes(utf16_bytes[i..], endian) catch {
            var buf: [4]u8 = undefined;
            const encoded = codepoint_mod.encodeUtf8(types.replacement_character, &buf);
            @memcpy(result[offset..][0..encoded.len], encoded);
            offset += encoded.len;
            i += 2;
            continue;
        };

        var buf: [4]u8 = undefined;
        const encoded = codepoint_mod.encodeUtf8(decode_result.value, &buf);
        @memcpy(result[offset..][0..encoded.len], encoded);
        offset += encoded.len;
        i += decode_result.bytes_consumed;
    }

    return result;
}

/// Converts UTF-8 to UTF-32 with allocator
pub fn utf8ToUtf32(allocator: std.mem.Allocator, utf8: []const u8, endian: std.builtin.Endian) ![]u8 {
    const cp_count = utf8_mod.countCodepoints(utf8) orelse return StringError.InvalidUtf8;
    const byte_len = std.math.mul(usize, cp_count, 4) catch return error.Overflow;

    var result = try allocator.alloc(u8, byte_len);
    errdefer allocator.free(result);

    var iter = utf8_mod.iterator(utf8);
    var offset: usize = 0;

    while (iter.next()) |cp| {
        std.mem.writeInt(u32, result[offset..][0..4], cp, endian);
        offset += 4;
    }

    return result;
}

/// Converts UTF-32 to UTF-8 with allocator
pub fn utf32ToUtf8(allocator: std.mem.Allocator, utf32_bytes: []const u8, endian: std.builtin.Endian) ![]u8 {
    if (utf32_bytes.len % 4 != 0) {
        return StringError.TruncatedSequence;
    }

    // Calculate output size
    var utf8_len: usize = 0;
    var i: usize = 0;

    while (i < utf32_bytes.len) {
        const result = utf32_mod.decodeBytes(utf32_bytes[i..], endian) catch {
            utf8_len += codepoint_mod.utf8Length(types.replacement_character);
            i += 4;
            continue;
        };
        utf8_len += codepoint_mod.utf8Length(result.value);
        i += 4;
    }

    // Allocate and convert
    var result = try allocator.alloc(u8, utf8_len);
    errdefer allocator.free(result);

    i = 0;
    var offset: usize = 0;

    while (i < utf32_bytes.len) {
        const cp = blk: {
            const decode_result = utf32_mod.decodeBytes(utf32_bytes[i..], endian) catch {
                break :blk types.replacement_character;
            };
            break :blk decode_result.value;
        };

        var buf: [4]u8 = undefined;
        const encoded = codepoint_mod.encodeUtf8(cp, &buf);
        @memcpy(result[offset..][0..encoded.len], encoded);
        offset += encoded.len;
        i += 4;
    }

    return result;
}

/// Converts Latin-1 to UTF-8 with allocator
pub fn latin1ToUtf8(allocator: std.mem.Allocator, latin1: []const u8) ![]u8 {
    const utf8_len = latin1_mod.utf8Length(latin1);
    var result = try allocator.alloc(u8, utf8_len);
    errdefer allocator.free(result);

    const written = try latin1_mod.toUtf8(latin1, result);
    return result[0..written];
}

/// Converts UTF-8 to Latin-1 with allocator
pub fn utf8ToLatin1(allocator: std.mem.Allocator, utf8: []const u8, options: TranscodeOptions) ![]u8 {
    const cp_count = utf8_mod.countCodepoints(utf8) orelse return StringError.InvalidUtf8;
    var result = try allocator.alloc(u8, cp_count);
    errdefer allocator.free(result);

    var iter = utf8_mod.iterator(utf8);
    var i: usize = 0;

    while (iter.next()) |cp| {
        if (latin1_mod.encode(cp)) |byte| {
            result[i] = byte;
        } else if (options.replacement) |replacement| {
            result[i] = latin1_mod.encode(replacement) orelse '?';
        } else {
            allocator.free(result);
            return StringError.InvalidEncoding;
        }
        i += 1;
    }

    return result[0..i];
}

/// Converts ASCII to UTF-8 (no-op for valid ASCII)
pub fn asciiToUtf8(allocator: std.mem.Allocator, ascii_bytes: []const u8) ![]u8 {
    if (!ascii_mod.isValidAscii(ascii_bytes)) {
        return StringError.InvalidEncoding;
    }
    const result = try allocator.alloc(u8, ascii_bytes.len);
    @memcpy(result, ascii_bytes);
    return result;
}

/// Converts UTF-8 to ASCII with optional replacement
pub fn utf8ToAscii(allocator: std.mem.Allocator, utf8: []const u8, options: TranscodeOptions) ![]u8 {
    const cp_count = utf8_mod.countCodepoints(utf8) orelse return StringError.InvalidUtf8;
    var result = try allocator.alloc(u8, cp_count);
    errdefer allocator.free(result);

    var iter = utf8_mod.iterator(utf8);
    var i: usize = 0;

    while (iter.next()) |cp| {
        if (cp <= 0x7F) {
            result[i] = @truncate(cp);
        } else if (options.replacement) |replacement| {
            if (replacement <= 0x7F) {
                result[i] = @truncate(replacement);
            } else {
                result[i] = '?';
            }
        } else {
            allocator.free(result);
            return StringError.InvalidEncoding;
        }
        i += 1;
    }

    return result[0..i];
}

/// Generic transcode function
pub fn transcode(
    allocator: std.mem.Allocator,
    input: []const u8,
    from: Encoding,
    to: Encoding,
    options: TranscodeOptions,
) ![]u8 {
    // Convert input to code points first (via UTF-8 as intermediate)
    const utf8 = switch (from) {
        .utf8 => input,
        .utf16_le => try utf16ToUtf8(allocator, input, .little),
        .utf16_be => try utf16ToUtf8(allocator, input, .big),
        .utf32_le => try utf32ToUtf8(allocator, input, .little),
        .utf32_be => try utf32ToUtf8(allocator, input, .big),
        .ascii => try asciiToUtf8(allocator, input),
        .latin1 => try latin1ToUtf8(allocator, input),
    };
    // Track if we need to free the intermediate utf8
    const should_free_utf8 = from != .utf8 and to != .utf8;
    defer if (should_free_utf8) allocator.free(utf8);

    // Convert to target encoding
    return switch (to) {
        .utf8 => blk: {
            if (from == .utf8) {
                // Input is already UTF-8, make a copy
                const result = try allocator.alloc(u8, utf8.len);
                @memcpy(result, utf8);
                break :blk result;
            }
            // utf8 was allocated by conversion, return it directly (don't free)
            break :blk @constCast(utf8);
        },
        .utf16_le => try utf8ToUtf16(allocator, utf8, .little),
        .utf16_be => try utf8ToUtf16(allocator, utf8, .big),
        .utf32_le => try utf8ToUtf32(allocator, utf8, .little),
        .utf32_be => try utf8ToUtf32(allocator, utf8, .big),
        .ascii => try utf8ToAscii(allocator, utf8, options),
        .latin1 => try utf8ToLatin1(allocator, utf8, options),
    };
}

test "utf8ToUtf16 and back" {
    const testing = std.testing;

    const utf8_str = "Hello, \xE4\xB8\xAD\xE6\x96\x87!"; // "Hello, 中文!"

    const utf16 = try utf8ToUtf16(testing.allocator, utf8_str, .little);
    defer testing.allocator.free(utf16);

    const back = try utf16ToUtf8(testing.allocator, utf16, .little);
    defer testing.allocator.free(back);

    try testing.expectEqualSlices(u8, utf8_str, back);
}

test "utf8ToUtf32 and back" {
    const testing = std.testing;

    const utf8_str = "Hello \xF0\x9F\x98\x80"; // "Hello [emoji]"

    const utf32 = try utf8ToUtf32(testing.allocator, utf8_str, .little);
    defer testing.allocator.free(utf32);

    const back = try utf32ToUtf8(testing.allocator, utf32, .little);
    defer testing.allocator.free(back);

    try testing.expectEqualSlices(u8, utf8_str, back);
}

test "latin1ToUtf8" {
    const testing = std.testing;

    const latin1 = &[_]u8{ 'H', 'e', 'l', 'l', 'o', ' ', 0xE9 }; // "Hello é"

    const utf8 = try latin1ToUtf8(testing.allocator, latin1);
    defer testing.allocator.free(utf8);

    try testing.expectEqualSlices(u8, "Hello \xC3\xA9", utf8);
}

test "utf8ToLatin1" {
    const testing = std.testing;

    const utf8 = "Hello \xC3\xA9"; // "Hello é"

    const latin1 = try utf8ToLatin1(testing.allocator, utf8, .{});
    defer testing.allocator.free(latin1);

    try testing.expectEqualSlices(u8, &[_]u8{ 'H', 'e', 'l', 'l', 'o', ' ', 0xE9 }, latin1);
}

test "transcode" {
    const testing = std.testing;

    const utf8_str = "Test";

    // UTF-8 to UTF-16 LE
    const utf16 = try transcode(testing.allocator, utf8_str, .utf8, .utf16_le, .{});
    defer testing.allocator.free(utf16);

    try testing.expectEqual(@as(usize, 8), utf16.len); // 4 chars * 2 bytes

    // Back to UTF-8
    const back = try transcode(testing.allocator, utf16, .utf16_le, .utf8, .{});
    defer testing.allocator.free(back);

    try testing.expectEqualSlices(u8, utf8_str, back);
}

// ============================================================================
// Overflow protection tests
// ============================================================================

test "utf8ToUtf16 overflow protection" {
    const testing = std.testing;
    const result = try utf8ToUtf16(testing.allocator, "Hello", .little);
    defer testing.allocator.free(result);
    try testing.expectEqual(@as(usize, 10), result.len);
}

test "utf8ToUtf32 overflow protection" {
    const testing = std.testing;
    const result = try utf8ToUtf32(testing.allocator, "Hi", .little);
    defer testing.allocator.free(result);
    try testing.expectEqual(@as(usize, 8), result.len);
}
