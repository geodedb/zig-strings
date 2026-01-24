// SPDX-License-Identifier: Apache-2.0
// Basic String Operations Example
//
// This example demonstrates the core String type with Small String Optimization (SSO),
// basic string operations, and common manipulation patterns.
//
// Run with: zig build-exe 01_basic_strings.zig --deps strings && ./01_basic_strings

const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    // Use a general purpose allocator for this example
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // =========================================================================
    // Creating Strings
    // =========================================================================

    std.debug.print("=== Creating Strings ===\n\n", .{});

    // Create a string from a slice (makes a copy)
    var str = try strings.String.fromSlice(allocator, "Hello, World!");
    defer str.deinit();

    std.debug.print("String: {s}\n", .{str.bytes()});
    std.debug.print("Length (bytes): {}\n", .{str.len()});
    std.debug.print("Is inline (SSO): {}\n\n", .{str.isInline()});

    // Small String Optimization (SSO): strings <= 23 bytes are stored inline
    // This avoids heap allocation for small strings
    var small = try strings.String.fromSlice(allocator, "Small!");
    defer small.deinit();
    std.debug.print("Small string '{s}' is inline: {}\n", .{ small.bytes(), small.isInline() });

    // Strings > 23 bytes use heap allocation
    var large = try strings.String.fromSlice(allocator, "This is a much longer string that exceeds SSO capacity");
    defer large.deinit();
    std.debug.print("Large string is inline: {} (len={})\n\n", .{ large.isInline(), large.len() });

    // =========================================================================
    // String Properties
    // =========================================================================

    std.debug.print("=== String Properties ===\n\n", .{});

    var unicode_str = try strings.String.fromSlice(allocator, "Hello, 世界!");
    defer unicode_str.deinit();

    std.debug.print("String: {s}\n", .{unicode_str.bytes()});
    std.debug.print("Byte length: {}\n", .{unicode_str.len()});
    std.debug.print("Code point count: {?}\n", .{unicode_str.codepointCount()});
    std.debug.print("Grapheme count: {}\n", .{unicode_str.graphemeCount()});
    std.debug.print("Is empty: {}\n\n", .{unicode_str.isEmpty()});

    // =========================================================================
    // Search Operations
    // =========================================================================

    std.debug.print("=== Search Operations ===\n\n", .{});

    var text = try strings.String.fromSlice(allocator, "The quick brown fox jumps over the lazy dog");
    defer text.deinit();

    std.debug.print("Text: {s}\n\n", .{text.bytes()});

    // Contains
    std.debug.print("Contains 'fox': {}\n", .{text.contains("fox")});
    std.debug.print("Contains 'cat': {}\n\n", .{text.contains("cat")});

    // Find positions
    std.debug.print("Index of 'quick': {?}\n", .{text.indexOf("quick")});
    std.debug.print("Index of 'the': {?}\n", .{text.indexOf("the")});
    std.debug.print("Last index of 'the': {?}\n\n", .{text.lastIndexOf("the")});

    // Starts/ends with
    std.debug.print("Starts with 'The': {}\n", .{text.startsWith("The")});
    std.debug.print("Ends with 'dog': {}\n", .{text.endsWith("dog")});
    std.debug.print("Ends with 'cat': {}\n\n", .{text.endsWith("cat")});

    // Count occurrences
    std.debug.print("Count of 'the': {}\n\n", .{text.count("the")});

    // =========================================================================
    // Comparison Operations
    // =========================================================================

    std.debug.print("=== Comparison Operations ===\n\n", .{});

    var s1 = try strings.String.fromSlice(allocator, "Hello");
    defer s1.deinit();
    var s2 = try strings.String.fromSlice(allocator, "hello");
    defer s2.deinit();

    std.debug.print("'{s}' == '{s}': {}\n", .{ s1.bytes(), s1.bytes(), s1.eql("Hello") });
    std.debug.print("'{s}' == '{s}' (case-sensitive): {}\n", .{ s1.bytes(), s2.bytes(), s1.eql(s2.bytes()) });
    std.debug.print("'{s}' == '{s}' (case-insensitive): {}\n\n", .{ s1.bytes(), s2.bytes(), s1.eqlIgnoreCase(s2.bytes()) });

    // =========================================================================
    // Concatenation and Appending
    // =========================================================================

    std.debug.print("=== Concatenation ===\n\n", .{});

    var greeting = try strings.String.fromSlice(allocator, "Hello");
    defer greeting.deinit();

    // Append modifies in place
    try greeting.append(", ");
    try greeting.append("World!");
    std.debug.print("After append: {s}\n", .{greeting.bytes()});

    // Concat creates a new string
    var part1 = try strings.String.fromSlice(allocator, "Foo");
    defer part1.deinit();
    var combined = try part1.concat("Bar");
    defer combined.deinit();
    std.debug.print("Concatenated: {s}\n\n", .{combined.bytes()});

    // Repeat a string
    var dash = try strings.String.fromSlice(allocator, "-");
    defer dash.deinit();
    var separator = try dash.repeat(20);
    defer separator.deinit();
    std.debug.print("Separator: {s}\n\n", .{separator.bytes()});

    // =========================================================================
    // Transformation Operations
    // =========================================================================

    std.debug.print("=== Transformations ===\n\n", .{});

    var mixed = try strings.String.fromSlice(allocator, "Hello, World!");
    defer mixed.deinit();

    var lower = try mixed.toLower();
    defer lower.deinit();
    std.debug.print("Lowercase: {s}\n", .{lower.bytes()});

    var upper = try mixed.toUpper();
    defer upper.deinit();
    std.debug.print("Uppercase: {s}\n", .{upper.bytes()});

    var title = try strings.String.fromSlice(allocator, "hello world");
    defer title.deinit();
    var titled = try title.toTitle();
    defer titled.deinit();
    std.debug.print("Title case: {s}\n\n", .{titled.bytes()});

    // Trimming
    var padded = try strings.String.fromSlice(allocator, "   Hello, World!   ");
    defer padded.deinit();
    var trimmed = try padded.trimmed();
    defer trimmed.deinit();
    std.debug.print("Original: '{s}'\n", .{padded.bytes()});
    std.debug.print("Trimmed: '{s}'\n\n", .{trimmed.bytes()});

    // Replacement
    var original = try strings.String.fromSlice(allocator, "Hello, World!");
    defer original.deinit();
    var replaced = try original.replaced("World", "Zig");
    defer replaced.deinit();
    std.debug.print("Original: {s}\n", .{original.bytes()});
    std.debug.print("Replaced: {s}\n\n", .{replaced.bytes()});

    // Reversing (Unicode-aware)
    var forward = try strings.String.fromSlice(allocator, "Hello");
    defer forward.deinit();
    var backward = try forward.reversed();
    defer backward.deinit();
    std.debug.print("Forward: {s}\n", .{forward.bytes()});
    std.debug.print("Reversed: {s}\n\n", .{backward.bytes()});

    // =========================================================================
    // Splitting
    // =========================================================================

    std.debug.print("=== Splitting ===\n\n", .{});

    var csv = try strings.String.fromSlice(allocator, "apple,banana,cherry,date");
    defer csv.deinit();

    const parts = try csv.split(",");
    defer allocator.free(parts);

    std.debug.print("CSV: {s}\n", .{csv.bytes()});
    std.debug.print("Parts:\n", .{});
    for (parts, 0..) |part, i| {
        std.debug.print("  [{d}] {s}\n", .{ i, part });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Substrings
    // =========================================================================

    std.debug.print("=== Substrings ===\n\n", .{});

    var source = try strings.String.fromSlice(allocator, "Hello, World!");
    defer source.deinit();

    // Get substring by code point indices
    const sub1 = source.substring(0, 5);
    std.debug.print("Substring [0:5]: {s}\n", .{sub1});

    const sub2 = source.substring(7, null);
    std.debug.print("Substring [7:end]: {s}\n\n", .{sub2});

    // =========================================================================
    // Iteration
    // =========================================================================

    std.debug.print("=== Iteration ===\n\n", .{});

    var iter_str = try strings.String.fromSlice(allocator, "ABC");
    defer iter_str.deinit();

    std.debug.print("Iterating over '{s}':\n", .{iter_str.bytes()});

    // Iterate over code points
    var cp_iter = iter_str.codepoints();
    while (cp_iter.next()) |cp| {
        std.debug.print("  Code point: U+{X:0>4} ('{u}')\n", .{ cp, @as(u21, cp) });
    }
    std.debug.print("\n", .{});

    // Iterate over grapheme clusters
    var emoji = try strings.String.fromSlice(allocator, "Hi!");
    defer emoji.deinit();

    std.debug.print("Grapheme clusters in '{s}':\n", .{emoji.bytes()});
    var grapheme_iter = emoji.graphemes();
    while (grapheme_iter.next()) |cluster| {
        std.debug.print("  '{s}'\n", .{cluster});
    }
    std.debug.print("\n", .{});

    // Iterate over lines
    var multiline = try strings.String.fromSlice(allocator, "Line 1\nLine 2\nLine 3");
    defer multiline.deinit();

    std.debug.print("Lines:\n", .{});
    var line_iter = multiline.lines();
    var line_num: usize = 1;
    while (line_iter.next()) |line| {
        std.debug.print("  {d}: {s}\n", .{ line_num, line });
        line_num += 1;
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Cloning
    // =========================================================================

    std.debug.print("=== Cloning ===\n\n", .{});

    var orig = try strings.String.fromSlice(allocator, "Original");
    defer orig.deinit();

    var clone = try orig.clone();
    defer clone.deinit();

    std.debug.print("Original: {s}\n", .{orig.bytes()});
    std.debug.print("Clone: {s}\n", .{clone.bytes()});
    std.debug.print("Are they the same memory: {}\n\n", .{orig.bytes().ptr == clone.bytes().ptr});

    std.debug.print("=== Example Complete ===\n", .{});
}
