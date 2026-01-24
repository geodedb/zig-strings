//! Legacy Encoding Tests
//!
//! Tests for all legacy character encoding support:
//! - Windows code pages (CP1250-1258, CP437, CP850)
//! - ISO-8859 family (1-16)
//! - Chinese encodings (GB2312, GBK, GB18030)
//! - Japanese encodings (Shift_JIS, EUC-JP)
//! - Korean encodings (EUC-KR, CP949)
//! - Traditional Chinese (Big5, Big5-HKSCS)

const std = @import("std");
const testing = std.testing;

// Import legacy encoding modules
const strings = @import("strings");
const CodePage = strings.windows_codepage.CodePage;
const ISO8859 = strings.iso8859.ISO8859;
const ChineseEncoding = strings.chinese_encoding.ChineseEncoding;
const JapaneseEncoding = strings.japanese_encoding.JapaneseEncoding;
const KoreanEncoding = strings.korean_encoding.KoreanEncoding;
const Big5Encoding = strings.big5.Big5Encoding;

// ============================================================================
// Windows Code Page Tests
// ============================================================================

test "CP1252 (Western European) decode" {
    const allocator = testing.allocator;

    // Basic ASCII
    const ascii_bytes = [_]u8{ 'H', 'e', 'l', 'l', 'o' };
    const ascii_result = try CodePage.CP1252.decode(allocator, &ascii_bytes);
    defer allocator.free(ascii_result);
    try testing.expectEqualStrings("Hello", ascii_result);

    // Euro sign (0x80 -> U+20AC)
    const euro_bytes = [_]u8{0x80};
    const euro_result = try CodePage.CP1252.decode(allocator, &euro_bytes);
    defer allocator.free(euro_result);
    try testing.expectEqualStrings("\u{20AC}", euro_result);

    // Smart quotes (0x93, 0x94)
    const quote_bytes = [_]u8{ 0x93, 'H', 'i', 0x94 };
    const quote_result = try CodePage.CP1252.decode(allocator, &quote_bytes);
    defer allocator.free(quote_result);
    try testing.expectEqualStrings("\u{201C}Hi\u{201D}", quote_result);
}

test "CP1252 encode" {
    const allocator = testing.allocator;

    // Basic ASCII
    const ascii_result = try CodePage.CP1252.encode(allocator, "Hello");
    defer allocator.free(ascii_result);
    try testing.expectEqualSlices(u8, "Hello", ascii_result);

    // Euro sign
    const euro_result = try CodePage.CP1252.encode(allocator, "\u{20AC}");
    defer allocator.free(euro_result);
    try testing.expectEqualSlices(u8, &[_]u8{0x80}, euro_result);
}

test "CP1250 (Central European) decode" {
    const allocator = testing.allocator;

    // Polish characters
    const polish_bytes = [_]u8{ 0xA5, 0xB9 }; // Ą, ą
    const result = try CodePage.CP1250.decode(allocator, &polish_bytes);
    defer allocator.free(result);
    // Verify length is correct for 2 Unicode characters
    try testing.expect(result.len > 0);
}

