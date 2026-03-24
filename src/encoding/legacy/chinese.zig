// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Chinese Legacy Encoding Support
//!
//! This module provides support for legacy Chinese character encodings:
//! - GB2312: Simplified Chinese (1980)
//! - GBK: Extended GB2312 (1995)
//! - GB18030: Unicode-compatible Chinese encoding (2000)
//!
//! GB18030 is a superset of GBK which is a superset of GB2312.
//! GB18030 can encode all Unicode code points.

const std = @import("std");
const legacy_errors = @import("legacy_encoding_errors");

/// Chinese encoding variants
pub const ChineseEncoding = enum {
    GB2312,
    GBK,
    GB18030,

    /// Decode bytes to UTF-8
    pub fn decode(self: ChineseEncoding, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        return switch (self) {
            .GB2312 => decodeGB2312(allocator, input),
            .GBK => decodeGBK(allocator, input),
            .GB18030 => decodeGB18030(allocator, input),
        };
    }

    /// Encode UTF-8 to this encoding
    pub fn encode(self: ChineseEncoding, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        return switch (self) {
            .GB2312 => encodeGB2312(allocator, input),
            .GBK => encodeGBK(allocator, input),
            .GB18030 => encodeGB18030(allocator, input),
        };
    }

    /// Get human-readable name
    pub fn name(self: ChineseEncoding) []const u8 {
        return switch (self) {
            .GB2312 => "GB2312",
            .GBK => "GBK",
            .GB18030 => "GB18030",
        };
    }
};

/// Errors that can occur during encoding/decoding
pub const EncodingError = legacy_errors.LegacyEncodingError;

// ============================================================================
// GB2312 Implementation
// ============================================================================

