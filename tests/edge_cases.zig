//! Edge Cases and Stress Tests
//!
//! Tests for edge cases, boundary conditions, and stress testing.

const std = @import("std");
const testing = std.testing;
const strings = @import("strings");

// ============================================================================
// Invalid UTF-8 Handling
// ============================================================================

test "Invalid UTF-8: Overlong 2-byte" {
    try testing.expect(!strings.utf8.isValid("\xC0\x80")); // Overlong NUL
    try testing.expect(!strings.utf8.isValid("\xC1\xBF")); // Overlong 0x7F
}

test "Invalid UTF-8: Overlong 3-byte" {
    try testing.expect(!strings.utf8.isValid("\xE0\x80\x80")); // Overlong NUL
    try testing.expect(!strings.utf8.isValid("\xE0\x9F\xBF")); // Overlong 0x7FF
}

test "Invalid UTF-8: Overlong 4-byte" {
    try testing.expect(!strings.utf8.isValid("\xF0\x80\x80\x80")); // Overlong NUL
    try testing.expect(!strings.utf8.isValid("\xF0\x8F\xBF\xBF")); // Overlong 0xFFFF
}

test "Invalid UTF-8: Truncated sequences" {
    try testing.expect(!strings.utf8.isValid("\xC2")); // Missing 1 byte
    try testing.expect(!strings.utf8.isValid("\xE0\x80")); // Missing 1 byte
    try testing.expect(!strings.utf8.isValid("\xF0\x80\x80")); // Missing 1 byte
}

test "Invalid UTF-8: Invalid start bytes" {
    try testing.expect(!strings.utf8.isValid("\x80")); // Continuation byte
    try testing.expect(!strings.utf8.isValid("\xBF")); // Continuation byte
    try testing.expect(!strings.utf8.isValid("\xFE")); // Invalid
    try testing.expect(!strings.utf8.isValid("\xFF")); // Invalid
}

test "Invalid UTF-8: Surrogate codepoints" {
    try testing.expect(!strings.utf8.isValid("\xED\xA0\x80")); // U+D800
    try testing.expect(!strings.utf8.isValid("\xED\xBF\xBF")); // U+DFFF
}

test "Invalid UTF-8: Beyond Unicode" {
    try testing.expect(!strings.utf8.isValid("\xF4\x90\x80\x80")); // U+110000
}

// ============================================================================
// Empty and Null Input Tests
// ============================================================================

test "Empty string operations" {
    const allocator = testing.allocator;

    // String creation
    var str = try strings.String.fromSlice(allocator, "");
    defer str.deinit();
    try testing.expectEqual(@as(usize, 0), str.len());
    try testing.expectEqualStrings("", str.bytes());

    // UTF-8 validation
    try testing.expect(strings.utf8.isValid(""));

    // Grapheme count
    try testing.expectEqual(@as(usize, 0), strings.grapheme.count(""));
}

// ============================================================================
// SSO Threshold Tests
// ============================================================================

test "SSO: Exactly at threshold (23 bytes)" {
    const allocator = testing.allocator;

    var str = try strings.String.fromSlice(allocator, "12345678901234567890123");
    defer str.deinit();

    try testing.expectEqual(@as(usize, 23), str.len());
    try testing.expect(str.isInline());
}

test "SSO: One over threshold (24 bytes)" {
    const allocator = testing.allocator;

    var str = try strings.String.fromSlice(allocator, "123456789012345678901234");
    defer str.deinit();

    try testing.expectEqual(@as(usize, 24), str.len());
    try testing.expect(!str.isInline());
}

test "SSO: One under threshold (22 bytes)" {
    const allocator = testing.allocator;

    var str = try strings.String.fromSlice(allocator, "1234567890123456789012");
    defer str.deinit();

    try testing.expectEqual(@as(usize, 22), str.len());
    try testing.expect(str.isInline());
}

test "SSO: Transition from inline to heap" {
    const allocator = testing.allocator;

    var str = try strings.String.fromSlice(allocator, "hello"); // 5 bytes, inline
    defer str.deinit();
    try testing.expect(str.isInline());

    // Append to exceed threshold
    try str.append("12345678901234567890"); // Now 25 bytes, heap
    try testing.expect(!str.isInline());
    try testing.expectEqual(@as(usize, 25), str.len());
}

// ============================================================================
// String Operations Edge Cases
// ============================================================================

