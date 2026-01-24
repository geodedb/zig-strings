//! Encoding Round-Trip Tests
//!
//! Tests for encoding/decoding operations and round-trip integrity.

const std = @import("std");
const testing = std.testing;
const strings = @import("strings");

// ============================================================================
// UTF-8 Validation Tests
// ============================================================================

test "UTF-8 validation: Valid ASCII" {
    try testing.expect(strings.utf8.isValid("Hello, World!"));
}

test "UTF-8 validation: Valid multibyte" {
    try testing.expect(strings.utf8.isValid("日本語"));
    try testing.expect(strings.utf8.isValid("emoji: 😀"));
    try testing.expect(strings.utf8.isValid("Здравствуй"));
}

test "UTF-8 validation: Invalid sequences" {
    // Overlong encoding
    try testing.expect(!strings.utf8.isValid("\xC0\x81"));
    // Invalid start byte
    try testing.expect(!strings.utf8.isValid("\xFF"));
    // Truncated sequence
    try testing.expect(!strings.utf8.isValid("\xC2"));
    // Invalid continuation
    try testing.expect(!strings.utf8.isValid("\xE0\x80"));
}

test "UTF-8 validation: Empty string" {
    try testing.expect(strings.utf8.isValid(""));
}

// ============================================================================
// UTF-16 Tests
// ============================================================================

test "UTF-16 validation: BMP characters" {
    const units = [_]u16{ 'H', 'e', 'l', 'l', 'o' };
    try testing.expect(strings.utf16.isValid(&units));
}

test "UTF-16 validation: Surrogate pairs" {
    // 😀 = U+1F600 = D83D DE00 in UTF-16
    const units = [_]u16{ 0xD83D, 0xDE00 };
    try testing.expect(strings.utf16.isValid(&units));
}

test "UTF-16 validation: Invalid lone surrogate" {
    const units = [_]u16{0xD800}; // Lone high surrogate
    try testing.expect(!strings.utf16.isValid(&units));
}

test "UTF-16 codepoint count" {
    const bmp = [_]u16{ 'H', 'e', 'l', 'l', 'o' };
    try testing.expectEqual(@as(?usize, 5), strings.utf16.countCodepoints(&bmp));

    // With surrogate pair (1 codepoint from 2 units)
    const with_emoji = [_]u16{ 'A', 0xD83D, 0xDE00, 'B' };
    try testing.expectEqual(@as(?usize, 3), strings.utf16.countCodepoints(&with_emoji));
}

test "UTF-16 iterator" {
    const units = [_]u16{ 'A', 'B', 'C' };
    var iter = strings.utf16.iterator(&units);

    try testing.expectEqual(@as(?u21, 'A'), iter.next());
    try testing.expectEqual(@as(?u21, 'B'), iter.next());
    try testing.expectEqual(@as(?u21, 'C'), iter.next());
    try testing.expectEqual(@as(?u21, null), iter.next());
}

// ============================================================================
// UTF-32 Tests
// ============================================================================

test "UTF-32 validation" {
    const valid = [_]u32{ 'H', 'e', 'l', 'l', 'o', 0x1F600 };
    try testing.expect(strings.utf32.isValid(&valid));

    const invalid = [_]u32{0x110000}; // Beyond Unicode range
    try testing.expect(!strings.utf32.isValid(&invalid));
}

test "UTF-32 codepoint count" {
    const units = [_]u32{ 'A', 'B', 'C', 0x1F600 };
    try testing.expectEqual(@as(usize, 4), strings.utf32.countCodepoints(&units));
}

// ============================================================================
// Transcoding Tests
// ============================================================================

test "Transcode UTF-8 to Latin-1" {
    const allocator = testing.allocator;
    const original = "Hello";

    const latin1 = try strings.transcoding.transcode(allocator, original, .utf8, .latin1, .{});
    defer allocator.free(latin1);

    try testing.expectEqualStrings("Hello", latin1);
}

test "Transcode UTF-8 to ASCII" {
    const allocator = testing.allocator;
    const original = "Test123";

    const ascii = try strings.transcoding.transcode(allocator, original, .utf8, .ascii, .{});
    defer allocator.free(ascii);

    try testing.expectEqualStrings("Test123", ascii);
}

test "Transcode UTF-8 round-trip via UTF-16LE" {
    const allocator = testing.allocator;
    const original = "Hello";

    const utf16le = try strings.transcoding.transcode(allocator, original, .utf8, .utf16_le, .{});
    defer allocator.free(utf16le);

    const back = try strings.transcoding.transcode(allocator, utf16le, .utf16_le, .utf8, .{});
    defer allocator.free(back);

    try testing.expectEqualStrings(original, back);
}

test "Transcode UTF-8 round-trip via UTF-32LE" {
    const allocator = testing.allocator;
    const original = "Hello";

    const utf32le = try strings.transcoding.transcode(allocator, original, .utf8, .utf32_le, .{});
    defer allocator.free(utf32le);

    const back = try strings.transcoding.transcode(allocator, utf32le, .utf32_le, .utf8, .{});
    defer allocator.free(back);

    try testing.expectEqualStrings(original, back);
}

// ============================================================================
// String Type Round-Trip Tests
// ============================================================================