/// GB2312 uses a 94x94 grid (rows 01-87, columns 01-94)
/// Each character is encoded as two bytes: (row + 0xA0, col + 0xA0)
/// Rows 01-09: Special symbols
/// Rows 16-55: Level 1 Chinese characters (3755 chars, sorted by pinyin)
/// Rows 56-87: Level 2 Chinese characters (3008 chars, sorted by radical)
fn decodeGB2312(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const b1 = input[i];

        if (b1 < 0x80) {
            // ASCII
            try result.append(allocator, b1);
            i += 1;
        } else if (b1 >= 0xA1 and b1 <= 0xF7 and i + 1 < input.len) {
            const b2 = input[i + 1];
            if (b2 >= 0xA1 and b2 <= 0xFE) {
                // Valid GB2312 double-byte sequence
                const codepoint = lookupGB2312(b1, b2);
                if (codepoint != 0xFFFD) {
                    try appendCodepoint(&result, allocator, codepoint);
                } else {
                    // Replacement character for unmapped
                    try appendCodepoint(&result, allocator, 0xFFFD);
                }
                i += 2;
            } else {
                try appendCodepoint(&result, allocator, 0xFFFD);
                i += 1;
            }
        } else {
            try appendCodepoint(&result, allocator, 0xFFFD);
            i += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

fn encodeGB2312(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
            i += 1;
            continue;
        };
        if (i + len > input.len) break;

        const codepoint = std.unicode.utf8Decode(input[i..][0..len]) catch {
            i += 1;
            continue;
        };

        if (codepoint < 0x80) {
            // ASCII
            try result.append(allocator, @intCast(codepoint));
        } else {
            // Try to find in GB2312 table
            const gb = reverseGB2312(codepoint);
            if (gb) |bytes| {
                try result.append(allocator, bytes[0]);
                try result.append(allocator, bytes[1]);
            } else {
                // Cannot encode - use question mark
                try result.append(allocator, '?');
            }
        }

        i += len;
    }

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// GBK Implementation
// ============================================================================

/// GBK extends GB2312:
/// - First byte: 0x81-0xFE
/// - Second byte: 0x40-0x7E or 0x80-0xFE
/// Total: 21,886 characters including all GB2312 characters
fn decodeGBK(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const b1 = input[i];

        if (b1 < 0x80) {
            // ASCII
            try result.append(allocator, b1);
            i += 1;
        } else if (b1 >= 0x81 and b1 <= 0xFE and i + 1 < input.len) {
            const b2 = input[i + 1];
            if ((b2 >= 0x40 and b2 <= 0x7E) or (b2 >= 0x80 and b2 <= 0xFE)) {
                // Valid GBK double-byte sequence
                const codepoint = lookupGBK(b1, b2);
                try appendCodepoint(&result, allocator, codepoint);
                i += 2;
            } else {
                try appendCodepoint(&result, allocator, 0xFFFD);
                i += 1;
            }
        } else {
            try appendCodepoint(&result, allocator, 0xFFFD);
            i += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

fn encodeGBK(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
            i += 1;
            continue;
        };
        if (i + len > input.len) break;

        const codepoint = std.unicode.utf8Decode(input[i..][0..len]) catch {
            i += 1;
            continue;
        };

        if (codepoint < 0x80) {
            try result.append(allocator, @intCast(codepoint));
        } else {
            const gbk = reverseGBK(codepoint);
            if (gbk) |bytes| {
                try result.append(allocator, bytes[0]);
                try result.append(allocator, bytes[1]);
            } else {
                try result.append(allocator, '?');
            }
        }

        i += len;
    }

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// GB18030 Implementation
// ============================================================================

/// GB18030 is a Unicode-compatible encoding:
/// - 1-byte: 0x00-0x7F (ASCII)
/// - 2-byte: First 0x81-0xFE, Second 0x40-0x7E or 0x80-0xFE (GBK compatible)
/// - 4-byte: First 0x81-0xFE, Second 0x30-0x39, Third 0x81-0xFE, Fourth 0x30-0x39
///
/// 4-byte sequences can encode any Unicode code point not covered by 1/2-byte forms
fn decodeGB18030(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const b1 = input[i];

        if (b1 < 0x80) {
            // 1-byte ASCII
            try result.append(allocator, b1);
            i += 1;
        } else if (b1 >= 0x81 and b1 <= 0xFE and i + 1 < input.len) {
            const b2 = input[i + 1];

            if (b2 >= 0x30 and b2 <= 0x39 and i + 3 < input.len) {
                // Potential 4-byte sequence
                const b3 = input[i + 2];
                const b4 = input[i + 3];

                if (b3 >= 0x81 and b3 <= 0xFE and b4 >= 0x30 and b4 <= 0x39) {
                    // Valid 4-byte GB18030 sequence
                    const codepoint = decode4ByteGB18030(b1, b2, b3, b4);
                    try appendCodepoint(&result, allocator, codepoint);
                    i += 4;
                    continue;
                }
            }

            if ((b2 >= 0x40 and b2 <= 0x7E) or (b2 >= 0x80 and b2 <= 0xFE)) {
                // 2-byte GBK-compatible sequence
                const codepoint = lookupGBK(b1, b2);
                try appendCodepoint(&result, allocator, codepoint);
                i += 2;
            } else {
                try appendCodepoint(&result, allocator, 0xFFFD);
                i += 1;
            }
        } else {
            try appendCodepoint(&result, allocator, 0xFFFD);
            i += 1;
        }
    }

    return result.toOwnedSlice(allocator);
}

fn encodeGB18030(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const len = std.unicode.utf8ByteSequenceLength(input[i]) catch {
            i += 1;
            continue;
        };
        if (i + len > input.len) break;

        const codepoint = std.unicode.utf8Decode(input[i..][0..len]) catch {
            i += 1;
            continue;
        };

        if (codepoint < 0x80) {
            // ASCII - 1 byte
            try result.append(allocator, @intCast(codepoint));
        } else {
            // Try 2-byte GBK first
            const gbk = reverseGBK(codepoint);
            if (gbk) |bytes| {
                try result.append(allocator, bytes[0]);
                try result.append(allocator, bytes[1]);
            } else {
                // Use 4-byte form
                const bytes = encode4ByteGB18030(codepoint);
                try result.append(allocator, bytes[0]);
                try result.append(allocator, bytes[1]);
                try result.append(allocator, bytes[2]);
                try result.append(allocator, bytes[3]);
            }
        }

        i += len;
    }

    return result.toOwnedSlice(allocator);
}