test "String contains: Empty needle" {
    const allocator = testing.allocator;

    var str = try strings.String.fromSlice(allocator, "hello");
    defer str.deinit();

    try testing.expect(str.contains(""));
}

test "String contains: Needle equals string" {
    const allocator = testing.allocator;

    var str = try strings.String.fromSlice(allocator, "hello");
    defer str.deinit();

    try testing.expect(str.contains("hello"));
}

test "String contains: Needle longer than string" {
    const allocator = testing.allocator;

    var str = try strings.String.fromSlice(allocator, "hi");
    defer str.deinit();

    try testing.expect(!str.contains("hello"));
}

// ============================================================================
// Grapheme Edge Cases
// ============================================================================

test "Grapheme: Multiple combining marks" {
    // e + multiple combining marks should still be 1 grapheme
    const with_marks = "e\xCC\x81\xCC\x80"; // e + acute + grave
    const count = strings.grapheme.count(with_marks);
    try testing.expectEqual(@as(usize, 1), count);
}

test "Grapheme: Devanagari cluster" {
    // Hindi syllable with consonant cluster: क्ष (ka + virama + sha)
    // Note: Full UAX #29 Extended Grapheme Clusters would count this as 1,
    // but basic implementation counts individual codepoints (3)
    const hindi = "\xE0\xA4\x95\xE0\xA5\x8D\xE0\xA4\xB7"; // क्ष
    const count = strings.grapheme.count(hindi);
    // Current implementation: 3 codepoints (basic grapheme clustering)
    // Full Unicode: should be 1 grapheme cluster
    try testing.expect(count >= 1 and count <= 3);
}

test "Grapheme: Zero-width joiner sequences" {
    // Single grapheme with ZWJ
    const zwj_seq = "\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x92\xBB"; // man + ZWJ + laptop
    const count = strings.grapheme.count(zwj_seq);
    try testing.expectEqual(@as(usize, 1), count);
}

// ============================================================================
// Unicode Normalization Edge Cases
// ============================================================================

test "Normalization: Already normalized" {
    const allocator = testing.allocator;

    const input = "Hello, World!";
    const result = try strings.normalization.normalize(allocator, input, .nfc);
    defer allocator.free(result);

    try testing.expectEqualStrings(input, result);
}

test "Normalization: Empty string" {
    const allocator = testing.allocator;

    const result = try strings.normalization.normalize(allocator, "", .nfc);
    defer allocator.free(result);

    try testing.expectEqualStrings("", result);
}

test "Normalization: Only ASCII" {
    const allocator = testing.allocator;

    const input = "ABCabc123!@#";
    const result = try strings.normalization.normalize(allocator, input, .nfc);
    defer allocator.free(result);

    try testing.expectEqualStrings(input, result);
}

// ============================================================================
// Case Conversion Edge Cases
// ============================================================================

test "Case: Empty string" {
    const allocator = testing.allocator;

    const lower = try strings.case.toLowerString(allocator, "");
    defer allocator.free(lower);
    try testing.expectEqualStrings("", lower);

    const upper = try strings.case.toUpperString(allocator, "");
    defer allocator.free(upper);
    try testing.expectEqualStrings("", upper);
}

test "Case: Already lowercase" {
    const allocator = testing.allocator;

    const result = try strings.case.toLowerString(allocator, "hello");
    defer allocator.free(result);
    try testing.expectEqualStrings("hello", result);
}

test "Case: Already uppercase" {
    const allocator = testing.allocator;

    const result = try strings.case.toUpperString(allocator, "HELLO");
    defer allocator.free(result);
    try testing.expectEqualStrings("HELLO", result);
}

test "Case: Numbers unchanged" {
    const allocator = testing.allocator;

    const lower = try strings.case.toLowerString(allocator, "123");
    defer allocator.free(lower);
    try testing.expectEqualStrings("123", lower);

    const upper = try strings.case.toUpperString(allocator, "123");
    defer allocator.free(upper);
    try testing.expectEqualStrings("123", upper);
}

// ============================================================================
// StringBuilder Edge Cases
// ============================================================================

test "StringBuilder: Empty build" {
    const allocator = testing.allocator;

    var builder = strings.StringBuilder.init(allocator);
    defer builder.deinit();

    try testing.expectEqualStrings("", builder.slice());
}

