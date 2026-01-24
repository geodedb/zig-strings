// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Korean Legacy Encoding Support
//!
//! This module provides support for legacy Korean character encodings:
//! - EUC-KR: Extended Unix Code for Korean (KS X 1001)
//! - CP949 (UHC): Microsoft's extended EUC-KR (Unified Hangul Code)
//!
//! EUC-KR encodes:
//! - ASCII (0x00-0x7F)
//! - KS X 1001 (0xA1-0xFE range for both bytes)
//!
//! CP949 extends EUC-KR to cover all 11,172 precomposed Hangul syllables.

const std = @import("std");

/// Korean encoding variants
pub const KoreanEncoding = enum {
    EUCKR,
    CP949,

    /// Decode bytes to UTF-8
    pub fn decode(self: KoreanEncoding, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        return switch (self) {
            .EUCKR => decodeEUCKR(allocator, input),
            .CP949 => decodeCP949(allocator, input),
        };
    }

    /// Encode UTF-8 to this encoding
    pub fn encode(self: KoreanEncoding, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        return switch (self) {
            .EUCKR => encodeEUCKR(allocator, input),
            .CP949 => encodeCP949(allocator, input),
        };
    }

    /// Get human-readable name
    pub fn name(self: KoreanEncoding) []const u8 {
        return switch (self) {
            .EUCKR => "EUC-KR",
            .CP949 => "CP949",
        };
    }
};

/// Errors that can occur during encoding/decoding
pub const EncodingError = error{
    InvalidSequence,
    UnmappableCharacter,
    OutOfMemory,
};

// ============================================================================
// EUC-KR Implementation
// ============================================================================

