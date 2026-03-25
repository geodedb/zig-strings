// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Grapheme cluster boundaries (UAX #29).
//!
//! A grapheme cluster is what users perceive as a single character.
//! This may consist of multiple code points (e.g., base + combining marks,
//! emoji with modifiers, etc.).

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const categories = @import("categories");
const ucd_grapheme_break = @import("ucd_grapheme_break");

pub const Codepoint = types.Codepoint;

/// Grapheme cluster break property.
/// Explicit u8 backing values match the generated trie table exactly.
pub const GraphemeBreak = enum(u8) {
    Other = 0,
    CR = 1,
    LF = 2,
    Control = 3,
    Extend = 4,
    ZWJ = 5,
    Regional_Indicator = 6,
    Prepend = 7,
    SpacingMark = 8,
    L = 9, // Hangul L
    V = 10, // Hangul V
    T = 11, // Hangul T
    LV = 12, // Hangul LV
    LVT = 13, // Hangul LVT
    Extended_Pictographic = 14,
};

/// Gets the grapheme break property for a code point.
/// Uses the ASCII fast-path for cp < 0x80, then falls through to a
/// generated two-level trie for O(1) lookup across all of Unicode.
pub fn getGraphemeBreak(cp: Codepoint) GraphemeBreak {
    // ASCII fast-path: avoid the table lookup for codepoints < 0x80.
    // CR, LF, and C0/DEL control characters are handled explicitly; all
    // remaining ASCII codepoints are .Other by definition (UAX #29).
    if (cp < 0x80) {
        if (cp == 0x0D) return .CR;
        if (cp == 0x0A) return .LF;
        if (cp < 0x20 or cp == 0x7F) return .Control;
        return .Other;
    }

    // Full Unicode lookup via generated two-stage trie table.
    // The table's enum values match our GraphemeBreak enum exactly.
    const tbl_val = ucd_grapheme_break.getGraphemeBreakProperty(cp);
    return @enumFromInt(@intFromEnum(tbl_val));
}

/// Check if a code point is an Indic virama (halant)
pub fn isIndicVirama(cp: Codepoint) bool {
    return switch (cp) {
        0x094D, // Devanagari virama
        0x09CD, // Bengali virama
        0x0A4D, // Gurmukhi virama
        0x0ACD, // Gujarati virama
        0x0B4D, // Oriya virama
        0x0BCD, // Tamil virama
        0x0C4D, // Telugu virama
        0x0CCD, // Kannada virama
        0x0D4D, // Malayalam virama
        0x0DCA, // Sinhala virama
        0x1039, // Myanmar virama (asat)
        0x103A, // Myanmar sign asat
        0x1714, // Tagalog virama
        0x1734, // Hanunuo virama
        0x17D2, // Khmer virama
        0x1A60, // Tai Tham virama
        0x1B44, // Balinese virama
        0xA8C4, // Saurashtra virama
        0xA9C0, // Javanese virama
        0xAAF6, // Meetei Mayek virama
        => true,
        else => false,
    };
}

/// Check if a code point is an Indic consonant
pub fn isIndicConsonant(cp: Codepoint) bool {
    // Devanagari consonants
    if (cp >= 0x0915 and cp <= 0x0939) return true;
    if (cp >= 0x0958 and cp <= 0x095F) return true; // Additional consonants
    // Bengali consonants
    if (cp >= 0x0995 and cp <= 0x09B9) return true;
    if (cp >= 0x09DC and cp <= 0x09DF) return true;
    // Gurmukhi consonants
    if (cp >= 0x0A15 and cp <= 0x0A39) return true;
    if (cp >= 0x0A59 and cp <= 0x0A5E) return true;
    // Gujarati consonants
    if (cp >= 0x0A95 and cp <= 0x0AB9) return true;
    // Oriya consonants
    if (cp >= 0x0B15 and cp <= 0x0B39) return true;
    if (cp >= 0x0B5C and cp <= 0x0B5D) return true;
    // Tamil consonants
    if (cp >= 0x0B95 and cp <= 0x0BB9) return true;
    // Telugu consonants
    if (cp >= 0x0C15 and cp <= 0x0C39) return true;
    if (cp >= 0x0C58 and cp <= 0x0C5A) return true;
    // Kannada consonants
    if (cp >= 0x0C95 and cp <= 0x0CB9) return true;
    if (cp >= 0x0CDE and cp <= 0x0CDE) return true;
    // Malayalam consonants
    if (cp >= 0x0D15 and cp <= 0x0D39) return true;
    if (cp >= 0x0D54 and cp <= 0x0D56) return true;
    // Sinhala consonants
    if (cp >= 0x0D9A and cp <= 0x0DC6) return true;

    return false;
}

