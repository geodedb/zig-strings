// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Fuzzy String Matching Algorithms
//!
//! Provides various algorithms for approximate string matching:
//!
//! - **Levenshtein Distance**: Edit distance (insertions, deletions, substitutions)
//! - **Damerau-Levenshtein**: Edit distance including transpositions
//! - **Jaro Similarity**: Based on matching characters and transpositions
//! - **Jaro-Winkler**: Jaro with prefix bonus
//! - **Longest Common Subsequence (LCS)**: Longest non-contiguous match
//! - **Longest Common Substring**: Longest contiguous match
//! - **Hamming Distance**: For equal-length strings
//! - **Cosine Similarity**: Based on character/n-gram frequency
//! - **Fuzzy Search**: Find best matches in a list
//!
//! Usage:
//! ```zig
//! const dist = levenshtein("kitten", "sitting");
//! // dist = 3
//!
//! const similarity = jaroWinkler("MARTHA", "MARHTA");
//! // similarity = 0.961
//!
//! const matches = try fuzzySearch(allocator, "apple", &.{"apply", "maple", "banana"}, 3);
//! // Returns top 3 matches sorted by similarity
//! ```

const std = @import("std");
const unicode = std.unicode;

/// Maximum input length for stack-based Jaro/Jaro-Winkler computation.
/// Inputs exceeding this length cause `jaro()` and `jaroWinkler()` to return 0.0.
const MAX_JARO_LEN = 256;

/// Maximum input length for stack-based Levenshtein, LCS, and longest-common-substring
/// computation. Inputs longer than `MAX_STACK_LEN - 1` (1023) bytes are silently truncated
/// via `@min`. For longer inputs, use the allocator-backed variants (e.g. `levenshteinAlloc`).
const MAX_STACK_LEN = 1024;

/// Maximum input length for the full Damerau-Levenshtein (with transpositions) algorithm.
/// For inputs longer than this, `damerauLevenshtein()` falls back to standard Levenshtein
/// distance, which does not count transpositions as a single edit.
const MAX_DAMERAU_LEN = 32;

/// Result of a fuzzy search
pub const FuzzyMatch = struct {
    /// The matched string
    text: []const u8,
    /// Similarity score (0.0 to 1.0)
    score: f64,
    /// Original index in the input list
    index: usize,

    /// Compare for sorting (higher score first)
    pub fn lessThan(_: void, a: FuzzyMatch, b: FuzzyMatch) bool {
        return a.score > b.score;
    }
};

/// Calculate Levenshtein edit distance between two strings.
/// Returns the minimum number of single-character edits (insertions,
/// deletions, or substitutions) needed to transform one string into another.
///
/// **Stack-size limit:** inputs longer than `MAX_STACK_LEN - 1` (1023) bytes
/// are silently truncated to 1023 bytes before comparison. For longer inputs,
/// use `levenshteinAlloc`, which heap-allocates its working memory.
pub fn levenshtein(a: []const u8, b: []const u8) usize {
    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;

    // Use two-row optimization
    var prev_row: [MAX_STACK_LEN]usize = undefined;
    var curr_row: [MAX_STACK_LEN]usize = undefined;

    const m = @min(a.len, prev_row.len - 1);
    const n = @min(b.len, curr_row.len - 1);

    // Initialize first row
    for (0..n + 1) |j| {
        prev_row[j] = j;
    }

    // Fill in the rest
    for (0..m) |i| {
        curr_row[0] = i + 1;

        for (0..n) |j| {
            const cost: usize = if (a[i] == b[j]) 0 else 1;

            curr_row[j + 1] = @min(
                @min(
                    prev_row[j + 1] + 1, // deletion
                    curr_row[j] + 1, // insertion
                ),
                prev_row[j] + cost, // substitution
            );
        }

        // Swap rows
        const tmp = prev_row;
        prev_row = curr_row;
        curr_row = tmp;
    }

    return prev_row[n];
}