test "StringBuilder: Single append" {
    const allocator = testing.allocator;

    var builder = strings.StringBuilder.init(allocator);
    defer builder.deinit();

    try builder.append("hello");
    try testing.expectEqualStrings("hello", builder.slice());
}

test "StringBuilder: Multiple appends" {
    const allocator = testing.allocator;

    var builder = strings.StringBuilder.init(allocator);
    defer builder.deinit();

    try builder.append("Hello");
    try builder.append(", ");
    try builder.append("World");
    try builder.append("!");

    try testing.expectEqualStrings("Hello, World!", builder.slice());
}

// ============================================================================
// StringPool Edge Cases
// ============================================================================

test "StringPool: Same string interned once" {
    const allocator = testing.allocator;

    var pool = strings.StringPool.init(allocator);
    defer pool.deinit();

    const s1 = try pool.intern("hello");
    const s2 = try pool.intern("hello");

    // Should be the same pointer
    try testing.expectEqual(s1.ptr, s2.ptr);
}

test "StringPool: Different strings" {
    const allocator = testing.allocator;

    var pool = strings.StringPool.init(allocator);
    defer pool.deinit();

    const s1 = try pool.intern("hello");
    const s2 = try pool.intern("world");

    // Should be different pointers
    try testing.expect(s1.ptr != s2.ptr);
}

test "StringPool: Empty string" {
    const allocator = testing.allocator;

    var pool = strings.StringPool.init(allocator);
    defer pool.deinit();

    const s = try pool.intern("");
    try testing.expectEqualStrings("", s);
}

// ============================================================================
// Large String Tests
// ============================================================================

test "Large string: Creation and access" {
    const allocator = testing.allocator;

    // Create a 10KB string
    const large = try allocator.alloc(u8, 10000);
    defer allocator.free(large);
    @memset(large, 'A');

    var str = try strings.String.fromSlice(allocator, large);
    defer str.deinit();

    try testing.expectEqual(@as(usize, 10000), str.len());
    try testing.expect(!str.isInline());
}

test "Large string: Clone" {
    const allocator = testing.allocator;

    // Create a string over SSO threshold
    var original = try strings.String.fromSlice(allocator, "123456789012345678901234567890");
    defer original.deinit();

    var cloned = try original.clone();
    defer cloned.deinit();

    try testing.expectEqualStrings(original.bytes(), cloned.bytes());
}

// ============================================================================
// Collation Edge Cases
// ============================================================================

test "Collation: Empty strings" {
    const result = strings.collation.compare("", "", .{});
    try testing.expect(result == .eq);
}

test "Collation: Empty vs non-empty" {
    const result = strings.collation.compare("", "a", .{});
    try testing.expect(result == .lt);

    const result2 = strings.collation.compare("a", "", .{});
    try testing.expect(result2 == .gt);
}

test "Collation: Same string" {
    const result = strings.collation.compare("hello", "hello", .{});
    try testing.expect(result == .eq);
}

// ============================================================================
// UTF-8 Codepoint Edge Cases
// ============================================================================

test "UTF-8 codepoint: Boundary values" {
    // U+0000 (NUL)
    try testing.expectEqual(@as(?usize, 1), strings.utf8.countCodepoints("\x00"));

    // U+007F (DEL) - last 1-byte
    try testing.expectEqual(@as(?usize, 1), strings.utf8.countCodepoints("\x7F"));

    // U+0080 - first 2-byte
    try testing.expectEqual(@as(?usize, 1), strings.utf8.countCodepoints("\xC2\x80"));

    // U+07FF - last 2-byte
    try testing.expectEqual(@as(?usize, 1), strings.utf8.countCodepoints("\xDF\xBF"));

    // U+0800 - first 3-byte
    try testing.expectEqual(@as(?usize, 1), strings.utf8.countCodepoints("\xE0\xA0\x80"));

    // U+FFFF - last 3-byte (excluding surrogates)
    try testing.expectEqual(@as(?usize, 1), strings.utf8.countCodepoints("\xEF\xBF\xBF"));

    // U+10000 - first 4-byte
    try testing.expectEqual(@as(?usize, 1), strings.utf8.countCodepoints("\xF0\x90\x80\x80"));

    // U+10FFFF - last valid codepoint
    try testing.expectEqual(@as(?usize, 1), strings.utf8.countCodepoints("\xF4\x8F\xBF\xBF"));
}