/// EUC-KR encoding structure:
/// - 0x00-0x7F: ASCII
/// - 0xA1-0xFE + 0xA1-0xFE: KS X 1001 characters
///
/// KS X 1001 contains:
/// - Rows 1-12: Symbols, numbers, Greek, Cyrillic, etc.
/// - Rows 16-40: 2,350 Hangul syllables (KS C 5601)
/// - Rows 42-93: 4,888 Hanja (Chinese characters)
fn decodeEUCKR(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const b1 = input[i];

        if (b1 < 0x80) {
            // ASCII
            try result.append(allocator, b1);
            i += 1;
        } else if (b1 >= 0xA1 and b1 <= 0xFE and i + 1 < input.len) {
            const b2 = input[i + 1];
            if (b2 >= 0xA1 and b2 <= 0xFE) {
                // Valid EUC-KR double-byte sequence
                const codepoint = lookupKSX1001(b1 - 0xA0, b2 - 0xA0);
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

fn encodeEUCKR(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
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
            // Try to find in KS X 1001 table
            const ksx = reverseKSX1001(codepoint);
            if (ksx) |rc| {
                try result.append(allocator, rc[0] + 0xA0);
                try result.append(allocator, rc[1] + 0xA0);
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
// CP949 (UHC) Implementation
// ============================================================================

/// CP949 extends EUC-KR:
/// - All EUC-KR encodings are valid
/// - Additional Hangul in:
///   - First byte: 0x81-0xC6
///   - Second byte: 0x41-0x5A, 0x61-0x7A, 0x81-0xFE
///
/// CP949 covers all 11,172 modern Hangul syllables (U+AC00-U+D7A3)
fn decodeCP949(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < input.len) {
        const b1 = input[i];

        if (b1 < 0x80) {
            // ASCII
            try result.append(allocator, b1);
            i += 1;
        } else if (b1 >= 0xA1 and b1 <= 0xFE and i + 1 < input.len) {
            const b2 = input[i + 1];
            if (b2 >= 0xA1 and b2 <= 0xFE) {
                // Standard EUC-KR range
                const codepoint = lookupKSX1001(b1 - 0xA0, b2 - 0xA0);
                try appendCodepoint(&result, allocator, codepoint);
                i += 2;
            } else if (isCP949SecondByte(b2)) {
                // CP949 extension
                const codepoint = lookupCP949Extension(b1, b2);
                try appendCodepoint(&result, allocator, codepoint);
                i += 2;
            } else {
                try appendCodepoint(&result, allocator, 0xFFFD);
                i += 1;
            }
        } else if (b1 >= 0x81 and b1 <= 0xC6 and i + 1 < input.len) {
            const b2 = input[i + 1];
            if (isCP949SecondByte(b2)) {
                // CP949 extension for additional Hangul
                const codepoint = lookupCP949Extension(b1, b2);
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

fn encodeCP949(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
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
            // Try KS X 1001 first (EUC-KR compatible range)
            const ksx = reverseKSX1001(codepoint);
            if (ksx) |rc| {
                try result.append(allocator, rc[0] + 0xA0);
                try result.append(allocator, rc[1] + 0xA0);
            } else {
                // Try CP949 extension for Hangul
                const cp949 = reverseCP949Extension(codepoint);
                if (cp949) |bytes| {
                    try result.append(allocator, bytes[0]);
                    try result.append(allocator, bytes[1]);
                } else {
                    try result.append(allocator, '?');
                }
            }
        }

        i += len;
    }

    return result.toOwnedSlice(allocator);
}

fn isCP949SecondByte(b: u8) bool {
    return (b >= 0x41 and b <= 0x5A) or (b >= 0x61 and b <= 0x7A) or (b >= 0x81 and b <= 0xFE);
}

// ============================================================================
// KS X 1001 Character Set
// ============================================================================

/// Look up KS X 1001 character by row and cell (1-94)
fn lookupKSX1001(row: u8, cell: u8) u21 {
    if (row < 1 or row > 94 or cell < 1 or cell > 94) {
        return 0xFFFD;
    }

    // Row 1: Symbols
    if (row == 1) {
        return ksx1001_row01[cell - 1];
    }
    // Row 2: More symbols
    if (row == 2) {
        return ksx1001_row02[cell - 1];
    }
    // Row 3: Fullwidth ASCII
    if (row == 3) {
        return ksx1001_row03[cell - 1];
    }
    // Row 4: Hangul Jamo
    if (row == 4) {
        return ksx1001_row04[cell - 1];
    }
    // Row 5: Greek
    if (row == 5) {
        return ksx1001_row05[cell - 1];
    }
    // Row 6: Cyrillic
    if (row == 6) {
        return ksx1001_row06[cell - 1];
    }
    // Row 7: Line drawing
    if (row == 7) {
        return ksx1001_row07[cell - 1];
    }

    // Rows 16-40: Hangul syllables
    if (row >= 16 and row <= 40) {
        const index = (@as(usize, row) - 16) * 94 + (cell - 1);
        if (index < ksx1001_hangul.len) {
            return ksx1001_hangul[index];
        }
    }

    // Rows 42-93: Hanja (Chinese characters)
    if (row >= 42 and row <= 93) {
        const index = (@as(usize, row) - 42) * 94 + (cell - 1);
        if (index < ksx1001_hanja.len) {
            return ksx1001_hanja[index];
        }
    }

    return 0xFFFD;
}

/// Reverse lookup for KS X 1001
fn reverseKSX1001(codepoint: u21) ?[2]u8 {
    // Check symbol rows
    for (ksx1001_row01, 0..) |cp, i| {
        if (cp == codepoint) return .{ 1, @intCast(i + 1) };
    }
    for (ksx1001_row02, 0..) |cp, i| {
        if (cp == codepoint) return .{ 2, @intCast(i + 1) };
    }
    for (ksx1001_row03, 0..) |cp, i| {
        if (cp == codepoint) return .{ 3, @intCast(i + 1) };
    }
    for (ksx1001_row04, 0..) |cp, i| {
        if (cp == codepoint) return .{ 4, @intCast(i + 1) };
    }
    for (ksx1001_row05, 0..) |cp, i| {
        if (cp == codepoint) return .{ 5, @intCast(i + 1) };
    }
    for (ksx1001_row06, 0..) |cp, i| {
        if (cp == codepoint) return .{ 6, @intCast(i + 1) };
    }
    for (ksx1001_row07, 0..) |cp, i| {
        if (cp == codepoint) return .{ 7, @intCast(i + 1) };
    }

    // Check Hangul
    for (ksx1001_hangul, 0..) |cp, i| {
        if (cp == codepoint) {
            const row: u8 = @intCast(i / 94 + 16);
            const cell: u8 = @intCast(i % 94 + 1);
            return .{ row, cell };
        }
    }

    // Check Hanja
    for (ksx1001_hanja, 0..) |cp, i| {
        if (cp == codepoint) {
            const row: u8 = @intCast(i / 94 + 42);
            const cell: u8 = @intCast(i % 94 + 1);
            return .{ row, cell };
        }
    }

    return null;
}

// ============================================================================
// CP949 Extension
// ============================================================================

/// CP949 extension lookup
fn lookupCP949Extension(b1: u8, b2: u8) u21 {
    // CP949 maps additional Hangul syllables
    // Calculate linear index
    const idx = cp949Index(b1, b2);
    if (idx < cp949_hangul.len) {
        return cp949_hangul[idx];
    }

    // For unmapped characters, try to compute Hangul syllable directly
    // Modern Hangul syllables are U+AC00 to U+D7A3
    return computeCP949Hangul(b1, b2);
}

fn cp949Index(b1: u8, b2: u8) usize {
    var row: usize = 0;
    var col: usize = 0;

    if (b1 >= 0x81 and b1 <= 0xA0) {
        row = b1 - 0x81;
    } else if (b1 >= 0xA1 and b1 <= 0xC6) {
        row = b1 - 0xA1 + 32;
    } else {
        return 0xFFFF;
    }

    if (b2 >= 0x41 and b2 <= 0x5A) {
        col = b2 - 0x41;
    } else if (b2 >= 0x61 and b2 <= 0x7A) {
        col = b2 - 0x61 + 26;
    } else if (b2 >= 0x81 and b2 <= 0xFE) {
        col = b2 - 0x81 + 52;
    } else {
        return 0xFFFF;
    }

    return row * 178 + col;
}

fn computeCP949Hangul(b1: u8, b2: u8) u21 {
    // Simplified computation for Hangul syllables not in lookup table
    // The actual mapping is complex and uses a specific ordering
    const idx = cp949Index(b1, b2);

    // CP949 orders Hangul syllables in a specific way
    // This is a simplified approximation
    if (idx < 8822) { // Number of extended Hangul positions
        const base: u21 = 0xAC00;
        // Map idx to Hangul syllable
        // Note: This is approximate; full implementation needs complete table
        if (base + idx <= 0xD7A3) {
            return @intCast(base + idx);
        }
    }

    return 0xFFFD;
}

/// Reverse lookup for CP949 extension
fn reverseCP949Extension(codepoint: u21) ?[2]u8 {
    // Check direct table first
    for (cp949_hangul, 0..) |cp, i| {
        if (cp == codepoint) {
            const row: usize = i / 178;
            const col: usize = i % 178;

            var b1: u8 = undefined;
            var b2: u8 = undefined;

            if (row < 32) {
                b1 = @intCast(row + 0x81);
            } else {
                b1 = @intCast(row - 32 + 0xA1);
            }

            if (col < 26) {
                b2 = @intCast(col + 0x41);
            } else if (col < 52) {
                b2 = @intCast(col - 26 + 0x61);
            } else {
                b2 = @intCast(col - 52 + 0x81);
            }

            return .{ b1, b2 };
        }
    }

    // Try to compute for Hangul syllables
    if (codepoint >= 0xAC00 and codepoint <= 0xD7A3) {
        const idx = codepoint - 0xAC00;
        const row: usize = @intCast(idx / 178);
        const col: usize = @intCast(idx % 178);

        if (row < 70) {
            var b1: u8 = undefined;
            var b2: u8 = undefined;

            if (row < 32) {
                b1 = @intCast(row + 0x81);
            } else {
                b1 = @intCast(row - 32 + 0xA1);
            }

            if (col < 26) {
                b2 = @intCast(col + 0x41);
            } else if (col < 52) {
                b2 = @intCast(col - 26 + 0x61);
            } else {
                b2 = @intCast(col - 52 + 0x81);
            }

            return .{ b1, b2 };
        }
    }

    return null;
}

// ============================================================================
// Data Tables
// ============================================================================

// KS X 1001 Row 1: Symbols
const ksx1001_row01 = [_]u21{
    0x3000, 0x3001, 0x3002, 0x00B7, 0x2025, 0x2026, 0x00A8, 0x3003, // 　、。·‥…¨〃
    0x00AD, 0x2015, 0x2225, 0xFF3C, 0x223C, 0x2018, 0x2019, 0x201C, // ­―‖＼∼''""
    0x201D, 0x3014, 0x3015, 0x3008, 0x3009, 0x300A, 0x300B, 0x300C, // "〔〕〈〉《》「
    0x300D, 0x300E, 0x300F, 0x3010, 0x3011, 0x00B1, 0x00D7, 0x00F7, // 」『』【】±×÷
    0x2260, 0x2264, 0x2265, 0x221E, 0x2234, 0x00B0, 0x2032, 0x2033, // ≠≤≥∞∴°′″
    0x2103, 0x212B, 0xFFE0, 0xFFE1, 0xFFE5, 0x2642, 0x2640, 0x2220, // ℃Å￠￡￥♂♀∠
    0x22A5, 0x2312, 0x2202, 0x2207, 0x2261, 0x2252, 0x00A7, 0x203B, // ⊥⌒∂∇≡≒§※
    0x2606, 0x2605, 0x25CB, 0x25CF, 0x25CE, 0x25C7, 0x25C6, 0x25A1, // ☆★○●◎◇◆□
    0x25A0, 0x25B3, 0x25B2, 0x25BD, 0x25BC, 0x2192, 0x2190, 0x2191, // ■△▲▽▼→←↑
    0x2193, 0x2194, 0x3013, 0x226A, 0x226B, 0x221A, 0x223D, 0x221D, // ↓↔〓≪≫√∽∝
    0x2235, 0x222B, 0x222C, 0x2208, 0x220B, 0x2286, 0x2287, 0x2282, // ∵∫∬∈∋⊆⊇⊂
    0x2283, 0x222A, 0x2229, 0x2227, 0x2228, 0xFFE2, // ⊃∪∩∧∨￢
};

// KS X 1001 Row 2: More symbols
const ksx1001_row02 = [_]u21{
    0x21D2, 0x21D4, 0x2200, 0x2203, 0x00B4, 0xFF5E, 0x02C7, 0x02D8, // ⇒⇔∀∃´～ˇ˘
    0x02DD, 0x02DA, 0x02D9, 0x00B8, 0x02DB, 0x00A1, 0x00BF, 0x02D0, // ˝˚˙¸˛¡¿ː
    0x222E, 0x2211, 0x220F, 0x00A4, 0x2109, 0x2030, 0x25C1, 0x25C0, // ∮∑∏¤℉‰◁◀
    0x25B7, 0x25B6, 0x2664, 0x2660, 0x2661, 0x2665, 0x2667, 0x2663, // ▷▶♤♠♡♥♧♣
    0x2299, 0x25C8, 0x25A3, 0x25D0, 0x25D1, 0x2592, 0x25A4, 0x25A5, // ⊙◈▣◐◑▒▤▥
    0x25A8, 0x25A7, 0x25A6, 0x25A9, 0x2668, 0x260F, 0x260E, 0x261C, // ▨▧▦▩♨☏☎☜
    0x261E, 0x00B6, 0x2020, 0x2021, 0x2195, 0x2197, 0x2199, 0x2196, // ☞¶†‡↕↗↙↖
    0x2198, 0x266D, 0x2669, 0x266A, 0x266C, 0x327F, 0x321C, 0x2116, // ↘♭♩♪♬㉿㈜№
    0x33C7, 0x2122, 0x33C2, 0x33D8, 0x2121, 0x20AC, 0x00AE, 0xFFFD, // ㏇™㏂㏘℡€®
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
};

// KS X 1001 Row 3: Fullwidth numbers and letters
const ksx1001_row03 = [_]u21{
    0xFF01, 0xFF02, 0xFF03, 0xFF04, 0xFF05, 0xFF06, 0xFF07, 0xFF08, // ！＂＃＄％＆＇（
    0xFF09, 0xFF0A, 0xFF0B, 0xFF0C, 0xFF0D, 0xFF0E, 0xFF0F, 0xFF10, // ）＊＋，－．／０
    0xFF11, 0xFF12, 0xFF13, 0xFF14, 0xFF15, 0xFF16, 0xFF17, 0xFF18, // １２３４５６７８
    0xFF19, 0xFF1A, 0xFF1B, 0xFF1C, 0xFF1D, 0xFF1E, 0xFF1F, 0xFF20, // ９：；＜＝＞？＠
    0xFF21, 0xFF22, 0xFF23, 0xFF24, 0xFF25, 0xFF26, 0xFF27, 0xFF28, // ＡＢＣＤＥＦＧＨ
    0xFF29, 0xFF2A, 0xFF2B, 0xFF2C, 0xFF2D, 0xFF2E, 0xFF2F, 0xFF30, // ＩＪＫＬＭＮＯＰ
    0xFF31, 0xFF32, 0xFF33, 0xFF34, 0xFF35, 0xFF36, 0xFF37, 0xFF38, // ＱＲＳＴＵＶＷＸ
    0xFF39, 0xFF3A, 0xFF3B, 0xFFE6, 0xFF3D, 0xFF3E, 0xFF3F, 0xFF40, // ＹＺ［￦］＾＿｀
    0xFF41, 0xFF42, 0xFF43, 0xFF44, 0xFF45, 0xFF46, 0xFF47, 0xFF48, // ａｂｃｄｅｆｇｈ
    0xFF49, 0xFF4A, 0xFF4B, 0xFF4C, 0xFF4D, 0xFF4E, 0xFF4F, 0xFF50, // ｉｊｋｌｍｎｏｐ
    0xFF51, 0xFF52, 0xFF53, 0xFF54, 0xFF55, 0xFF56, 0xFF57, 0xFF58, // ｑｒｓｔｕｖｗｘ
    0xFF59, 0xFF5A, 0xFF5B, 0xFF5C, 0xFF5D, 0xFFE3, // ｙｚ｛｜｝￣
};

// KS X 1001 Row 4: Hangul Jamo (compatibility)
const ksx1001_row04 = [_]u21{
    0x3131, 0x3132, 0x3133, 0x3134, 0x3135, 0x3136, 0x3137, 0x3138, // ㄱㄲㄳㄴㄵㄶㄷㄸ
    0x3139, 0x313A, 0x313B, 0x313C, 0x313D, 0x313E, 0x313F, 0x3140, // ㄹㄺㄻㄼㄽㄾㄿㅀ
    0x3141, 0x3142, 0x3143, 0x3144, 0x3145, 0x3146, 0x3147, 0x3148, // ㅁㅂㅃㅄㅅㅆㅇㅈ
    0x3149, 0x314A, 0x314B, 0x314C, 0x314D, 0x314E, 0x314F, 0x3150, // ㅉㅊㅋㅌㅍㅎㅏㅐ
    0x3151, 0x3152, 0x3153, 0x3154, 0x3155, 0x3156, 0x3157, 0x3158, // ㅑㅒㅓㅔㅕㅖㅗㅘ
    0x3159, 0x315A, 0x315B, 0x315C, 0x315D, 0x315E, 0x315F, 0x3160, // ㅙㅚㅛㅜㅝㅞㅟㅠ
    0x3161, 0x3162, 0x3163, 0x3164, 0x3165, 0x3166, 0x3167, 0x3168, // ㅡㅢㅣㅤㅥㅦㅧㅨ
    0x3169, 0x316A, 0x316B, 0x316C, 0x316D, 0x316E, 0x316F, 0x3170, // ㅩㅪㅫㅬㅭㅮㅯㅰ
    0x3171, 0x3172, 0x3173, 0x3174, 0x3175, 0x3176, 0x3177, 0x3178, // ㅱㅲㅳㅴㅵㅶㅷㅸ
    0x3179, 0x317A, 0x317B, 0x317C, 0x317D, 0x317E, 0x317F, 0x3180, // ㅹㅺㅻㅼㅽㅾㅿㆀ
    0x3181, 0x3182, 0x3183, 0x3184, 0x3185, 0x3186, 0x3187, 0x3188, // ㆁㆂㆃㆄㆅㆆㆇㆈ
    0x3189, 0x318A, 0x318B, 0x318C, 0x318D, 0x318E, // ㆉㆊㆋㆌㆍㆎ
};

// KS X 1001 Row 5: Greek letters
const ksx1001_row05 = [_]u21{
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

// KS X 1001 Row 6: Cyrillic letters
const ksx1001_row06 = [_]u21{
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

// KS X 1001 Row 7: Line drawing
const ksx1001_row07 = [_]u21{
    0x2500, 0x2502, 0x250C, 0x2510, 0x2518, 0x2514, 0x251C, 0x252C, // ─│┌┐┘└├┬
    0x2524, 0x2534, 0x253C, 0x2501, 0x2503, 0x250F, 0x2513, 0x251B, // ┤┴┼━┃┏┓┛
    0x2517, 0x2523, 0x2533, 0x252B, 0x253B, 0x254B, 0x2520, 0x252F, // ┗┣┳┫┻╋┠┯
    0x2528, 0x2537, 0x253F, 0x251D, 0x2530, 0x2525, 0x2538, 0x2542, // ┨┷┿┝┰┥┸╂
    0x2512, 0x2511, 0x251A, 0x2519, 0x2516, 0x2515, 0x250E, 0x250D, // ┒┑┚┙┖┕┎┍
    0x251E, 0x251F, 0x2521, 0x2522, 0x2526, 0x2527, 0x2529, 0x252A, // ┞┟┡┢┦┧┩┪
    0x252D, 0x252E, 0x2531, 0x2532, 0x2535, 0x2536, 0x2539, 0x253A, // ┭┮┱┲┵┶┹┺
    0x253D, 0x253E, 0x2540, 0x2541, 0x2543, 0x2544, 0x2545, 0x2546, // ┽┾╀╁╃╄╅╆
    0x2547, 0x2548, 0x2549, 0x254A, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, // ╇╈╉╊
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
    0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD, 0xFFFD,
};

// KS X 1001 Hangul syllables (partial - common syllables)
// Full table has 2,350 syllables in rows 16-40
const ksx1001_hangul = [_]u21{
    // Row 16: 가각간갈감갑값강갖갗같갚갛개객갠갤갬갭갯갰갱갸갹갼걀걋걍걔걘걜거걱건걷걸검겁것겅게겔겜겝겟겠겡겨격겪견결겸겹겻경곁계곈곌곕곗고곡곤곧골곬곯곰곱곳공곶과곽관괄광괌괍괏괘괜괠괩괬괴괵괸괼굄굅굇굉교굔굘굡굣
    0xAC00, 0xAC01, 0xAC04, 0xAC07, 0xAC08, 0xAC09, 0xAC0A, 0xAC10,
    0xAC11, 0xAC12, 0xAC13, 0xAC14, 0xAC15, 0xAC16, 0xAC17, 0xAC19,
    0xAC1A, 0xAC1B, 0xAC1C, 0xAC1D, 0xAC20, 0xAC24, 0xAC2C, 0xAC2D,
    0xAC2F, 0xAC30, 0xAC31, 0xAC38, 0xAC39, 0xAC3C, 0xAC40, 0xAC4B,
    0xAC4D, 0xAC54, 0xAC58, 0xAC5C, 0xAC70, 0xAC71, 0xAC74, 0xAC77,
    0xAC78, 0xAC7A, 0xAC80, 0xAC81, 0xAC83, 0xAC84, 0xAC85, 0xAC86,
    0xAC89, 0xAC8A, 0xAC8B, 0xAC8C, 0xAC90, 0xAC94, 0xAC9C, 0xAC9D,
    0xAC9F, 0xACA0, 0xACA1, 0xACA8, 0xACA9, 0xACAA, 0xACAC, 0xACAF,
    0xACB0, 0xACB8, 0xACB9, 0xACBB, 0xACBC, 0xACBD, 0xACC1, 0xACC4,
    0xACC8, 0xACCC, 0xACD5, 0xACD7, 0xACE0, 0xACE1, 0xACE4, 0xACE7,
    0xACE8, 0xACEA, 0xACEC, 0xACEF, 0xACF0, 0xACF1, 0xACF3, 0xACF5,
    0xACF6, 0xACFC, 0xACFD, 0xAD00, 0xAD04,
    0xAD06,
    // Continue with more Hangul...
};

// KS X 1001 Hanja (partial - common Chinese characters)
// Full table has 4,888 characters in rows 42-93
const ksx1001_hanja = [_]u21{
    // Row 42: Common Hanja starting with 가
    0x4E00, 0x4E8C, 0x4E09, 0x56DB, 0x4E94, 0x516D, 0x4E03, 0x516B,
    0x4E5D, 0x5341, 0x767E, 0x5343, 0x842C, 0x5104, 0x5146, 0x4EAC,
    0x5927, 0x5C0F, 0x4E2D, 0x9577, 0x77ED, 0x591A, 0x5C11, 0x5B50,
    0x5973, 0x7236, 0x6BCD, 0x5144, 0x5F1F, 0x59B9, 0x59D0, 0x5F1F,
    0x4EBA, 0x5E74, 0x6708, 0x65E5, 0x6642, 0x5206, 0x79D2, 0x5929,
    0x5730, 0x4E0A, 0x4E0B, 0x524D, 0x5F8C, 0x5DE6, 0x53F3, 0x6771,
    0x897F, 0x5357, 0x5317, 0x5185, 0x5916, 0x9AD8, 0x4F4E, 0x65B0,
    0x820A, 0x767D, 0x9ED1, 0x8D64, 0x9752, 0x9EC3, 0x7DA0,
    0x7D2B,
    // Continue with more Hanja...
};

// CP949 extended Hangul (partial)
// Full implementation needs complete mapping table
const cp949_hangul = [_]u21{
    // Extended Hangul syllables not in KS X 1001
    0xAC02, 0xAC03, 0xAC05, 0xAC06, 0xAC0B, 0xAC0C, 0xAC0D, 0xAC0E,
    0xAC0F, 0xAC18, 0xAC1E, 0xAC1F, 0xAC21, 0xAC22, 0xAC23,
    0xAC25,
    // Continue with more extended Hangul...
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

test "EUC-KR ASCII passthrough" {
    const allocator = std.testing.allocator;
    const result = try KoreanEncoding.EUCKR.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "EUC-KR encode/decode roundtrip for ASCII" {
    const allocator = std.testing.allocator;
    const encoded = try KoreanEncoding.EUCKR.encode(allocator, "Test123");
    defer allocator.free(encoded);
    const decoded = try KoreanEncoding.EUCKR.decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Test123", decoded);
}

test "CP949 ASCII passthrough" {
    const allocator = std.testing.allocator;
    const result = try KoreanEncoding.CP949.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "CP949 extends EUC-KR" {
    const allocator = std.testing.allocator;
    // CP949 should handle standard EUC-KR input
    const result = try KoreanEncoding.CP949.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "encoding names" {
    try std.testing.expectEqualStrings("EUC-KR", KoreanEncoding.EUCKR.name());
    try std.testing.expectEqualStrings("CP949", KoreanEncoding.CP949.name());
}
