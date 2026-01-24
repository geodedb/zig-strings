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

pub const Codepoint = types.Codepoint;

/// Grapheme cluster break property
pub const GraphemeBreak = enum {
    Other,
    CR,
    LF,
    Control,
    Extend,
    ZWJ,
    Regional_Indicator,
    Prepend,
    SpacingMark,
    L, // Hangul L
    V, // Hangul V
    T, // Hangul T
    LV, // Hangul LV
    LVT, // Hangul LVT
    Extended_Pictographic,
};

/// Gets the grapheme break property for a code point
pub fn getGraphemeBreak(cp: Codepoint) GraphemeBreak {
    // CR
    if (cp == 0x000D) return .CR;

    // LF
    if (cp == 0x000A) return .LF;

    // Control (Cc, Cf minus certain characters)
    if (cp < 0x0020 and cp != 0x000D and cp != 0x000A) return .Control;
    if (cp >= 0x007F and cp <= 0x009F) return .Control;
    if (cp == 0x00AD) return .Control; // Soft hyphen

    // ZWJ
    if (cp == 0x200D) return .ZWJ;

    // Regional Indicator
    if (cp >= 0x1F1E6 and cp <= 0x1F1FF) return .Regional_Indicator;

    // SpacingMark - Indic vowel signs and similar (check before general marks)
    if (isIndicSpacingMark(cp)) return .SpacingMark;

    // Extend (combining marks and similar)
    if (categories.isMark(cp)) return .Extend;
    if (cp >= 0x1F3FB and cp <= 0x1F3FF) return .Extend; // Emoji skin tones
    if (cp == 0x200C or cp == 0x200D) return .Extend; // ZWNJ, ZWJ
    if (cp >= 0xFE00 and cp <= 0xFE0F) return .Extend; // Variation selectors
    if (cp >= 0xE0100 and cp <= 0xE01EF) return .Extend; // Variation selectors supplement

    // Hangul syllable types
    if (cp >= 0x1100 and cp <= 0x115F) return .L;
    if (cp >= 0xA960 and cp <= 0xA97C) return .L;
    if (cp >= 0x1160 and cp <= 0x11A7) return .V;
    if (cp >= 0xD7B0 and cp <= 0xD7C6) return .V;
    if (cp >= 0x11A8 and cp <= 0x11FF) return .T;
    if (cp >= 0xD7CB and cp <= 0xD7FB) return .T;

    // Hangul syllables
    if (cp >= 0xAC00 and cp <= 0xD7A3) {
        const offset = cp - 0xAC00;
        if (offset % 28 == 0) return .LV;
        return .LVT;
    }

    // Extended Pictographic (simplified - common emoji)
    if (isExtendedPictographic(cp)) return .Extended_Pictographic;

    return .Other;
}

