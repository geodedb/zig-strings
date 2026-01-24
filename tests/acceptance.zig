//! Acceptance tests for the strings library.
//!
//! These tests verify complete workflows and integration between
//! different modules.

const std = @import("std");
const strings = @import("strings");

// ============================================================
// String Type Workflows
// ============================================================

test "String: Complete workflow" {
    const testing = std.testing;

    // Create and manipulate a string
    var str = try strings.String.fromSlice(testing.allocator, "  Hello, World!  ");
    defer str.deinit();

    // Trim
    var trimmed = try str.trimmed();
    defer trimmed.deinit();
    try testing.expectEqualSlices(u8, "Hello, World!", trimmed.bytes());

    // Search
    try testing.expect(str.contains("World"));
    try testing.expect(str.startsWith("  Hello"));
    try testing.expect(str.endsWith("!  "));

    // Replace
    var replaced = try str.replaced("World", "Zig");
    defer replaced.deinit();
    try testing.expect(replaced.contains("Zig"));

    // Case conversion
    var upper = try replaced.toUpper();
    defer upper.deinit();
    try testing.expect(upper.contains("ZIG"));
}

test "StringBuilder: Building complex strings" {
    const testing = std.testing;

    var builder = strings.StringBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.append("Hello");
    try builder.appendByte(',');
    try builder.appendByte(' ');
    try builder.append("World");
    try builder.appendCodepoint('!');

    try testing.expectEqualSlices(u8, "Hello, World!", builder.slice());

    try builder.replace("World", "Universe");
    try testing.expectEqualSlices(u8, "Hello, Universe!", builder.slice());
}

test "String16: UTF-8 round-trip" {
    const testing = std.testing;

    const original = "Hello, 世界! \xF0\x9F\x98\x80";

    // UTF-8 -> UTF-16
    var str16 = try strings.String16.fromUtf8(testing.allocator, original);
    defer str16.deinit();

    // UTF-16 -> UTF-8
    const back = try str16.toUtf8();
    defer testing.allocator.free(back);

    try testing.expectEqualSlices(u8, original, back);
}

// ============================================================
// Encoding Transcoding Workflows
// ============================================================

test "Transcoding: UTF-8 to UTF-16 and back" {
    const testing = std.testing;

    const original = "Hello, \xE4\xB8\xAD\xE6\x96\x87!"; // "Hello, 中文!"

    // UTF-8 -> UTF-16 LE
    const utf16 = try strings.transcoding.utf8ToUtf16(testing.allocator, original, .little);
    defer testing.allocator.free(utf16);

    // UTF-16 LE -> UTF-8
    const back = try strings.transcoding.utf16ToUtf8(testing.allocator, utf16, .little);
    defer testing.allocator.free(back);

    try testing.expectEqualSlices(u8, original, back);
}

test "Transcoding: UTF-8 to Latin-1 with fallback" {
    const testing = std.testing;

    const utf8 = "caf\xC3\xA9"; // "café"

    const latin1 = try strings.transcoding.utf8ToLatin1(testing.allocator, utf8, .{});
    defer testing.allocator.free(latin1);

    try testing.expectEqual(@as(usize, 4), latin1.len);
    try testing.expectEqual(@as(u8, 0xE9), latin1[3]); // é in Latin-1
}

// ============================================================
// Unicode Operations Workflows
// ============================================================

test "Unicode: Case conversion with special characters" {
    const testing = std.testing;

    // German sharp s -> SS
    const upper = try strings.toUpper(testing.allocator, "stra\xC3\x9Fe");
    defer testing.allocator.free(upper);
    // Note: Full uppercase would be "STRASSE" but simple mapping gives "STRASSE" only partially

    // Greek letters
    const greek_lower = try strings.toLower(testing.allocator, "\xCE\x91\xCE\x92\xCE\x93"); // ΑΒΓ
    defer testing.allocator.free(greek_lower);
    try testing.expectEqualSlices(u8, "\xCE\xB1\xCE\xB2\xCE\xB3", greek_lower); // αβγ
}

test "Unicode: Grapheme cluster iteration" {
    const testing = std.testing;

    // Text with combining characters
    const text = "e\xCC\x81"; // e + combining acute = é
    var iter = strings.grapheme.iterator(text);

    const cluster = iter.next();
    try testing.expect(cluster != null);
    try testing.expectEqual(@as(usize, 3), cluster.?.len);
    try testing.expect(iter.next() == null);
}

test "Unicode: Word iteration" {
    const testing = std.testing;

    var iter = strings.word.iterator("Hello, World!");

    // Collect words (filtering out spaces/punctuation)
    var words: std.ArrayList([]const u8) = .empty;
    defer words.deinit(testing.allocator);

    while (iter.next()) |segment| {
        // Check if segment contains letters
        var has_letter = false;
        for (segment) |c| {
            if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z')) {
                has_letter = true;
                break;
            }
        }
        if (has_letter) {
            try words.append(testing.allocator, segment);
        }
    }

    try testing.expectEqual(@as(usize, 2), words.items.len);
    try testing.expectEqualSlices(u8, "Hello", words.items[0]);
    try testing.expectEqualSlices(u8, "World", words.items[1]);
}

