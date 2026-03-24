// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Phonetic Algorithms
//!
//! Provides phonetic encoding algorithms for matching words that sound similar
//! but are spelled differently. Useful for:
//!
//! - Name matching and deduplication
//! - Spell checking suggestions
//! - Search applications
//! - Data cleaning
//!
//! Algorithms:
//! - **Soundex**: Classic algorithm from the 1910s, 4-character codes
//! - **Refined Soundex**: More nuanced version of Soundex
//! - **Metaphone**: More accurate than Soundex for English
//! - **Double Metaphone**: Handles multiple pronunciations
//! - **NYSIIS**: New York State Identification and Intelligence System
//! - **Match Rating Approach**: For name comparison
//! - **Caverphone**: Optimized for New Zealand English
//!
//! Usage:
//! ```zig
//! const code = soundex("Robert");
//! // code = "R163"
//!
//! const m = metaphone(allocator, "Knight");
//! defer allocator.free(m);
//! // m = "NT"
//!
//! const match = phoneticMatch("Smith", "Smyth", .soundex);
//! // match = true (both encode to "S530")
//! ```

const std = @import("std");
const metaphone_mod = @import("phonetic_metaphone.zig");

/// Phonetic algorithm to use
pub const Algorithm = enum {
    soundex,
    refined_soundex,
    metaphone,
    double_metaphone,
    nysiis,
    match_rating,
    caverphone,
};

// Re-export metaphone sub-module types and functions
pub const DoubleMetaphoneResult = metaphone_mod.DoubleMetaphoneResult;
pub const metaphone = metaphone_mod.metaphone;
pub const doubleMetaphone = metaphone_mod.doubleMetaphone;

// Import isVowel for use by NYSIIS and matchRating
const isVowel = metaphone_mod.isVowel;

// Force test runner to include sub-module tests
comptime {
    _ = metaphone_mod;
}

/// Calculate Soundex code for a string.
/// Returns a 4-character code (letter + 3 digits).
pub fn soundex(input: []const u8) [4]u8 {
    var result: [4]u8 = .{ '0', '0', '0', '0' };
    if (input.len == 0) return result;

    // Find first letter
    var start: usize = 0;
    while (start < input.len and !std.ascii.isAlphabetic(input[start])) {
        start += 1;
    }
    if (start >= input.len) return result;

    // First character is always a letter
    result[0] = std.ascii.toUpper(input[start]);

    var result_idx: usize = 1;
    var last_code: u8 = soundexCode(result[0]);

    for (input[start + 1 ..]) |c| {
        if (!std.ascii.isAlphabetic(c)) continue;

        const code = soundexCode(std.ascii.toUpper(c));

        // Skip if same as previous or is a vowel/separator
        if (code != '0' and code != last_code) {
            result[result_idx] = code;
            result_idx += 1;
            if (result_idx >= 4) break;
        }

        last_code = code;
    }

    return result;
}

fn soundexCode(c: u8) u8 {
    return switch (c) {
        'B', 'F', 'P', 'V' => '1',
        'C', 'G', 'J', 'K', 'Q', 'S', 'X', 'Z' => '2',
        'D', 'T' => '3',
        'L' => '4',
        'M', 'N' => '5',
        'R' => '6',
        else => '0', // A, E, I, O, U, H, W, Y
    };
}

/// Calculate Refined Soundex code.
/// More detailed encoding than standard Soundex.
pub fn refinedSoundex(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) {
        return allocator.dupe(u8, "");
    }

    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var last_code: u8 = 0;

    for (input) |c| {
        if (!std.ascii.isAlphabetic(c)) continue;

        const upper = std.ascii.toUpper(c);
        const code = refinedSoundexCode(upper);

        if (result.items.len == 0) {
            try result.append(allocator, upper);
            last_code = code;
        } else if (code != last_code and code != '0') {
            try result.append(allocator, code);
            last_code = code;
        }
    }

    return result.toOwnedSlice(allocator);
}

fn refinedSoundexCode(c: u8) u8 {
    return switch (c) {
        'B', 'P' => '1',
        'F', 'V' => '2',
        'C', 'K', 'S' => '3',
        'G', 'J' => '4',
        'Q', 'X', 'Z' => '5',
        'D', 'T' => '6',
        'L' => '7',
        'M', 'N' => '8',
        'R' => '9',
        else => '0',
    };
}