/// Calculate Levenshtein distance with allocator (for large strings)
pub fn levenshteinAlloc(allocator: std.mem.Allocator, a: []const u8, b: []const u8) !usize {
    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;

    // Ensure a is the shorter string for space efficiency
    const s1 = if (a.len <= b.len) a else b;
    const s2 = if (a.len <= b.len) b else a;

    var prev_row = try allocator.alloc(usize, s2.len + 1);
    defer allocator.free(prev_row);
    var curr_row = try allocator.alloc(usize, s2.len + 1);
    defer allocator.free(curr_row);

    // Initialize first row
    for (0..s2.len + 1) |j| {
        prev_row[j] = j;
    }

    // Fill in the rest
    for (0..s1.len) |i| {
        curr_row[0] = i + 1;

        for (0..s2.len) |j| {
            const cost: usize = if (s1[i] == s2[j]) 0 else 1;

            curr_row[j + 1] = @min(
                @min(
                    prev_row[j + 1] + 1,
                    curr_row[j] + 1,
                ),
                prev_row[j] + cost,
            );
        }

        // Swap rows
        const tmp = prev_row;
        prev_row = curr_row;
        curr_row = tmp;
    }

    return prev_row[s2.len];
}

/// Calculate Damerau-Levenshtein distance.
/// Like Levenshtein, but also allows transpositions of adjacent characters.
///
/// **Fallback behaviour:** for inputs longer than `MAX_DAMERAU_LEN` (32) bytes,
/// the function falls back to standard Levenshtein distance, which does **not**
/// count transpositions of adjacent characters as a single edit. Callers needing
/// true Damerau-Levenshtein distance for longer strings should implement a
/// heap-allocated version.
pub fn damerauLevenshtein(a: []const u8, b: []const u8) usize {
    if (a.len == 0) return b.len;
    if (b.len == 0) return a.len;

    const m = a.len;
    const n = b.len;

    // Use fixed-size arrays for small strings
    if (m <= MAX_DAMERAU_LEN and n <= MAX_DAMERAU_LEN) {
        var d: [MAX_DAMERAU_LEN + 1][MAX_DAMERAU_LEN + 1]usize = undefined;

        for (0..m + 1) |i| {
            d[i][0] = i;
        }
        for (0..n + 1) |j| {
            d[0][j] = j;
        }

        for (1..m + 1) |i| {
            for (1..n + 1) |j| {
                const cost: usize = if (a[i - 1] == b[j - 1]) 0 else 1;

                d[i][j] = @min(
                    @min(
                        d[i - 1][j] + 1, // deletion
                        d[i][j - 1] + 1, // insertion
                    ),
                    d[i - 1][j - 1] + cost, // substitution
                );

                // Transposition
                if (i > 1 and j > 1 and a[i - 1] == b[j - 2] and a[i - 2] == b[j - 1]) {
                    d[i][j] = @min(d[i][j], d[i - 2][j - 2] + cost);
                }
            }
        }

        return d[m][n];
    }

    // Fall back to Levenshtein for large strings
    return levenshtein(a, b);
}

/// Calculate Hamming distance between two equal-length strings.
/// Returns the number of positions where corresponding characters differ.
pub fn hamming(a: []const u8, b: []const u8) ?usize {
    if (a.len != b.len) return null;

    var distance: usize = 0;
    for (a, b) |ca, cb| {
        if (ca != cb) distance += 1;
    }
    return distance;
}

/// Calculate Jaro similarity between two strings.
/// Returns a value between 0.0 (no similarity) and 1.0 (identical).
///
/// **Stack-size limit:** if either input exceeds `MAX_JARO_LEN` (256) bytes,
/// the function returns 0.0 instead of risking an out-of-bounds write on the
/// fixed-size match arrays. Use a heap-allocated implementation for longer inputs.
pub fn jaro(a: []const u8, b: []const u8) f64 {
    if (a.len == 0 and b.len == 0) return 1.0;
    if (a.len == 0 or b.len == 0) return 0.0;

    // Guard: inputs must fit in fixed-size match arrays
    if (a.len > MAX_JARO_LEN or b.len > MAX_JARO_LEN) return 0.0;

    const match_distance = @max(a.len, b.len) / 2;
    if (match_distance == 0) {
        return if (a[0] == b[0]) 1.0 else 0.0;
    }

    var a_matches: [MAX_JARO_LEN]bool = [_]bool{false} ** MAX_JARO_LEN;
    var b_matches: [MAX_JARO_LEN]bool = [_]bool{false} ** MAX_JARO_LEN;

    var matches: f64 = 0;
    var transpositions: f64 = 0;

    // Find matches
    for (0..a.len) |i| {
        const start = if (i > match_distance) i - match_distance else 0;
        const end = @min(i + match_distance + 1, b.len);

        for (start..end) |j| {
            if (b_matches[j] or a[i] != b[j]) continue;
            a_matches[i] = true;
            b_matches[j] = true;
            matches += 1;
            break;
        }
    }

    if (matches == 0) return 0.0;

    // Count transpositions
    var k: usize = 0;
    for (0..a.len) |i| {
        if (!a_matches[i]) continue;
        while (!b_matches[k]) k += 1;
        if (a[i] != b[k]) transpositions += 1;
        k += 1;
    }

    const m = matches;
    const t = transpositions / 2.0;
    const al: f64 = @floatFromInt(a.len);
    const bl: f64 = @floatFromInt(b.len);

    return (m / al + m / bl + (m - t) / m) / 3.0;
}

