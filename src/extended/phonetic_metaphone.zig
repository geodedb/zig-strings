// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Metaphone Phonetic Algorithms
//!
//! Provides the Metaphone and Double Metaphone phonetic encoding algorithms.
//!
//! - **Metaphone**: More accurate than Soundex for English pronunciation
//! - **Double Metaphone**: Handles multiple pronunciations by returning
//!   primary and alternate codes
//!
//! These algorithms are re-exported by the parent `phonetic` module.

const std = @import("std");

/// Double Metaphone result (primary and alternate codes)
pub const DoubleMetaphoneResult = struct {
    primary: []const u8,
    alternate: ?[]const u8,

    /// Frees the primary and alternate code strings.
    pub fn deinit(self: *DoubleMetaphoneResult, allocator: std.mem.Allocator) void {
        allocator.free(self.primary);
        if (self.alternate) |alt| {
            allocator.free(alt);
        }
    }
};

pub fn isVowel(c: u8) bool {
    return switch (c) {
        'A', 'E', 'I', 'O', 'U' => true,
        else => false,
    };
}

/// Calculate Metaphone code.
/// More accurate than Soundex for English pronunciation.
pub fn metaphone(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    if (input.len == 0) {
        return allocator.dupe(u8, "");
    }

    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    // Convert to uppercase and extract letters only
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

    const w = word.items;
    var i: usize = 0;

    // Handle initial special cases
    if (w.len >= 2) {
        const pair = [2]u8{ w[0], w[1] };
        if (std.mem.eql(u8, &pair, "KN") or
            std.mem.eql(u8, &pair, "GN") or
            std.mem.eql(u8, &pair, "PN") or
            std.mem.eql(u8, &pair, "AE") or
            std.mem.eql(u8, &pair, "WR"))
        {
            i = 1;
        } else if (w[0] == 'X') {
            try result.append(allocator, 'S');
            i = 1;
        } else if (std.mem.eql(u8, &pair, "WH")) {
            try result.append(allocator, 'W');
            i = 2;
        }
    }

    while (i < w.len) {
        const c = w[i];

        // Skip duplicates (except C)
        if (i > 0 and c == w[i - 1] and c != 'C') {
            i += 1;
            continue;
        }

        switch (c) {
            'A', 'E', 'I', 'O', 'U' => {
                // Vowels only at the beginning
                if (i == 0) try result.append(allocator, c);
                i += 1;
            },
            'B' => {
                // B is silent at end after M
                if (!(i == w.len - 1 and i > 0 and w[i - 1] == 'M')) {
                    try result.append(allocator, 'B');
                }
                i += 1;
            },
            'C' => {
                if (i + 1 < w.len and w[i + 1] == 'H') {
                    try result.append(allocator, 'X');
                    i += 2;
                } else if (i + 1 < w.len and (w[i + 1] == 'I' or w[i + 1] == 'E' or w[i + 1] == 'Y')) {
                    try result.append(allocator, 'S');
                    i += 1;
                } else {
                    try result.append(allocator, 'K');
                    i += 1;
                }
            },
            'D' => {
                if (i + 2 < w.len and w[i + 1] == 'G' and
                    (w[i + 2] == 'E' or w[i + 2] == 'I' or w[i + 2] == 'Y'))
                {
                    try result.append(allocator, 'J');
                    i += 3;
                } else {
                    try result.append(allocator, 'T');
                    i += 1;
                }
            },
            'F', 'J', 'L', 'M', 'N', 'R' => {
                try result.append(allocator, c);
                i += 1;
            },
            'G' => {
                if (i + 1 < w.len and w[i + 1] == 'H') {
                    // GH is silent before certain consonants
                    if (i + 2 < w.len and !isVowel(w[i + 2])) {
                        i += 2;
                        continue;
                    }
                    try result.append(allocator, 'F');
                    i += 2;
                } else if (i + 1 < w.len and w[i + 1] == 'N') {
                    i += 1;
                } else if (i + 1 < w.len and (w[i + 1] == 'I' or w[i + 1] == 'E' or w[i + 1] == 'Y')) {
                    try result.append(allocator, 'J');
                    i += 1;
                } else {
                    try result.append(allocator, 'K');
                    i += 1;
                }
            },
            'H' => {
                // H is silent after vowels or certain consonants
                if (i > 0 and isVowel(w[i - 1])) {
                    i += 1;
                    continue;
                }
                if (i + 1 < w.len and isVowel(w[i + 1])) {
                    try result.append(allocator, 'H');
                }
                i += 1;
            },
            'K' => {
                if (!(i > 0 and w[i - 1] == 'C')) {
                    try result.append(allocator, 'K');
                }
                i += 1;
            },
            'P' => {
                if (i + 1 < w.len and w[i + 1] == 'H') {
                    try result.append(allocator, 'F');
                    i += 2;
                } else {
                    try result.append(allocator, 'P');
                    i += 1;
                }
            },
            'Q' => {
                try result.append(allocator, 'K');
                i += 1;
            },
            'S' => {
                if (i + 1 < w.len and w[i + 1] == 'H') {
                    try result.append(allocator, 'X');
                    i += 2;
                } else if (i + 2 < w.len and w[i + 1] == 'I' and (w[i + 2] == 'O' or w[i + 2] == 'A')) {
                    try result.append(allocator, 'X');
                    i += 3;
                } else {
                    try result.append(allocator, 'S');
                    i += 1;
                }
            },
            'T' => {
                if (i + 1 < w.len and w[i + 1] == 'H') {
                    try result.append(allocator, '0'); // theta sound
                    i += 2;
                } else if (i + 2 < w.len and w[i + 1] == 'I' and (w[i + 2] == 'O' or w[i + 2] == 'A')) {
                    try result.append(allocator, 'X');
                    i += 3;
                } else {
                    try result.append(allocator, 'T');
                    i += 1;
                }
            },
            'V' => {
                try result.append(allocator, 'F');
                i += 1;
            },
            'W', 'Y' => {
                if (i + 1 < w.len and isVowel(w[i + 1])) {
                    try result.append(allocator, c);
                }
                i += 1;
            },
            'X' => {
                try result.append(allocator, 'K');
                try result.append(allocator, 'S');
                i += 1;
            },
            'Z' => {
                try result.append(allocator, 'S');
                i += 1;
            },
            else => i += 1,
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Simplified double metaphone implementation. Returns primary and alternate codes.
/// Note: This is not the full Philips (2000) Double Metaphone algorithm -- it uses
/// standard metaphone for the primary code and generates an alternate only for specific
/// letter patterns (e.g., X -> 'S'). For production phonetic matching, consider using
/// the allocating variants.
pub fn doubleMetaphone(allocator: std.mem.Allocator, input: []const u8) !DoubleMetaphoneResult {
    // Simplified implementation - returns primary as Metaphone, alternate as null for most cases
    const primary = try metaphone(allocator, input);

    // For words with ambiguous pronunciation, compute alternate
    var has_alternate = false;

    // Check for certain patterns that have alternate pronunciations
    for (input) |c| {
        if (c == 'x' or c == 'X') {
            has_alternate = true;
            break;
        }
    }

    const alternate: ?[]const u8 = if (has_alternate) blk: {
        var alt: std.ArrayListUnmanaged(u8) = .{};
        errdefer alt.deinit(allocator);

        for (input) |c| {
            if (!std.ascii.isAlphabetic(c)) continue;
            const upper = std.ascii.toUpper(c);
            if (upper == 'X') {
                try alt.append(allocator, 'S'); // Alternative: X as S
            } else {
                try alt.append(allocator, upper);
            }
        }
        break :blk try alt.toOwnedSlice(allocator);
    } else null;

    return DoubleMetaphoneResult{
        .primary = primary,
        .alternate = alternate,
    };
}

// ============================================================
// Tests
// ============================================================

test "Metaphone basic" {
    const testing = std.testing;

    const m1 = try metaphone(testing.allocator, "Knight");
    defer testing.allocator.free(m1);
    try testing.expectEqualStrings("NT", m1);

    const m2 = try metaphone(testing.allocator, "Night");
    defer testing.allocator.free(m2);
    try testing.expectEqualStrings("NT", m2);
}

test "Metaphone phone vs fone" {
    const testing = std.testing;

    const m1 = try metaphone(testing.allocator, "phone");
    defer testing.allocator.free(m1);
    const m2 = try metaphone(testing.allocator, "fone");
    defer testing.allocator.free(m2);

    try testing.expectEqualStrings(m1, m2);
}

test "Double Metaphone" {
    const testing = std.testing;

    var result = try doubleMetaphone(testing.allocator, "Schmidt");
    defer result.deinit(testing.allocator);

    try testing.expect(result.primary.len > 0);
}

test "Metaphone empty input" {
    const testing = std.testing;

    const m = try metaphone(testing.allocator, "");
    defer testing.allocator.free(m);
    try testing.expectEqualStrings("", m);
}