/// Calculate NYSIIS (New York State Identification and Intelligence System) code.
pub fn nysiis(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) {
        return allocator.dupe(u8, "");
    }

    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    // Convert to uppercase
    var word: std.ArrayListUnmanaged(u8) = .{};
    defer word.deinit(allocator);

    for (input) |c| {
        if (std.ascii.isAlphabetic(c)) {
            try word.append(allocator, std.ascii.toUpper(c));
        }
    }

    if (word.items.len == 0) {
        return result.toOwnedSlice(allocator);
    }

    var w = word.items;

    // Translate first characters
    if (w.len >= 3 and std.mem.eql(u8, w[0..3], "MAC")) {
        w[0] = 'M';
        w[1] = 'C';
        w[2] = 'C';
    } else if (w.len >= 2 and std.mem.eql(u8, w[0..2], "KN")) {
        w[0] = 'N';
        w[1] = 'N';
    } else if (w.len >= 1 and w[0] == 'K') {
        w[0] = 'C';
    } else if (w.len >= 2 and std.mem.eql(u8, w[0..2], "PH")) {
        w[0] = 'F';
        w[1] = 'F';
    } else if (w.len >= 2 and std.mem.eql(u8, w[0..2], "PF")) {
        w[0] = 'F';
        w[1] = 'F';
    } else if (w.len >= 3 and std.mem.eql(u8, w[0..3], "SCH")) {
        w[0] = 'S';
        w[1] = 'S';
        w[2] = 'S';
    }

    // First character is kept
    try result.append(allocator, w[0]);

    var i: usize = 1;
    var last: u8 = w[0];

    while (i < w.len) {
        var c = w[i];

        // Translate vowels to A
        if (isVowel(c)) {
            c = 'A';
        }

        // Other translations
        if (c == 'K') {
            c = 'C';
        } else if (c == 'Z') {
            c = 'S';
        } else if (c == 'Q') {
            c = 'G';
        }

        // Drop duplicate consecutive characters
        if (c != last) {
            // Don't add vowels in middle
            if (c != 'A' or i == w.len - 1) {
                try result.append(allocator, c);
            }
        }

        last = c;
        i += 1;
    }

    return result.toOwnedSlice(allocator);
}

/// Calculate Match Rating Approach code.
/// Designed specifically for name matching.
pub fn matchRating(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) {
        return allocator.dupe(u8, "");
    }

    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    // Convert to uppercase and remove non-alphabetic
    var word: std.ArrayListUnmanaged(u8) = .{};
    defer word.deinit(allocator);

    for (input) |c| {
        if (std.ascii.isAlphabetic(c)) {
            try word.append(allocator, std.ascii.toUpper(c));
        }
    }

    if (word.items.len == 0) {
        return result.toOwnedSlice(allocator);
    }

    // Remove vowels (except first)
    try result.append(allocator, word.items[0]);
    var last = word.items[0];

    for (word.items[1..]) |c| {
        if (!isVowel(c) and c != last) {
            try result.append(allocator, c);
        }
        last = c;
    }

    // Keep first 3 and last 3 characters if longer than 6
    if (result.items.len > 6) {
        const first3 = result.items[0..3];
        const last3 = result.items[result.items.len - 3 ..];
        result.shrinkRetainingCapacity(0);
        try result.appendSlice(allocator, first3);
        try result.appendSlice(allocator, last3);
    }

    return result.toOwnedSlice(allocator);
}

/// Calculate Caverphone 2.0 code.
/// Optimized for matching names in New Zealand.
pub fn caverphone(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) {
        return allocator.dupe(u8, "1111111111");
    }

    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    // Convert to lowercase and extract letters
    var word: std.ArrayListUnmanaged(u8) = .{};
    defer word.deinit(allocator);

    for (input) |c| {
        if (std.ascii.isAlphabetic(c)) {
            try word.append(allocator, std.ascii.toLower(c));
        }
    }

    if (word.items.len == 0) {
        return allocator.dupe(u8, "1111111111");
    }

    // Apply transformations (simplified)
    for (word.items) |c| {
        const code = switch (c) {
            'a', 'e', 'i', 'o', 'u' => 'A',
            'b', 'p' => 'P',
            'c', 'k', 'q' => 'K',
            'd', 't' => 'T',
            'f', 'v' => 'F',
            'g', 'j' => 'J',
            'l', 'r' => 'L',
            'm', 'n' => 'N',
            's', 'x', 'z' => 'S',
            'w', 'y' => '2',
            'h' => '2',
            else => c,
        };
        if (result.items.len == 0 or result.items[result.items.len - 1] != code or code == 'A') {
            try result.append(allocator, code);
        }
    }

    // Pad to 10 characters
    while (result.items.len < 10) {
        try result.append(allocator, '1');
    }

    if (result.items.len > 10) {
        result.shrinkRetainingCapacity(10);
    }

    return result.toOwnedSlice(allocator);
}

