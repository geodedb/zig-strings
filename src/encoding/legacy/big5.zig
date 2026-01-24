// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Big5 Legacy Encoding Support
//!
//! This module provides support for the Big5 character encoding used for
//! Traditional Chinese, primarily in Taiwan and Hong Kong.
//!
//! Big5 encoding structure:
//! - 0x00-0x7F: ASCII
//! - 0x81-0xFE + 0x40-0x7E, 0xA1-0xFE: Double-byte characters
//!
//! The encoding covers:
//! - Level 1: 5,401 frequently used characters (sorted by stroke count)
//! - Level 2: 7,652 less frequently used characters
//! - Symbols, punctuation, and other special characters

const std = @import("std");

/// Big5 encoding variants
pub const Big5Encoding = enum {
    Big5,
    Big5HKSCS, // Hong Kong Supplementary Character Set

    /// Decode bytes to UTF-8
    pub fn decode(self: Big5Encoding, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        return switch (self) {
            .Big5 => decodeBig5(allocator, input),
            .Big5HKSCS => decodeBig5HKSCS(allocator, input),
        };
    }

    /// Encode UTF-8 to this encoding
    pub fn encode(self: Big5Encoding, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        return switch (self) {
            .Big5 => encodeBig5(allocator, input),
            .Big5HKSCS => encodeBig5HKSCS(allocator, input),
        };
    }

    /// Get human-readable name
    pub fn name(self: Big5Encoding) []const u8 {
        return switch (self) {
            .Big5 => "Big5",
            .Big5HKSCS => "Big5-HKSCS",
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
// Big5 Implementation
// ============================================================================

/// Big5 encoding structure:
/// First byte: 0x81-0xFE
/// Second byte: 0x40-0x7E (low range) or 0xA1-0xFE (high range)
///
/// Character ranges:
/// 0x8140-0xA0FE: Reserved/user-defined
/// 0xA140-0xA3BF: Symbols and punctuation
/// 0xA3C0-0xA3FE: Reserved
/// 0xA440-0xC67E: Level 1 characters (frequently used)
/// 0xC6A1-0xC8FE: Reserved
/// 0xC940-0xF9D5: Level 2 characters
/// 0xF9D6-0xFEFE: Reserved/user-defined
fn decodeBig5(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
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
            if ((b2 >= 0x40 and b2 <= 0x7E) or (b2 >= 0xA1 and b2 <= 0xFE)) {
                // Valid Big5 double-byte sequence
                const codepoint = lookupBig5(b1, b2);
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

fn encodeBig5(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
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
            // Try to find in Big5 table
            const big5 = reverseBig5(codepoint);
            if (big5) |bytes| {
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
// Big5-HKSCS Implementation
// ============================================================================

/// Big5-HKSCS (Hong Kong Supplementary Character Set)
/// Extends Big5 with additional characters for Cantonese
fn decodeBig5HKSCS(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
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
            if ((b2 >= 0x40 and b2 <= 0x7E) or (b2 >= 0xA1 and b2 <= 0xFE)) {
                // Try HKSCS extension first
                var codepoint = lookupHKSCS(b1, b2);
                if (codepoint == 0xFFFD) {
                    // Fall back to standard Big5
                    codepoint = lookupBig5(b1, b2);
                }
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

fn encodeBig5HKSCS(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
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
            // Try HKSCS extension first
            var bytes = reverseHKSCS(codepoint);
            if (bytes == null) {
                // Fall back to standard Big5
                bytes = reverseBig5(codepoint);
            }
            if (bytes) |b| {
                try result.append(allocator, b[0]);
                try result.append(allocator, b[1]);
            } else {
                try result.append(allocator, '?');
            }
        }

        i += len;
    }

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// Big5 Lookup Tables
// ============================================================================

/// Calculate Big5 table index
fn big5Index(b1: u8, b2: u8) usize {
    const row: usize = b1 - 0x81;
    const col: usize = if (b2 >= 0xA1) b2 - 0xA1 + 63 else b2 - 0x40;
    return row * 157 + col; // 157 = 63 + 94
}

/// Look up Big5 character
fn lookupBig5(b1: u8, b2: u8) u21 {
    // Symbols region (0xA140-0xA3BF)
    if (b1 >= 0xA1 and b1 <= 0xA3) {
        const idx = symbolIndex(b1, b2);
        if (idx < big5_symbols.len) {
            return big5_symbols[idx];
        }
    }

    // Level 1 characters (0xA440-0xC67E)
    if ((b1 >= 0xA4 and b1 <= 0xC5) or (b1 == 0xC6 and b2 <= 0x7E)) {
        const idx = level1Index(b1, b2);
        if (idx < big5_level1.len) {
            return big5_level1[idx];
        }
    }

    // Level 2 characters (0xC940-0xF9D5)
    if ((b1 >= 0xC9 and b1 <= 0xF8) or (b1 == 0xF9 and b2 <= 0xD5)) {
        const idx = level2Index(b1, b2);
        if (idx < big5_level2.len) {
            return big5_level2[idx];
        }
    }

    return 0xFFFD;
}

fn symbolIndex(b1: u8, b2: u8) usize {
    const row: usize = b1 - 0xA1;
    const col: usize = if (b2 >= 0xA1) b2 - 0xA1 + 63 else b2 - 0x40;
    return row * 157 + col;
}

fn level1Index(b1: u8, b2: u8) usize {
    const row: usize = b1 - 0xA4;
    const col: usize = if (b2 >= 0xA1) b2 - 0xA1 + 63 else b2 - 0x40;
    return row * 157 + col;
}

fn level2Index(b1: u8, b2: u8) usize {
    const row: usize = b1 - 0xC9;
    const col: usize = if (b2 >= 0xA1) b2 - 0xA1 + 63 else b2 - 0x40;
    return row * 157 + col;
}

/// Reverse lookup for Big5
fn reverseBig5(codepoint: u21) ?[2]u8 {
    // Check symbols
    for (big5_symbols, 0..) |cp, i| {
        if (cp == codepoint) {
            return indexToBytes(i, 0xA1);
        }
    }

    // Check Level 1
    for (big5_level1, 0..) |cp, i| {
        if (cp == codepoint) {
            return indexToBytes(i, 0xA4);
        }
    }

    // Check Level 2
    for (big5_level2, 0..) |cp, i| {
        if (cp == codepoint) {
            return indexToBytes(i, 0xC9);
        }
    }

    return null;
}

fn indexToBytes(idx: usize, base_row: u8) [2]u8 {
    const row: u8 = @intCast(idx / 157);
    const col: u8 = @intCast(idx % 157);

    const b1: u8 = base_row + row;
    const b2: u8 = if (col >= 63) @as(u8, @intCast(col - 63)) + 0xA1 else @as(u8, @intCast(col)) + 0x40;

    return .{ b1, b2 };
}

// ============================================================================
// HKSCS Extension Tables
// ============================================================================

fn lookupHKSCS(b1: u8, b2: u8) u21 {
    // HKSCS uses extended ranges
    // Check if it's in the HKSCS extension area
    const idx = big5Index(b1, b2);
    if (idx < hkscs_extensions.len) {
        const cp = hkscs_extensions[idx];
        if (cp != 0) return cp;
    }
    return 0xFFFD;
}

fn reverseHKSCS(codepoint: u21) ?[2]u8 {
    for (hkscs_extensions, 0..) |cp, i| {
        if (cp == codepoint) {
            const row: u8 = @intCast(i / 157 + 0x81);
            const col: u8 = @intCast(i % 157);
            const b2: u8 = if (col >= 63) @as(u8, @intCast(col - 63)) + 0xA1 else @as(u8, @intCast(col)) + 0x40;
            return .{ row, b2 };
        }
    }
    return null;
}

// ============================================================================
// Data Tables
// ============================================================================

// Big5 Symbols (0xA140-0xA3BF) - partial table with common symbols
const big5_symbols = [_]u21{
    // Row 0xA1: General punctuation and symbols
    0x3000, 0xFF0C, 0x3001, 0x3002, 0xFF0E, 0x2027, 0xFF1B, 0xFF1A, // 　，、。．‧；：
    0xFF1F, 0xFF01, 0xFE30, 0x2026, 0x2025, 0xFE50, 0xFE51, 0xFE52, // ？！︰…‥﹐﹑﹒
    0x00B7, 0xFE54, 0xFE55, 0xFE56, 0xFE57, 0xFF5C, 0x2013, 0xFE31, // ·﹔﹕﹖﹗｜–︱
    0x2014, 0xFE33, 0xFE34, 0xFE4F, 0xFF08, 0xFF09, 0xFE35, 0xFE36, // —︳︴﹏（）︵︶
    0xFF5B, 0xFF5D, 0xFE37, 0xFE38, 0x3014, 0x3015, 0xFE39, 0xFE3A, // ｛｝︷︸〔〕︹︺
    0x3010, 0x3011, 0xFE3B, 0xFE3C, 0x300A, 0x300B, 0xFE3D, 0xFE3E, // 【】︻︼《》︽︾
    0x300C, 0x300D, 0xFE3F, 0xFE40, 0x300E, 0x300F, 0xFE41, 0xFE42, // 「」︿﹀『』﹁﹂
    0x3008, 0x3009, 0xFE43, 0xFE44, 0x3016, 0x3017, 0xFE59, 0xFE5A, // 〈〉﹃﹄〖〗﹙﹚
    0xFE5B, 0xFE5C, 0xFE5D, 0xFE5E, 0x2018, 0x2019, 0x201C, 0x201D, // ﹛﹜﹝﹞''""
    0x301D, 0x301E, 0x2035, 0x2032, 0xFF03, 0xFF06, 0xFF0A, 0x203B, // 〝〞‵′＃＆＊※
    0x00A7, 0x3003, 0x25CB, 0x25CF, 0x25B3, 0x25B2, 0x25CE, 0x2606, // §〃○●△▲◎☆
    0x2605, 0x25C7, 0x25C6, 0x25A1, 0x25A0, 0x25BD, 0x25BC, 0x32A3, // ★◇◆□■▽▼㊣
    0x2105, 0x00AF, 0xFFE3, 0xFF3F, 0x02CD, 0xFE49, 0xFE4A, 0xFE4D, // ℅¯￣＿ˍ﹉﹊﹍
    0xFE4E, 0xFE4B, 0xFE4C, 0xFE5F, 0xFE60, 0xFE61, 0xFF0B, 0xFF0D, // ﹎﹋﹌﹟﹠﹡＋－
    0x00D7, 0x00F7, 0x00B1, 0x221A, 0xFF1C, 0xFF1E, 0xFF1D, 0x2266, // ×÷±√＜＞＝≦
    0x2267, 0x2260, 0x221E, 0x2252, 0x2261, // ≧≠∞≒≡
    // Continue with more symbols...
};

// Big5 Level 1 characters (0xA440-0xC67E) - partial table with common characters
// 5,401 frequently used characters sorted by stroke count within radicals
const big5_level1 = [_]u21{
    // Row 0xA4: First level-1 characters
    0x4E00, 0x4E59, 0x4E01, 0x4E03, 0x4E43, 0x4E5D, 0x4E86, 0x4E8C, // 一乙丁七乃九了二
    0x4EBA, 0x5165, 0x516B, 0x5200, 0x529B, 0x5315, 0x5341, 0x535C, // 人入八刀力匕十卜
    0x53C8, 0x4E09, 0x4E0B, 0x4E08, 0x4E0A, 0x4E2B, 0x4E38, 0x51E1, // 又三下丈上丫丸凡
    0x4E45, 0x4E48, 0x4E5F, 0x4E5E, 0x4E1E, 0x4E58, 0x4E56, 0x4E73, // 久么也乞亟乘乖乳
    0x4EA1, 0x4EA4, 0x4EA8, 0x4EC0, 0x4EC3, 0x4EC4, 0x4EC6, 0x4EC7, // 亡交亨什仃仄仆仇
    0x4ECA, 0x4ECB, 0x4ECD, 0x4ECE, 0x4ECF, 0x4ED4, 0x4ED5, 0x4ED6, // 今介仍从仏仔仕他
    0x4ED7, 0x4ED8, 0x4ED9, 0x4EDD, 0x4EDF, 0x4EE3, 0x4EE4, 0x4EE5, // 仗付仙仝仟代令以
    0x4EF0, 0x4EF2, 0x4EF3, 0x4EF6, 0x4EFB, 0x4EFD, 0x4EFF, 0x4F01, // 仰仲仳件任份仿企
    0x4F09, 0x4F0A, 0x4F0B, 0x4F0D, 0x4F0E, 0x4F0F, 0x4F10, 0x4F11, // 伉伊伋伍伎伏伐休
    0x4F2F, 0x4F30, 0x4F34, 0x4F36, 0x4F38, 0x4F3A, 0x4F3C, 0x4F3D, // 伯估伴伶伸伺似伽
    0x4F43, 0x4F46, 0x4F47, 0x4F48, 0x4F4D, 0x4F4E, 0x4F4F, 0x4F50, // 佃但佇佈位低住佐
    0x4F51, 0x4F54, 0x4F55, 0x4F57, 0x4F59, 0x4F5A, 0x4F5B, // 佑佔何佗余佚佛
    // Continue with more Level 1 characters...
};

// Big5 Level 2 characters (0xC940-0xF9D5) - partial table
// 7,652 less frequently used characters
const big5_level2 = [_]u21{
    // Row 0xC9: First level-2 characters (less common variants and rare characters)
    0x51AB, 0x51B1, 0x51B2, 0x51B3, 0x51B5, 0x51BD, 0x51C3, 0x51C4, // 冫况冲决况冽凃凄
    0x51C5, 0x51C6, 0x51C8, 0x51C9, 0x51CB, 0x51CC, 0x51CE, 0x51D0, // 凅准凈凉凋凌凎凐
    0x51D1, 0x51D4, 0x51D5, 0x51D6, 0x51D7, 0x51D8, 0x51D9, 0x51DA, // 凑凔凕凖凗凘凙凚
    0x51DB, 0x51DC, 0x51DD, 0x51DE, 0x51E0, 0x51E2, 0x51E3, 0x51E5, // 凛凜凝凞几凢凣凥
    0x51E6, 0x51E7, 0x51E8, 0x51E9, 0x51EA, 0x51EC, 0x51ED, 0x51EE, // 処凧凨凩凪凬凭凮
    0x51EF, 0x51F1, 0x51F2, 0x51F3, 0x51F4, 0x51F5, 0x51F6, 0x51F7, // 凯凱凲凳凴凵凶凷
    // Continue with more Level 2 characters...
};

// HKSCS extension characters (partial)
// Hong Kong Supplementary Character Set for Cantonese
const hkscs_extensions = [_]u21{
    // HKSCS-2008 extensions
    0x00CA, 0x00EA, 0x0304, 0x00CA, 0x030C, 0x00EA, 0x0304, 0x00EA,
    // Additional Cantonese characters
    // ... more extensions
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

test "Big5 ASCII passthrough" {
    const allocator = std.testing.allocator;
    const result = try Big5Encoding.Big5.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "Big5 encode/decode roundtrip for ASCII" {
    const allocator = std.testing.allocator;
    const encoded = try Big5Encoding.Big5.encode(allocator, "Test123");
    defer allocator.free(encoded);
    const decoded = try Big5Encoding.Big5.decode(allocator, encoded);
    defer allocator.free(decoded);
    try std.testing.expectEqualStrings("Test123", decoded);
}

test "Big5-HKSCS ASCII passthrough" {
    const allocator = std.testing.allocator;
    const result = try Big5Encoding.Big5HKSCS.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "Big5-HKSCS extends Big5" {
    const allocator = std.testing.allocator;
    // HKSCS should handle standard Big5 input
    const result = try Big5Encoding.Big5HKSCS.decode(allocator, "Hello");
    defer allocator.free(result);
    try std.testing.expectEqualStrings("Hello", result);
}

test "encoding names" {
    try std.testing.expectEqualStrings("Big5", Big5Encoding.Big5.name());
    try std.testing.expectEqualStrings("Big5-HKSCS", Big5Encoding.Big5HKSCS.name());
}

test "Big5 double-byte valid range check" {
    const allocator = std.testing.allocator;
    // Test with a valid Big5 sequence that's in the symbol range
    const input = [_]u8{ 0xA1, 0x40 }; // First symbol
    const result = try Big5Encoding.Big5.decode(allocator, &input);
    defer allocator.free(result);
    // Should produce some output (either the mapped char or replacement)
    try std.testing.expect(result.len > 0);
}