/// Calculate Jaro-Winkler similarity.
/// Like Jaro, but gives a boost to strings that share a common prefix.
pub fn jaroWinkler(a: []const u8, b: []const u8) f64 {
    const jaro_sim = jaro(a, b);

    // Find common prefix length (up to 4 characters)
    var prefix_len: usize = 0;
    const max_prefix = @min(@min(a.len, b.len), 4);
    for (0..max_prefix) |i| {
        if (a[i] == b[i]) {
            prefix_len += 1;
        } else {
            break;
        }
    }

    // Winkler modification
    const p: f64 = 0.1; // Scaling factor
    const l: f64 = @floatFromInt(prefix_len);

    return jaro_sim + l * p * (1.0 - jaro_sim);
}

/// Calculate normalized Levenshtein similarity (0.0 to 1.0).
pub fn levenshteinSimilarity(a: []const u8, b: []const u8) f64 {
    if (a.len == 0 and b.len == 0) return 1.0;

    const distance = levenshtein(a, b);
    const max_len: f64 = @floatFromInt(@max(a.len, b.len));

    return 1.0 - (@as(f64, @floatFromInt(distance)) / max_len);
}

/// Find the longest common subsequence length.
///
/// **Stack-size limit:** inputs longer than `MAX_STACK_LEN - 1` (1023) bytes
/// are silently truncated to 1023 bytes before comparison.
pub fn lcsLength(a: []const u8, b: []const u8) usize {
    if (a.len == 0 or b.len == 0) return 0;

    // Use two-row optimization
    var prev_row: [MAX_STACK_LEN]usize = [_]usize{0} ** MAX_STACK_LEN;
    var curr_row: [MAX_STACK_LEN]usize = [_]usize{0} ** MAX_STACK_LEN;

    const m = @min(a.len, prev_row.len);
    const n = @min(b.len, curr_row.len);

    for (0..m) |i| {
        for (0..n) |j| {
            if (a[i] == b[j]) {
                curr_row[j + 1] = prev_row[j] + 1;
            } else {
                curr_row[j + 1] = @max(prev_row[j + 1], curr_row[j]);
            }
        }

        const tmp = prev_row;
        prev_row = curr_row;
        curr_row = tmp;
        for (&curr_row) |*c| c.* = 0;
    }

    return prev_row[n];
}

/// Calculate LCS similarity (0.0 to 1.0).
pub fn lcsSimilarity(a: []const u8, b: []const u8) f64 {
    if (a.len == 0 and b.len == 0) return 1.0;
    if (a.len == 0 or b.len == 0) return 0.0;

    const lcs = lcsLength(a, b);
    const max_len: f64 = @floatFromInt(@max(a.len, b.len));

    return @as(f64, @floatFromInt(lcs)) / max_len;
}

