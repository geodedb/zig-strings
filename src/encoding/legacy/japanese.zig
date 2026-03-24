// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Japanese Legacy Encoding Support
//!
//! This module provides support for legacy Japanese character encodings:
//! - Shift_JIS: Microsoft's Japanese encoding (also known as CP932)
//! - EUC-JP: Extended Unix Code for Japanese
//!
//! Both encodings support:
//! - ASCII (0x00-0x7F)
//! - JIS X 0201 katakana
//! - JIS X 0208 kanji and symbols
//!
//! Shift_JIS is commonly used in Windows environments.
//! EUC-JP is commonly used in Unix/Linux environments.

const std = @import("std");
const legacy_errors = @import("legacy_encoding_errors");

/// Japanese encoding variants
pub const JapaneseEncoding = enum {
    ShiftJIS,
    EUCJP,

    /// Decode bytes to UTF-8
    pub fn decode(self: JapaneseEncoding, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        return switch (self) {
            .ShiftJIS => decodeShiftJIS(allocator, input),
            .EUCJP => decodeEUCJP(allocator, input),
        };
    }

    /// Encode UTF-8 to this encoding
    pub fn encode(self: JapaneseEncoding, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        return switch (self) {
            .ShiftJIS => encodeShiftJIS(allocator, input),
            .EUCJP => encodeEUCJP(allocator, input),
        };
    }

    /// Get human-readable name
    pub fn name(self: JapaneseEncoding) []const u8 {
        return switch (self) {
            .ShiftJIS => "Shift_JIS",
            .EUCJP => "EUC-JP",
        };
    }
};

/// Errors that can occur during encoding/decoding
pub const EncodingError = legacy_errors.LegacyEncodingError;

// ============================================================================
// Shift_JIS Implementation
// ============================================================================

