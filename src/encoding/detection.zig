// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Encoding detection.
//!
//! This module provides functions for detecting the character encoding
//! of text data, including BOM detection and heuristic analysis.

const std = @import("std");
const types = @import("types");
const utf8 = @import("utf8");
const utf16 = @import("utf16");
const ascii = @import("ascii");

pub const Encoding = types.Encoding;

/// Result of encoding detection
pub const DetectionResult = struct {
    /// Detected encoding
    encoding: Encoding,
    /// Confidence level (0.0 to 1.0)
    confidence: f32,
    /// Whether a BOM was found
    has_bom: bool,
    /// Offset to start of actual content (after BOM if present)
    content_offset: usize,
};

/// Detects the encoding of the given bytes.
/// WARNING: Heuristic detection can be unreliable. Callers MUST check the
/// `confidence` field of the result before trusting the detected encoding.
/// A confidence below 0.5 indicates uncertain detection. When no encoding
/// can be confidently identified, the function falls back to UTF-8 with
/// a low confidence value (0.3).
pub fn detect(bytes: []const u8) DetectionResult {
    // Try BOM detection first
    if (detectBom(bytes)) |result| {
        return result;
    }

    // Heuristic detection
    return detectHeuristic(bytes);
}

/// Detects encoding from BOM (Byte Order Mark)
pub fn detectBom(bytes: []const u8) ?DetectionResult {
    if (bytes.len >= 4) {
        // UTF-32 LE (FF FE 00 00) - must check before UTF-16 LE
        if (bytes[0] == 0xFF and bytes[1] == 0xFE and bytes[2] == 0x00 and bytes[3] == 0x00) {
            return .{
                .encoding = .utf32_le,
                .confidence = 1.0,
                .has_bom = true,
                .content_offset = 4,
            };
        }
        // UTF-32 BE (00 00 FE FF)
        if (bytes[0] == 0x00 and bytes[1] == 0x00 and bytes[2] == 0xFE and bytes[3] == 0xFF) {
            return .{
                .encoding = .utf32_be,
                .confidence = 1.0,
                .has_bom = true,
                .content_offset = 4,
            };
        }
    }

    if (bytes.len >= 3) {
        // UTF-8 BOM (EF BB BF)
        if (bytes[0] == 0xEF and bytes[1] == 0xBB and bytes[2] == 0xBF) {
            return .{
                .encoding = .utf8,
                .confidence = 1.0,
                .has_bom = true,
                .content_offset = 3,
            };
        }
    }

    if (bytes.len >= 2) {
        // UTF-16 LE (FF FE)
        if (bytes[0] == 0xFF and bytes[1] == 0xFE) {
            return .{
                .encoding = .utf16_le,
                .confidence = 1.0,
                .has_bom = true,
                .content_offset = 2,
            };
        }
        // UTF-16 BE (FE FF)
        if (bytes[0] == 0xFE and bytes[1] == 0xFF) {
            return .{
                .encoding = .utf16_be,
                .confidence = 1.0,
                .has_bom = true,
                .content_offset = 2,
            };
        }
    }

    return null;
}

/// Heuristic encoding detection
fn detectHeuristic(bytes: []const u8) DetectionResult {
    if (bytes.len == 0) {
        return .{
            .encoding = .utf8,
            .confidence = 0.5,
            .has_bom = false,
            .content_offset = 0,
        };
    }

    // Check for pure ASCII
    if (isPureAscii(bytes)) {
        return .{
            .encoding = .ascii,
            .confidence = 1.0,
            .has_bom = false,
            .content_offset = 0,
        };
    }

    // Check for valid UTF-8
    const utf8_score = scoreUtf8(bytes);
    if (utf8_score > 0.8) {
        return .{
            .encoding = .utf8,
            .confidence = utf8_score,
            .has_bom = false,
            .content_offset = 0,
        };
    }

    // Check for UTF-16
    const utf16_le_score = scoreUtf16(bytes, .little);
    const utf16_be_score = scoreUtf16(bytes, .big);

    if (utf16_le_score > utf8_score and utf16_le_score > utf16_be_score) {
        return .{
            .encoding = .utf16_le,
            .confidence = utf16_le_score,
            .has_bom = false,
            .content_offset = 0,
        };
    }

    if (utf16_be_score > utf8_score) {
        return .{
            .encoding = .utf16_be,
            .confidence = utf16_be_score,
            .has_bom = false,
            .content_offset = 0,
        };
    }

    // Check if it could be Latin-1
    if (couldBeLatin1(bytes)) {
        return .{
            .encoding = .latin1,
            .confidence = 0.6,
            .has_bom = false,
            .content_offset = 0,
        };
    }

    // Default to UTF-8 with low confidence
    return .{
        .encoding = .utf8,
        .confidence = 0.3,
        .has_bom = false,
        .content_offset = 0,
    };
}

/// Checks if all bytes are valid ASCII
fn isPureAscii(bytes: []const u8) bool {
    for (bytes) |b| {
        if (b > 0x7F) return false;
    }
    return true;
}

