// SPDX-License-Identifier: Apache-2.0
// Word and Sentence Segmentation Example
//
// This example demonstrates Unicode text segmentation (UAX #29) for
// breaking text into words and sentences. This is more complex than
// splitting on whitespace because it handles:
// - Contractions (don't, we're)
// - Abbreviations (Dr., U.S.A.)
// - Numbers with punctuation (3.14, 1,000)
// - Non-Latin scripts
//
// Run with: zig build-exe 09_word_sentence.zig --deps strings && ./09_word_sentence

const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    _ = allocator;

    // =========================================================================
    // Word Segmentation Basics
    // =========================================================================

    std.debug.print("=== Word Segmentation Basics ===\n\n", .{});

    std.debug.print("Unicode word boundaries (UAX #29) define where words\n", .{});
    std.debug.print("start and end in text. This handles:\n", .{});
    std.debug.print("  - Letters followed by letters\n", .{});
    std.debug.print("  - Numbers followed by numbers\n", .{});
    std.debug.print("  - Letters followed by numbers (and vice versa)\n", .{});
    std.debug.print("  - Apostrophes in contractions\n", .{});
    std.debug.print("  - And much more...\n\n", .{});

    // =========================================================================
    // Simple Word Iteration
    // =========================================================================

    std.debug.print("=== Simple Word Iteration ===\n\n", .{});

    const simple_text = "Hello, World!";
    std.debug.print("Text: '{s}'\n", .{simple_text});
    std.debug.print("Word segments:\n", .{});

    var word_iter = strings.word.iterator(simple_text);
    while (word_iter.next()) |segment| {
        // Show what type of segment this is
        const is_word = isWordLike(segment);
        std.debug.print("  '{s}'{s}\n", .{ segment, if (is_word) " (word)" else "" });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Words with Numbers
    // =========================================================================

    std.debug.print("=== Words with Numbers ===\n\n", .{});

    const alphanumeric = "test123 version2.0 abc456def";
    std.debug.print("Text: '{s}'\n", .{alphanumeric});
    std.debug.print("Word segments:\n", .{});

    var num_iter = strings.word.iterator(alphanumeric);
    while (num_iter.next()) |segment| {
        std.debug.print("  '{s}'\n", .{segment});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Word Break Properties
    // =========================================================================

    std.debug.print("=== Word Break Properties ===\n\n", .{});

    const test_chars = [_]struct { cp: u21, name: []const u8 }{
        .{ .cp = 'a', .name = "lowercase a" },
        .{ .cp = 'A', .name = "uppercase A" },
        .{ .cp = '5', .name = "digit 5" },
        .{ .cp = '\'', .name = "apostrophe" },
        .{ .cp = ' ', .name = "space" },
        .{ .cp = '\n', .name = "newline" },
        .{ .cp = 0x30A2, .name = "katakana A" },
    };

    for (test_chars) |item| {
        const prop = strings.word.getWordBreak(item.cp);
        std.debug.print("U+{X:0>4} ({s}): {s}\n", .{ item.cp, item.name, @tagName(prop) });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Counting Words
    // =========================================================================

    std.debug.print("=== Counting Words ===\n\n", .{});

    const count_text = "The quick brown fox jumps over the lazy dog.";
    std.debug.print("Text: '{s}'\n", .{count_text});

    // Count all segments
    const segment_count = strings.word.count(count_text);
    std.debug.print("Total segments: {}\n", .{segment_count});

    // Count only word-like segments
    var actual_words: usize = 0;
    var count_iter = strings.word.iterator(count_text);
    while (count_iter.next()) |segment| {
        if (isWordLike(segment)) {
            actual_words += 1;
        }
    }
    std.debug.print("Actual words: {}\n\n", .{actual_words});

    // =========================================================================
    // Japanese Text (Katakana)
    // =========================================================================

    std.debug.print("=== Japanese Katakana ===\n\n", .{});

    // Katakana sequences stay together
    const katakana = "\xE3\x82\xA2\xE3\x82\xA4 \xE3\x82\xA6\xE3\x82\xA8"; // "ai ue" in katakana
    std.debug.print("Katakana text: {s}\n", .{katakana});
    std.debug.print("Word segments:\n", .{});

    var kata_iter = strings.word.iterator(katakana);
    while (kata_iter.next()) |segment| {
        std.debug.print("  '{s}'\n", .{segment});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Mixed Scripts
    // =========================================================================

    std.debug.print("=== Mixed Scripts ===\n\n", .{});

    const mixed = "Hello \xE4\xB8\x96\xE7\x95\x8C!"; // Hello 世界!
    std.debug.print("Mixed text: {s}\n", .{mixed});
    std.debug.print("Word segments:\n", .{});

    var mixed_iter = strings.word.iterator(mixed);
    while (mixed_iter.next()) |segment| {
        std.debug.print("  '{s}'\n", .{segment});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Practical Example: Extract Words
    // =========================================================================

    std.debug.print("=== Practical: Extract Words Only ===\n\n", .{});

    const article = "The Zig programming language (v0.11.0) is fast!";
    std.debug.print("Text: {s}\n", .{article});
    std.debug.print("Words only:\n", .{});

    var extract_iter = strings.word.iterator(article);
    var word_num: usize = 1;
    while (extract_iter.next()) |segment| {
        if (isWordLike(segment)) {
            std.debug.print("  {d}. {s}\n", .{ word_num, segment });
            word_num += 1;
        }
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Practical Example: Word Frequency
    // =========================================================================

    std.debug.print("=== Practical: Simple Word Analysis ===\n\n", .{});

    const sample = "The quick brown fox jumps over the lazy dog. The dog was not amused.";
    std.debug.print("Text: {s}\n\n", .{sample});

    // Count word-like segments
    var analysis_iter = strings.word.iterator(sample);
    var total_words: usize = 0;
    var total_chars: usize = 0;

    while (analysis_iter.next()) |segment| {
        if (isWordLike(segment)) {
            total_words += 1;
            total_chars += segment.len;
        }
    }

    const avg_len: f64 = if (total_words > 0) @as(f64, @floatFromInt(total_chars)) / @as(f64, @floatFromInt(total_words)) else 0;
    std.debug.print("Total words: {}\n", .{total_words});
    std.debug.print("Average word length: {d:.1} bytes\n\n", .{avg_len});

    // =========================================================================
    // Regional Indicators (Flags)
    // =========================================================================

    std.debug.print("=== Regional Indicators ===\n\n", .{});

    std.debug.print("Regional indicator pairs form flag emojis.\n", .{});
    std.debug.print("The word algorithm keeps pairs together.\n\n", .{});

    // =========================================================================
    // CRLF and Newlines
    // =========================================================================

    std.debug.print("=== Newline Handling ===\n\n", .{});

    const with_newlines = "Line1\nLine2\r\nLine3";
    std.debug.print("Text with newlines:\n", .{});
    std.debug.print("Word segments:\n", .{});

    var nl_iter = strings.word.iterator(with_newlines);
    while (nl_iter.next()) |segment| {
        // Show special characters
        if (std.mem.eql(u8, segment, "\n")) {
            std.debug.print("  '\\n'\n", .{});
        } else if (std.mem.eql(u8, segment, "\r\n")) {
            std.debug.print("  '\\r\\n'\n", .{});
        } else {
            std.debug.print("  '{s}'\n", .{segment});
        }
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Whitespace Segments
    // =========================================================================

    std.debug.print("=== Whitespace Handling ===\n\n", .{});

    const spaced = "word1   word2\tword3";
    std.debug.print("Text with various whitespace: '{s}'\n", .{spaced});
    std.debug.print("Segments:\n", .{});

    var ws_iter = strings.word.iterator(spaced);
    while (ws_iter.next()) |segment| {
        if (isWhitespaceOnly(segment)) {
            std.debug.print("  <whitespace: {} bytes>\n", .{segment.len});
        } else {
            std.debug.print("  '{s}'\n", .{segment});
        }
    }
    std.debug.print("\n", .{});

    std.debug.print("=== Example Complete ===\n", .{});
}

/// Helper: Check if a segment looks like a word (contains alphanumeric)
fn isWordLike(segment: []const u8) bool {
    for (segment) |byte| {
        if ((byte >= 'a' and byte <= 'z') or
            (byte >= 'A' and byte <= 'Z') or
            (byte >= '0' and byte <= '9') or
            byte >= 0x80)
        { // Non-ASCII (likely letter in other scripts)
            return true;
        }
    }
    return false;
}

/// Helper: Check if a segment is only whitespace
fn isWhitespaceOnly(segment: []const u8) bool {
    for (segment) |byte| {
        if (byte != ' ' and byte != '\t' and byte != '\n' and byte != '\r') {
            return false;
        }
    }
    return true;
}