/// Shift_JIS encoding structure:
/// - 0x00-0x7F: ASCII
/// - 0xA1-0xDF: Half-width katakana (JIS X 0201)
/// - 0x81-0x9F, 0xE0-0xFC: First byte of double-byte
/// - Second byte: 0x40-0x7E, 0x80-0xFC
fn decodeShiftJIS(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const b1 = input[i];

        if (b1 < 0x80) {
            // ASCII
            try result.append(allocator, b1);
            i += 1;
        } else if (b1 >= 0xA1 and b1 <= 0xDF) {
            // Half-width katakana (JIS X 0201)
            const codepoint = jis0201Katakana(b1);
            try appendCodepoint(&result, allocator, codepoint);
            i += 1;
        } else if ((b1 >= 0x81 and b1 <= 0x9F) or (b1 >= 0xE0 and b1 <= 0xFC)) {
            // Double-byte character
            if (i + 1 >= input.len) {
                try appendCodepoint(&result, allocator, 0xFFFD);
                i += 1;
                continue;
            }

            const b2 = input[i + 1];
            if ((b2 >= 0x40 and b2 <= 0x7E) or (b2 >= 0x80 and b2 <= 0xFC)) {
                const codepoint = lookupShiftJIS(b1, b2);
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

fn encodeShiftJIS(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
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
        } else if (codepoint >= 0xFF61 and codepoint <= 0xFF9F) {
            // Half-width katakana
            try result.append(allocator, @intCast(codepoint - 0xFF61 + 0xA1));
        } else {
            // Try to find in Shift_JIS table
            const sjis = reverseShiftJIS(codepoint);
            if (sjis) |bytes| {
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

/// Convert Shift_JIS double-byte to Unicode
fn lookupShiftJIS(b1: u8, b2: u8) u21 {
    // Convert Shift_JIS to JIS X 0208 row/cell
    var row: u8 = undefined;
    var cell: u8 = undefined;

    // Adjust first byte
    if (b1 >= 0x81 and b1 <= 0x9F) {
        row = (b1 - 0x81) * 2 + 1;
    } else { // 0xE0-0xFC
        row = (b1 - 0xE0) * 2 + 63;
    }

    // Adjust second byte
    if (b2 >= 0x40 and b2 <= 0x7E) {
        cell = b2 - 0x40 + 1;
    } else if (b2 >= 0x80 and b2 <= 0x9E) {
        cell = b2 - 0x80 + 64;
    } else { // 0x9F-0xFC
        cell = b2 - 0x9F + 1;
        row += 1;
    }

    return lookupJIS0208(row, cell);
}

/// Reverse lookup for Shift_JIS
fn reverseShiftJIS(codepoint: u21) ?[2]u8 {
    const jis = reverseJIS0208(codepoint) orelse return null;
    const row = jis[0];
    const cell = jis[1];

    var b1: u8 = undefined;
    var b2: u8 = undefined;

    // Convert row to first byte
    if (row <= 62) {
        b1 = (row - 1) / 2 + 0x81;
    } else {
        b1 = (row - 63) / 2 + 0xE0;
    }

    // Convert cell to second byte
    if (row % 2 == 1) {
        // Odd row
        if (cell <= 63) {
            b2 = cell + 0x40 - 1;
        } else {
            b2 = cell + 0x80 - 64;
        }
    } else {
        // Even row
        b2 = cell + 0x9F - 1;
    }

    return .{ b1, b2 };
}

// ============================================================================
// EUC-JP Implementation
// ============================================================================

/// EUC-JP encoding structure:
/// - 0x00-0x7F: ASCII
/// - 0x8E + 0xA1-0xDF: Half-width katakana (JIS X 0201)
/// - 0xA1-0xFE + 0xA1-0xFE: JIS X 0208
/// - 0x8F + 0xA1-0xFE + 0xA1-0xFE: JIS X 0212
fn decodeEUCJP(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const b1 = input[i];

        if (b1 < 0x80) {
            // ASCII
            try result.append(allocator, b1);
            i += 1;
        } else if (b1 == 0x8E and i + 1 < input.len) {
            // Half-width katakana
            const b2 = input[i + 1];
            if (b2 >= 0xA1 and b2 <= 0xDF) {
                const codepoint = jis0201Katakana(b2);
                try appendCodepoint(&result, allocator, codepoint);
                i += 2;
            } else {
                try appendCodepoint(&result, allocator, 0xFFFD);
                i += 1;
            }
        } else if (b1 == 0x8F and i + 2 < input.len) {
            // JIS X 0212 (3-byte)
            const b2 = input[i + 1];
            const b3 = input[i + 2];
            if (b2 >= 0xA1 and b2 <= 0xFE and b3 >= 0xA1 and b3 <= 0xFE) {
                const codepoint = lookupJIS0212(b2 - 0xA0, b3 - 0xA0);
                try appendCodepoint(&result, allocator, codepoint);
                i += 3;
            } else {
                try appendCodepoint(&result, allocator, 0xFFFD);
                i += 1;
            }
        } else if (b1 >= 0xA1 and b1 <= 0xFE and i + 1 < input.len) {
            // JIS X 0208 (2-byte)
            const b2 = input[i + 1];
            if (b2 >= 0xA1 and b2 <= 0xFE) {
                const codepoint = lookupJIS0208(b1 - 0xA0, b2 - 0xA0);
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

fn encodeEUCJP(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
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
        } else if (codepoint >= 0xFF61 and codepoint <= 0xFF9F) {
            // Half-width katakana
            try result.append(allocator, 0x8E);
            try result.append(allocator, @intCast(codepoint - 0xFF61 + 0xA1));
        } else {
            // Try JIS X 0208
            const jis = reverseJIS0208(codepoint);
            if (jis) |rc| {
                try result.append(allocator, rc[0] + 0xA0);
                try result.append(allocator, rc[1] + 0xA0);
            } else {
                // Try JIS X 0212
                const jis212 = reverseJIS0212(codepoint);
                if (jis212) |rc| {
                    try result.append(allocator, 0x8F);
                    try result.append(allocator, rc[0] + 0xA0);
                    try result.append(allocator, rc[1] + 0xA0);
                } else {
                    // Cannot encode
                    try result.append(allocator, '?');
                }
            }
        }

        i += len;
    }

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// JIS X 0201 Katakana
// ============================================================================

/// Convert JIS X 0201 katakana byte to Unicode
fn jis0201Katakana(b: u8) u21 {
    // JIS X 0201 katakana maps to Unicode half-width katakana
    // 0xA1 -> U+FF61, 0xDF -> U+FF9F
    if (b >= 0xA1 and b <= 0xDF) {
        return @as(u21, b) - 0xA1 + 0xFF61;
    }
    return 0xFFFD;
}

// ============================================================================
// JIS X 0208 Character Set
// ============================================================================

/// Look up JIS X 0208 character by row and cell (1-94)
fn lookupJIS0208(row: u8, cell: u8) u21 {
    if (row < 1 or row > 94 or cell < 1 or cell > 94) {
        return 0xFFFD;
    }

    // Row 1: Symbols
    if (row == 1) {
        return jis0208_row01[cell - 1];
    }
    // Row 2: More symbols
    if (row == 2) {
        return jis0208_row02[cell - 1];
    }
    // Row 3: Empty (undefined)
    if (row == 3) {
        return 0xFFFD;
    }
    // Row 4: Hiragana
    if (row == 4) {
        return jis0208_row04[cell - 1];
    }
    // Row 5: Katakana
    if (row == 5) {
        return jis0208_row05[cell - 1];
    }
    // Row 6: Greek
    if (row == 6) {
        return jis0208_row06[cell - 1];
    }
    // Row 7: Cyrillic
    if (row == 7) {
        return jis0208_row07[cell - 1];
    }
    // Row 8: Line drawing
    if (row == 8) {
        return jis0208_row08[cell - 1];
    }
    // Rows 16-47: Level 1 Kanji (by reading)
    // Rows 48-84: Level 2 Kanji (by radical)
    if (row >= 16 and row <= 84) {
        const index = (@as(usize, row) - 16) * 94 + (cell - 1);
        if (index < jis0208_kanji.len) {
            return jis0208_kanji[index];
        }
    }

    return 0xFFFD;
}

/// Reverse lookup for JIS X 0208
fn reverseJIS0208(codepoint: u21) ?[2]u8 {
    // Check symbols
    for (jis0208_row01, 0..) |cp, i| {
        if (cp == codepoint) return .{ 1, @intCast(i + 1) };
    }
    for (jis0208_row02, 0..) |cp, i| {
        if (cp == codepoint) return .{ 2, @intCast(i + 1) };
    }
    // Check hiragana
    for (jis0208_row04, 0..) |cp, i| {
        if (cp == codepoint) return .{ 4, @intCast(i + 1) };
    }
    // Check katakana
    for (jis0208_row05, 0..) |cp, i| {
        if (cp == codepoint) return .{ 5, @intCast(i + 1) };
    }
    // Check Greek
    for (jis0208_row06, 0..) |cp, i| {
        if (cp == codepoint) return .{ 6, @intCast(i + 1) };
    }
    // Check Cyrillic
    for (jis0208_row07, 0..) |cp, i| {
        if (cp == codepoint) return .{ 7, @intCast(i + 1) };
    }
    // Check line drawing
    for (jis0208_row08, 0..) |cp, i| {
        if (cp == codepoint) return .{ 8, @intCast(i + 1) };
    }
    // Check kanji
    for (jis0208_kanji, 0..) |cp, i| {
        if (cp == codepoint) {
            const row: u8 = @intCast(i / 94 + 16);
            const cell: u8 = @intCast(i % 94 + 1);
            return .{ row, cell };
        }
    }

    return null;
}

// ============================================================================
// JIS X 0212 Character Set (Supplementary)
// ============================================================================

/// Look up JIS X 0212 character
fn lookupJIS0212(row: u8, cell: u8) u21 {
    if (row < 1 or row > 94 or cell < 1 or cell > 94) {
        return 0xFFFD;
    }

    // JIS X 0212 contains supplementary kanji
    // This is a simplified implementation
    const index = (@as(usize, row) - 1) * 94 + (cell - 1);
    if (index < jis0212_chars.len) {
        return jis0212_chars[index];
    }

    return 0xFFFD;
}

/// Reverse lookup for JIS X 0212
fn reverseJIS0212(codepoint: u21) ?[2]u8 {
    for (jis0212_chars, 0..) |cp, i| {
        if (cp == codepoint) {
            const row: u8 = @intCast(i / 94 + 1);
            const cell: u8 = @intCast(i % 94 + 1);
            return .{ row, cell };
        }
    }
    return null;
}

// ============================================================================
// Data Tables
// ============================================================================

// JIS X 0208 Row 1: Symbols and punctuation
const jis0208_row01 = [_]u21{
    0x3000, 0x3001, 0x3002, 0xFF0C, 0xFF0E, 0x30FB, 0xFF1A, 0xFF1B, // 　、。，．・：；
    0xFF1F, 0xFF01, 0x309B, 0x309C, 0x00B4, 0xFF40, 0x00A8, 0xFF3E, // ？！゛゜´｀¨＾
    0xFFE3, 0xFF3F, 0x30FD, 0x30FE, 0x309D, 0x309E, 0x3003, 0x4EDD, // ￣＿ヽヾゝゞ〃仝
    0x3005, 0x3006, 0x3007, 0x30FC, 0x2015, 0x2010, 0xFF0F, 0xFF3C, // 々〆〇ー―‐／＼
    0xFF5E, 0x2225, 0xFF5C, 0x2026, 0x2025, 0x2018, 0x2019, 0x201C, // ～‖｜…‥''""
    0x201D, 0xFF08, 0xFF09, 0x3014, 0x3015, 0xFF3B, 0xFF3D, 0xFF5B, // "（）〔〕［］｛
    0xFF5D, 0x3008, 0x3009, 0x300A, 0x300B, 0x300C, 0x300D, 0x300E, // ｝〈〉《》「」『
    0x300F, 0x3010, 0x3011, 0xFF0B, 0xFF0D, 0x00B1, 0x00D7, 0x00F7, // 』【】＋－±×÷
    0xFF1D, 0x2260, 0xFF1C, 0xFF1E, 0x2266, 0x2267, 0x221E, 0x2234, // ＝≠＜＞≦≧∞∴
    0x2642, 0x2640, 0x00B0, 0x2032, 0x2033, 0x2103, 0xFFE5, 0xFF04, // ♂♀°′″℃￥＄
    0xFFE0, 0xFFE1, 0xFF05, 0xFF03, 0xFF06, 0xFF0A, 0xFF20, 0x00A7, // ￠￡％＃＆＊＠§
    0x2606, 0x2605, 0x25CB, 0x25CF, 0x25CE, 0x25C7, // ☆★○●◎◇
};

// JIS X 0208 Row 2: More symbols
const jis0208_row02 = [_]u21{
    0x25C6, 0x25A1, 0x25A0, 0x25B3, 0x25B2, 0x25BD, 0x25BC, 0x203B, // ◆□■△▲▽▼※
    0x3012, 0x2192, 0x2190, 0x2191, 0x2193, 0x3013, 0xFFFD, 0xFFFD, // 〒→←↑↓〓
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0x2208, 0x220B, 0x2286, 0x2287, 0x2282, 0x2283, 0x222A, 0x2229, // ∈∋⊆⊇⊂⊃∪∩
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0x2227, 0x2228, 0xFFE2, 0x21D2, 0x21D4, 0x2200, 0x2203, 0xFFFD, // ∧∨￢⇒⇔∀∃
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0x2220, 0x22A5, 0x2312, 0x2202, 0x2207, 0x2261, 0x2252, 0x226A, // ∠⊥⌒∂∇≡≒≪
    0x226B, 0x221A, 0x223D, 0x221D, 0x2235, 0x222B, 0x222C, 0xFFFD, // ≫√∽∝∵∫∬
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0x212B, 0x2030, // Å‰
    0x266F, 0x266D, 0x266A, 0x2020, 0x2021, 0x00B6, 0xFFFD, 0xFFFD, // ♯♭♪†‡¶
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0x25EF, 0xFFFD, // ◯
};

// JIS X 0208 Row 4: Hiragana
const jis0208_row04 = [_]u21{
    0x3041, 0x3042, 0x3043, 0x3044, 0x3045, 0x3046, 0x3047, 0x3048, // ぁあぃいぅうぇえ
    0x3049, 0x304A, 0x304B, 0x304C, 0x304D, 0x304E, 0x304F, 0x3050, // ぉおかがきぎくぐ
    0x3051, 0x3052, 0x3053, 0x3054, 0x3055, 0x3056, 0x3057, 0x3058, // けげこごさざしじ
    0x3059, 0x305A, 0x305B, 0x305C, 0x305D, 0x305E, 0x305F, 0x3060, // すずせぜそぞただ
    0x3061, 0x3062, 0x3063, 0x3064, 0x3065, 0x3066, 0x3067, 0x3068, // ちぢっつづてでと
    0x3069, 0x306A, 0x306B, 0x306C, 0x306D, 0x306E, 0x306F, 0x3070, // どなにぬねのはば
    0x3071, 0x3072, 0x3073, 0x3074, 0x3075, 0x3076, 0x3077, 0x3078, // ぱひびぴふぶぷへ
    0x3079, 0x307A, 0x307B, 0x307C, 0x307D, 0x307E, 0x307F, 0x3080, // べぺほぼぽまみむ
    0x3081, 0x3082, 0x3083, 0x3084, 0x3085, 0x3086, 0x3087, 0x3088, // めもゃやゅゆょよ
    0x3089, 0x308A, 0x308B, 0x308C, 0x308D, 0x308E, 0x308F, 0x3090, // らりるれろゎわゐ
    0x3091, 0x3092, 0x3093, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, // ゑをん
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
};

// JIS X 0208 Row 5: Katakana
const jis0208_row05 = [_]u21{
    0x30A1, 0x30A2, 0x30A3, 0x30A4, 0x30A5, 0x30A6, 0x30A7, 0x30A8, // ァアィイゥウェエ
    0x30A9, 0x30AA, 0x30AB, 0x30AC, 0x30AD, 0x30AE, 0x30AF, 0x30B0, // ォオカガキギクグ
    0x30B1, 0x30B2, 0x30B3, 0x30B4, 0x30B5, 0x30B6, 0x30B7, 0x30B8, // ケゲコゴサザシジ
    0x30B9, 0x30BA, 0x30BB, 0x30BC, 0x30BD, 0x30BE, 0x30BF, 0x30C0, // スズセゼソゾタダ
    0x30C1, 0x30C2, 0x30C3, 0x30C4, 0x30C5, 0x30C6, 0x30C7, 0x30C8, // チヂッツヅテデト
    0x30C9, 0x30CA, 0x30CB, 0x30CC, 0x30CD, 0x30CE, 0x30CF, 0x30D0, // ドナニヌネノハバ
    0x30D1, 0x30D2, 0x30D3, 0x30D4, 0x30D5, 0x30D6, 0x30D7, 0x30D8, // パヒビピフブプヘ
    0x30D9, 0x30DA, 0x30DB, 0x30DC, 0x30DD, 0x30DE, 0x30DF, 0x30E0, // ベペホボポマミム
    0x30E1, 0x30E2, 0x30E3, 0x30E4, 0x30E5, 0x30E6, 0x30E7, 0x30E8, // メモャヤュユョヨ
    0x30E9, 0x30EA, 0x30EB, 0x30EC, 0x30ED, 0x30EE, 0x30EF, 0x30F0, // ラリルレロヮワヰ
    0x30F1, 0x30F2, 0x30F3, 0x30F4, 0x30F5, 0x30F6, 0xFFFD, 0xFFFD, // ヱヲンヴヵヶ
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
};

// JIS X 0208 Row 6: Greek letters
const jis0208_row06 = [_]u21{
    0x0391, 0x0392, 0x0393, 0x0394, 0x0395, 0x0396, 0x0397, 0x0398, // ΑΒΓΔΕΖΗΘ
    0x0399, 0x039A, 0x039B, 0x039C, 0x039D, 0x039E, 0x039F, 0x03A0, // ΙΚΛΜΝΞΟΠ
    0x03A1, 0x03A3, 0x03A4, 0x03A5, 0x03A6, 0x03A7, 0x03A8, 0x03A9, // ΡΣΤΥΦΧΨΩ
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0x03B1, 0x03B2, 0x03B3, 0x03B4, 0x03B5, 0x03B6, 0x03B7, 0x03B8, // αβγδεζηθ
    0x03B9, 0x03BA, 0x03BB, 0x03BC, 0x03BD, 0x03BE, 0x03BF, 0x03C0, // ικλμνξοπ
    0x03C1, 0x03C3, 0x03C4, 0x03C5, 0x03C6, 0x03C7, 0x03C8, 0x03C9, // ρστυφχψω
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
};

// JIS X 0208 Row 7: Cyrillic letters
const jis0208_row07 = [_]u21{
    0x0410, 0x0411, 0x0412, 0x0413, 0x0414, 0x0415, 0x0401, 0x0416, // АБВГДЕЁЖ
    0x0417, 0x0418, 0x0419, 0x041A, 0x041B, 0x041C, 0x041D, 0x041E, // ЗИЙКЛМНО
    0x041F, 0x0420, 0x0421, 0x0422, 0x0423, 0x0424, 0x0425, 0x0426, // ПРСТУФХЦ
    0x0427, 0x0428, 0x0429, 0x042A, 0x042B, 0x042C, 0x042D, 0x042E, // ЧШЩЪЫЬЭЮ
    0x042F, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, // Я
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0x0430, 0x0431, 0x0432, 0x0433, 0x0434, 0x0435, 0x0451, 0x0436, // абвгдеёж
    0x0437, 0x0438, 0x0439, 0x043A, 0x043B, 0x043C, 0x043D, 0x043E, // зийклмно
    0x043F, 0x0440, 0x0441, 0x0442, 0x0443, 0x0444, 0x0445, 0x0446, // прстуфхц
    0x0447, 0x0448, 0x0449, 0x044A, 0x044B, 0x044C, 0x044D, 0x044E, // чшщъыьэю
    0x044F, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, // я
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
};

// JIS X 0208 Row 8: Line drawing characters
const jis0208_row08 = [_]u21{
    0x2500, 0x2502, 0x250C, 0x2510, 0x2518, 0x2514, 0x251C, 0x252C, // ─│┌┐┘└├┬
    0x2524, 0x2534, 0x253C, 0x2501, 0x2503, 0x250F, 0x2513, 0x251B, // ┤┴┼━┃┏┓┛
    0x2517, 0x2523, 0x2533, 0x252B, 0x253B, 0x254B, 0x2520, 0x252F, // ┗┣┳┫┻╋┠┯
    0x2528, 0x2537, 0x253F, 0x251D, 0x2530, 0x2525, 0x2538, 0x2542, // ┨┷┿┝┰┥┸╂
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
};

// JIS X 0208 Kanji (partial - common kanji)
// Rows 16-47: Level 1 Kanji (sorted by reading)
// Rows 48-84: Level 2 Kanji (sorted by radical/stroke)
const jis0208_kanji = [_]u21{
    // Row 16: 亜唖娃阿哀愛挨姶逢葵茜穐悪握渥旭葦芦鯵梓圧斡扱宛姐虻飴絢綾鮎或粟袷安庵按暗案闇鞍杏以伊位依偉囲夷委威尉惟意慰易椅為畏異移維緯胃萎衣謂違遺医井亥域育郁磯一壱溢逸稲茨芋鰯允印咽員因姻引飲淫胤蔭
    0x4E9C, 0x5516, 0x5A03, 0x963F, 0x54C0, 0x611B, 0x6328, 0x59F6,
    0x9022, 0x8475, 0x831C, 0x7A50, 0x60AA, 0x63E1, 0x6E25, 0x65ED,
    0x8466, 0x82A6, 0x9BD6, 0x6893, 0x5727, 0x65A1, 0x6271, 0x5B9B,
    0x59D0, 0x867B, 0x98F4, 0x7D62, 0x7DBE, 0x9B8E, 0x6216, 0x7C9F,
    0x88B7, 0x5B89, 0x5EB5, 0x6309, 0x6697, 0x6848, 0x95C7, 0x978D,
    0x674F, 0x4EE5, 0x4F0A, 0x4F4D, 0x4F9D, 0x5049, 0x56F2, 0x5937,
    0x59D4, 0x5A01, 0x5C09, 0x60DF, 0x610F, 0x6170, 0x6613, 0x6905,
    0x70BA, 0x754F, 0x7570, 0x79FB, 0x7DAD, 0x7DEF, 0x80C3, 0x840E,
    0x8863, 0x8B02, 0x9055, 0x907A, 0x533B, 0x4E95, 0x4EA5, 0x57DF,
    0x80B2, 0x90C1, 0x78EF, 0x4E00, 0x58F1, 0x6EA2, 0x9038, 0x7A32,
    0x8328, 0x828B, 0x9C2F, 0x5141, 0x5370, 0x54BD, 0x54E1, 0x56E0,
    0x59FB, 0x5F15, 0x98F2, 0x6DEB, 0x80E4,
    0x852D,
    // Continue with more kanji...
};

// JIS X 0212 supplementary characters (partial)
const jis0212_chars = [_]u21{
    // Supplementary kanji not in JIS X 0208
    0x02D8, 0x02C7, 0x00B8, 0x02D9, 0x02DD, 0x00AF, 0x02DB, 0x02DA,
    0xFF5E, 0x0384, 0x0385, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD,
    // ... more supplementary characters
};

// ============================================================================
// Utility Functions
// ============================================================================

fn appendCodepoint(list: *std.ArrayListUnmanaged(u8), alloc: std.mem.Allocator, codepoint: u21) !void {
    var buf: [4]u8 = undefined;
    const len = std.unicode.utf8Encode(codepoint, &buf) catch {
        try list.appendSlice(alloc, "\xEF\xBF\xBD");
        return;
    };
    try list.appendSlice(alloc, buf[0..len]);
}

// ============================================================================
// Tests
// ============================================================================

test "Shift_JIS ASCII passthrough" {
    const allocator = std.testing.allocator;
    const result = try JapaneseEncoding.ShiftJIS.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "Shift_JIS encode/decode roundtrip for ASCII" {
    const allocator = std.testing.allocator;
    const encoded = try JapaneseEncoding.ShiftJIS.encode(allocator, "Test123");
    defer allocator.free(encoded);
    const decoded = try JapaneseEncoding.ShiftJIS.decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Test123", decoded);
}

test "EUC-JP ASCII passthrough" {
    const allocator = std.testing.allocator;
    const result = try JapaneseEncoding.EUCJP.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "EUC-JP encode/decode roundtrip for ASCII" {
    const allocator = std.testing.allocator;
    const encoded = try JapaneseEncoding.EUCJP.encode(allocator, "Test123");
    defer allocator.free(encoded);
    const decoded = try JapaneseEncoding.EUCJP.decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Test123", decoded);
}

test "encoding names" {
    try std.testing.expectEqualStrings("Shift_JIS", JapaneseEncoding.ShiftJIS.name());
    try std.testing.expectEqualStrings("EUC-JP", JapaneseEncoding.EUCJP.name());
}

test "half-width katakana via Shift_JIS" {
    const allocator = std.testing.allocator;
    // Half-width katakana in UTF-8
    const utf8_kata = "\u{FF61}\u{FF62}\u{FF63}"; // ｡｢｣
    const encoded = try JapaneseEncoding.ShiftJIS.encode(allocator, utf8_kata);
    defer allocator.free(encoded);
    try std.testing.expectEqual(@as(usize, 3), encoded.len);
    try std.testing.expectEqual(@as(u8, 0xA1), encoded[0]);
    try std.testing.expectEqual(@as(u8, 0xA2), encoded[1]);
    try std.testing.expectEqual(@as(u8, 0xA3), encoded[2]);
}

test "half-width katakana via EUC-JP" {
    const allocator = std.testing.allocator;
    const utf8_kata = "\u{FF61}\u{FF62}\u{FF63}"; // ｡｢｣
    const encoded = try JapaneseEncoding.EUCJP.encode(allocator, utf8_kata);
    defer allocator.free(encoded);
    // EUC-JP uses 0x8E prefix for half-width katakana
    try std.testing.expectEqual(@as(usize, 6), encoded.len);
    try std.testing.expectEqual(@as(u8, 0x8E), encoded[0]);
    try std.testing.expectEqual(@as(u8, 0xA1), encoded[1]);
}