/// Decode 4-byte GB18030 to Unicode
fn decode4ByteGB18030(b1: u8, b2: u8, b3: u8, b4: u8) u21 {
    // Linear index calculation
    const linear: u32 = (@as(u32, b1 - 0x81) * 12600) +
        (@as(u32, b2 - 0x30) * 1260) +
        (@as(u32, b3 - 0x81) * 10) +
        (@as(u32, b4 - 0x30));

    // GB18030 uses offset ranges to map to Unicode
    // This is a simplified implementation for BMP and beyond
    return gb18030LinearToUnicode(linear);
}

/// Encode Unicode to 4-byte GB18030
fn encode4ByteGB18030(codepoint: u21) [4]u8 {
    // Guard against codepoints beyond the valid Unicode range (U+10FFFF).
    // unicodeToGB18030Linear can return values that overflow u8 byte
    // calculations for invalid codepoints above 0x10FFFF.
    const safe_cp: u21 = if (codepoint > 0x10FFFF) 0xFFFD else codepoint;
    const linear = unicodeToGB18030Linear(safe_cp);

    // After clamping to valid Unicode, the maximum linear value is bounded:
    // max linear = 39420 + (0x10FFFF - 0x10000) = 1087995
    // b1 max = 1087995 / 12600 + 0x81 = 86 + 129 = 215, fits in u8
    const b1: u8 = @intCast((linear / 12600) + 0x81);
    const rem1 = linear % 12600;
    const b2: u8 = @intCast((rem1 / 1260) + 0x30);
    const rem2 = rem1 % 1260;
    const b3: u8 = @intCast((rem2 / 10) + 0x81);
    const b4: u8 = @intCast((rem2 % 10) + 0x30);

    return .{ b1, b2, b3, b4 };
}

// GB18030 offset ranges for 4-byte encoding
// These map linear values to Unicode code points
const GB18030Range = struct {
    linear_start: u32,
    linear_end: u32,
    unicode_start: u21,
};

const gb18030_ranges = [_]GB18030Range{
    .{ .linear_start = 0, .linear_end = 7533, .unicode_start = 0x0080 },
    .{ .linear_start = 7534, .linear_end = 7603, .unicode_start = 0x00D8 },
    .{ .linear_start = 7604, .linear_end = 7674, .unicode_start = 0x0100 },
    .{ .linear_start = 7675, .linear_end = 23948, .unicode_start = 0x0452 },
    .{ .linear_start = 23949, .linear_end = 39419, .unicode_start = 0x2643 },
    .{ .linear_start = 39420, .linear_end = 189000, .unicode_start = 0x10000 },
};

fn gb18030LinearToUnicode(linear: u32) u21 {
    // Simplified linear to Unicode mapping
    // In practice, this uses complex offset tables
    if (linear < 39420) {
        // BMP mapping with gaps
        return unicodeBMPFromLinear(linear);
    } else {
        // Supplementary planes (linear mapping)
        const offset = linear - 39420;
        const result = 0x10000 + offset;
        // Guard: return replacement character if the linear index maps
        // beyond the valid Unicode range (U+10FFFF)
        return std.math.cast(u21, result) orelse 0xFFFD;
    }
}

fn unicodeToGB18030Linear(codepoint: u21) u32 {
    if (codepoint >= 0x10000) {
        // Supplementary planes
        return 39420 + (codepoint - 0x10000);
    } else {
        // BMP (simplified)
        return unicodeBMPToLinear(codepoint);
    }
}

fn unicodeBMPFromLinear(linear: u32) u21 {
    // Simplified BMP conversion - in practice uses detailed tables
    // This handles common ranges
    if (linear < 7534) {
        return @intCast(0x0080 + linear);
    }
    return 0xFFFD;
}