/// Check if two strings match phonetically using the specified algorithm.
///
/// Only `.soundex` is supported in the non-allocating path.
/// For other algorithms (`.refined_soundex`, `.metaphone`,
/// `.double_metaphone`, `.nysiis`, `.match_rating`, `.caverphone`),
/// use `phoneticMatchAlloc` which accepts an allocator.
///
/// Passing an unsupported algorithm panics in all build modes.
pub fn phoneticMatch(a: []const u8, b: []const u8, algo: Algorithm) bool {
    return switch (algo) {
        .soundex => {
            const code_a = soundex(a);
            const code_b = soundex(b);
            return std.mem.eql(u8, &code_a, &code_b);
        },
        else => @panic("phoneticMatch only supports .soundex; use phoneticMatchAlloc for other algorithms"),
    };
}

/// Check if two strings match phonetically (with allocator).
pub fn phoneticMatchAlloc(
    allocator: std.mem.Allocator,
    a: []const u8,
    b: []const u8,
    algo: Algorithm,
) !bool {
    return switch (algo) {
        .soundex => {
            const code_a = soundex(a);
            const code_b = soundex(b);
            return std.mem.eql(u8, &code_a, &code_b);
        },
        .refined_soundex => {
            const code_a = try refinedSoundex(allocator, a);
            defer allocator.free(code_a);
            const code_b = try refinedSoundex(allocator, b);
            defer allocator.free(code_b);
            return std.mem.eql(u8, code_a, code_b);
        },
        .metaphone => {
            const code_a = try metaphone(allocator, a);
            defer allocator.free(code_a);
            const code_b = try metaphone(allocator, b);
            defer allocator.free(code_b);
            return std.mem.eql(u8, code_a, code_b);
        },
        .double_metaphone => {
            var result_a = try doubleMetaphone(allocator, a);
            defer result_a.deinit(allocator);
            var result_b = try doubleMetaphone(allocator, b);
            defer result_b.deinit(allocator);

            // Match if primary or alternate matches
            if (std.mem.eql(u8, result_a.primary, result_b.primary)) return true;
            if (result_a.alternate) |alt_a| {
                if (std.mem.eql(u8, alt_a, result_b.primary)) return true;
                if (result_b.alternate) |alt_b| {
                    if (std.mem.eql(u8, alt_a, alt_b)) return true;
                }
            }
            if (result_b.alternate) |alt_b| {
                if (std.mem.eql(u8, result_a.primary, alt_b)) return true;
            }
            return false;
        },
        .nysiis => {
            const code_a = try nysiis(allocator, a);
            defer allocator.free(code_a);
            const code_b = try nysiis(allocator, b);
            defer allocator.free(code_b);
            return std.mem.eql(u8, code_a, code_b);
        },
        .match_rating => {
            const code_a = try matchRating(allocator, a);
            defer allocator.free(code_a);
            const code_b = try matchRating(allocator, b);
            defer allocator.free(code_b);
            return std.mem.eql(u8, code_a, code_b);
        },
        .caverphone => {
            const code_a = try caverphone(allocator, a);
            defer allocator.free(code_a);
            const code_b = try caverphone(allocator, b);
            defer allocator.free(code_b);
            return std.mem.eql(u8, code_a, code_b);
        },
    };
}

// ============================================================
// Tests
// ============================================================

test "Soundex basic" {
    const testing = std.testing;

    try testing.expectEqualStrings("R163", &soundex("Robert"));
    try testing.expectEqualStrings("R163", &soundex("Rupert"));
    try testing.expectEqualStrings("A261", &soundex("Ashcraft"));
    try testing.expectEqualStrings("T522", &soundex("Tymczak"));
    try testing.expectEqualStrings("P236", &soundex("Pfister"));
}

test "Soundex same code" {
    const testing = std.testing;

    // These should produce the same code
    const smith = soundex("Smith");
    const smyth = soundex("Smyth");
    try testing.expectEqualStrings(&smith, &smyth);
}

test "NYSIIS basic" {
    const testing = std.testing;

    const n1 = try nysiis(testing.allocator, "Macintosh");
    defer testing.allocator.free(n1);
    // NYSIIS transforms MAC to MCC
    try testing.expect(n1.len > 0);
}

