//! Test vectors for string operations.
//!
//! This file contains test vectors derived from Unicode standards
//! and other specifications to verify correct implementation.

const std = @import("std");
const strings = @import("strings");

// ============================================================
// UTF-8 Test Vectors (RFC 3629)
// ============================================================

test "UTF-8: Valid sequences" {
    const testing = std.testing;

    // Single byte (ASCII)
    try testing.expect(strings.isValidUtf8("\x00"));
    try testing.expect(strings.isValidUtf8("\x7F"));
    try testing.expect(strings.isValidUtf8("Hello"));

    // Two bytes
    try testing.expect(strings.isValidUtf8("\xC2\x80")); // U+0080
    try testing.expect(strings.isValidUtf8("\xDF\xBF")); // U+07FF
    try testing.expect(strings.isValidUtf8("\xC3\xA9")); // U+00E9 (é)

    // Three bytes
    try testing.expect(strings.isValidUtf8("\xE0\xA0\x80")); // U+0800
    try testing.expect(strings.isValidUtf8("\xEF\xBF\xBD")); // U+FFFD (replacement)
    try testing.expect(strings.isValidUtf8("\xE4\xB8\xAD")); // U+4E2D (中)

    // Four bytes
    try testing.expect(strings.isValidUtf8("\xF0\x90\x80\x80")); // U+10000
    try testing.expect(strings.isValidUtf8("\xF4\x8F\xBF\xBF")); // U+10FFFF
    try testing.expect(strings.isValidUtf8("\xF0\x9F\x98\x80")); // U+1F600 (emoji)
}

test "UTF-8: Invalid sequences" {
    const testing = std.testing;

    // Invalid start bytes
    try testing.expect(!strings.isValidUtf8("\x80")); // Continuation byte
    try testing.expect(!strings.isValidUtf8("\xC0")); // Overlong prefix
    try testing.expect(!strings.isValidUtf8("\xC1")); // Overlong prefix
    try testing.expect(!strings.isValidUtf8("\xF5")); // Beyond U+10FFFF
    try testing.expect(!strings.isValidUtf8("\xFF")); // Invalid

    // Truncated sequences
    try testing.expect(!strings.isValidUtf8("\xC2")); // Missing continuation
    try testing.expect(!strings.isValidUtf8("\xE0\xA0")); // Missing continuation
    try testing.expect(!strings.isValidUtf8("\xF0\x90\x80")); // Missing continuation

    // Invalid continuation bytes
    try testing.expect(!strings.isValidUtf8("\xC2\x00")); // Not continuation
    try testing.expect(!strings.isValidUtf8("\xC2\xFF")); // Not continuation

    // Overlong encodings
    try testing.expect(!strings.isValidUtf8("\xC0\x80")); // Overlong U+0000
    try testing.expect(!strings.isValidUtf8("\xE0\x80\x80")); // Overlong U+0000

    // Surrogates (invalid in UTF-8)
    try testing.expect(!strings.isValidUtf8("\xED\xA0\x80")); // U+D800
    try testing.expect(!strings.isValidUtf8("\xED\xBF\xBF")); // U+DFFF
}

test "UTF-8: Boundary conditions" {
    const testing = std.testing;

    // One byte boundaries
    try testing.expectEqual(@as(?usize, 1), strings.countCodepoints("\x00")); // U+0000
    try testing.expectEqual(@as(?usize, 1), strings.countCodepoints("\x7F")); // U+007F

    // Two byte boundaries
    try testing.expectEqual(@as(?usize, 1), strings.countCodepoints("\xC2\x80")); // U+0080
    try testing.expectEqual(@as(?usize, 1), strings.countCodepoints("\xDF\xBF")); // U+07FF

    // Three byte boundaries
    try testing.expectEqual(@as(?usize, 1), strings.countCodepoints("\xE0\xA0\x80")); // U+0800
    try testing.expectEqual(@as(?usize, 1), strings.countCodepoints("\xEF\xBF\xBF")); // U+FFFF

    // Four byte boundaries
    try testing.expectEqual(@as(?usize, 1), strings.countCodepoints("\xF0\x90\x80\x80")); // U+10000
    try testing.expectEqual(@as(?usize, 1), strings.countCodepoints("\xF4\x8F\xBF\xBF")); // U+10FFFF
}

// ============================================================
// UTF-16 Test Vectors (RFC 2781)
// ============================================================

test "UTF-16: BMP characters" {
    const testing = std.testing;

    // ASCII
    const ascii = try strings.String16.fromUtf8(testing.allocator, "A");
    defer @constCast(&ascii).deinit();
    try testing.expectEqual(@as(usize, 1), ascii.len());

    // CJK
    const cjk = try strings.String16.fromUtf8(testing.allocator, "\xE4\xB8\xAD");
    defer @constCast(&cjk).deinit();
    try testing.expectEqual(@as(usize, 1), cjk.len());
    try testing.expectEqual(@as(u16, 0x4E2D), cjk.units()[0]);
}

