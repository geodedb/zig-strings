// SPDX-License-Identifier: Apache-2.0
// Unicode Collation Example
//
// This example demonstrates the Unicode Collation Algorithm (UTS #10)
// for locale-aware string comparison and sorting. Collation is essential for:
// - Sorting strings in user-expected order
// - Case-insensitive comparison
// - Accent-insensitive comparison
// - Locale-specific ordering
//
// Run with: zig build-exe 08_collation.zig --deps strings && ./08_collation

const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // =========================================================================
    // Understanding Collation Strength
    // =========================================================================

    std.debug.print("=== Understanding Collation Strength ===\n\n", .{});

    std.debug.print("Collation strength determines what differences matter:\n", .{});
    std.debug.print("  - Primary: Base character (a vs b)\n", .{});
    std.debug.print("  - Secondary: Accent differences (a vs a)\n", .{});
    std.debug.print("  - Tertiary: Case differences (a vs A)\n", .{});
    std.debug.print("  - Quaternary: Punctuation\n", .{});
    std.debug.print("  - Identical: Code point differences\n\n", .{});

    // =========================================================================
    // Basic Comparison
    // =========================================================================

    std.debug.print("=== Basic Collation Comparison ===\n\n", .{});

    const default_options = strings.collation.CollationOptions{};

    const pairs = [_][2][]const u8{
        .{ "apple", "banana" },
        .{ "hello", "hello" },
        .{ "zebra", "apple" },
    };

    for (pairs) |pair| {
        const result = strings.collation.compare(pair[0], pair[1], default_options);
        const symbol = switch (result) {
            .lt => "<",
            .eq => "=",
            .gt => ">",
        };
        std.debug.print("  '{s}' {s} '{s}'\n", .{ pair[0], symbol, pair[1] });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Case Sensitivity
    // =========================================================================

    std.debug.print("=== Case Sensitivity ===\n\n", .{});

    // Tertiary strength (default) distinguishes case
    const tertiary = strings.collation.CollationOptions{ .strength = .tertiary };
    // Primary strength ignores case
    const primary = strings.collation.CollationOptions{ .strength = .primary };

    const case_pairs = [_][2][]const u8{
        .{ "hello", "HELLO" },
        .{ "Apple", "apple" },
        .{ "abc", "ABC" },
    };

    std.debug.print("Tertiary (case-sensitive):\n", .{});
    for (case_pairs) |pair| {
        const result = strings.collation.compare(pair[0], pair[1], tertiary);
        const eq = strings.collation.equals(pair[0], pair[1], tertiary);
        std.debug.print("  '{s}' vs '{s}': order={s}, equal={}\n", .{
            pair[0], pair[1], @tagName(result), eq,
        });
    }
    std.debug.print("\n", .{});

    std.debug.print("Primary (case-insensitive):\n", .{});
    for (case_pairs) |pair| {
        const result = strings.collation.compare(pair[0], pair[1], primary);
        const eq = strings.collation.equals(pair[0], pair[1], primary);
        std.debug.print("  '{s}' vs '{s}': order={s}, equal={}\n", .{
            pair[0], pair[1], @tagName(result), eq,
        });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Accent Sensitivity
    // =========================================================================

    std.debug.print("=== Accent Sensitivity ===\n\n", .{});

    // Secondary strength distinguishes accents but not case
    const secondary = strings.collation.CollationOptions{ .strength = .secondary };

    const accent_pairs = [_][2][]const u8{
        .{ "cafe", "caf\xC3\xA9" }, // cafe vs cafe
        .{ "resume", "r\xC3\xA9sum\xC3\xA9" }, // resume vs resume
        .{ "naive", "na\xC3\xAFve" }, // naive vs naive
    };

    std.debug.print("Secondary (accent-sensitive, case-insensitive):\n", .{});
    for (accent_pairs) |pair| {
        const eq = strings.collation.equals(pair[0], pair[1], secondary);
        std.debug.print("  '{s}' vs '{s}': equal={}\n", .{ pair[0], pair[1], eq });
    }
    std.debug.print("\n", .{});

    std.debug.print("Primary (accent-insensitive, case-insensitive):\n", .{});
    for (accent_pairs) |pair| {
        const eq = strings.collation.equals(pair[0], pair[1], primary);
        std.debug.print("  '{s}' vs '{s}': equal={}\n", .{ pair[0], pair[1], eq });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Sort Keys
    // =========================================================================

    std.debug.print("=== Sort Keys ===\n\n", .{});

    std.debug.print("Sort keys allow efficient repeated comparisons.\n", .{});
    std.debug.print("Compare sort keys with memcmp instead of full collation.\n\n", .{});

    const words = [_][]const u8{ "apple", "Banana", "cherry" };
    const options = strings.collation.CollationOptions{ .strength = .primary };

    std.debug.print("Sort keys (primary strength):\n", .{});
    for (words) |word| {
        const key = try strings.collation.getSortKey(allocator, word, options);
        defer allocator.free(key);

        std.debug.print("  '{s}': ", .{word});
        for (key) |byte| {
            std.debug.print("{X:0>2} ", .{byte});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});

    // Sort keys can be compared with memcmp
    const key1 = try strings.collation.getSortKey(allocator, "apple", options);
    defer allocator.free(key1);
    const key2 = try strings.collation.getSortKey(allocator, "banana", options);
    defer allocator.free(key2);

    std.debug.print("Comparing sort keys with std.mem.lessThan:\n", .{});
    std.debug.print("  'apple' < 'banana': {}\n\n", .{std.mem.lessThan(u8, key1, key2)});

    // =========================================================================
    // Collation Elements
    // =========================================================================

    std.debug.print("=== Collation Elements ===\n\n", .{});

    std.debug.print("Each character maps to collation elements with weights.\n\n", .{});

    const chars = [_]u21{ 'a', 'A', '\xE9', '1', ' ' };
    const char_names = [_][]const u8{ "a", "A", "e", "1", "space" };

    for (chars, char_names) |cp, name| {
        const elem = strings.collation.getCollationElement(cp);
        std.debug.print("  '{s}' (U+{X:0>4}): primary={X:0>4}, secondary={X:0>4}, tertiary={X:0>4}\n", .{
            name, cp, elem.primary, elem.secondary, elem.tertiary,
        });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Practical Example: Sorting a List
    // =========================================================================

    std.debug.print("=== Practical: Sorting a List ===\n\n", .{});

    var names = [_][]const u8{
        "Charlie",
        "alice",
        "Bob",
        "DIANA",
        "eve",
    };

    std.debug.print("Original order:\n", .{});
    for (names) |name| {
        std.debug.print("  {s}\n", .{name});
    }
    std.debug.print("\n", .{});

    // Sort with case-insensitive collation
    const sort_options = strings.collation.CollationOptions{ .strength = .primary };

    std.mem.sort([]const u8, &names, sort_options, struct {
        pub fn lessThan(opts: strings.collation.CollationOptions, a: []const u8, b: []const u8) bool {
            return strings.collation.compare(a, b, opts) == .lt;
        }
    }.lessThan);

    std.debug.print("Sorted (case-insensitive):\n", .{});
    for (names) |name| {
        std.debug.print("  {s}\n", .{name});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Practical Example: Dictionary Lookup
    // =========================================================================

    std.debug.print("=== Practical: Dictionary Lookup ===\n\n", .{});

    const dictionary = [_][]const u8{
        "caf\xC3\xA9",
        "naive",
        "r\xC3\xA9sum\xC3\xA9",
        "touch\xC3\xA9",
    };

    const lookups = [_][]const u8{
        "cafe", // Should match cafe
        "naive", // Should match naive
        "RESUME", // Should match resume
    };

    const lookup_options = strings.collation.CollationOptions{ .strength = .primary };

    for (lookups) |lookup| {
        std.debug.print("Looking up '{s}':\n", .{lookup});
        var found = false;
        for (dictionary) |entry| {
            if (strings.collation.equals(lookup, entry, lookup_options)) {
                std.debug.print("  Found: {s}\n", .{entry});
                found = true;
            }
        }
        if (!found) {
            std.debug.print("  Not found\n", .{});
        }
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Comparison with Simple Methods
    // =========================================================================

    std.debug.print("=== Comparison: Collation vs Simple Methods ===\n\n", .{});

    const test_str1 = "caf\xC3\xA9"; // cafe with accent
    const test_str2 = "cafe"; // cafe without accent

    std.debug.print("Comparing '{s}' and '{s}':\n", .{ test_str1, test_str2 });

    // Byte comparison
    std.debug.print("  Byte-equal: {}\n", .{std.mem.eql(u8, test_str1, test_str2)});

    // Collation primary (ignores accents)
    const coll_primary = strings.collation.CollationOptions{ .strength = .primary };
    std.debug.print("  Collation primary equal: {}\n", .{
        strings.collation.equals(test_str1, test_str2, coll_primary),
    });

    // Collation secondary (distinguishes accents)
    const coll_secondary = strings.collation.CollationOptions{ .strength = .secondary };
    std.debug.print("  Collation secondary equal: {}\n\n", .{
        strings.collation.equals(test_str1, test_str2, coll_secondary),
    });

    // =========================================================================
    // When to Use Collation
    // =========================================================================

    std.debug.print("=== When to Use Collation ===\n\n", .{});

    std.debug.print("Use collation when:\n", .{});
    std.debug.print("  - Sorting user-visible lists (names, titles)\n", .{});
    std.debug.print("  - Case-insensitive search/comparison\n", .{});
    std.debug.print("  - Accent-insensitive matching\n", .{});
    std.debug.print("  - Locale-specific ordering\n\n", .{});

    std.debug.print("Use byte comparison when:\n", .{});
    std.debug.print("  - Exact matching is required\n", .{});
    std.debug.print("  - Performance is critical\n", .{});
    std.debug.print("  - Data is already normalized\n", .{});
    std.debug.print("  - Internal identifiers/keys\n\n", .{});

    std.debug.print("=== Example Complete ===\n", .{});
}