fn unicodeBMPToLinear(codepoint: u21) u32 {
    if (codepoint >= 0x0080 and codepoint < 0x0452) {
        return codepoint - 0x0080;
    }
    return 0;
}

// ============================================================================
// Character Lookup Tables (Partial - Common Characters)
// ============================================================================

/// GB2312 row/column to Unicode mapping
/// This is a partial table covering common characters
fn lookupGB2312(b1: u8, b2: u8) u21 {
    const row = b1 - 0xA0;
    const col = b2 - 0xA0;

    // Row 1: General punctuation and symbols
    if (row == 1) {
        return gb2312_row01[col - 1];
    }
    // Row 2: Numbering and symbols
    if (row == 2) {
        return gb2312_row02[col - 1];
    }
    // Row 3: ASCII fullwidth variants (added for common use)
    if (row == 3) {
        return gb2312_row03[col - 1];
    }

    // For Chinese characters (rows 16-87), use lookup
    if (row >= 16 and row <= 87) {
        const index = (@as(usize, row) - 16) * 94 + (col - 1);
        if (index < gb2312_hanzi.len) {
            return gb2312_hanzi[index];
        }
    }

    return 0xFFFD;
}

/// GBK lookup - extends GB2312
fn lookupGBK(b1: u8, b2: u8) u21 {
    // Check if it's in GB2312 range first
    if (b1 >= 0xA1 and b1 <= 0xF7 and b2 >= 0xA1 and b2 <= 0xFE) {
        const cp = lookupGB2312(b1, b2);
        if (cp != 0xFFFD) return cp;
    }

    // GBK extensions
    // Calculate linear index for GBK extensions
    const idx = gbkIndex(b1, b2);
    if (idx < gbk_extensions.len) {
        return gbk_extensions[idx];
    }

    return 0xFFFD;
}

fn gbkIndex(b1: u8, b2: u8) usize {
    const row: usize = b1 - 0x81;
    const col: usize = if (b2 >= 0x80) b2 - 0x41 else b2 - 0x40;
    return row * 190 + col;
}

/// Reverse lookup for GB2312
fn reverseGB2312(codepoint: u21) ?[2]u8 {
    // Check punctuation rows
    for (gb2312_row01, 0..) |cp, i| {
        if (cp == codepoint) {
            return .{ 0xA1, @intCast(i + 0xA1) };
        }
    }
    for (gb2312_row02, 0..) |cp, i| {
        if (cp == codepoint) {
            return .{ 0xA2, @intCast(i + 0xA1) };
        }
    }
    for (gb2312_row03, 0..) |cp, i| {
        if (cp == codepoint) {
            return .{ 0xA3, @intCast(i + 0xA1) };
        }
    }

    // Check hanzi
    for (gb2312_hanzi, 0..) |cp, i| {
        if (cp == codepoint) {
            const row: u8 = @intCast(i / 94 + 16);
            const col: u8 = @intCast(i % 94 + 1);
            return .{ row + 0xA0, col + 0xA0 };
        }
    }

    return null;
}

/// Reverse lookup for GBK
fn reverseGBK(codepoint: u21) ?[2]u8 {
    // Try GB2312 first
    if (reverseGB2312(codepoint)) |bytes| {
        return bytes;
    }

    // Check GBK extensions
    for (gbk_extensions, 0..) |cp, i| {
        if (cp == codepoint) {
            const row: u8 = @intCast(i / 190 + 0x81);
            const col_idx: u8 = @intCast(i % 190);
            const col: u8 = if (col_idx >= 0x3F) col_idx + 0x41 else col_idx + 0x40;
            return .{ row, col };
        }
    }

    return null;
}

// ============================================================================
// Data Tables
// ============================================================================