/// Find the longest common substring length.
///
/// **Stack-size limit:** inputs longer than `MAX_STACK_LEN - 1` (1023) bytes
/// are silently truncated to 1023 bytes before comparison.
pub fn longestCommonSubstring(a: []const u8, b: []const u8) usize {
    if (a.len == 0 or b.len == 0) return 0;

    var max_len: usize = 0;
    var prev_row: [MAX_STACK_LEN]usize = [_]usize{0} ** MAX_STACK_LEN;
    var curr_row: [MAX_STACK_LEN]usize = [_]usize{0} ** MAX_STACK_LEN;

    const m = @min(a.len, prev_row.len);
    const n = @min(b.len, curr_row.len);

    for (0..m) |i| {
        for (0..n) |j| {
            if (a[i] == b[j]) {
                const val = if (j > 0) prev_row[j - 1] + 1 else 1;
                curr_row[j] = val;
                max_len = @max(max_len, val);
            } else {
                curr_row[j] = 0;
            }
        }

        const tmp = prev_row;
        prev_row = curr_row;
        curr_row = tmp;
    }

    return max_len;
}

/// Calculate cosine similarity based on character frequency.
pub fn cosineSimilarity(a: []const u8, b: []const u8) f64 {
    if (a.len == 0 and b.len == 0) return 1.0;
    if (a.len == 0 or b.len == 0) return 0.0;

    // Count character frequencies
    var freq_a: [256]usize = [_]usize{0} ** 256;
    var freq_b: [256]usize = [_]usize{0} ** 256;

    for (a) |c| freq_a[c] += 1;
    for (b) |c| freq_b[c] += 1;

    // Calculate dot product and magnitudes
    var dot_product: f64 = 0;
    var mag_a: f64 = 0;
    var mag_b: f64 = 0;

    for (0..256) |i| {
        const fa: f64 = @floatFromInt(freq_a[i]);
        const fb: f64 = @floatFromInt(freq_b[i]);
        dot_product += fa * fb;
        mag_a += fa * fa;
        mag_b += fb * fb;
    }

    if (mag_a == 0 or mag_b == 0) return 0.0;

    return dot_product / (@sqrt(mag_a) * @sqrt(mag_b));
}

/// N-gram based similarity
pub fn ngramSimilarity(allocator: std.mem.Allocator, a: []const u8, b: []const u8, n: usize) !f64 {
    if (n == 0) return 0.0;
    if (a.len < n and b.len < n) return if (std.mem.eql(u8, a, b)) 1.0 else 0.0;
    if (a.len < n or b.len < n) return 0.0;

    // Build n-gram sets
    var ngrams_a = std.StringHashMap(usize).init(allocator);
    defer ngrams_a.deinit();
    var ngrams_b = std.StringHashMap(usize).init(allocator);
    defer ngrams_b.deinit();

    // Count n-grams in a
    var i: usize = 0;
    while (i + n <= a.len) : (i += 1) {
        const ngram = a[i .. i + n];
        const entry = try ngrams_a.getOrPut(ngram);
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }

    // Count n-grams in b
    i = 0;
    while (i + n <= b.len) : (i += 1) {
        const ngram = b[i .. i + n];
        const entry = try ngrams_b.getOrPut(ngram);
        if (!entry.found_existing) {
            entry.value_ptr.* = 0;
        }
        entry.value_ptr.* += 1;
    }

    // Calculate Jaccard-like similarity
    var intersection: usize = 0;
    var total_a: usize = 0;
    var total_b: usize = 0;

    var it = ngrams_a.iterator();
    while (it.next()) |entry| {
        total_a += entry.value_ptr.*;
        if (ngrams_b.get(entry.key_ptr.*)) |count_b| {
            intersection += @min(entry.value_ptr.*, count_b);
        }
    }

    var it_b = ngrams_b.iterator();
    while (it_b.next()) |entry| {
        total_b += entry.value_ptr.*;
    }

    if (total_a == 0 and total_b == 0) return 1.0;
    if (total_a == 0 or total_b == 0) return 0.0;

    // Dice coefficient
    const inter: f64 = @floatFromInt(intersection);
    const ta: f64 = @floatFromInt(total_a);
    const tb: f64 = @floatFromInt(total_b);

    return (2.0 * inter) / (ta + tb);
}

