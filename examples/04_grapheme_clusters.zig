// SPDX-License-Identifier: Apache-2.0
// Grapheme Cluster Handling Example
//
// This example demonstrates grapheme cluster segmentation (UAX #29).
// A grapheme cluster represents what users perceive as a single "character",
// which may consist of multiple Unicode code points.
//
// Run with: zig build-exe 04_grapheme_clusters.zig --deps strings && ./04_grapheme_clusters

const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // =========================================================================
    // What is a Grapheme Cluster?
    // =========================================================================

    std.debug.print("=== What is a Grapheme Cluster? ===\n\n", .{});

    std.debug.print("A grapheme cluster is what users perceive as a single 'character'.\n", .{});
    std.debug.print("Examples of grapheme clusters that span multiple code points:\n", .{});
    std.debug.print("  - Combining marks: e + combining acute = e\n", .{});
    std.debug.print("  - Emoji with skin tone: Base emoji + skin tone modifier\n", .{});
    std.debug.print("  - Regional indicators: Flag emojis (two regional indicators)\n", .{});
    std.debug.print("  - ZWJ sequences: Family emojis joined by Zero Width Joiner\n\n", .{});

    // =========================================================================
    // Basic Grapheme Counting
    // =========================================================================

    std.debug.print("=== Basic Grapheme Counting ===\n\n", .{});

    // Simple ASCII
    const ascii = "Hello";
    std.debug.print("'{s}':\n", .{ascii});
    std.debug.print("  Bytes: {}\n", .{ascii.len});
    std.debug.print("  Code points: {?}\n", .{strings.utf8.countCodepoints(ascii)});
    std.debug.print("  Graphemes: {}\n\n", .{strings.grapheme.count(ascii)});

    // Accented character (precomposed)
    const precomposed = "caf\xC3\xA9"; // cafe
    std.debug.print("'{s}' (precomposed e):\n", .{precomposed});
    std.debug.print("  Bytes: {}\n", .{precomposed.len});
    std.debug.print("  Code points: {?}\n", .{strings.utf8.countCodepoints(precomposed)});
    std.debug.print("  Graphemes: {}\n\n", .{strings.grapheme.count(precomposed)});

    // Combining mark (decomposed)
    const decomposed = "cafe\xCC\x81"; // cafe + combining acute
    std.debug.print("'{s}' (e + combining acute):\n", .{decomposed});
    std.debug.print("  Bytes: {}\n", .{decomposed.len});
    std.debug.print("  Code points: {?}\n", .{strings.utf8.countCodepoints(decomposed)});
    std.debug.print("  Graphemes: {} (same visual result!)\n\n", .{strings.grapheme.count(decomposed)});

    // =========================================================================
    // Iterating Over Graphemes
    // =========================================================================

    std.debug.print("=== Iterating Over Grapheme Clusters ===\n\n", .{});

    const text = "Ae\xCC\x81B"; // A + e + combining acute + B = A e B
    std.debug.print("Text: '{s}'\n", .{text});
    std.debug.print("Grapheme clusters:\n", .{});

    var iter = strings.grapheme.iterator(text);
    var i: usize = 0;
    while (iter.next()) |cluster| {
        std.debug.print("  [{d}] '{s}' ({} bytes)\n", .{ i, cluster, cluster.len });
        i += 1;
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Using String.graphemes() and String.graphemeCount()
    // =========================================================================

    std.debug.print("=== Using String Type ===\n\n", .{});

    var str = try strings.String.fromSlice(allocator, "Hello, \xE4\xB8\x96\xE7\x95\x8C!"); // Hello, 世界!
    defer str.deinit();

    std.debug.print("String: {s}\n", .{str.bytes()});
    std.debug.print("Byte length: {}\n", .{str.len()});
    std.debug.print("Code point count: {?}\n", .{str.codepointCount()});
    std.debug.print("Grapheme count: {}\n\n", .{str.graphemeCount()});

    std.debug.print("Grapheme clusters:\n", .{});
    var str_iter = str.graphemes();
    while (str_iter.next()) |cluster| {
        std.debug.print("  '{s}'\n", .{cluster});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // CRLF as Single Grapheme
    // =========================================================================

    std.debug.print("=== CRLF Handling ===\n\n", .{});

    const with_crlf = "Line1\r\nLine2";
    std.debug.print("Text with CRLF: '{s}'\n", .{with_crlf});
    std.debug.print("Code points: {?}\n", .{strings.utf8.countCodepoints(with_crlf)});
    std.debug.print("Graphemes: {}\n", .{strings.grapheme.count(with_crlf)});
    std.debug.print("(CRLF counts as 1 grapheme, not 2)\n\n", .{});

    // =========================================================================
    // Hangul Syllables
    // =========================================================================

    std.debug.print("=== Hangul Syllables ===\n\n", .{});

    // Korean syllables composed of jamo
    const hangul = "\xED\x95\x9C\xEA\xB5\xAD"; // 한국 (Korea)
    std.debug.print("Korean: '{s}'\n", .{hangul});
    std.debug.print("Bytes: {}\n", .{hangul.len});
    std.debug.print("Code points: {?}\n", .{strings.utf8.countCodepoints(hangul)});
    std.debug.print("Graphemes: {}\n\n", .{strings.grapheme.count(hangul)});

    // =========================================================================
    // Indic Scripts (Conjuncts)
    // =========================================================================

    std.debug.print("=== Indic Scripts ===\n\n", .{});

    // Devanagari conjunct: ka + virama + ssa = ksha
    const ksha = "\xe0\xa4\x95\xe0\xa5\x8d\xe0\xa4\xb7"; // क्ष
    std.debug.print("Devanagari 'ksha': '{s}'\n", .{ksha});
    std.debug.print("Code points: {?}\n", .{strings.utf8.countCodepoints(ksha)});
    std.debug.print("Graphemes: {} (conjunct is 1 grapheme)\n\n", .{strings.grapheme.count(ksha)});

    // Tamil with vowel sign
    const tamil = "\xe0\xae\x95\xe0\xae\xbe"; // கா (ka + aa)
    std.debug.print("Tamil 'kaa': '{s}'\n", .{tamil});
    std.debug.print("Code points: {?}\n", .{strings.utf8.countCodepoints(tamil)});
    std.debug.print("Graphemes: {}\n\n", .{strings.grapheme.count(tamil)});

    // =========================================================================
    // Grapheme Break Properties
    // =========================================================================

    std.debug.print("=== Grapheme Break Properties ===\n\n", .{});

    const test_cps = [_]struct { cp: u21, name: []const u8 }{
        .{ .cp = 0x000D, .name = "Carriage Return" },
        .{ .cp = 0x000A, .name = "Line Feed" },
        .{ .cp = 0x200D, .name = "Zero Width Joiner" },
        .{ .cp = 0x0301, .name = "Combining Acute" },
        .{ .cp = 0x1F1FA, .name = "Regional Indicator U" },
        .{ .cp = 'A', .name = "Letter A" },
    };

    for (test_cps) |item| {
        const prop = strings.grapheme.getGraphemeBreak(item.cp);
        std.debug.print("U+{X:0>4} ({s}): {s}\n", .{ item.cp, item.name, @tagName(prop) });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Practical Example: Truncating by Graphemes
    // =========================================================================

    std.debug.print("=== Practical: Safe Truncation ===\n\n", .{});

    // Truncating by bytes can split multi-byte characters!
    const original = "Hello, \xE4\xB8\x96\xE7\x95\x8C!"; // Hello, 世界!

    std.debug.print("Original: '{s}' ({} graphemes)\n", .{ original, strings.grapheme.count(original) });

    // Safe truncation to 8 graphemes
    const max_graphemes: usize = 8;
    var truncate_iter = strings.grapheme.iterator(original);
    var grapheme_count: usize = 0;
    var end_byte: usize = 0;

    while (truncate_iter.next()) |cluster| {
        if (grapheme_count >= max_graphemes) break;
        end_byte += cluster.len;
        grapheme_count += 1;
    }

    const truncated = original[0..end_byte];
    std.debug.print("Truncated to {} graphemes: '{s}'\n\n", .{ max_graphemes, truncated });

    // =========================================================================
    // Practical Example: Grapheme-aware Substring
    // =========================================================================

    std.debug.print("=== Practical: Grapheme-aware Substring ===\n\n", .{});

    const input = "cafe\xCC\x81 is good"; // cafe is good

    // Get graphemes 0-3 (inclusive)
    const start_grapheme: usize = 0;
    const end_grapheme: usize = 4;

    var sub_iter = strings.grapheme.iterator(input);
    var sub_count: usize = 0;
    var sub_start: usize = 0;
    var sub_end: usize = 0;
    var found_start = false;

    while (sub_iter.next()) |cluster| {
        if (sub_count == start_grapheme) {
            sub_start = sub_iter.index - cluster.len;
            found_start = true;
        }
        if (sub_count == end_grapheme) {
            sub_end = sub_iter.index - cluster.len;
            break;
        }
        sub_count += 1;
        if (sub_count > end_grapheme) break;
    }
    if (sub_count >= end_grapheme and sub_end == 0) {
        sub_end = input.len;
    }

    if (found_start) {
        std.debug.print("Original: '{s}'\n", .{input});
        std.debug.print("Graphemes [{d}:{d}]: '{s}'\n\n", .{ start_grapheme, end_grapheme, input[sub_start..sub_end] });
    }

    // =========================================================================
    // Comparing Bytes vs Code Points vs Graphemes
    // =========================================================================

    std.debug.print("=== Bytes vs Code Points vs Graphemes ===\n\n", .{});

    const examples = [_][]const u8{
        "Hello", // ASCII only
        "cafe\xCC\x81", // e with combining mark
        "\xE4\xB8\xAD\xE6\x96\x87", // Chinese: 中文
        "\xED\x95\x9C\xEA\xB5\xAD\xEC\x96\xB4", // Korean: 한국어
    };

    std.debug.print("{s:<20} {s:>6} {s:>6} {s:>8}\n", .{ "Text", "Bytes", "CPs", "Graphemes" });
    std.debug.print("{s}\n", .{"-" ** 42});

    for (examples) |example| {
        std.debug.print("{s:<20} {d:>6} {d:>6} {d:>8}\n", .{
            example,
            example.len,
            strings.utf8.countCodepoints(example) orelse 0,
            strings.grapheme.count(example),
        });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Emoji (Limited Support Note)
    // =========================================================================

    std.debug.print("=== Emoji Handling ===\n\n", .{});

    std.debug.print("Note: Full emoji support (ZWJ sequences, skin tones) requires\n", .{});
    std.debug.print("the complete Unicode Extended_Pictographic property table.\n", .{});
    std.debug.print("This library provides basic emoji support.\n\n", .{});

    // Basic emoji
    const simple_emoji = "\xF0\x9F\x98\x80"; // Grinning face
    std.debug.print("Simple emoji: '{s}'\n", .{simple_emoji});
    std.debug.print("  Bytes: {}, Graphemes: {}\n\n", .{ simple_emoji.len, strings.grapheme.count(simple_emoji) });

    std.debug.print("=== Example Complete ===\n", .{});
}