// GB2312 Row 01: General punctuation (partial)
const gb2312_row01 = [_]u21{
    0x3000, 0x3001, 0x3002, 0x00B7, 0x02C9, 0x02C7, 0x00A8, 0x3003, // SP、。·ˉˇ¨〃
    0x3005, 0x2014, 0x301C, 0x2016, 0x2026, 0x2018, 0x2019, 0x201C, // 々—〜‖…''""
    0x201D, 0x3014, 0x3015, 0x3010, 0x3011, 0x3008, 0x3009, 0x300A, // "〔〕【】〈〉《
    0x300B, 0x300C, 0x300D, 0x300E, 0x300F, 0x3016, 0x3017, 0x3018, // 》「」『』〖〗〘
    0x3019, 0xFF5B, 0xFF5D, 0x3020, 0x00A7, 0x2606, 0x2605, 0x25CB, // 〙{}〠§☆★○
    0x25CF, 0x25CE, 0x25C7, 0x25C6, 0x25A1, 0x25A0, 0x25B3, 0x25B2, // ●◎◇◆□■△▲
    0x203B, 0x2192, 0x2190, 0x2191, 0x2193, 0x3013, 0xFFFD, 0xFFFD, // ※→←↑↓〓
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
};

// GB2312 Row 02: Numbering symbols (partial)
const gb2312_row02 = [_]u21{
    0x2170, 0x2171, 0x2172, 0x2173, 0x2174, 0x2175, 0x2176, 0x2177, // ⅰⅱⅲⅳⅴⅵⅶⅷ
    0x2178, 0x2179, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, // ⅸⅹ
    0x2160, 0x2161, 0x2162, 0x2163, 0x2164, 0x2165, 0x2166, 0x2167, // ⅠⅡⅢⅣⅤⅥⅦⅧ
    0x2168, 0x2169, 0x216A, 0x216B, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, // ⅨⅩⅪⅫv
    0x0391, 0x0392, 0x0393, 0x0394, 0x0395, 0x0396, 0x0397, 0x0398, // ΑΒΓΔΕΖΗΘ
    0x0399, 0x039A, 0x039B, 0x039C, 0x039D, 0x039E, 0x039F, 0x03A0, // ΙΚΛΜΝΞΟΠ
    0x03A1, 0x03A3, 0x03A4, 0x03A5, 0x03A6, 0x03A7, 0x03A8, 0x03A9, // ΡΣΤΥΦΧΨΩ
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0x03B1, 0x03B2, 0x03B3, 0x03B4, 0x03B5, 0x03B6, 0x03B7, 0x03B8, // αβγδεζηθ
    0x03B9, 0x03BA, 0x03BB, 0x03BC, 0x03BD, 0x03BE, 0x03BF, 0x03C0, // ικλμνξοπ
    0x03C1, 0x03C3, 0x03C4, 0x03C5, 0x03C6, 0x03C7, 0x03C8, 0x03C9, // ρστυφχψω
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
};

// GB2312 Row 03: Fullwidth ASCII (partial)
const gb2312_row03 = [_]u21{
    0xFF01, 0xFF02, 0xFF03, 0xFF04, 0xFF05, 0xFF06, 0xFF07, 0xFF08, // ！＂＃＄％＆＇（
    0xFF09, 0xFF0A, 0xFF0B, 0xFF0C, 0xFF0D, 0xFF0E, 0xFF0F, 0xFF10, // ）＊＋，－．／０
    0xFF11, 0xFF12, 0xFF13, 0xFF14, 0xFF15, 0xFF16, 0xFF17, 0xFF18, // １２３４５６７８
    0xFF19, 0xFF1A, 0xFF1B, 0xFF1C, 0xFF1D, 0xFF1E, 0xFF1F, 0xFF20, // ９：；＜＝＞？＠
    0xFF21, 0xFF22, 0xFF23, 0xFF24, 0xFF25, 0xFF26, 0xFF27, 0xFF28, // ＡＢＣＤＥＦＧＨ
    0xFF29, 0xFF2A, 0xFF2B, 0xFF2C, 0xFF2D, 0xFF2E, 0xFF2F, 0xFF30, // ＩＪＫＬＭＮＯＰ
    0xFF31, 0xFF32, 0xFF33, 0xFF34, 0xFF35, 0xFF36, 0xFF37, 0xFF38, // ＱＲＳＴＵＶＷＸ
    0xFF39, 0xFF3A, 0xFF3B, 0xFF3C, 0xFF3D, 0xFF3E, 0xFF3F, 0xFF40, // ＹＺ［＼］＾＿｀
    0xFF41, 0xFF42, 0xFF43, 0xFF44, 0xFF45, 0xFF46, 0xFF47, 0xFF48, // ａｂｃｄｅｆｇｈ
    0xFF49, 0xFF4A, 0xFF4B, 0xFF4C, 0xFF4D, 0xFF4E, 0xFF4F, 0xFF50, // ｉｊｋｌｍｎｏｐ
    0xFF51, 0xFF52, 0xFF53, 0xFF54, 0xFF55, 0xFF56, 0xFF57, 0xFF58, // ｑｒｓｔｕｖｗｘ
    0xFF59, 0xFF5A, 0xFF5B, 0xFF5C, 0xFF5D, 0xFF5E, // ｙｚ｛｜｝～
};