/// Scores likelihood of UTF-8 encoding (0.0 to 1.0)
fn scoreUtf8(bytes: []const u8) f32 {
    if (utf8.isValid(bytes)) {
        // Count multi-byte sequences to distinguish from ASCII
        var multi_byte: usize = 0;
        var i: usize = 0;
        while (i < bytes.len) {
            const len = utf8.sequenceLength(bytes[i]) orelse {
                i += 1;
                continue;
            };
            if (len > 1) multi_byte += 1;
            i += len;
        }

        if (multi_byte > 0) {
            return 0.95;
        }
        return 0.7; // Valid UTF-8 but no multi-byte (could be ASCII)
    }

    // Count valid vs invalid sequences
    var valid: usize = 0;
    var invalid: usize = 0;
    var i: usize = 0;

    while (i < bytes.len) {
        const result = utf8.decode(bytes[i..]) catch {
            invalid += 1;
            i += 1;
            continue;
        };
        valid += 1;
        i += result.bytes_consumed;
    }

    if (valid + invalid == 0) return 0.5;
    return @as(f32, @floatFromInt(valid)) / @as(f32, @floatFromInt(valid + invalid));
}

/// Scores likelihood of UTF-16 encoding
fn scoreUtf16(bytes: []const u8, endian: std.builtin.Endian) f32 {
    if (bytes.len < 2 or bytes.len % 2 != 0) {
        return 0.0;
    }

    var ascii_like: usize = 0;
    var valid_pairs: usize = 0;
    var total_units: usize = 0;
    var i: usize = 0;

    while (i + 1 < bytes.len) {
        const unit = std.mem.readInt(u16, bytes[i..][0..2], endian);
        total_units += 1;

        // Check for ASCII-range characters (common in text)
        if (unit < 0x80) {
            ascii_like += 1;
            valid_pairs += 1;
        }
        // Check for common Latin/Cyrillic/etc characters
        else if (unit < 0xD800 or unit > 0xDFFF) {
            valid_pairs += 1;
        }
        // Check for valid surrogate pairs
        else if (types.surrogate.isHighSurrogate(unit)) {
            if (i + 3 < bytes.len) {
                const low = std.mem.readInt(u16, bytes[i + 2 ..][0..2], endian);
                if (types.surrogate.isLowSurrogate(low)) {
                    valid_pairs += 1;
                    i += 2;
                }
            }
        }

        i += 2;
    }

    if (total_units == 0) return 0.0;

    // High proportion of ASCII-like characters suggests UTF-16
    const ascii_ratio = @as(f32, @floatFromInt(ascii_like)) / @as(f32, @floatFromInt(total_units));
    const valid_ratio = @as(f32, @floatFromInt(valid_pairs)) / @as(f32, @floatFromInt(total_units));

    // UTF-16 text typically has many null bytes (for ASCII chars)
    var null_count: usize = 0;
    const null_pos: usize = if (endian == .little) 1 else 0;
    i = null_pos;
    while (i < bytes.len) : (i += 2) {
        if (bytes[i] == 0) null_count += 1;
    }

    const null_ratio = @as(f32, @floatFromInt(null_count)) / @as(f32, @floatFromInt(total_units));

    // Combine scores
    return (ascii_ratio * 0.3 + valid_ratio * 0.4 + null_ratio * 0.3);
}

/// Checks if bytes could reasonably be Latin-1
fn couldBeLatin1(bytes: []const u8) bool {
    for (bytes) |b| {
        // Latin-1 printable range: 0x20-0x7E, 0xA0-0xFF
        // Control characters: 0x00-0x1F, 0x7F-0x9F
        if (b >= 0x80 and b < 0xA0 and b != 0x85) {
            // C1 control characters are rare in text
            return false;
        }
    }
    return true;
}

/// Strips BOM from the beginning of a byte sequence if present
pub fn stripBom(bytes: []const u8) []const u8 {
    if (detectBom(bytes)) |result| {
        return bytes[result.content_offset..];
    }
    return bytes;
}

test "BOM detection" {
    const testing = std.testing;

    // UTF-8 BOM
    const utf8_with_bom = "\xEF\xBB\xBFHello";
    const result1 = detect(utf8_with_bom);
    try testing.expectEqual(Encoding.utf8, result1.encoding);
    try testing.expect(result1.has_bom);
    try testing.expectEqual(@as(usize, 3), result1.content_offset);

    // UTF-16 LE BOM
    const utf16_le_bom = "\xFF\xFEH\x00e\x00";
    const result2 = detect(utf16_le_bom);
    try testing.expectEqual(Encoding.utf16_le, result2.encoding);
    try testing.expect(result2.has_bom);

    // UTF-16 BE BOM
    const utf16_be_bom = "\xFE\xFF\x00H\x00e";
    const result3 = detect(utf16_be_bom);
    try testing.expectEqual(Encoding.utf16_be, result3.encoding);
    try testing.expect(result3.has_bom);
}

test "heuristic detection" {
    const testing = std.testing;

    // Pure ASCII
    const ascii_text = "Hello, World!";
    const result1 = detect(ascii_text);
    try testing.expectEqual(Encoding.ascii, result1.encoding);
    try testing.expect(!result1.has_bom);

    // UTF-8 with multi-byte
    const utf8_text = "Hello, \xC3\xA9"; // "Hello, é"
    const result2 = detect(utf8_text);
    try testing.expectEqual(Encoding.utf8, result2.encoding);
    try testing.expect(result2.confidence > 0.9);
}

test "stripBom" {
    const testing = std.testing;

    const with_bom = "\xEF\xBB\xBFHello";
    try testing.expectEqualSlices(u8, "Hello", stripBom(with_bom));

    const without_bom = "Hello";
    try testing.expectEqualSlices(u8, "Hello", stripBom(without_bom));
}