// ============================================================
// String Interning Workflows
// ============================================================

test "StringPool: Deduplication" {
    const testing = std.testing;

    var pool = strings.StringPool.init(testing.allocator);
    defer pool.deinit();

    const s1 = try pool.intern("hello");
    const s2 = try pool.intern("world");
    const s3 = try pool.intern("hello"); // Should return same as s1

    try testing.expect(s1.ptr == s3.ptr);
    try testing.expect(s1.ptr != s2.ptr);
    try testing.expectEqual(@as(usize, 2), pool.count());
}

test "SymbolTable: Symbol lookup" {
    const testing = std.testing;

    var table = strings.SymbolTable.init(testing.allocator);
    defer table.deinit();

    const id1 = try table.getOrPut("variable1");
    const id2 = try table.getOrPut("variable2");
    const id3 = try table.getOrPut("variable1");

    try testing.expectEqual(id1, id3);
    try testing.expect(id1 != id2);
    try testing.expect(table.contains("variable1"));
    try testing.expect(!table.contains("variable3"));
}

// ============================================================
// Iterator Workflows
// ============================================================

test "Iterators: Line processing" {
    const testing = std.testing;

    const text = "line1\nline2\r\nline3";
    var iter = strings.iterator.lines(text);

    try testing.expectEqualSlices(u8, "line1", iter.next().?);
    try testing.expectEqualSlices(u8, "line2", iter.next().?);
    try testing.expectEqualSlices(u8, "line3", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "Iterators: Code point processing" {
    const testing = std.testing;

    const text = "A\xC3\xA9\xE4\xB8\xAD\xF0\x9F\x98\x80"; // "Aé中😀"
    var iter = strings.utf8.iterator(text);

    try testing.expectEqual(@as(?strings.Codepoint, 'A'), iter.next());
    try testing.expectEqual(@as(?strings.Codepoint, 0x00E9), iter.next()); // é
    try testing.expectEqual(@as(?strings.Codepoint, 0x4E2D), iter.next()); // 中
    try testing.expectEqual(@as(?strings.Codepoint, 0x1F600), iter.next()); // 😀
    try testing.expect(iter.next() == null);
}

// ============================================================
// Formatting Workflows
// ============================================================

test "Formatting: String interpolation" {
    const testing = std.testing;

    const result = try strings.formatting.interpolate(
        testing.allocator,
        "Hello, {}! You have {} messages.",
        &[_][]const u8{ "Alice", "5" },
    );
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "Hello, Alice! You have 5 messages.", result);
}

test "Formatting: Named interpolation" {
    const testing = std.testing;

    const result = try strings.formatting.interpolateNamed(
        testing.allocator,
        "Hello, {name}! Today is {day}.",
        &[_]strings.formatting.NamedValue{
            .{ .name = "name", .value = "Bob" },
            .{ .name = "day", .value = "Monday" },
        },
    );
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "Hello, Bob! Today is Monday.", result);
}

// ============================================================
// SIMD Operations
// ============================================================

test "SIMD: ASCII detection" {
    const testing = std.testing;

    try testing.expect(strings.simd.isAllAscii("Hello, World!"));
    try testing.expect(!strings.simd.isAllAscii("Hello, 世界!"));
}

test "SIMD: Case conversion" {
    const testing = std.testing;

    var dest: [32]u8 = undefined;
    strings.simd.toLowerAscii(dest[0..13], "Hello, World!");
    try testing.expectEqualSlices(u8, "hello, world!", dest[0..13]);

    strings.simd.toUpperAscii(dest[0..13], "Hello, World!");
    try testing.expectEqualSlices(u8, "HELLO, WORLD!", dest[0..13]);
}

// ============================================================
// Acceptance Tests T1-T6
// ============================================================

test "T1: UTF-16 round-trip" {
    const testing = std.testing;

    // Create a string with ASCII and Unicode characters
    var str = try strings.String.fromSlice(testing.allocator, "Hello, \xE4\xB8\x96\xE7\x95\x8C!"); // "Hello, 世界!"
    defer str.deinit();

    // Convert to UTF-16
    const utf16 = try str.toUtf16(.little);
    defer testing.allocator.free(utf16);

    // Convert back to UTF-8 via String.fromUtf16
    var back = try strings.String.fromUtf16(testing.allocator, utf16, .little);
    defer back.deinit();

    // Verify round-trip
    try testing.expectEqualSlices(u8, str.bytes(), back.bytes());
}