// GB2312 Hanzi characters (Level 1 and 2) - partial table with common characters
// In a complete implementation, this would have 6763 entries
const gb2312_hanzi = [_]u21{
    // Row 16 (0xB0A1-0xB0FE): 啊阿埃挨哎唉哀皑癌蔼矮艾碍爱隘鞍氨安俺按暗岸胺案肮昂盎凹敖熬翱袄傲奥懊澳芭捌扒叭吧笆八疤巴拔跋靶把耙坝霸罢爸白柏百摆佰败拜稗斑班搬扳般颁板版扮拌伴瓣半办绊邦帮梆榜膀绑棒磅蚌镑傍谤苞胞包褒雹保堡饱宝抱报暴豹鲍爆杯碑悲卑北辈背贝钡倍狈备惫焙被
    0x554A, 0x963F, 0x57C3, 0x6328, 0x54CE, 0x5509, 0x54C0, 0x7691,
    0x764C, 0x853C, 0x77EE, 0x827E, 0x788D, 0x7231, 0x9698, 0x978D,
    0x6C28, 0x5B89, 0x4FFA, 0x6309, 0x6697, 0x5CB8, 0x80FA, 0x6848,
    0x80AE, 0x6602, 0x76CE, 0x51F9, 0x6556, 0x71AC, 0x7FF1, 0x8884,
    0x50B2, 0x5965, 0x61CA, 0x6FB3, 0x82AD, 0x634C, 0x6252, 0x53ED,
    0x5427, 0x7B06, 0x516B, 0x75A4, 0x5DF4, 0x62D4, 0x8DCB, 0x9776,
    0x628A, 0x8019, 0x575D, 0x9738, 0x7F62, 0x7238, 0x767D, 0x67CF,
    0x767E, 0x6446, 0x4F70, 0x8D25, 0x62DC, 0x7A17, 0x6591, 0x73ED,
    0x642C, 0x6273, 0x822C, 0x9881, 0x677F, 0x7248, 0x626E, 0x62CC,
    0x4F34, 0x74E3, 0x534A, 0x529E, 0x7ECA, 0x90A6, 0x5E2E, 0x6886,
    0x699C, 0x8180, 0x7ED1, 0x68D2, 0x78C5, 0x868C, 0x9551, 0x508D,
    0x8C24, 0x82DE, 0x80DE, 0x5305, 0x8912, 0x96F9,
    // Continue with more characters...
    0x4FDD, 0x5821,
    0x9971, 0x5B9D, 0x62B1, 0x62A5, 0x66B4, 0x8C79, 0x9C8D, 0x7206,
    0x676F, 0x7891, 0x60B2, 0x5351, 0x5317, 0x8F88, 0x80CC, 0x8D1D,
    0x94A1, 0x500D, 0x72C8, 0x5907, 0x60EB, 0x7119, 0x88AB, 0x5954,
    0x82EF, 0x672C, 0x7B28, 0x5D29, 0x7EF7, 0x752D, 0x6CF5, 0x8E66,
    0x8FF8, 0x903C, 0x9F3B, 0x6BD4, 0x9119, 0x7B14, 0x5F7C, 0x78A7,
    0x84D6, 0x853D, 0x6BD5, 0x6BD9, 0x6BD6, 0x5E01, 0x5E87, 0x75F9,
    0x95ED, 0x655D, 0x5F0A, 0x5FC5, 0x8F9F, 0x58C1, 0x81C2, 0x907F,
    0x965B, 0x97AD, 0x8FB9, 0x7F16, 0x8D2C, 0x6241, 0x4FBF, 0x53D8,
    0x535E, 0x8FA8, 0x8FA9, 0x8FAB, 0x904D, 0x6807, 0x5F6A, 0x8198,
    0x8868, 0x9CD6, 0x618B, 0x522B, 0x762A, 0x5F6C, 0x658C, 0x6FD2,
    0x6EE8, 0x5BBE, 0x6448, 0x5175, 0x51B0, 0x67C4, 0x4E19, 0x79C9,
    0x997C, 0x70B3,
};