/// Search for best fuzzy matches in a list.
pub fn fuzzySearch(
    allocator: std.mem.Allocator,
    query: []const u8,
    candidates: []const []const u8,
    max_results: usize,
) ![]FuzzyMatch {
    var matches: std.ArrayListUnmanaged(FuzzyMatch) = .{};
    errdefer matches.deinit(allocator);

    for (candidates, 0..) |candidate, i| {
        const score = jaroWinkler(query, candidate);
        try matches.append(allocator, .{
            .text = candidate,
            .score = score,
            .index = i,
        });
    }

    // Sort by score (descending)
    std.mem.sort(FuzzyMatch, matches.items, {}, FuzzyMatch.lessThan);

    // Return top N results
    const result_count = @min(max_results, matches.items.len);
    const result = try allocator.alloc(FuzzyMatch, result_count);
    @memcpy(result, matches.items[0..result_count]);

    matches.deinit(allocator);
    return result;
}

/// Search with minimum score threshold.
pub fn fuzzySearchThreshold(
    allocator: std.mem.Allocator,
    query: []const u8,
    candidates: []const []const u8,
    min_score: f64,
) ![]FuzzyMatch {
    var matches: std.ArrayListUnmanaged(FuzzyMatch) = .{};
    errdefer matches.deinit(allocator);

    for (candidates, 0..) |candidate, i| {
        const score = jaroWinkler(query, candidate);
        if (score >= min_score) {
            try matches.append(allocator, .{
                .text = candidate,
                .score = score,
                .index = i,
            });
        }
    }

    // Sort by score (descending)
    std.mem.sort(FuzzyMatch, matches.items, {}, FuzzyMatch.lessThan);

    return matches.toOwnedSlice(allocator);
}

/// Calculate the best matching algorithm to use based on string characteristics.
pub const SimilarityAlgorithm = enum {
    levenshtein,
    damerau_levenshtein,
    jaro,
    jaro_winkler,
    lcs,
    cosine,
    hamming,
};

/// Get recommended algorithm based on use case
pub fn recommendAlgorithm(a: []const u8, b: []const u8) SimilarityAlgorithm {
    // Same length: consider Hamming
    if (a.len == b.len and a.len <= 32) {
        return .hamming;
    }

    // Short strings: Jaro-Winkler works well
    if (a.len <= 10 and b.len <= 10) {
        return .jaro_winkler;
    }

    // Medium strings: Damerau-Levenshtein
    if (a.len <= 50 and b.len <= 50) {
        return .damerau_levenshtein;
    }

    // Long strings: LCS or Cosine
    return .lcs;
}

/// Calculate similarity using the recommended algorithm
pub fn autoSimilarity(a: []const u8, b: []const u8) f64 {
    const algo = recommendAlgorithm(a, b);
    return switch (algo) {
        .levenshtein => levenshteinSimilarity(a, b),
        .damerau_levenshtein => {
            const dist = damerauLevenshtein(a, b);
            const max_len: f64 = @floatFromInt(@max(a.len, b.len));
            return if (max_len == 0) 1.0 else 1.0 - (@as(f64, @floatFromInt(dist)) / max_len);
        },
        .jaro => jaro(a, b),
        .jaro_winkler => jaroWinkler(a, b),
        .lcs => lcsSimilarity(a, b),
        .cosine => cosineSimilarity(a, b),
        .hamming => {
            if (hamming(a, b)) |dist| {
                const len: f64 = @floatFromInt(a.len);
                return if (len == 0) 1.0 else 1.0 - (@as(f64, @floatFromInt(dist)) / len);
            }
            return 0.0;
        },
    };
}

// ============================================================
// Tests
// ============================================================

test "Levenshtein distance" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 0), levenshtein("", ""));
    try testing.expectEqual(@as(usize, 5), levenshtein("", "hello"));
    try testing.expectEqual(@as(usize, 5), levenshtein("hello", ""));
    try testing.expectEqual(@as(usize, 0), levenshtein("hello", "hello"));
    try testing.expectEqual(@as(usize, 3), levenshtein("kitten", "sitting"));
    try testing.expectEqual(@as(usize, 2), levenshtein("flaw", "lawn"));
}

test "Damerau-Levenshtein distance" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 0), damerauLevenshtein("", ""));
    try testing.expectEqual(@as(usize, 0), damerauLevenshtein("hello", "hello"));
    try testing.expectEqual(@as(usize, 1), damerauLevenshtein("ab", "ba")); // transposition
    try testing.expectEqual(@as(usize, 3), damerauLevenshtein("kitten", "sitting"));
}