test "Match Rating" {
    const testing = std.testing;

    const m = try matchRating(testing.allocator, "Catherine");
    defer testing.allocator.free(m);
    try testing.expect(m.len <= 6);
}

test "Caverphone basic" {
    const testing = std.testing;

    const c = try caverphone(testing.allocator, "Thompson");
    defer testing.allocator.free(c);
    try testing.expectEqual(@as(usize, 10), c.len);
}

test "Phonetic match" {
    const testing = std.testing;

    try testing.expect(phoneticMatch("Smith", "Smyth", .soundex));
    try testing.expect(!phoneticMatch("Smith", "Jones", .soundex));
}

test "Empty input" {
    const testing = std.testing;

    try testing.expectEqualStrings("0000", &soundex(""));

    const m = try metaphone(testing.allocator, "");
    defer testing.allocator.free(m);
    try testing.expectEqualStrings("", m);
}

test "Refined Soundex" {
    const testing = std.testing;

    const r1 = try refinedSoundex(testing.allocator, "Robert");
    defer testing.allocator.free(r1);
    try testing.expect(r1.len > 0);
    try testing.expect(r1[0] == 'R');
}

test "phoneticMatchAlloc soundex" {
    const testing = std.testing;

    // soundex path through phoneticMatchAlloc
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "Smith", "Smyth", .soundex));
    try testing.expect(!try phoneticMatchAlloc(testing.allocator, "Smith", "Jones", .soundex));
}

test "phoneticMatchAlloc refined_soundex" {
    const testing = std.testing;

    // Same-sounding names via refined_soundex
    const match = try phoneticMatchAlloc(testing.allocator, "Robert", "Robert", .refined_soundex);
    try testing.expect(match);

    const no_match = try phoneticMatchAlloc(testing.allocator, "Robert", "Jones", .refined_soundex);
    try testing.expect(!no_match);
}

test "phoneticMatchAlloc metaphone" {
    const testing = std.testing;

    // "Knight" and "Night" produce the same Metaphone code "NT"
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "Knight", "Night", .metaphone));
    try testing.expect(!try phoneticMatchAlloc(testing.allocator, "Knight", "Day", .metaphone));
}

test "phoneticMatchAlloc double_metaphone" {
    const testing = std.testing;

    // Self-equality
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "Schmidt", "Schmidt", .double_metaphone));
    // Cross-string: Knight and Night share primary metaphone code "NT"
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "Knight", "Night", .double_metaphone));
    // Non-matching: different primary metaphone codes
    try testing.expect(!try phoneticMatchAlloc(testing.allocator, "Knight", "Day", .double_metaphone));
}

test "phoneticMatchAlloc nysiis" {
    const testing = std.testing;

    // Self-equality
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "Macintosh", "Macintosh", .nysiis));
    // Non-matching: clearly different names
    try testing.expect(!try phoneticMatchAlloc(testing.allocator, "Macintosh", "Jones", .nysiis));
}

test "phoneticMatchAlloc match_rating" {
    const testing = std.testing;

    // Self-equality
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "Catherine", "Catherine", .match_rating));
    // Non-matching: clearly different names
    try testing.expect(!try phoneticMatchAlloc(testing.allocator, "Catherine", "Smith", .match_rating));
}

test "phoneticMatchAlloc caverphone" {
    const testing = std.testing;

    // Self-equality
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "Thompson", "Thompson", .caverphone));
    // Non-matching: clearly different names
    try testing.expect(!try phoneticMatchAlloc(testing.allocator, "Thompson", "Williams", .caverphone));
}

test "phoneticMatchAlloc soundex cross-string" {
    const testing = std.testing;

    // Smith and Smyth share soundex code S530
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "Smith", "Smyth", .soundex));
    // Robert and Rupert share soundex code R163
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "Robert", "Rupert", .soundex));
    // Non-matching
    try testing.expect(!try phoneticMatchAlloc(testing.allocator, "Smith", "Jones", .soundex));
}

test "phoneticMatchAlloc metaphone cross-string" {
    const testing = std.testing;

    // Cat and Kat share metaphone code "KT"
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "Cat", "Kat", .metaphone));
    // phone and fone share the same metaphone code
    try testing.expect(try phoneticMatchAlloc(testing.allocator, "phone", "fone", .metaphone));
    // Non-matching
    try testing.expect(!try phoneticMatchAlloc(testing.allocator, "Cat", "Dog", .metaphone));
}
