// SPDX-License-Identifier: Apache-2.0
// Go-style String Functions Example
//
// This example demonstrates Go-style string functions for developers
// familiar with Go's "strings" package. The library provides similar
// APIs for an easier transition.
//
// Run with: zig build-exe 10_go_style.zig --deps strings && ./10_go_style

const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // =========================================================================
    // Search Functions
    // =========================================================================

    std.debug.print("=== Search Functions ===\n\n", .{});

    const text = "Hello, World! Hello, Zig!";

    // Contains
    std.debug.print("Contains:\n", .{});
    std.debug.print("  '{s}' contains 'World': {}\n", .{ text, strings.contains(text, "World") });
    std.debug.print("  '{s}' contains 'Go': {}\n\n", .{ text, strings.contains(text, "Go") });

    // IndexOf / LastIndexOf
    std.debug.print("IndexOf:\n", .{});
    std.debug.print("  indexOf('Hello'): {?}\n", .{strings.indexOf(text, "Hello")});
    std.debug.print("  indexOf('Zig'): {?}\n", .{strings.indexOf(text, "Zig")});
    std.debug.print("  indexOf('missing'): {?}\n\n", .{strings.indexOf(text, "missing")});

    // StartsWith / EndsWith
    std.debug.print("StartsWith/EndsWith:\n", .{});
    std.debug.print("  startsWith('Hello'): {}\n", .{strings.startsWith(text, "Hello")});
    std.debug.print("  endsWith('Zig!'): {}\n\n", .{strings.endsWith(text, "Zig!")});

    // IndexByte
    std.debug.print("IndexByte:\n", .{});
    std.debug.print("  indexByte('o'): {?}\n", .{strings.search.indexByte(text, 'o')});
    std.debug.print("  lastIndexByte('o'): {?}\n\n", .{strings.search.lastIndexByte(text, 'o')});

    // IndexAny
    std.debug.print("IndexAny:\n", .{});
    std.debug.print("  indexAny('aeiou'): {?}\n", .{strings.search.indexAny(text, "aeiou")});
    std.debug.print("  lastIndexAny('aeiou'): {?}\n\n", .{strings.search.lastIndexAny(text, "aeiou")});

    // Count
    std.debug.print("Count:\n", .{});
    std.debug.print("  count('Hello'): {}\n", .{strings.search.count(text, "Hello")});
    std.debug.print("  count('o'): {}\n\n", .{strings.search.count(text, "o")});

    // =========================================================================
    // Case Conversion
    // =========================================================================

    std.debug.print("=== Case Conversion ===\n\n", .{});

    const mixed = "Hello, World!";

    const lower = try strings.toLower(allocator, mixed);
    defer allocator.free(lower);
    std.debug.print("toLower('{s}'): {s}\n", .{ mixed, lower });

    const upper = try strings.toUpper(allocator, mixed);
    defer allocator.free(upper);
    std.debug.print("toUpper('{s}'): {s}\n", .{ mixed, upper });

    const title = try strings.toTitle(allocator, "hello world");
    defer allocator.free(title);
    std.debug.print("toTitle('hello world'): {s}\n\n", .{title});

    // Case-insensitive comparison
    std.debug.print("Case-insensitive comparison:\n", .{});
    std.debug.print("  equalsIgnoreCase('Hello', 'HELLO'): {}\n", .{strings.equalsIgnoreCase("Hello", "HELLO")});
    std.debug.print("  equalsIgnoreCase('Hello', 'World'): {}\n\n", .{strings.equalsIgnoreCase("Hello", "World")});

    // =========================================================================
    // Trimming
    // =========================================================================

    std.debug.print("=== Trimming ===\n\n", .{});

    const padded = "   Hello, World!   ";

    // Trim whitespace from both ends
    const trimmed = strings.trim(padded);
    std.debug.print("trim('{s}'): '{s}'\n\n", .{ padded, trimmed });

    // Using manipulation module for more options
    std.debug.print("Additional trim functions:\n", .{});
    std.debug.print("  trimLeft: '{s}'\n", .{strings.manipulation.trimLeft(padded)});
    std.debug.print("  trimRight: '{s}'\n\n", .{strings.manipulation.trimRight(padded)});

    // =========================================================================
    // Split and Join
    // =========================================================================

    std.debug.print("=== Split and Join ===\n\n", .{});

    // Split
    const csv = "apple,banana,cherry,date";
    const parts = try strings.split(allocator, csv, ",");
    defer allocator.free(parts);

    std.debug.print("split('{s}', ','):\n", .{csv});
    for (parts, 0..) |part, i| {
        std.debug.print("  [{d}] {s}\n", .{ i, part });
    }
    std.debug.print("\n", .{});

    // Join
    const join_parts = [_][]const u8{ "one", "two", "three" };
    const joined = try strings.join(allocator, &join_parts, ", ");
    defer allocator.free(joined);
    std.debug.print("join(['one', 'two', 'three'], ', '): {s}\n\n", .{joined});

    // =========================================================================
    // Replace
    // =========================================================================

    std.debug.print("=== Replace ===\n\n", .{});

    const original = "Hello, World! World is great!";
    const replaced = try strings.replace(allocator, original, "World", "Zig");
    defer allocator.free(replaced);

    std.debug.print("Original: {s}\n", .{original});
    std.debug.print("Replaced: {s}\n\n", .{replaced});

    // =========================================================================
    // Unicode-aware Functions
    // =========================================================================

    std.debug.print("=== Unicode-aware Functions ===\n\n", .{});

    // UTF-8 validation
    std.debug.print("isValidUtf8:\n", .{});
    std.debug.print("  'Hello': {}\n", .{strings.isValidUtf8("Hello")});
    std.debug.print("  invalid bytes: {}\n\n", .{strings.isValidUtf8("\xFF\xFE")});

    // Count code points vs graphemes
    const unicode_text = "cafe\xCC\x81"; // cafe with combining accent
    std.debug.print("Text: '{s}'\n", .{unicode_text});
    std.debug.print("  countCodepoints: {?}\n", .{strings.countCodepoints(unicode_text)});
    std.debug.print("  countGraphemes: {}\n\n", .{strings.countGraphemes(unicode_text)});

    // =========================================================================
    // Iterator-based Search
    // =========================================================================

    std.debug.print("=== Find Iterator ===\n\n", .{});

    const search_text = "abcabcabc";
    std.debug.print("Finding all 'abc' in '{s}':\n", .{search_text});

    var find_iter = strings.search.findIter(search_text, "abc");
    while (find_iter.next()) |pos| {
        std.debug.print("  Found at position: {}\n", .{pos});
    }
    std.debug.print("\n", .{});

    // FindAll (returns slice)
    const all_positions = try strings.search.findAll(allocator, search_text, "abc");
    defer allocator.free(all_positions);
    std.debug.print("findAll positions: ", .{});
    for (all_positions) |pos| {
        std.debug.print("{} ", .{pos});
    }
    std.debug.print("\n\n", .{});

    // =========================================================================
    // IndexFunc (predicate-based search)
    // =========================================================================

    std.debug.print("=== IndexFunc (predicate search) ===\n\n", .{});

    const isDigit = struct {
        fn check(cp: strings.Codepoint) bool {
            return cp >= '0' and cp <= '9';
        }
    }.check;

    const mixed_text = "hello123world";
    const digit_pos = strings.search.indexFunc(mixed_text, isDigit);
    std.debug.print("First digit in '{s}': position {?}\n\n", .{ mixed_text, digit_pos });

    // =========================================================================
    // Manipulation Functions
    // =========================================================================

    std.debug.print("=== Manipulation Functions ===\n\n", .{});

    // Repeat
    const repeated = try strings.manipulation.repeat(allocator, "ab", 3);
    defer allocator.free(repeated);
    std.debug.print("repeat('ab', 3): {s}\n", .{repeated});

    // Reverse
    const reversed = try strings.manipulation.reverse(allocator, "Hello");
    defer allocator.free(reversed);
    std.debug.print("reverse('Hello'): {s}\n", .{reversed});

    // Substring (by code point index)
    const unicode_str = "Hello, \xE4\xB8\x96\xE7\x95\x8C!";
    const sub = strings.manipulation.substring(unicode_str, 7, 9);
    std.debug.print("substring('{s}', 7, 9): '{s}'\n\n", .{ unicode_str, sub });

    // =========================================================================
    // Practical Example: Path Manipulation
    // =========================================================================

    std.debug.print("=== Practical: Path Manipulation ===\n\n", .{});

    const path = "/home/user/documents/file.txt";

    // Get filename
    if (strings.search.lastIndexOf(path, "/")) |last_slash| {
        const filename = path[last_slash + 1 ..];
        std.debug.print("Path: {s}\n", .{path});
        std.debug.print("Filename: {s}\n", .{filename});
    }

    // Get extension
    if (strings.search.lastIndexOf(path, ".")) |dot_pos| {
        const ext = path[dot_pos..];
        std.debug.print("Extension: {s}\n\n", .{ext});
    }

    // =========================================================================
    // Practical Example: URL Parsing
    // =========================================================================

    std.debug.print("=== Practical: Simple URL Parsing ===\n\n", .{});

    const url = "https://example.com:8080/path?query=value";
    std.debug.print("URL: {s}\n", .{url});

    // Find protocol
    if (strings.indexOf(url, "://")) |proto_end| {
        const protocol = url[0..proto_end];
        std.debug.print("Protocol: {s}\n", .{protocol});

        // Find host (after :// and before / or :)
        const after_proto = url[proto_end + 3 ..];
        var host_end = after_proto.len;

        if (strings.indexOf(after_proto, "/")) |slash| {
            host_end = @min(host_end, slash);
        }
        if (strings.indexOf(after_proto, ":")) |colon| {
            host_end = @min(host_end, colon);
        }

        const host = after_proto[0..host_end];
        std.debug.print("Host: {s}\n", .{host});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Practical Example: CSV Line Processing
    // =========================================================================

    std.debug.print("=== Practical: CSV Processing ===\n\n", .{});

    const csv_line = "John,Doe,30,Engineer";
    const fields = try strings.split(allocator, csv_line, ",");
    defer allocator.free(fields);

    const field_names = [_][]const u8{ "First Name", "Last Name", "Age", "Occupation" };

    std.debug.print("CSV: {s}\n", .{csv_line});
    for (fields, 0..) |field, i| {
        if (i < field_names.len) {
            std.debug.print("  {s}: {s}\n", .{ field_names[i], field });
        }
    }
    std.debug.print("\n", .{});

    std.debug.print("=== Example Complete ===\n", .{});
}