test "Hamming distance" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 0), hamming("", ""));
    try testing.expectEqual(@as(?usize, 0), hamming("hello", "hello"));
    try testing.expectEqual(@as(?usize, 2), hamming("karolin", "kathrin"));
    try testing.expectEqual(@as(?usize, null), hamming("hello", "hi"));
}

test "Jaro similarity" {
    const testing = std.testing;

    try testing.expect(jaro("", "") == 1.0);
    try testing.expect(jaro("hello", "hello") == 1.0);
    try testing.expect(jaro("hello", "") == 0.0);

    // Classic example
    const sim = jaro("MARTHA", "MARHTA");
    try testing.expect(sim > 0.94 and sim < 0.95);
}

test "Jaro-Winkler similarity" {
    const testing = std.testing;

    try testing.expect(jaroWinkler("", "") == 1.0);
    try testing.expect(jaroWinkler("hello", "hello") == 1.0);

    // Jaro-Winkler should be higher than Jaro for common prefix
    const jw = jaroWinkler("MARTHA", "MARHTA");
    const j = jaro("MARTHA", "MARHTA");
    try testing.expect(jw >= j);
}

test "LCS length" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 0), lcsLength("", ""));
    try testing.expectEqual(@as(usize, 0), lcsLength("abc", ""));
    try testing.expectEqual(@as(usize, 3), lcsLength("abc", "abc"));
    try testing.expectEqual(@as(usize, 2), lcsLength("abc", "ac"));
    try testing.expectEqual(@as(usize, 4), lcsLength("AGCAT", "GAC"));
}

test "Longest common substring" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 0), longestCommonSubstring("", ""));
    try testing.expectEqual(@as(usize, 3), longestCommonSubstring("abc", "abc"));
    try testing.expectEqual(@as(usize, 3), longestCommonSubstring("abcdef", "zabcf"));
    try testing.expectEqual(@as(usize, 0), longestCommonSubstring("abc", "xyz"));
}

test "Cosine similarity" {
    const testing = std.testing;

    try testing.expect(cosineSimilarity("", "") == 1.0);
    try testing.expect(cosineSimilarity("hello", "hello") == 1.0);
    try testing.expect(cosineSimilarity("abc", "xyz") == 0.0);

    const sim = cosineSimilarity("hello", "hallo");
    try testing.expect(sim > 0.8);
}

test "Fuzzy search" {
    const testing = std.testing;

    const candidates = [_][]const u8{ "apple", "apply", "maple", "banana", "application" };
    const results = try fuzzySearch(testing.allocator, "appl", &candidates, 3);
    defer testing.allocator.free(results);

    try testing.expectEqual(@as(usize, 3), results.len);
    // "apply" or "apple" should be at top
    try testing.expect(std.mem.eql(u8, results[0].text, "apple") or
        std.mem.eql(u8, results[0].text, "apply"));
}

test "Levenshtein similarity" {
    const testing = std.testing;

    try testing.expect(levenshteinSimilarity("", "") == 1.0);
    try testing.expect(levenshteinSimilarity("hello", "hello") == 1.0);
    try testing.expect(levenshteinSimilarity("abc", "xyz") < 0.1);
}

test "jaro bounds guard for strings > 256 bytes" {
    const testing = std.testing;

    // Create a 257-byte string (exceeds MAX_JARO_LEN of 256)
    const long_string = "a" ** 257;

    // jaro() must return 0.0 for oversized inputs instead of OOB write
    try testing.expectEqual(@as(f64, 0.0), jaro(long_string, "hello"));
    try testing.expectEqual(@as(f64, 0.0), jaro("hello", long_string));
    try testing.expectEqual(@as(f64, 0.0), jaro(long_string, long_string));

    // jaroWinkler() delegates to jaro(), so it must also return 0.0
    try testing.expectEqual(@as(f64, 0.0), jaroWinkler(long_string, "hello"));
    try testing.expectEqual(@as(f64, 0.0), jaroWinkler("hello", long_string));
    try testing.expectEqual(@as(f64, 0.0), jaroWinkler(long_string, long_string));

    // Exactly 256 bytes should still work (boundary case)
    const exact_string = "a" ** 256;
    try testing.expect(jaro(exact_string, exact_string) == 1.0);
    try testing.expect(jaroWinkler(exact_string, exact_string) == 1.0);
}