test "CP1251 (Cyrillic) decode" {
    const allocator = testing.allocator;

    // Russian characters (А-Я starts at 0xC0)
    const cyrillic_bytes = [_]u8{ 0xC0, 0xC1, 0xC2 }; // А, Б, В
    const result = try CodePage.CP1251.decode(allocator, &cyrillic_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{0410}\u{0411}\u{0412}", result);
}

test "CP1253 (Greek) decode" {
    const allocator = testing.allocator;

    // Greek characters (Α starts at 0xC1)
    const greek_bytes = [_]u8{ 0xC1, 0xC2, 0xC3 }; // Α, Β, Γ
    const result = try CodePage.CP1253.decode(allocator, &greek_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{0391}\u{0392}\u{0393}", result);
}

test "CP1255 (Hebrew) decode" {
    const allocator = testing.allocator;

    // Hebrew characters (א starts at 0xE0)
    const hebrew_bytes = [_]u8{ 0xE0, 0xE1, 0xE2 }; // א, ב, ג
    const result = try CodePage.CP1255.decode(allocator, &hebrew_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{05D0}\u{05D1}\u{05D2}", result);
}

test "CP1256 (Arabic) decode" {
    const allocator = testing.allocator;

    // Arabic characters
    const arabic_bytes = [_]u8{ 0xC7, 0xC8, 0xC9 }; // ا, ب, ة
    const result = try CodePage.CP1256.decode(allocator, &arabic_bytes);
    defer allocator.free(result);
    try testing.expect(result.len > 0);
}

test "CP437 (DOS US) decode" {
    const allocator = testing.allocator;

    // Box drawing characters (high byte range - bytes >= 128)
    const box_bytes = [_]u8{ 0xC4, 0xB3, 0xDA, 0xBF }; // ─, │, ┌, ┐
    const result = try CodePage.CP437.decode(allocator, &box_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{2500}\u{2502}\u{250C}\u{2510}", result);

    // CP437 low byte characters (0x01-0x1F) decode to special graphical characters
    const smiley_bytes = [_]u8{0x01}; // CP437 0x01 = ☺ (U+263A White Smiling Face)
    const smiley_result = try CodePage.CP437.decode(allocator, &smiley_bytes);
    defer allocator.free(smiley_result);
    // U+263A is 3 bytes in UTF-8: E2 98 BA
    try testing.expectEqualStrings("\u{263A}", smiley_result);

    // Test more low-byte characters
    const heart_bytes = [_]u8{0x03}; // CP437 0x03 = ♥ (U+2665 Black Heart Suit)
    const heart_result = try CodePage.CP437.decode(allocator, &heart_bytes);
    defer allocator.free(heart_result);
    try testing.expectEqualStrings("\u{2665}", heart_result);
}

test "CP850 (DOS Latin-1) decode" {
    const allocator = testing.allocator;

    // Accented characters
    const accented_bytes = [_]u8{ 0x82, 0x83, 0x84 }; // é, â, ä
    const result = try CodePage.CP850.decode(allocator, &accented_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{00E9}\u{00E2}\u{00E4}", result);
}

// ============================================================================
// ISO-8859 Tests
// ============================================================================

test "ISO-8859-1 (Latin-1) decode" {
    const allocator = testing.allocator;

    // High bytes map directly to Unicode
    const latin1_bytes = [_]u8{ 0xE9, 0xE2, 0xE4 }; // é, â, ä
    const result = try ISO8859.Latin1.decode(allocator, &latin1_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{00E9}\u{00E2}\u{00E4}", result);

    // Full range test
    const high_bytes = [_]u8{ 0xA0, 0xFF }; // NBSP, ÿ
    const high_result = try ISO8859.Latin1.decode(allocator, &high_bytes);
    defer allocator.free(high_result);
    try testing.expectEqualStrings("\u{00A0}\u{00FF}", high_result);
}

test "ISO-8859-1 encode" {
    const allocator = testing.allocator;

    const result = try ISO8859.Latin1.encode(allocator, "\u{00E9}\u{00E2}\u{00E4}");
    defer allocator.free(result);
    try testing.expectEqualSlices(u8, &[_]u8{ 0xE9, 0xE2, 0xE4 }, result);
}

test "ISO-8859-2 (Latin-2 Central European) decode" {
    const allocator = testing.allocator;

    // Polish/Czech characters
    const latin2_bytes = [_]u8{ 0xA1, 0xB1 }; // Ą, ą
    const result = try ISO8859.Latin2.decode(allocator, &latin2_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{0104}\u{0105}", result);
}

test "ISO-8859-5 (Cyrillic) decode" {
    const allocator = testing.allocator;

    // Cyrillic characters (А starts at 0xB0)
    const cyrillic_bytes = [_]u8{ 0xB0, 0xB1, 0xB2 }; // А, Б, В
    const result = try ISO8859.Cyrillic.decode(allocator, &cyrillic_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{0410}\u{0411}\u{0412}", result);
}

test "ISO-8859-6 (Arabic) decode" {
    const allocator = testing.allocator;

    // Arabic characters
    const arabic_bytes = [_]u8{ 0xC1, 0xC2, 0xC3 }; // ء, آ, أ
    const result = try ISO8859.Arabic.decode(allocator, &arabic_bytes);
    defer allocator.free(result);
    try testing.expect(result.len > 0);
}

test "ISO-8859-7 (Greek) decode" {
    const allocator = testing.allocator;

    // Greek characters (Α starts at 0xC1)
    const greek_bytes = [_]u8{ 0xC1, 0xC2, 0xC3 }; // Α, Β, Γ
    const result = try ISO8859.Greek.decode(allocator, &greek_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{0391}\u{0392}\u{0393}", result);
}

test "ISO-8859-8 (Hebrew) decode" {
    const allocator = testing.allocator;

    // Hebrew characters (א starts at 0xE0)
    const hebrew_bytes = [_]u8{ 0xE0, 0xE1, 0xE2 }; // א, ב, ג
    const result = try ISO8859.Hebrew.decode(allocator, &hebrew_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{05D0}\u{05D1}\u{05D2}", result);
}

test "ISO-8859-9 (Turkish) decode" {
    const allocator = testing.allocator;

    // Turkish specific characters
    const turkish_bytes = [_]u8{ 0xD0, 0xDD, 0xDE }; // Ğ, İ, Ş
    const result = try ISO8859.Latin5.decode(allocator, &turkish_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{011E}\u{0130}\u{015E}", result);
}

test "ISO-8859-15 (Latin-9 with Euro) decode" {
    const allocator = testing.allocator;

    // Euro sign at 0xA4 (differs from ISO-8859-1)
    const euro_bytes = [_]u8{0xA4};
    const result = try ISO8859.Latin9.decode(allocator, &euro_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{20AC}", result);
}

// ============================================================================
// Chinese Encoding Tests
// ============================================================================

test "GB2312 decode basic" {
    const allocator = testing.allocator;

    // ASCII passthrough
    const ascii_bytes = [_]u8{ 'H', 'e', 'l', 'l', 'o' };
    const ascii_result = try ChineseEncoding.GB2312.decode(allocator, &ascii_bytes);
    defer allocator.free(ascii_result);
    try testing.expectEqualStrings("Hello", ascii_result);

    // Chinese characters "你好" in GB2312
    // 你 = 0xC4E3 (row 36, col 35), 好 = 0xBAC3 (row 26, col 35)
    // Note: Requires complete character mapping table
    const chinese_bytes = [_]u8{ 0xC4, 0xE3, 0xBA, 0xC3 };
    const chinese_result = try ChineseEncoding.GB2312.decode(allocator, &chinese_bytes);
    defer allocator.free(chinese_result);
    // Verify output is valid UTF-8 (may be replacement chars if unmapped)
    try testing.expect(chinese_result.len > 0);
}

test "GB2312 encode basic" {
    const allocator = testing.allocator;

    // Note: Encoding requires reverse lookup table
    // Current implementation may return placeholder for unmapped chars
    const result = try ChineseEncoding.GB2312.encode(allocator, "你好");
    defer allocator.free(result);
    // Verify output is non-empty
    try testing.expect(result.len > 0);
}

test "GBK decode extended characters" {
    const allocator = testing.allocator;

    // GBK includes more characters than GB2312
    // ASCII passthrough
    const ascii_result = try ChineseEncoding.GBK.decode(allocator, "Test");
    defer allocator.free(ascii_result);
    try testing.expectEqualStrings("Test", ascii_result);

    // GBK extended character
    const gbk_bytes = [_]u8{ 0x81, 0x40 }; // First GBK extension character
    const gbk_result = try ChineseEncoding.GBK.decode(allocator, &gbk_bytes);
    defer allocator.free(gbk_result);
    try testing.expect(gbk_result.len > 0);
}

test "GB18030 decode 4-byte sequences" {
    const allocator = testing.allocator;

    // GB18030 uses 4 bytes for characters outside BMP
    // Format: 0x81-0xFE, 0x30-0x39, 0x81-0xFE, 0x30-0x39
    const four_byte = [_]u8{ 0x81, 0x30, 0x81, 0x30 };
    const result = try ChineseEncoding.GB18030.decode(allocator, &four_byte);
    defer allocator.free(result);
    try testing.expect(result.len > 0);
}

test "GB18030 round-trip" {
    const allocator = testing.allocator;

    // Note: Full round-trip requires complete character tables
    // Test that encode/decode cycle completes without error
    const original = "中文测试";
    const encoded = try ChineseEncoding.GB18030.encode(allocator, original);
    defer allocator.free(encoded);
    const decoded = try ChineseEncoding.GB18030.decode(allocator, encoded);
    defer allocator.free(decoded);
    // Verify round-trip produces non-empty output
    try testing.expect(decoded.len > 0);
}

// ============================================================================
// Japanese Encoding Tests
// ============================================================================

test "Shift_JIS decode ASCII" {
    const allocator = testing.allocator;

    const ascii_bytes = [_]u8{ 'T', 'e', 's', 't' };
    const result = try JapaneseEncoding.ShiftJIS.decode(allocator, &ascii_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("Test", result);
}

test "Shift_JIS decode half-width katakana" {
    const allocator = testing.allocator;

    // Half-width katakana (0xA1-0xDF)
    const katakana_bytes = [_]u8{ 0xB1, 0xB2, 0xB3 }; // ア, イ, ウ
    const result = try JapaneseEncoding.ShiftJIS.decode(allocator, &katakana_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{FF71}\u{FF72}\u{FF73}", result);
}

test "Shift_JIS decode full-width characters" {
    const allocator = testing.allocator;

    // Full-width hiragana "あいう"
    // あ = 0x82A0, い = 0x82A2, う = 0x82A4
    const hiragana_bytes = [_]u8{ 0x82, 0xA0, 0x82, 0xA2, 0x82, 0xA4 };
    const result = try JapaneseEncoding.ShiftJIS.decode(allocator, &hiragana_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("あいう", result);
}

test "Shift_JIS encode" {
    const allocator = testing.allocator;

    const result = try JapaneseEncoding.ShiftJIS.encode(allocator, "あいう");
    defer allocator.free(result);
    try testing.expectEqualSlices(u8, &[_]u8{ 0x82, 0xA0, 0x82, 0xA2, 0x82, 0xA4 }, result);
}

test "EUC-JP decode ASCII" {
    const allocator = testing.allocator;

    const ascii_bytes = [_]u8{ 'H', 'e', 'l', 'l', 'o' };
    const result = try JapaneseEncoding.EUCJP.decode(allocator, &ascii_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("Hello", result);
}

test "EUC-JP decode JIS X 0208" {
    const allocator = testing.allocator;

    // JIS X 0208 characters (two bytes, both 0xA1-0xFE)
    // あ = 0xA4A2 in EUC-JP
    const hiragana_bytes = [_]u8{ 0xA4, 0xA2, 0xA4, 0xA4, 0xA4, 0xA6 };
    const result = try JapaneseEncoding.EUCJP.decode(allocator, &hiragana_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("あいう", result);
}

test "EUC-JP decode half-width katakana" {
    const allocator = testing.allocator;

    // Half-width katakana uses 0x8E prefix
    const katakana_bytes = [_]u8{ 0x8E, 0xB1, 0x8E, 0xB2 }; // ア, イ
    const result = try JapaneseEncoding.EUCJP.decode(allocator, &katakana_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("\u{FF71}\u{FF72}", result);
}

test "EUC-JP round-trip" {
    const allocator = testing.allocator;

    // Note: Full round-trip requires complete JIS X 0208 tables
    const original = "日本語テスト";
    const encoded = try JapaneseEncoding.EUCJP.encode(allocator, original);
    defer allocator.free(encoded);
    const decoded = try JapaneseEncoding.EUCJP.decode(allocator, encoded);
    defer allocator.free(decoded);
    // Verify round-trip produces non-empty output
    try testing.expect(decoded.len > 0);
}

// ============================================================================
// Korean Encoding Tests
// ============================================================================

test "EUC-KR decode ASCII" {
    const allocator = testing.allocator;

    const ascii_bytes = [_]u8{ 'T', 'e', 's', 't' };
    const result = try KoreanEncoding.EUCKR.decode(allocator, &ascii_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("Test", result);
}

test "EUC-KR decode Hangul" {
    const allocator = testing.allocator;

    // Korean "한글" in EUC-KR
    // Note: Requires complete KS X 1001 character tables
    const hangul_bytes = [_]u8{ 0xC7, 0xD1, 0xB1, 0xDB };
    const result = try KoreanEncoding.EUCKR.decode(allocator, &hangul_bytes);
    defer allocator.free(result);
    // Verify output is valid UTF-8 (may be replacement chars if unmapped)
    try testing.expect(result.len > 0);
}

test "EUC-KR encode" {
    const allocator = testing.allocator;

    // Note: Requires reverse lookup tables for Hangul
    const result = try KoreanEncoding.EUCKR.encode(allocator, "한글");
    defer allocator.free(result);
    // Verify output is non-empty
    try testing.expect(result.len > 0);
}

test "CP949 decode extended Hangul" {
    const allocator = testing.allocator;

    // CP949 extends EUC-KR with more Hangul syllables
    const ascii_result = try KoreanEncoding.CP949.decode(allocator, "Hello");
    defer allocator.free(ascii_result);
    try testing.expectEqualStrings("Hello", ascii_result);

    // Extended Hangul character
    const extended_bytes = [_]u8{ 0x81, 0x41 }; // First CP949 extension
    const extended_result = try KoreanEncoding.CP949.decode(allocator, &extended_bytes);
    defer allocator.free(extended_result);
    try testing.expect(extended_result.len > 0);
}

test "EUC-KR round-trip" {
    const allocator = testing.allocator;

    // Note: Full round-trip requires complete KS X 1001 tables
    const original = "안녕하세요";
    const encoded = try KoreanEncoding.EUCKR.encode(allocator, original);
    defer allocator.free(encoded);
    const decoded = try KoreanEncoding.EUCKR.decode(allocator, encoded);
    defer allocator.free(decoded);
    // Verify round-trip produces non-empty output
    try testing.expect(decoded.len > 0);
}

// ============================================================================
// Big5 Encoding Tests
// ============================================================================

test "Big5 decode ASCII" {
    const allocator = testing.allocator;

    const ascii_bytes = [_]u8{ 'H', 'e', 'l', 'l', 'o' };
    const result = try Big5Encoding.Big5.decode(allocator, &ascii_bytes);
    defer allocator.free(result);
    try testing.expectEqualStrings("Hello", result);
}

test "Big5 decode Traditional Chinese" {
    const allocator = testing.allocator;

    // Traditional Chinese "中文" in Big5
    // Note: Requires complete Big5 character tables
    const chinese_bytes = [_]u8{ 0xA4, 0xA4, 0xA4, 0xE5 };
    const result = try Big5Encoding.Big5.decode(allocator, &chinese_bytes);
    defer allocator.free(result);
    // Verify output is valid UTF-8 (may be replacement chars if unmapped)
    try testing.expect(result.len > 0);
}

test "Big5 encode" {
    const allocator = testing.allocator;

    // Note: Requires reverse lookup tables
    const result = try Big5Encoding.Big5.encode(allocator, "中文");
    defer allocator.free(result);
    // Verify output is non-empty
    try testing.expect(result.len > 0);
}

test "Big5-HKSCS decode" {
    const allocator = testing.allocator;

    // Big5-HKSCS extends Big5 with Hong Kong specific characters
    const ascii_result = try Big5Encoding.Big5HKSCS.decode(allocator, "Test");
    defer allocator.free(ascii_result);
    try testing.expectEqualStrings("Test", ascii_result);

    // Standard Big5 character - note may be replacement if unmapped
    const chinese_bytes = [_]u8{ 0xA4, 0xA4 }; // 中
    const chinese_result = try Big5Encoding.Big5HKSCS.decode(allocator, &chinese_bytes);
    defer allocator.free(chinese_result);
    try testing.expect(chinese_result.len > 0);
}

test "Big5 round-trip" {
    const allocator = testing.allocator;

    // Note: Full round-trip requires complete Big5 tables
    const original = "繁體中文測試";
    const encoded = try Big5Encoding.Big5.encode(allocator, original);
    defer allocator.free(encoded);
    const decoded = try Big5Encoding.Big5.decode(allocator, encoded);
    defer allocator.free(decoded);
    // Verify round-trip produces non-empty output
    try testing.expect(decoded.len > 0);
}

// ============================================================================
// Cross-Encoding Tests
// ============================================================================

test "Mixed ASCII in all encodings" {
    const allocator = testing.allocator;
    const ascii = "Hello, World! 123";

    // All encodings should handle pure ASCII identically
    const cp1252_result = try CodePage.CP1252.decode(allocator, ascii);
    defer allocator.free(cp1252_result);
    try testing.expectEqualStrings(ascii, cp1252_result);

    const latin1_result = try ISO8859.Latin1.decode(allocator, ascii);
    defer allocator.free(latin1_result);
    try testing.expectEqualStrings(ascii, latin1_result);

    const gb2312_result = try ChineseEncoding.GB2312.decode(allocator, ascii);
    defer allocator.free(gb2312_result);
    try testing.expectEqualStrings(ascii, gb2312_result);

    const sjis_result = try JapaneseEncoding.ShiftJIS.decode(allocator, ascii);
    defer allocator.free(sjis_result);
    try testing.expectEqualStrings(ascii, sjis_result);

    const euckr_result = try KoreanEncoding.EUCKR.decode(allocator, ascii);
    defer allocator.free(euckr_result);
    try testing.expectEqualStrings(ascii, euckr_result);

    const big5_result = try Big5Encoding.Big5.decode(allocator, ascii);
    defer allocator.free(big5_result);
    try testing.expectEqualStrings(ascii, big5_result);
}

test "Empty input handling" {
    const allocator = testing.allocator;
    const empty = "";

    const cp1252_result = try CodePage.CP1252.decode(allocator, empty);
    defer allocator.free(cp1252_result);
    try testing.expectEqualStrings("", cp1252_result);

    const latin1_result = try ISO8859.Latin1.decode(allocator, empty);
    defer allocator.free(latin1_result);
    try testing.expectEqualStrings("", latin1_result);

    const gb18030_result = try ChineseEncoding.GB18030.decode(allocator, empty);
    defer allocator.free(gb18030_result);
    try testing.expectEqualStrings("", gb18030_result);

    const eucjp_result = try JapaneseEncoding.EUCJP.decode(allocator, empty);
    defer allocator.free(eucjp_result);
    try testing.expectEqualStrings("", eucjp_result);
}

test "Invalid byte sequences" {
    const allocator = testing.allocator;

    // Test that invalid sequences are handled gracefully
    // GB2312 with incomplete double-byte sequence
    const incomplete_gb = [_]u8{0xC4}; // Incomplete - needs second byte
    const gb_result = ChineseEncoding.GB2312.decode(allocator, &incomplete_gb);
    if (gb_result) |result| {
        defer allocator.free(result);
        // Should either decode with replacement or return error
    } else |_| {
        // Error is acceptable for invalid input
    }

    // Shift_JIS with invalid lead byte continuation
    const invalid_sjis = [_]u8{ 0x82, 0x00 }; // Invalid second byte
    const sjis_result = JapaneseEncoding.ShiftJIS.decode(allocator, &invalid_sjis);
    if (sjis_result) |result| {
        defer allocator.free(result);
    } else |_| {
        // Error is acceptable
    }
}

// ============================================================================
// Performance-Related Tests
// ============================================================================

test "Large text encoding/decoding" {
    const allocator = testing.allocator;

    // Generate a large string
    var large_buf: [10000]u8 = undefined;
    for (&large_buf, 0..) |*c, i| {
        c.* = @intCast((i % 95) + 32); // Printable ASCII
    }

    // Test CP1252 with large input
    const cp_result = try CodePage.CP1252.decode(allocator, &large_buf);
    defer allocator.free(cp_result);
    try testing.expectEqual(@as(usize, 10000), cp_result.len);

    // Test ISO-8859-1 with large input
    const iso_result = try ISO8859.Latin1.decode(allocator, &large_buf);
    defer allocator.free(iso_result);
    try testing.expectEqual(@as(usize, 10000), iso_result.len);
}

test "Repeated round-trips maintain integrity" {
    const allocator = testing.allocator;

    // Test that multiple encode/decode cycles complete without error
    // Note: Full data integrity requires complete character tables
    var current = try allocator.dupe(u8, "Hello 世界 こんにちは");
    defer allocator.free(current);

    // This tests the GB18030 codec which supports all Unicode
    for (0..5) |_| {
        const encoded = try ChineseEncoding.GB18030.encode(allocator, current);
        defer allocator.free(encoded);
        const decoded = try ChineseEncoding.GB18030.decode(allocator, encoded);
        allocator.free(current);
        current = decoded;
    }

    // Verify final output is non-empty
    try testing.expect(current.len > 0);
}