// GBK extension characters (partial - common extensions)
// This covers characters not in GB2312
const gbk_extensions = [_]u21{
    0x4E02, 0x4E04, 0x4E05, 0x4E06, 0x4E0F, 0x4E12, 0x4E17, 0x4E1F,
    0x4E20, 0x4E21, 0x4E23, 0x4E26, 0x4E29, 0x4E2E, 0x4E2F, 0x4E31,
    0x4E33, 0x4E35, 0x4E37, 0x4E3C, 0x4E40, 0x4E41, 0x4E42, 0x4E44,
    0x4E46, 0x4E4A, 0x4E51, 0x4E55, 0x4E57, 0x4E5A, 0x4E5B,
    0x4E62,
    // ... more extension characters
};

// ============================================================================
// Utility Functions
// ============================================================================

fn appendCodepoint(list: *std.ArrayListUnmanaged(u8), alloc: std.mem.Allocator, codepoint: u21) !void {
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(codepoint, &buf) catch {
        // Invalid codepoint - use replacement character
        try list.appendSlice(alloc, "\xEF\xBF\xBD");
        return;
    };
    try list.appendSlice(alloc, buf[0..len]);
}

// ============================================================================
// Tests
// ============================================================================

test "GB2312 ASCII passthrough" {
    const allocator = std.testing.allocator;
    const result = try ChineseEncoding.GB2312.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "GB2312 encode/decode roundtrip for ASCII" {
    const allocator = std.testing.allocator;
    const encoded = try ChineseEncoding.GB2312.encode(allocator, "Test123");
    defer allocator.free(encoded);
    const decoded = try ChineseEncoding.GB2312.decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Test123", decoded);
}

test "GBK extends GB2312" {
    const allocator = std.testing.allocator;
    // GBK should handle the same input as GB2312
    const result = try ChineseEncoding.GBK.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "GB18030 ASCII passthrough" {
    const allocator = std.testing.allocator;
    const result = try ChineseEncoding.GB18030.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "GB18030 4-byte encoding" {
    const allocator = std.testing.allocator;
    // Test that we can encode and decode supplementary plane characters
    const original = "A\u{10000}B"; // A + LINEAR B SYLLABLE B008 A + B
    const encoded = try ChineseEncoding.GB18030.encode(allocator, original);
    defer allocator.free(encoded);
    const decoded = try ChineseEncoding.GB18030.decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings(original, decoded);
}

test "encoding names" {
    try std.testing.expectEqualStrings("GB2312", ChineseEncoding.GB2312.name());
    try std.testing.expectEqualStrings("GBK", ChineseEncoding.GBK.name());
    try std.testing.expectEqualStrings("GB18030", ChineseEncoding.GB18030.name());
}