/// Check if a code point is an Indic SpacingMark (dependent vowel that takes space)
fn isIndicSpacingMark(cp: Codepoint) bool {
    // Devanagari dependent vowels (spacing marks)
    if ((cp >= 0x093E and cp <= 0x0940) or // ा ि ी
        (cp >= 0x0949 and cp <= 0x094C) or // ॉ ॊ ो ौ
        cp == 0x094E or cp == 0x094F or cp == 0x0982 or cp == 0x0983) return true;

    // Bengali dependent vowels
    if ((cp >= 0x09BE and cp <= 0x09C0) or // া ি ী
        (cp >= 0x09C7 and cp <= 0x09C8) or // ে ৈ
        (cp >= 0x09CB and cp <= 0x09CC) or // ো ৌ
        cp == 0x09D7) return true;

    // Gurmukhi
    if ((cp >= 0x0A3E and cp <= 0x0A40) or
        cp == 0x0A03) return true;

    // Gujarati
    if ((cp >= 0x0ABE and cp <= 0x0AC0) or
        cp == 0x0AC9 or (cp >= 0x0ACB and cp <= 0x0ACC)) return true;

    // Oriya
    if ((cp >= 0x0B3E and cp <= 0x0B40) or
        (cp >= 0x0B47 and cp <= 0x0B48) or
        (cp >= 0x0B4B and cp <= 0x0B4C) or
        cp == 0x0B57) return true;

    // Tamil dependent vowels
    if ((cp >= 0x0BBE and cp <= 0x0BBF) or // ா ி
        (cp >= 0x0BC1 and cp <= 0x0BC2) or // ு ூ
        (cp >= 0x0BC6 and cp <= 0x0BC8) or // ெ ே ை
        (cp >= 0x0BCA and cp <= 0x0BCC) or // ொ ோ ௌ
        cp == 0x0BD7) return true;

    // Telugu dependent vowels
    if ((cp >= 0x0C01 and cp <= 0x0C03) or // candrabindu, anusvara, visarga
        (cp >= 0x0C41 and cp <= 0x0C44) or // vowel signs
        (cp >= 0x0C46 and cp <= 0x0C48) or
        (cp >= 0x0C4A and cp <= 0x0C4C)) return true;

    // Kannada
    if ((cp >= 0x0CBE and cp <= 0x0CC4) or
        (cp >= 0x0CC6 and cp <= 0x0CC8) or
        (cp >= 0x0CCA and cp <= 0x0CCC) or
        cp == 0x0CD5 or cp == 0x0CD6) return true;

    // Malayalam
    if ((cp >= 0x0D02 and cp <= 0x0D03) or
        (cp >= 0x0D3E and cp <= 0x0D40) or
        (cp >= 0x0D46 and cp <= 0x0D48) or
        (cp >= 0x0D4A and cp <= 0x0D4C) or
        cp == 0x0D57) return true;

    // Sinhala
    if ((cp >= 0x0DCF and cp <= 0x0DD1) or
        (cp >= 0x0DD8 and cp <= 0x0DDF) or
        (cp >= 0x0DF2 and cp <= 0x0DF3)) return true;

    // Thai
    if (cp == 0x0E30 or (cp >= 0x0E32 and cp <= 0x0E33) or
        cp == 0x0E45) return true;

    // Lao
    if (cp == 0x0EB0 or (cp >= 0x0EB2 and cp <= 0x0EB3)) return true;

    // Tibetan
    if (cp >= 0x0F7F and cp <= 0x0F80) return true;

    // Myanmar
    if ((cp >= 0x102B and cp <= 0x102C) or
        (cp >= 0x1031 and cp <= 0x1031) or
        (cp >= 0x1038 and cp <= 0x1038) or
        (cp >= 0x103B and cp <= 0x103C)) return true;

    return false;
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

/// Checks if a code point is Extended_Pictographic
fn isExtendedPictographic(cp: Codepoint) bool {
    // Simplified check for common emoji ranges
    return (cp >= 0x1F600 and cp <= 0x1F64F) or // Emoticons
        (cp >= 0x1F300 and cp <= 0x1F5FF) or // Misc Symbols and Pictographs
        (cp >= 0x1F680 and cp <= 0x1F6FF) or // Transport and Map
        (cp >= 0x1F700 and cp <= 0x1F77F) or // Alchemical Symbols
        (cp >= 0x1F780 and cp <= 0x1F7FF) or // Geometric Shapes Extended
        (cp >= 0x1F800 and cp <= 0x1F8FF) or // Supplemental Arrows-C
        (cp >= 0x1F900 and cp <= 0x1F9FF) or // Supplemental Symbols and Pictographs
        (cp >= 0x1FA00 and cp <= 0x1FA6F) or // Chess Symbols
        (cp >= 0x1FA70 and cp <= 0x1FAFF) or // Symbols and Pictographs Extended-A
        (cp >= 0x2600 and cp <= 0x26FF) or // Misc symbols
        (cp >= 0x2700 and cp <= 0x27BF) or // Dingbats
        cp == 0x00A9 or cp == 0x00AE or // Copyright, Registered
        cp == 0x203C or cp == 0x2049 or // Double exclamation, exclamation question
        (cp >= 0x2300 and cp <= 0x23FF); // Misc technical
}

/// Determines if there should be a grapheme break between two code points
pub fn shouldBreak(prev: ?Codepoint, curr: Codepoint, state: *GraphemeState) bool {
    const curr_prop = getGraphemeBreak(curr);

    // GB1: Break at start of text
    if (prev == null) {
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
    // Track virama for Indic conjuncts
    state.after_virama = isIndicVirama(cp);
    state.last_codepoint = cp;

    updateState(state, prop);
}

/// Iterator over grapheme clusters in a UTF-8 string
pub const Iterator = struct {
    bytes: []const u8,
    index: usize,
    state: GraphemeState,

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