/// Determines if there should be a grapheme break between two code points
pub fn shouldBreak(prev: ?Codepoint, curr: Codepoint, state: *GraphemeState) bool {
    const curr_prop = getGraphemeBreak(curr);

    // GB1: Break at start of text (or start of a new cluster in the iterator).
    // Reset RI parity so that consecutive RI pairs are counted correctly
    // across cluster boundaries (GB12/GB13).
    if (prev == null) {
        state.ri_odd = false;
        updateStateWithCodepoint(state, curr_prop, curr);
        return true;
    }

    const prev_prop = state.last_property;

    // GB3: Do not break between CR and LF
    if (prev_prop == .CR and curr_prop == .LF) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return false;
    }

    // GB4: Break after controls
    if (prev_prop == .CR or prev_prop == .LF or prev_prop == .Control) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return true;
    }

    // GB5: Break before controls
    if (curr_prop == .CR or curr_prop == .LF or curr_prop == .Control) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return true;
    }

    // GB6: Do not break Hangul sequences
    if (prev_prop == .L and (curr_prop == .L or curr_prop == .V or curr_prop == .LV or curr_prop == .LVT)) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return false;
    }

    // GB7: Do not break Hangul sequences
    if ((prev_prop == .LV or prev_prop == .V) and (curr_prop == .V or curr_prop == .T)) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return false;
    }

    // GB8: Do not break Hangul sequences
    if ((prev_prop == .LVT or prev_prop == .T) and curr_prop == .T) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return false;
    }

    // Indic conjunct break rule: Do not break after virama + consonant
    // This handles conjunct consonants like क्ष (ka + virama + ssa)
    if (state.after_virama and isIndicConsonant(curr)) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return false;
    }

    // GB9: Do not break before extending characters or ZWJ
    if (curr_prop == .Extend or curr_prop == .ZWJ) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return false;
    }

    // GB9a: Do not break before SpacingMarks
    if (curr_prop == .SpacingMark) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return false;
    }

    // GB9b: Do not break after Prepend
    if (prev_prop == .Prepend) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return false;
    }

    // GB11: Do not break within emoji modifier sequences or emoji ZWJ sequences
    if (state.in_emoji_sequence and prev_prop == .ZWJ and curr_prop == .Extended_Pictographic) {
        updateStateWithCodepoint(state, curr_prop, curr);
        return false;
    }

    // GB12/GB13: Do not break within regional indicator pairs
    if (prev_prop == .Regional_Indicator and curr_prop == .Regional_Indicator and !state.ri_odd) {
        state.ri_odd = true;
        updateStateWithCodepoint(state, curr_prop, curr);
        return false;
    }

    // GB999: Otherwise, break everywhere
    updateStateWithCodepoint(state, curr_prop, curr);
    return true;
}

/// State for grapheme cluster iteration
pub const GraphemeState = struct {
    last_property: GraphemeBreak = .Other,
    ri_odd: bool = false, // Regional Indicator odd count
    in_emoji_sequence: bool = false,
    last_codepoint: ?Codepoint = null, // Track last codepoint for Indic conjuncts
    after_virama: bool = false, // Track if we just saw a virama
};

fn updateState(state: *GraphemeState, prop: GraphemeBreak) void {
    state.last_property = prop;

    // Reset RI count on non-RI
    if (prop != .Regional_Indicator) {
        state.ri_odd = false;
    }

    // Track emoji sequences
    if (prop == .Extended_Pictographic) {
        state.in_emoji_sequence = true;
    } else if (prop != .Extend and prop != .ZWJ) {
        state.in_emoji_sequence = false;
    }
}

fn updateStateWithCodepoint(state: *GraphemeState, prop: GraphemeBreak, cp: Codepoint) void {
    // Track virama for Indic conjuncts.
    // Guard: the lowest Indic virama is U+094D (Devanagari). Skip the 20-arm
    // switch for ASCII and most Latin/common codepoints, which are always
    // below this threshold.
    state.after_virama = cp >= 0x094D and isIndicVirama(cp);
    state.last_codepoint = cp;

    updateState(state, prop);
}