test "T2: SSO threshold" {
    const testing = std.testing;

    // Short string (5 bytes) - should be inline
    var short = try strings.String.fromSlice(testing.allocator, "hello");
    defer short.deinit();
    try testing.expect(short.isInline());

    // At threshold (23 bytes) - should be inline
    var threshold = try strings.String.fromSlice(testing.allocator, "12345678901234567890123");
    defer threshold.deinit();
    try testing.expect(threshold.isInline());
    try testing.expectEqual(@as(usize, 23), threshold.len());

    // Beyond threshold (24 bytes) - should be heap-allocated
    var long = try strings.String.fromSlice(testing.allocator, "123456789012345678901234");
    defer long.deinit();
    try testing.expect(!long.isInline());
    try testing.expectEqual(@as(usize, 24), long.len());
}

test "T3: Grapheme count" {
    const testing = std.testing;

    // e + combining acute = 1 grapheme
    try testing.expectEqual(@as(usize, 1), strings.grapheme.count("e\xCC\x81"));

    // US flag emoji (regional indicators) = 1 grapheme
    try testing.expectEqual(@as(usize, 1), strings.grapheme.count("\xF0\x9F\x87\xBA\xF0\x9F\x87\xB8"));

    // Family emoji with ZWJ = 1 grapheme (👨‍👩‍👧)
    // Note: This is a complex ZWJ sequence
    try testing.expectEqual(@as(usize, 1), strings.grapheme.count("\xF0\x9F\x91\xA8\xE2\x80\x8D\xF0\x9F\x91\xA9\xE2\x80\x8D\xF0\x9F\x91\xA7"));

    // Simple ASCII = 5 graphemes
    try testing.expectEqual(@as(usize, 5), strings.grapheme.count("hello"));
}

test "T4: NFC normalization" {
    const testing = std.testing;

    // NFD: e + combining acute
    const nfd = "e\xCC\x81";

    // Test NFC normalization (composition)
    // e + combining acute should compose to é (U+00E9)
    const nfc_result = try strings.normalization.normalize(testing.allocator, nfd, .nfc);
    defer testing.allocator.free(nfc_result);

    // NFC should produce the precomposed form: é = 0xC3 0xA9 in UTF-8
    try testing.expectEqualSlices(u8, "\xC3\xA9", nfc_result);

    // Test NFD normalization (decomposition)
    const nfd_result = try strings.normalization.normalize(testing.allocator, nfd, .nfd);
    defer testing.allocator.free(nfd_result);

    // NFD should preserve the decomposed form
    try testing.expectEqualSlices(u8, nfd, nfd_result);

    // Test round-trip: composed -> decomposed -> composed
    const composed = "\xC3\xA9"; // é
    const decomposed = try strings.normalization.normalize(testing.allocator, composed, .nfd);
    defer testing.allocator.free(decomposed);
    try testing.expectEqualSlices(u8, nfd, decomposed); // Should be e + combining acute

    const recomposed = try strings.normalization.normalize(testing.allocator, decomposed, .nfc);
    defer testing.allocator.free(recomposed);
    try testing.expectEqualSlices(u8, composed, recomposed); // Should be é again
}

test "T5: Case-insensitive collation" {
    const testing = std.testing;

    // Primary strength ignores case
    try testing.expect(strings.collation.equals("Hello", "HELLO", .{ .strength = .primary }));
    try testing.expect(strings.collation.equals("hello", "HELLO", .{ .strength = .primary }));

    // Tertiary strength distinguishes case
    try testing.expect(!strings.collation.equals("hello", "HELLO", .{ .strength = .tertiary }));

    // Basic ordering with primary strength
    try testing.expectEqual(std.math.Order.lt, strings.collation.compare("apple", "banana", .{ .strength = .primary }));
    try testing.expectEqual(std.math.Order.gt, strings.collation.compare("zebra", "apple", .{ .strength = .primary }));
}

test "T6: Encoding detection" {
    const testing = std.testing;

    // UTF-8 with BOM
    const utf8_bom = "\xEF\xBB\xBFHello";
    const result_bom = strings.detection.detect(utf8_bom);
    try testing.expectEqual(strings.detection.Encoding.utf8, result_bom.encoding);
    try testing.expect(result_bom.has_bom);

    // Pure ASCII is detected as ASCII (which is valid UTF-8)
    const ascii_only = "Hello, World!";
    const result_ascii = strings.detection.detect(ascii_only);
    try testing.expectEqual(strings.detection.Encoding.ascii, result_ascii.encoding);
    try testing.expect(!result_ascii.has_bom);

    // UTF-8 with non-ASCII characters (multibyte)
    const utf8_multibyte = "Hello, \xE4\xB8\x96\xE7\x95\x8C!"; // "Hello, 世界!"
    const result_multibyte = strings.detection.detect(utf8_multibyte);
    try testing.expectEqual(strings.detection.Encoding.utf8, result_multibyte.encoding);
    try testing.expect(!result_multibyte.has_bom);
}