test "String from/to slice" {
    const allocator = testing.allocator;

    var str = try strings.String.fromSlice(allocator, "Hello, World!");
    defer str.deinit();

    try testing.expectEqualStrings("Hello, World!", str.bytes());
}

test "String SSO threshold" {
    const allocator = testing.allocator;

    // Short string (should use SSO)
    var short = try strings.String.fromSlice(allocator, "hello");
    defer short.deinit();
    try testing.expect(short.isInline());
    try testing.expectEqualStrings("hello", short.bytes());

    // 23 bytes (SSO limit)
    var at_limit = try strings.String.fromSlice(allocator, "12345678901234567890123");
    defer at_limit.deinit();
    try testing.expect(at_limit.isInline());

    // 24 bytes (over SSO limit)
    var over_limit = try strings.String.fromSlice(allocator, "123456789012345678901234");
    defer over_limit.deinit();
    try testing.expect(!over_limit.isInline());
}

test "String clone" {
    const allocator = testing.allocator;

    var original = try strings.String.fromSlice(allocator, "Original");
    defer original.deinit();

    var cloned = try original.clone();
    defer cloned.deinit();

    try testing.expectEqualStrings(original.bytes(), cloned.bytes());
}

test "String append" {
    const allocator = testing.allocator;

    var str = try strings.String.fromSlice(allocator, "Hello");
    defer str.deinit();

    try str.append(", World!");
    try testing.expectEqualStrings("Hello, World!", str.bytes());
}

// ============================================================================
// Language-Specific Round-Trip Tests
// ============================================================================

test "Chinese text round-trip" {
    const allocator = testing.allocator;
    const chinese = "中文测试";

    var str = try strings.String.fromSlice(allocator, chinese);
    defer str.deinit();

    try testing.expectEqualStrings(chinese, str.bytes());
    try testing.expect(strings.utf8.isValid(str.bytes()));
}

test "Japanese text round-trip" {
    const allocator = testing.allocator;
    const japanese = "日本語テスト";

    var str = try strings.String.fromSlice(allocator, japanese);
    defer str.deinit();

    try testing.expectEqualStrings(japanese, str.bytes());
    try testing.expect(strings.utf8.isValid(str.bytes()));
}

test "Korean text round-trip" {
    const allocator = testing.allocator;
    const korean = "한글 테스트";

    var str = try strings.String.fromSlice(allocator, korean);
    defer str.deinit();

    try testing.expectEqualStrings(korean, str.bytes());
    try testing.expect(strings.utf8.isValid(str.bytes()));
}

test "Arabic text round-trip" {
    const allocator = testing.allocator;
    const arabic = "العربية";

    var str = try strings.String.fromSlice(allocator, arabic);
    defer str.deinit();

    try testing.expectEqualStrings(arabic, str.bytes());
    try testing.expect(strings.utf8.isValid(str.bytes()));
}

test "Hebrew text round-trip" {
    const allocator = testing.allocator;
    const hebrew = "עברית";

    var str = try strings.String.fromSlice(allocator, hebrew);
    defer str.deinit();

    try testing.expectEqualStrings(hebrew, str.bytes());
    try testing.expect(strings.utf8.isValid(str.bytes()));
}

test "Mixed script text round-trip" {
    const allocator = testing.allocator;
    const mixed = "Hello 世界 مرحبا";

    var str = try strings.String.fromSlice(allocator, mixed);
    defer str.deinit();

    try testing.expectEqualStrings(mixed, str.bytes());
    try testing.expect(strings.utf8.isValid(str.bytes()));
}

test "Emoji round-trip" {
    const allocator = testing.allocator;
    const emojis = "😀🎉🚀💻🌍";

    var str = try strings.String.fromSlice(allocator, emojis);
    defer str.deinit();

    try testing.expectEqualStrings(emojis, str.bytes());
    try testing.expect(strings.utf8.isValid(str.bytes()));
}

// ============================================================================
// Edge Cases
// ============================================================================

test "Empty string round-trip" {
    const allocator = testing.allocator;

    var str = try strings.String.fromSlice(allocator, "");
    defer str.deinit();

    try testing.expectEqualStrings("", str.bytes());
    try testing.expectEqual(@as(usize, 0), str.len());
}

test "Single character strings" {
    const allocator = testing.allocator;

    // ASCII
    var ascii = try strings.String.fromSlice(allocator, "A");
    defer ascii.deinit();
    try testing.expectEqualStrings("A", ascii.bytes());

    // 2-byte UTF-8
    var two_byte = try strings.String.fromSlice(allocator, "\xC3\xA9");
    defer two_byte.deinit();
    try testing.expectEqualStrings("\xC3\xA9", two_byte.bytes());

    // 3-byte UTF-8
    var three_byte = try strings.String.fromSlice(allocator, "\xE4\xB8\xAD");
    defer three_byte.deinit();
    try testing.expectEqualStrings("\xE4\xB8\xAD", three_byte.bytes());

    // 4-byte UTF-8
    var four_byte = try strings.String.fromSlice(allocator, "\xF0\x9F\x98\x80");
    defer four_byte.deinit();
    try testing.expectEqualStrings("\xF0\x9F\x98\x80", four_byte.bytes());
}