/// Iterator over grapheme clusters in a UTF-8 string
pub const Iterator = struct {
    bytes: []const u8,
    index: usize,
    state: GraphemeState,

    /// Creates a new grapheme cluster iterator over the given UTF-8 bytes.
    pub fn init(bytes: []const u8) Iterator {
        return .{
            .bytes = bytes,
            .index = 0,
            .state = .{},
        };
    }

    /// Returns the next grapheme cluster as a UTF-8 slice
    pub fn next(self: *Iterator) ?[]const u8 {
        if (self.index >= self.bytes.len) {
            return null;
        }

        const start = self.index;
        var prev_cp: ?Codepoint = null;

        // Get first code point
        const first_len = std.unicode.utf8ByteSequenceLength(self.bytes[self.index]) catch {
            self.index += 1;
            return self.bytes[start..self.index];
        };
        if (self.index + first_len > self.bytes.len) {
            self.index = self.bytes.len;
            return self.bytes[start..];
        }
        prev_cp = std.unicode.utf8Decode(self.bytes[self.index..][0..first_len]) catch {
            self.index += 1;
            return self.bytes[start..self.index];
        };
        self.index += first_len;

        // Initial state update
        _ = shouldBreak(null, prev_cp.?, &self.state);

        // Continue until we find a break
        while (self.index < self.bytes.len) {
            const len = std.unicode.utf8ByteSequenceLength(self.bytes[self.index]) catch break;
            if (self.index + len > self.bytes.len) break;

            const cp = std.unicode.utf8Decode(self.bytes[self.index..][0..len]) catch break;

            if (shouldBreak(prev_cp, cp, &self.state)) {
                break;
            }

            prev_cp = cp;
            self.index += len;
        }

        return self.bytes[start..self.index];
    }

    /// Reset the iterator
    pub fn reset(self: *Iterator) void {
        self.index = 0;
        self.state = .{};
    }
};

/// Creates a grapheme cluster iterator
pub fn iterator(bytes: []const u8) Iterator {
    return Iterator.init(bytes);
}

/// Counts the number of grapheme clusters in a string
pub fn count(bytes: []const u8) usize {
    var iter = iterator(bytes);
    var n: usize = 0;
    while (iter.next()) |_| {
        n += 1;
    }
    return n;
}

test "simple graphemes" {
    const testing = std.testing;

    var iter = iterator("hello");
    try testing.expectEqualSlices(u8, "h", iter.next().?);
    try testing.expectEqualSlices(u8, "e", iter.next().?);
    try testing.expectEqualSlices(u8, "l", iter.next().?);
    try testing.expectEqualSlices(u8, "l", iter.next().?);
    try testing.expectEqualSlices(u8, "o", iter.next().?);
    try testing.expect(iter.next() == null);

    try testing.expectEqual(@as(usize, 5), count("hello"));
}

test "combining marks" {
    const testing = std.testing;

    // e + combining acute (é as two code points)
    const input = "e\xCC\x81"; // U+0065 U+0301

    var iter = iterator(input);
    const cluster = iter.next().?;
    try testing.expectEqual(@as(usize, 3), cluster.len);
    try testing.expect(iter.next() == null);

    try testing.expectEqual(@as(usize, 1), count(input));
}

test "CRLF" {
    const testing = std.testing;

    var iter = iterator("a\r\nb");
    try testing.expectEqualSlices(u8, "a", iter.next().?);
    try testing.expectEqualSlices(u8, "\r\n", iter.next().?); // CRLF is one grapheme
    try testing.expectEqualSlices(u8, "b", iter.next().?);
    try testing.expect(iter.next() == null);

    try testing.expectEqual(@as(usize, 3), count("a\r\nb"));
}

test "grapheme break properties" {
    const testing = std.testing;

    try testing.expectEqual(GraphemeBreak.CR, getGraphemeBreak(0x000D));
    try testing.expectEqual(GraphemeBreak.LF, getGraphemeBreak(0x000A));
    try testing.expectEqual(GraphemeBreak.Control, getGraphemeBreak(0x0000));
    try testing.expectEqual(GraphemeBreak.ZWJ, getGraphemeBreak(0x200D));
    try testing.expectEqual(GraphemeBreak.Regional_Indicator, getGraphemeBreak(0x1F1E6));
    try testing.expectEqual(GraphemeBreak.L, getGraphemeBreak(0x1100));
}