test "UTF-16: Surrogate pairs" {
    const testing = std.testing;

    // Emoji U+1F600
    const emoji = try strings.String16.fromUtf8(testing.allocator, "\xF0\x9F\x98\x80");
    defer @constCast(&emoji).deinit();
    try testing.expectEqual(@as(usize, 2), emoji.len());
    try testing.expectEqual(@as(u16, 0xD83D), emoji.units()[0]); // High surrogate
    try testing.expectEqual(@as(u16, 0xDE00), emoji.units()[1]); // Low surrogate
}

// ============================================================
// Grapheme Cluster Test Vectors (UAX #29)
// ============================================================

test "Grapheme clusters: Basic" {
    const testing = std.testing;

    // Single characters
    try testing.expectEqual(@as(usize, 5), strings.countGraphemes("hello"));

    // CRLF is one grapheme
    try testing.expectEqual(@as(usize, 3), strings.countGraphemes("a\r\nb"));
}

test "Grapheme clusters: Combining marks" {
    const testing = std.testing;

    // e + combining acute = 1 grapheme
    try testing.expectEqual(@as(usize, 1), strings.countGraphemes("e\xCC\x81"));

    // a + combining diaeresis + combining macron = 1 grapheme
    try testing.expectEqual(@as(usize, 1), strings.countGraphemes("a\xCC\x88\xCC\x84"));
}

// ============================================================
// Case Conversion Test Vectors
// ============================================================

test "Case conversion: ASCII" {
    const testing = std.testing;

    const lower = try strings.toLower(testing.allocator, "HELLO");
    defer testing.allocator.free(lower);
    try testing.expectEqualSlices(u8, "hello", lower);

    const upper = try strings.toUpper(testing.allocator, "hello");
    defer testing.allocator.free(upper);
    try testing.expectEqualSlices(u8, "HELLO", upper);
}

test "Case conversion: Latin-1" {
    const testing = std.testing;

    // É (U+00C9) -> é (U+00E9)
    const lower = try strings.toLower(testing.allocator, "\xC3\x89");
    defer testing.allocator.free(lower);
    try testing.expectEqualSlices(u8, "\xC3\xA9", lower);
}

// ============================================================
// String Operation Test Vectors
// ============================================================

test "String operations: Trim" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "hello", strings.trim("  hello  "));
    try testing.expectEqualSlices(u8, "hello", strings.trim("\t\nhello\r\n"));
    try testing.expectEqualSlices(u8, "", strings.trim("   "));
    try testing.expectEqualSlices(u8, "hello", strings.trim("hello"));
}

test "String operations: Split" {
    const testing = std.testing;

    const parts = try strings.split(testing.allocator, "a,b,c", ",");
    defer testing.allocator.free(parts);

    try testing.expectEqual(@as(usize, 3), parts.len);
    try testing.expectEqualSlices(u8, "a", parts[0]);
    try testing.expectEqualSlices(u8, "b", parts[1]);
    try testing.expectEqualSlices(u8, "c", parts[2]);
}

test "String operations: Join" {
    const testing = std.testing;

    const parts = [_][]const u8{ "a", "b", "c" };
    const joined = try strings.join(testing.allocator, &parts, ", ");
    defer testing.allocator.free(joined);

    try testing.expectEqualSlices(u8, "a, b, c", joined);
}

test "String operations: Replace" {
    const testing = std.testing;

    const replaced = try strings.replace(testing.allocator, "hello world", "world", "zig");
    defer testing.allocator.free(replaced);

    try testing.expectEqualSlices(u8, "hello zig", replaced);
}

test "String operations: Search" {
    const testing = std.testing;

    try testing.expect(strings.contains("hello world", "world"));
    try testing.expect(!strings.contains("hello", "world"));

    try testing.expectEqual(@as(?usize, 0), strings.indexOf("hello", "h"));
    try testing.expectEqual(@as(?usize, 6), strings.indexOf("hello world", "world"));
    try testing.expectEqual(@as(?usize, null), strings.indexOf("hello", "x"));

    try testing.expect(strings.startsWith("hello", "hel"));
    try testing.expect(!strings.startsWith("hello", "llo"));

    try testing.expect(strings.endsWith("hello", "llo"));
    try testing.expect(!strings.endsWith("hello", "hel"));
}

// ============================================================
// Encoding Detection Test Vectors
// ============================================================

test "Encoding detection: BOM" {
    const testing = std.testing;

    // UTF-8 BOM
    const utf8_result = strings.detection.detect("\xEF\xBB\xBFHello");
    try testing.expectEqual(strings.Encoding.utf8, utf8_result.encoding);
    try testing.expect(utf8_result.has_bom);

    // UTF-16 LE BOM
    const utf16le_result = strings.detection.detect("\xFF\xFEH\x00");
    try testing.expectEqual(strings.Encoding.utf16_le, utf16le_result.encoding);
    try testing.expect(utf16le_result.has_bom);

    // UTF-16 BE BOM
    const utf16be_result = strings.detection.detect("\xFE\xFF\x00H");
    try testing.expectEqual(strings.Encoding.utf16_be, utf16be_result.encoding);
    try testing.expect(utf16be_result.has_bom);
}
