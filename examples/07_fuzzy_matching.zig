// SPDX-License-Identifier: Apache-2.0
// Fuzzy String Matching Example
//
// This example demonstrates various fuzzy matching algorithms for
// approximate string matching. Useful for:
// - Spell checking
// - Search suggestions
// - Data deduplication
// - Typo tolerance
//
// Run with: zig build-exe 07_fuzzy_matching.zig --deps strings && ./07_fuzzy_matching

const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // =========================================================================
    // Levenshtein Distance
    // =========================================================================

    std.debug.print("=== Levenshtein Distance ===\n\n", .{});

    std.debug.print("Levenshtein distance counts the minimum number of\n", .{});
    std.debug.print("single-character edits (insertions, deletions, substitutions)\n", .{});
    std.debug.print("needed to transform one string into another.\n\n", .{});

    const lev_examples = [_][2][]const u8{
        .{ "kitten", "sitting" },
        .{ "flaw", "lawn" },
        .{ "hello", "hello" },
        .{ "abc", "def" },
        .{ "", "test" },
    };

    for (lev_examples) |pair| {
        const dist = strings.fuzzy.levenshtein(pair[0], pair[1]);
        std.debug.print("  '{s}' <-> '{s}': {}\n", .{ pair[0], pair[1], dist });
    }
    std.debug.print("\n", .{});

    // Levenshtein similarity (normalized to 0.0-1.0)
    std.debug.print("Normalized similarity:\n", .{});
    const sim = strings.fuzzy.levenshteinSimilarity("hello", "hallo");
    std.debug.print("  'hello' <-> 'hallo': {d:.2}\n\n", .{sim});

    // =========================================================================
    // Damerau-Levenshtein Distance
    // =========================================================================

    std.debug.print("=== Damerau-Levenshtein Distance ===\n\n", .{});

    std.debug.print("Like Levenshtein, but also allows transpositions\n", .{});
    std.debug.print("of adjacent characters as a single operation.\n\n", .{});

    // Transposition example: ab -> ba is 1 edit
    std.debug.print("  'ab' <-> 'ba' (Levenshtein): {}\n", .{strings.fuzzy.levenshtein("ab", "ba")});
    std.debug.print("  'ab' <-> 'ba' (Damerau-Lev): {}\n\n", .{strings.fuzzy.damerauLevenshtein("ab", "ba")});

    const dl_examples = [_][2][]const u8{
        .{ "ca", "abc" },
        .{ "recieve", "receive" }, // Common typo
        .{ "teh", "the" }, // Common transposition
    };

    for (dl_examples) |pair| {
        const dist = strings.fuzzy.damerauLevenshtein(pair[0], pair[1]);
        std.debug.print("  '{s}' <-> '{s}': {}\n", .{ pair[0], pair[1], dist });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Hamming Distance
    // =========================================================================

    std.debug.print("=== Hamming Distance ===\n\n", .{});

    std.debug.print("Hamming distance counts positions where characters differ.\n", .{});
    std.debug.print("Only works for equal-length strings.\n\n", .{});

    if (strings.fuzzy.hamming("karolin", "kathrin")) |dist| {
        std.debug.print("  'karolin' <-> 'kathrin': {}\n", .{dist});
    }
    if (strings.fuzzy.hamming("1011101", "1001001")) |dist| {
        std.debug.print("  '1011101' <-> '1001001': {}\n", .{dist});
    }
    if (strings.fuzzy.hamming("hello", "hi")) |_| {
        std.debug.print("  Should not reach here\n", .{});
    } else {
        std.debug.print("  'hello' <-> 'hi': null (different lengths)\n", .{});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Jaro Similarity
    // =========================================================================

    std.debug.print("=== Jaro Similarity ===\n\n", .{});

    std.debug.print("Jaro similarity is based on matching characters and\n", .{});
    std.debug.print("transpositions. Returns a value from 0.0 to 1.0.\n\n", .{});

    const jaro_examples = [_][2][]const u8{
        .{ "MARTHA", "MARHTA" },
        .{ "DWAYNE", "DUANE" },
        .{ "DIXON", "DICKSONX" },
    };

    for (jaro_examples) |pair| {
        const score = strings.fuzzy.jaro(pair[0], pair[1]);
        std.debug.print("  '{s}' <-> '{s}': {d:.4}\n", .{ pair[0], pair[1], score });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Jaro-Winkler Similarity
    // =========================================================================

    std.debug.print("=== Jaro-Winkler Similarity ===\n\n", .{});

    std.debug.print("Jaro-Winkler gives a boost to strings with common prefixes.\n", .{});
    std.debug.print("This is often better for matching names.\n\n", .{});

    for (jaro_examples) |pair| {
        const jaro = strings.fuzzy.jaro(pair[0], pair[1]);
        const jw = strings.fuzzy.jaroWinkler(pair[0], pair[1]);
        std.debug.print("  '{s}' <-> '{s}':\n", .{ pair[0], pair[1] });
        std.debug.print("    Jaro: {d:.4}, Jaro-Winkler: {d:.4}\n", .{ jaro, jw });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Longest Common Subsequence (LCS)
    // =========================================================================

    std.debug.print("=== Longest Common Subsequence ===\n\n", .{});

    std.debug.print("LCS finds the longest sequence of characters that appear\n", .{});
    std.debug.print("in both strings in the same order (not necessarily contiguous).\n\n", .{});

    const lcs_examples = [_][2][]const u8{
        .{ "AGCAT", "GAC" },
        .{ "abc", "ac" },
        .{ "abcdef", "ace" },
    };

    for (lcs_examples) |pair| {
        const len = strings.fuzzy.lcsLength(pair[0], pair[1]);
        const sim_score = strings.fuzzy.lcsSimilarity(pair[0], pair[1]);
        std.debug.print("  '{s}' <-> '{s}': LCS length={}, similarity={d:.2}\n", .{
            pair[0], pair[1], len, sim_score,
        });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Longest Common Substring
    // =========================================================================

    std.debug.print("=== Longest Common Substring ===\n\n", .{});

    std.debug.print("Unlike LCS, longest common substring must be contiguous.\n\n", .{});

    const substr_examples = [_][2][]const u8{
        .{ "abcdef", "zabcf" },
        .{ "Hello World", "Hello There" },
        .{ "programming", "programmer" },
    };

    for (substr_examples) |pair| {
        const len = strings.fuzzy.longestCommonSubstring(pair[0], pair[1]);
        std.debug.print("  '{s}' <-> '{s}': {}\n", .{ pair[0], pair[1], len });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Cosine Similarity
    // =========================================================================

    std.debug.print("=== Cosine Similarity ===\n\n", .{});

    std.debug.print("Cosine similarity based on character frequency.\n", .{});
    std.debug.print("Good for comparing documents or longer texts.\n\n", .{});

    const cosine_examples = [_][2][]const u8{
        .{ "hello", "hello" },
        .{ "hello", "hallo" },
        .{ "abc", "xyz" },
        .{ "programming", "programmer" },
    };

    for (cosine_examples) |pair| {
        const sim_score = strings.fuzzy.cosineSimilarity(pair[0], pair[1]);
        std.debug.print("  '{s}' <-> '{s}': {d:.4}\n", .{ pair[0], pair[1], sim_score });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // N-gram Similarity
    // =========================================================================

    std.debug.print("=== N-gram Similarity ===\n\n", .{});

    std.debug.print("Compares strings based on shared n-grams (substrings of length n).\n\n", .{});

    const ngram_pairs = [_][2][]const u8{
        .{ "night", "nacht" },
        .{ "hello", "hallo" },
    };

    for (ngram_pairs) |pair| {
        const sim2 = try strings.fuzzy.ngramSimilarity(allocator, pair[0], pair[1], 2);
        const sim3 = try strings.fuzzy.ngramSimilarity(allocator, pair[0], pair[1], 3);
        std.debug.print("  '{s}' <-> '{s}':\n", .{ pair[0], pair[1] });
        std.debug.print("    2-gram: {d:.4}, 3-gram: {d:.4}\n", .{ sim2, sim3 });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Fuzzy Search
    // =========================================================================

    std.debug.print("=== Fuzzy Search ===\n\n", .{});

    const fruits = [_][]const u8{
        "apple",
        "apricot",
        "banana",
        "blueberry",
        "cherry",
        "grape",
        "grapefruit",
        "mango",
        "orange",
        "pineapple",
    };

    std.debug.print("Searching for 'aple' (typo for 'apple') in fruit list:\n", .{});
    const results = try strings.fuzzy.fuzzySearch(allocator, "aple", &fruits, 5);
    defer allocator.free(results);

    for (results, 0..) |match, i| {
        std.debug.print("  {d}. '{s}' (score: {d:.4})\n", .{ i + 1, match.text, match.score });
    }
    std.debug.print("\n", .{});

    // Search with threshold
    std.debug.print("Search with minimum score threshold (0.7):\n", .{});
    const threshold_results = try strings.fuzzy.fuzzySearchThreshold(allocator, "grape", &fruits, 0.7);
    defer allocator.free(threshold_results);

    for (threshold_results, 0..) |match, i| {
        std.debug.print("  {d}. '{s}' (score: {d:.4})\n", .{ i + 1, match.text, match.score });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Auto Algorithm Selection
    // =========================================================================

    std.debug.print("=== Auto Algorithm Selection ===\n\n", .{});

    std.debug.print("The library can recommend the best algorithm based on input:\n\n", .{});

    const auto_examples = [_][2][]const u8{
        .{ "hi", "ho" }, // Short strings
        .{ "hello world", "hallo welt" }, // Medium strings
        .{ "a", "a" }, // Same length
    };

    for (auto_examples) |pair| {
        const recommended = strings.fuzzy.recommendAlgorithm(pair[0], pair[1]);
        const auto_sim = strings.fuzzy.autoSimilarity(pair[0], pair[1]);
        std.debug.print("  '{s}' <-> '{s}':\n", .{ pair[0], pair[1] });
        std.debug.print("    Recommended: {s}, Similarity: {d:.4}\n", .{ @tagName(recommended), auto_sim });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Practical: Spell Checker
    // =========================================================================

    std.debug.print("=== Practical: Simple Spell Checker ===\n\n", .{});

    const dictionary = [_][]const u8{
        "accommodation",
        "acknowledge",
        "acquire",
        "address",
        "beginning",
        "believe",
        "calendar",
        "category",
        "committee",
        "definitely",
        "environment",
        "government",
        "immediately",
        "necessary",
        "occurrence",
        "receive",
        "recommend",
        "separate",
        "successful",
        "tomorrow",
    };

    const typos = [_][]const u8{
        "accomodation", // Missing 'm'
        "begining", // Missing 'n'
        "recieve", // i before e
        "seperate", // a instead of a
        "tommorow", // Extra 'm'
    };

    std.debug.print("Correcting common misspellings:\n", .{});
    for (typos) |typo| {
        const suggestions = try strings.fuzzy.fuzzySearch(allocator, typo, &dictionary, 1);
        defer allocator.free(suggestions);

        if (suggestions.len > 0) {
            std.debug.print("  '{s}' -> '{s}' (score: {d:.2})\n", .{
                typo,
                suggestions[0].text,
                suggestions[0].score,
            });
        }
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Practical: Data Deduplication
    // =========================================================================

    std.debug.print("=== Practical: Data Deduplication ===\n\n", .{});

    const records = [_][]const u8{
        "John Smith",
        "Jon Smith",
        "John Smyth",
        "Jane Doe",
        "Jane Do",
        "Robert Johnson",
        "Bob Johnson",
    };

    std.debug.print("Finding potential duplicates (similarity > 0.8):\n", .{});
    var i: usize = 0;
    while (i < records.len) : (i += 1) {
        var j = i + 1;
        while (j < records.len) : (j += 1) {
            const similarity = strings.fuzzy.jaroWinkler(records[i], records[j]);
            if (similarity > 0.8) {
                std.debug.print("  '{s}' <-> '{s}' ({d:.2})\n", .{
                    records[i],
                    records[j],
                    similarity,
                });
            }
        }
    }
    std.debug.print("\n", .{});

    std.debug.print("=== Example Complete ===\n", .{});
}