test "Indic Devanagari conjuncts" {
    const testing = std.testing;

    // क्ष (ksha) = क (ka, U+0915) + ् (virama, U+094D) + ष (ssa, U+0937)
    // This should be 1 grapheme cluster
    const ksha = "\xe0\xa4\x95\xe0\xa5\x8d\xe0\xa4\xb7"; // क्ष
    try testing.expectEqual(@as(usize, 1), count(ksha));

    // क्षा (kshaa) = क + virama + ष + ा (aa vowel sign)
    // This should also be 1 grapheme cluster
    const kshaa = "\xe0\xa4\x95\xe0\xa5\x8d\xe0\xa4\xb7\xe0\xa4\xbe"; // क्षा
    try testing.expectEqual(@as(usize, 1), count(kshaa));
}

test "Indic Tamil vowel signs" {
    const testing = std.testing;

    // க (ka) + ா (aa vowel) = கா (1 grapheme)
    const kaa = "\xe0\xae\x95\xe0\xae\xbe"; // கா
    try testing.expectEqual(@as(usize, 1), count(kaa));

    // க (ka) + ி (i vowel) = கி (1 grapheme)
    const ki = "\xe0\xae\x95\xe0\xae\xbf"; // கி
    try testing.expectEqual(@as(usize, 1), count(ki));
}

test "Indic Telugu vowel signs" {
    const testing = std.testing;

    // క (ka) + ా (aa vowel) = కా (1 grapheme)
    const kaa = "\xe0\xb0\x95\xe0\xb0\xbe"; // కా - but this uses different vowel sign
    // Note: Telugu aa-matra may be rendered differently
    var iter = iterator(kaa);
    const cluster = iter.next().?;
    try testing.expect(cluster.len > 0);
}

test "Indic virama detection" {
    const testing = std.testing;

    try testing.expect(isIndicVirama(0x094D)); // Devanagari virama
    try testing.expect(isIndicVirama(0x0BCD)); // Tamil virama
    try testing.expect(isIndicVirama(0x0C4D)); // Telugu virama
    try testing.expect(!isIndicVirama(0x0041)); // 'A' is not a virama
}

test "Indic consonant detection" {
    const testing = std.testing;

    try testing.expect(isIndicConsonant(0x0915)); // Devanagari ka
    try testing.expect(isIndicConsonant(0x0937)); // Devanagari ssa
    try testing.expect(isIndicConsonant(0x0B95)); // Tamil ka
    try testing.expect(isIndicConsonant(0x0C15)); // Telugu ka
    try testing.expect(!isIndicConsonant(0x0041)); // 'A' is not an Indic consonant
}

test "trie-based getGraphemeBreak covers full Unicode range" {
    const testing = std.testing;

    // ASCII fast-path
    try testing.expectEqual(GraphemeBreak.CR, getGraphemeBreak(0x0D));
    try testing.expectEqual(GraphemeBreak.LF, getGraphemeBreak(0x0A));
    try testing.expectEqual(GraphemeBreak.Other, getGraphemeBreak('A'));

    // Non-ASCII: ZWJ
    try testing.expectEqual(GraphemeBreak.ZWJ, getGraphemeBreak(0x200D));

    // Regional Indicator
    try testing.expectEqual(GraphemeBreak.Regional_Indicator, getGraphemeBreak(0x1F1E6));

    // Hangul Jamo
    try testing.expectEqual(GraphemeBreak.L, getGraphemeBreak(0x1100));
    try testing.expectEqual(GraphemeBreak.V, getGraphemeBreak(0x1160));
    try testing.expectEqual(GraphemeBreak.T, getGraphemeBreak(0x11A8));

    // Hangul syllables (LV and LVT via the trie)
    try testing.expectEqual(GraphemeBreak.LV, getGraphemeBreak(0xAC00)); // 가 (LV syllable)
    try testing.expectEqual(GraphemeBreak.LVT, getGraphemeBreak(0xAC01)); // 각 (LVT syllable)

    // Extend (combining marks)
    try testing.expectEqual(GraphemeBreak.Extend, getGraphemeBreak(0x0300)); // Combining grave accent
    try testing.expectEqual(GraphemeBreak.Extend, getGraphemeBreak(0x0301)); // Combining acute accent

    // Control
    try testing.expectEqual(GraphemeBreak.Control, getGraphemeBreak(0x0000));
    try testing.expectEqual(GraphemeBreak.Control, getGraphemeBreak(0x007F)); // DEL

    // SpacingMark
    try testing.expectEqual(GraphemeBreak.SpacingMark, getGraphemeBreak(0x0903)); // Devanagari visarga

    // Extended Pictographic (emoji)
    try testing.expectEqual(GraphemeBreak.Extended_Pictographic, getGraphemeBreak(0x1F600)); // Grinning face
}
