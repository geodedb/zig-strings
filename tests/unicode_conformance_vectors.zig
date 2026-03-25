// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode Conformance Test Vectors
//!
//! This module contains test vectors derived from official Unicode Consortium
//! test data files:
//!
//! - **NormalizationTest.txt** (Unicode 15.1): Part 1 character-by-character tests
//!   for NFC, NFD, NFKC, NFKD normalization forms. These vectors are taken
//!   directly from https://www.unicode.org/Public/15.1.0/ucd/NormalizationTest.txt
//!
//! - **GraphemeBreakTest.txt** (Unicode 15.1): Grapheme cluster boundary tests
//!   from https://www.unicode.org/Public/15.1.0/ucd/auxiliary/GraphemeBreakTest.txt
//!
//! The format of NormalizationTest.txt Part 1 is:
//!   source; NFC; NFD; NFKC; NFKD
//! where each column is a sequence of code point values in hex.
//!
//! The invariants tested (from the Unicode Standard, UAX #15):
//!   NFC:  toNFC(source)  == NFC column
//!   NFD:  toNFD(source)  == NFD column
//!   NFKC: toNFKC(source) == NFKC column
//!   NFKD: toNFKD(source) == NFKD column
//!
//! We also verify the additional invariants from the standard:
//!   toNFC(NFC)   == NFC
//!   toNFC(NFD)   == NFC
//!   toNFD(NFC)   == NFD
//!   toNFD(NFD)   == NFD
//!   toNFKC(NFKC) == NFKC
//!   toNFKC(NFKD) == NFKC
//!   toNFKD(NFKC) == NFKD
//!   toNFKD(NFKD) == NFKD

const std = @import("std");
const testing = std.testing;
const strings = @import("strings");

// ============================================================================
// Helper: encode a codepoint sequence as UTF-8
// ============================================================================

/// Encodes a slice of Unicode codepoints into a UTF-8 byte buffer.
/// Returns the number of bytes written.
fn encodeCodepoints(codepoints: []const u21, buf: []u8) ![]const u8 {
    var pos: usize = 0;
    for (codepoints) |cp| {
        const len = std.unicode.utf8CodepointSequenceLength(cp) catch return error.InvalidCodepoint;
        if (pos + len > buf.len) return error.BufferTooSmall;
        _ = std.unicode.utf8Encode(cp, buf[pos..][0..len]) catch return error.InvalidCodepoint;
        pos += len;
    }
    return buf[0..pos];
}

// ============================================================================
// NormalizationTest.txt Part 1 -- Official Unicode 15.1 Test Vectors
//
// Each entry: { source_codepoints, nfc_codepoints, nfd_codepoints, nfkc_codepoints, nfkd_codepoints }
//
// Source: https://www.unicode.org/Public/15.1.0/ucd/NormalizationTest.txt
// These are the actual Part 1 test entries for specific characters.
// ============================================================================

const NormTestVector = struct {
    /// Description of the test case (for diagnostics)
    desc: []const u8,
    /// Source codepoints
    source: []const u21,
    /// Expected NFC result
    nfc: []const u21,
    /// Expected NFD result
    nfd: []const u21,
    /// Expected NFKC result
    nfkc: []const u21,
    /// Expected NFKD result
    nfkd: []const u21,
};

// Real test vectors from NormalizationTest.txt Part 1 (Unicode 15.1)
//
// Format in the original file:
//   source;NFC;NFD;NFKC;NFKD;  # description
//
// Each field is a space-separated list of hex codepoint values.
const norm_test_vectors = [_]NormTestVector{
    // ---- Basic Latin with diacritics ----

    // 00C8;00C8;0045 0300;00C8;0045 0300;  # (È; È; E◌̀; È; E◌̀; ) LATIN CAPITAL LETTER E WITH GRAVE
    .{
        .desc = "U+00C8 LATIN CAPITAL LETTER E WITH GRAVE",
        .source = &[_]u21{0x00C8},
        .nfc = &[_]u21{0x00C8},
        .nfd = &[_]u21{ 0x0045, 0x0300 },
        .nfkc = &[_]u21{0x00C8},
        .nfkd = &[_]u21{ 0x0045, 0x0300 },
    },
    // 00C9;00C9;0045 0301;00C9;0045 0301;  # LATIN CAPITAL LETTER E WITH ACUTE
    .{
        .desc = "U+00C9 LATIN CAPITAL LETTER E WITH ACUTE",
        .source = &[_]u21{0x00C9},
        .nfc = &[_]u21{0x00C9},
        .nfd = &[_]u21{ 0x0045, 0x0301 },
        .nfkc = &[_]u21{0x00C9},
        .nfkd = &[_]u21{ 0x0045, 0x0301 },
    },
    // 00E9;00E9;0065 0301;00E9;0065 0301;  # LATIN SMALL LETTER E WITH ACUTE
    .{
        .desc = "U+00E9 LATIN SMALL LETTER E WITH ACUTE",
        .source = &[_]u21{0x00E9},
        .nfc = &[_]u21{0x00E9},
        .nfd = &[_]u21{ 0x0065, 0x0301 },
        .nfkc = &[_]u21{0x00E9},
        .nfkd = &[_]u21{ 0x0065, 0x0301 },
    },
    // 00F1;00F1;006E 0303;00F1;006E 0303;  # LATIN SMALL LETTER N WITH TILDE
    .{
        .desc = "U+00F1 LATIN SMALL LETTER N WITH TILDE",
        .source = &[_]u21{0x00F1},
        .nfc = &[_]u21{0x00F1},
        .nfd = &[_]u21{ 0x006E, 0x0303 },
        .nfkc = &[_]u21{0x00F1},
        .nfkd = &[_]u21{ 0x006E, 0x0303 },
    },
    // 00FC;00FC;0075 0308;00FC;0075 0308;  # LATIN SMALL LETTER U WITH DIAERESIS
    .{
        .desc = "U+00FC LATIN SMALL LETTER U WITH DIAERESIS",
        .source = &[_]u21{0x00FC},
        .nfc = &[_]u21{0x00FC},
        .nfd = &[_]u21{ 0x0075, 0x0308 },
        .nfkc = &[_]u21{0x00FC},
        .nfkd = &[_]u21{ 0x0075, 0x0308 },
    },

    // ---- Precomposed with multiple combining marks ----

    // 01D5;01D5;0055 0308 0304;01D5;0055 0308 0304;  # LATIN CAPITAL LETTER U WITH DIAERESIS AND MACRON
    .{
        .desc = "U+01D5 LATIN CAPITAL LETTER U WITH DIAERESIS AND MACRON",
        .source = &[_]u21{0x01D5},
        .nfc = &[_]u21{0x01D5},
        .nfd = &[_]u21{ 0x0055, 0x0308, 0x0304 },
        .nfkc = &[_]u21{0x01D5},
        .nfkd = &[_]u21{ 0x0055, 0x0308, 0x0304 },
    },

    // ---- Dot-above characters ----

    // 1E0A;1E0A;0044 0307;1E0A;0044 0307;  # LATIN CAPITAL LETTER D WITH DOT ABOVE
    .{
        .desc = "U+1E0A LATIN CAPITAL LETTER D WITH DOT ABOVE",
        .source = &[_]u21{0x1E0A},
        .nfc = &[_]u21{0x1E0A},
        .nfd = &[_]u21{ 0x0044, 0x0307 },
        .nfkc = &[_]u21{0x1E0A},
        .nfkd = &[_]u21{ 0x0044, 0x0307 },
    },
    // 1E0C;1E0C;0044 0323;1E0C;0044 0323;  # LATIN CAPITAL LETTER D WITH DOT BELOW
    .{
        .desc = "U+1E0C LATIN CAPITAL LETTER D WITH DOT BELOW",
        .source = &[_]u21{0x1E0C},
        .nfc = &[_]u21{0x1E0C},
        .nfd = &[_]u21{ 0x0044, 0x0323 },
        .nfkc = &[_]u21{0x1E0C},
        .nfkd = &[_]u21{ 0x0044, 0x0323 },
    },

    // ---- Multi-codepoint source: decomposed input that should compose ----

    // 0045 0301;00C9;0045 0301;00C9;0045 0301;  # (E◌́; É; E◌́; É; E◌́; )
    .{
        .desc = "E + COMBINING ACUTE -> NFC E WITH ACUTE",
        .source = &[_]u21{ 0x0045, 0x0301 },
        .nfc = &[_]u21{0x00C9},
        .nfd = &[_]u21{ 0x0045, 0x0301 },
        .nfkc = &[_]u21{0x00C9},
        .nfkd = &[_]u21{ 0x0045, 0x0301 },
    },
    // 0061 0308;00E4;0061 0308;00E4;0061 0308;  # (a◌̈; ä; a◌̈; ä; a◌̈; )
    .{
        .desc = "a + COMBINING DIAERESIS -> NFC a WITH DIAERESIS",
        .source = &[_]u21{ 0x0061, 0x0308 },
        .nfc = &[_]u21{0x00E4},
        .nfd = &[_]u21{ 0x0061, 0x0308 },
        .nfkc = &[_]u21{0x00E4},
        .nfkd = &[_]u21{ 0x0061, 0x0308 },
    },

    // ---- Hangul syllables (algorithmic decomposition) ----

    // AC00;AC00;1100 1161;AC00;1100 1161;  # (가; 가; 가; 가; 가; ) HANGUL SYLLABLE GA
    .{
        .desc = "U+AC00 HANGUL SYLLABLE GA (LV type)",
        .source = &[_]u21{0xAC00},
        .nfc = &[_]u21{0xAC00},
        .nfd = &[_]u21{ 0x1100, 0x1161 },
        .nfkc = &[_]u21{0xAC00},
        .nfkd = &[_]u21{ 0x1100, 0x1161 },
    },
    // AC01;AC01;1100 1161 11A8;AC01;1100 1161 11A8;  # HANGUL SYLLABLE GAG (LVT type)
    .{
        .desc = "U+AC01 HANGUL SYLLABLE GAG (LVT type)",
        .source = &[_]u21{0xAC01},
        .nfc = &[_]u21{0xAC01},
        .nfd = &[_]u21{ 0x1100, 0x1161, 0x11A8 },
        .nfkc = &[_]u21{0xAC01},
        .nfkd = &[_]u21{ 0x1100, 0x1161, 0x11A8 },
    },
    // Hangul Jamo -> composed syllable in NFC
    // 1100 1161;AC00;1100 1161;AC00;1100 1161;  # Hangul L+V -> syllable GA
    .{
        .desc = "Hangul Jamo L+V -> NFC syllable GA",
        .source = &[_]u21{ 0x1100, 0x1161 },
        .nfc = &[_]u21{0xAC00},
        .nfd = &[_]u21{ 0x1100, 0x1161 },
        .nfkc = &[_]u21{0xAC00},
        .nfkd = &[_]u21{ 0x1100, 0x1161 },
    },
    // 1100 1161 11A8;AC01;1100 1161 11A8;AC01;1100 1161 11A8;  # Hangul L+V+T -> syllable GAG
    .{
        .desc = "Hangul Jamo L+V+T -> NFC syllable GAG",
        .source = &[_]u21{ 0x1100, 0x1161, 0x11A8 },
        .nfc = &[_]u21{0xAC01},
        .nfd = &[_]u21{ 0x1100, 0x1161, 0x11A8 },
        .nfkc = &[_]u21{0xAC01},
        .nfkd = &[_]u21{ 0x1100, 0x1161, 0x11A8 },
    },
    // D4DB;D4DB;1111 1171 11B6;D4DB;1111 1171 11B6;  # HANGUL SYLLABLE PWILH
    .{
        .desc = "U+D4DB HANGUL SYLLABLE PWILH",
        .source = &[_]u21{0xD4DB},
        .nfc = &[_]u21{0xD4DB},
        .nfd = &[_]u21{ 0x1111, 0x1171, 0x11B6 },
        .nfkc = &[_]u21{0xD4DB},
        .nfkd = &[_]u21{ 0x1111, 0x1171, 0x11B6 },
    },

    // ---- Compatibility mappings (NFKC/NFKD differ from NFC/NFD) ----

    // 2126;03A9;03A9;03A9;03A9;  # OHM SIGN -> GREEK CAPITAL LETTER OMEGA
    .{
        .desc = "U+2126 OHM SIGN -> OMEGA",
        .source = &[_]u21{0x2126},
        .nfc = &[_]u21{0x03A9},
        .nfd = &[_]u21{0x03A9},
        .nfkc = &[_]u21{0x03A9},
        .nfkd = &[_]u21{0x03A9},
    },
    // 212B;00C5;0041 030A;00C5;0041 030A;  # ANGSTROM SIGN -> A WITH RING ABOVE
    .{
        .desc = "U+212B ANGSTROM SIGN -> A WITH RING ABOVE",
        .source = &[_]u21{0x212B},
        .nfc = &[_]u21{0x00C5},
        .nfd = &[_]u21{ 0x0041, 0x030A },
        .nfkc = &[_]u21{0x00C5},
        .nfkd = &[_]u21{ 0x0041, 0x030A },
    },

    // ---- Compatibility decompositions (NFKC/NFKD only) ----

    // FB01;FB01;FB01;0066 0069;0066 0069;  # LATIN SMALL LIGATURE FI
    .{
        .desc = "U+FB01 LATIN SMALL LIGATURE FI -> fi",
        .source = &[_]u21{0xFB01},
        .nfc = &[_]u21{0xFB01},
        .nfd = &[_]u21{0xFB01},
        .nfkc = &[_]u21{ 0x0066, 0x0069 },
        .nfkd = &[_]u21{ 0x0066, 0x0069 },
    },
    // FF21;FF21;FF21;0041;0041;  # FULLWIDTH LATIN CAPITAL LETTER A
    .{
        .desc = "U+FF21 FULLWIDTH LATIN CAPITAL LETTER A -> A",
        .source = &[_]u21{0xFF21},
        .nfc = &[_]u21{0xFF21},
        .nfd = &[_]u21{0xFF21},
        .nfkc = &[_]u21{0x0041},
        .nfkd = &[_]u21{0x0041},
    },
    // 2460;2460;2460;0031;0031;  # CIRCLED DIGIT ONE -> 1
    .{
        .desc = "U+2460 CIRCLED DIGIT ONE -> 1",
        .source = &[_]u21{0x2460},
        .nfc = &[_]u21{0x2460},
        .nfd = &[_]u21{0x2460},
        .nfkc = &[_]u21{0x0031},
        .nfkd = &[_]u21{0x0031},
    },
    // 2126 already tested above (Ohm sign)

    // ---- Greek characters ----

    // 0385;0385;00A8 0301;0020 0308 0301;0020 0308 0301;  # GREEK DIALYTIKA TONOS
    // Under NFKC/NFKD, U+00A8 DIAERESIS compat-decomposes to SPACE + COMBINING DIAERESIS
    .{
        .desc = "U+0385 GREEK DIALYTIKA TONOS",
        .source = &[_]u21{0x0385},
        .nfc = &[_]u21{0x0385},
        .nfd = &[_]u21{ 0x00A8, 0x0301 },
        .nfkc = &[_]u21{ 0x0020, 0x0308, 0x0301 },
        .nfkd = &[_]u21{ 0x0020, 0x0308, 0x0301 },
    },

    // ---- Arabic characters ----

    // 0622;0622;0627 0653;0622;0627 0653;  # ARABIC LETTER ALEF WITH MADDA ABOVE
    .{
        .desc = "U+0622 ARABIC LETTER ALEF WITH MADDA ABOVE",
        .source = &[_]u21{0x0622},
        .nfc = &[_]u21{0x0622},
        .nfd = &[_]u21{ 0x0627, 0x0653 },
        .nfkc = &[_]u21{0x0622},
        .nfkd = &[_]u21{ 0x0627, 0x0653 },
    },
    // 0623;0623;0627 0654;0623;0627 0654;  # ARABIC LETTER ALEF WITH HAMZA ABOVE
    .{
        .desc = "U+0623 ARABIC LETTER ALEF WITH HAMZA ABOVE",
        .source = &[_]u21{0x0623},
        .nfc = &[_]u21{0x0623},
        .nfd = &[_]u21{ 0x0627, 0x0654 },
        .nfkc = &[_]u21{0x0623},
        .nfkd = &[_]u21{ 0x0627, 0x0654 },
    },

    // ---- CCC ordering tests ----

    // 0044 0307 0323;1E0C 0307;0044 0323 0307;1E0C 0307;0044 0323 0307;
    // D + dot above + dot below -> canonical reorder: D + dot below + dot above
    .{
        .desc = "D + dot above + dot below (CCC reorder)",
        .source = &[_]u21{ 0x0044, 0x0307, 0x0323 },
        .nfc = &[_]u21{ 0x1E0C, 0x0307 },
        .nfd = &[_]u21{ 0x0044, 0x0323, 0x0307 },
        .nfkc = &[_]u21{ 0x1E0C, 0x0307 },
        .nfkd = &[_]u21{ 0x0044, 0x0323, 0x0307 },
    },
    // 0044 0323 0307;1E0C 0307;0044 0323 0307;1E0C 0307;0044 0323 0307;
    // D + dot below + dot above (already in canonical order)
    .{
        .desc = "D + dot below + dot above (already canonical order)",
        .source = &[_]u21{ 0x0044, 0x0323, 0x0307 },
        .nfc = &[_]u21{ 0x1E0C, 0x0307 },
        .nfd = &[_]u21{ 0x0044, 0x0323, 0x0307 },
        .nfkc = &[_]u21{ 0x1E0C, 0x0307 },
        .nfkd = &[_]u21{ 0x0044, 0x0323, 0x0307 },
    },
    // 1E0A 0323;1E0C 0307;0044 0323 0307;1E0C 0307;0044 0323 0307;
    // D-dot-above + dot below
    .{
        .desc = "D-dot-above + dot below (decompose, reorder, recompose)",
        .source = &[_]u21{ 0x1E0A, 0x0323 },
        .nfc = &[_]u21{ 0x1E0C, 0x0307 },
        .nfd = &[_]u21{ 0x0044, 0x0323, 0x0307 },
        .nfkc = &[_]u21{ 0x1E0C, 0x0307 },
        .nfkd = &[_]u21{ 0x0044, 0x0323, 0x0307 },
    },

    // ---- Devanagari ----

    // 0929;0929;0928 093C;0929;0928 093C;  # DEVANAGARI LETTER NNNA
    .{
        .desc = "U+0929 DEVANAGARI LETTER NNNA",
        .source = &[_]u21{0x0929},
        .nfc = &[_]u21{0x0929},
        .nfd = &[_]u21{ 0x0928, 0x093C },
        .nfkc = &[_]u21{0x0929},
        .nfkd = &[_]u21{ 0x0928, 0x093C },
    },

    // ---- CJK Compatibility Ideographs (NFKC maps to unified) ----

    // F900;8C48;8C48;8C48;8C48;  # CJK COMPATIBILITY IDEOGRAPH-F900
    // F900 has a canonical (not compatibility) decomposition to 8C48.
    // All four normalization forms map to 8C48.
    .{
        .desc = "U+F900 CJK COMPATIBILITY IDEOGRAPH -> U+8C48",
        .source = &[_]u21{0xF900},
        .nfc = &[_]u21{0x8C48},
        .nfd = &[_]u21{0x8C48},
        .nfkc = &[_]u21{0x8C48},
        .nfkd = &[_]u21{0x8C48},
    },

    // ---- Superscript / subscript (compatibility) ----

    // 00B2;00B2;00B2;0032;0032;  # SUPERSCRIPT TWO -> 2
    .{
        .desc = "U+00B2 SUPERSCRIPT TWO -> 2",
        .source = &[_]u21{0x00B2},
        .nfc = &[_]u21{0x00B2},
        .nfd = &[_]u21{0x00B2},
        .nfkc = &[_]u21{0x0032},
        .nfkd = &[_]u21{0x0032},
    },

    // ---- Cedilla ----

    // 00C7;00C7;0043 0327;00C7;0043 0327;  # LATIN CAPITAL LETTER C WITH CEDILLA
    .{
        .desc = "U+00C7 LATIN CAPITAL LETTER C WITH CEDILLA",
        .source = &[_]u21{0x00C7},
        .nfc = &[_]u21{0x00C7},
        .nfd = &[_]u21{ 0x0043, 0x0327 },
        .nfkc = &[_]u21{0x00C7},
        .nfkd = &[_]u21{ 0x0043, 0x0327 },
    },

    // ---- Musical symbols (supplementary plane, compatibility) ----

    // 1D15E;1D157 1D165;1D157 1D165;1D157 1D165;1D157 1D165;  # MUSICAL SYMBOL HALF NOTE
    .{
        .desc = "U+1D15E MUSICAL SYMBOL HALF NOTE",
        .source = &[_]u21{0x1D15E},
        .nfc = &[_]u21{ 0x1D157, 0x1D165 },
        .nfd = &[_]u21{ 0x1D157, 0x1D165 },
        .nfkc = &[_]u21{ 0x1D157, 0x1D165 },
        .nfkd = &[_]u21{ 0x1D157, 0x1D165 },
    },

    // ---- Hebrew ----

    // FB2C -> 05E9 05BC 05C1 in all forms (FB49 is composition-excluded)
    // FB2C decomposes canonically to FB49 + 05C1, FB49 decomposes to 05E9 + 05BC.
    // Since FB49 is in CompositionExclusions.txt, NFC cannot recompose to FB49.
    .{
        .desc = "U+FB2C HEBREW LETTER SHIN WITH DAGESH AND SHIN DOT",
        .source = &[_]u21{0xFB2C},
        .nfc = &[_]u21{ 0x05E9, 0x05BC, 0x05C1 },
        .nfd = &[_]u21{ 0x05E9, 0x05BC, 0x05C1 },
        .nfkc = &[_]u21{ 0x05E9, 0x05BC, 0x05C1 },
        .nfkd = &[_]u21{ 0x05E9, 0x05BC, 0x05C1 },
    },

    // ---- Spacing modifier letters ----

    // 02DA;02DA;02DA;0020 030A;0020 030A;  # RING ABOVE (spacing) -> SPACE + COMBINING RING ABOVE
    // Under NFKC/NFKD, 02DA compat-decomposes to SPACE + COMBINING RING ABOVE
    .{
        .desc = "U+02DA RING ABOVE -> SPACE + COMBINING RING ABOVE (NFKC/NFKD)",
        .source = &[_]u21{0x02DA},
        .nfc = &[_]u21{0x02DA},
        .nfd = &[_]u21{0x02DA},
        .nfkc = &[_]u21{ 0x0020, 0x030A },
        .nfkd = &[_]u21{ 0x0020, 0x030A },
    },
};

// ============================================================================
// GraphemeBreakTest.txt -- Official Unicode 15.1 Test Vectors
//
// Each entry describes grapheme cluster boundaries in a codepoint sequence.
// The "clusters" field lists the codepoints in each cluster.
//
// Source: https://www.unicode.org/Public/15.1.0/ucd/auxiliary/GraphemeBreakTest.txt
// ============================================================================

const GraphemeTestVector = struct {
    /// Description of the test case
    desc: []const u8,
    /// All codepoints in sequence
    codepoints: []const u21,
    /// Expected number of grapheme clusters
    expected_clusters: usize,
    /// Codepoints per cluster -- each sub-slice is one grapheme cluster
    /// (We store the expected count of codepoints in each cluster for validation)
    cluster_lengths: []const usize,
};

const grapheme_test_vectors = [_]GraphemeTestVector{
    // ÷ 0020 ÷ 0020 ÷  # ÷ [0.2] SPACE (Other) ÷ [999.0] SPACE (Other) ÷ [0.3]
    .{
        .desc = "Two spaces -> two graphemes",
        .codepoints = &[_]u21{ 0x0020, 0x0020 },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 1, 1 },
    },
    // ÷ 0020 × 0308 ÷  # SPACE + COMBINING DIAERESIS -> one grapheme
    .{
        .desc = "SPACE + combining diaeresis -> one grapheme",
        .codepoints = &[_]u21{ 0x0020, 0x0308 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },
    // ÷ 000D × 000A ÷  # CR + LF -> one grapheme (GB3)
    .{
        .desc = "CR + LF -> one grapheme (GB3)",
        .codepoints = &[_]u21{ 0x000D, 0x000A },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },
    // ÷ 000D ÷ 0020 ÷  # CR + SPACE -> two graphemes (GB4)
    .{
        .desc = "CR + SPACE -> two graphemes (GB4)",
        .codepoints = &[_]u21{ 0x000D, 0x0020 },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 1, 1 },
    },
    // ÷ 000A ÷ 000A ÷  # LF + LF -> two graphemes (GB4)
    .{
        .desc = "LF + LF -> two graphemes (GB4)",
        .codepoints = &[_]u21{ 0x000A, 0x000A },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 1, 1 },
    },
    // ÷ 0061 × 0308 ÷  # 'a' + combining diaeresis -> one grapheme (GB9)
    .{
        .desc = "'a' + combining diaeresis -> one grapheme (GB9)",
        .codepoints = &[_]u21{ 0x0061, 0x0308 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },
    // ÷ 0061 × 0308 ÷ 0062 ÷  # 'a' + diaeresis + 'b' -> two graphemes
    .{
        .desc = "'a' + diaeresis + 'b' -> two graphemes",
        .codepoints = &[_]u21{ 0x0061, 0x0308, 0x0062 },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 2, 1 },
    },
    // ÷ 0061 × 0300 × 0308 ÷  # 'a' + grave + diaeresis -> one grapheme (multiple Extend)
    .{
        .desc = "'a' + grave + diaeresis -> one grapheme",
        .codepoints = &[_]u21{ 0x0061, 0x0300, 0x0308 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{3},
    },

    // ---- Hangul tests (GB6, GB7, GB8) ----

    // ÷ 1100 × 1161 ÷  # Hangul L + V -> one grapheme (GB6)
    .{
        .desc = "Hangul L + V -> one grapheme (GB6)",
        .codepoints = &[_]u21{ 0x1100, 0x1161 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },
    // ÷ 1100 × 1161 × 11A8 ÷  # Hangul L + V + T -> one grapheme (GB6+GB7/GB8)
    .{
        .desc = "Hangul L + V + T -> one grapheme (GB6+GB8)",
        .codepoints = &[_]u21{ 0x1100, 0x1161, 0x11A8 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{3},
    },
    // ÷ AC00 × 11A8 ÷  # Hangul LV syllable + T -> one grapheme (GB8)
    .{
        .desc = "Hangul LV syllable + T -> one grapheme (GB8)",
        .codepoints = &[_]u21{ 0xAC00, 0x11A8 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },
    // ÷ AC01 ÷ 1100 ÷  # Hangul LVT syllable + L -> two graphemes
    .{
        .desc = "Hangul LVT syllable + L -> two graphemes",
        .codepoints = &[_]u21{ 0xAC01, 0x1100 },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 1, 1 },
    },
    // ÷ 1100 × 1100 ÷  # Hangul L + L -> one grapheme (GB6)
    .{
        .desc = "Hangul L + L -> one grapheme (GB6)",
        .codepoints = &[_]u21{ 0x1100, 0x1100 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },
    // ÷ AC00 × 1161 ÷  # Hangul LV + V -> one grapheme (GB7)
    .{
        .desc = "Hangul LV + V -> one grapheme (GB7)",
        .codepoints = &[_]u21{ 0xAC00, 0x1161 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },

    // ---- Regional indicators (GB12/GB13) ----

    // ÷ 1F1E6 × 1F1E8 ÷  # RI + RI -> one grapheme (first pair)
    .{
        .desc = "Two regional indicators -> one grapheme (flag pair)",
        .codepoints = &[_]u21{ 0x1F1E6, 0x1F1E8 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },
    // ÷ 1F1E6 × 1F1E8 ÷ 1F1EA ÷  # Three RIs -> first two pair, third alone
    .{
        .desc = "Three regional indicators -> two graphemes (pair + single)",
        .codepoints = &[_]u21{ 0x1F1E6, 0x1F1E8, 0x1F1EA },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 2, 1 },
    },
    // ÷ 1F1E6 × 1F1E8 ÷ 1F1EA × 1F1EB ÷  # Four RIs -> two flag pairs
    .{
        .desc = "Four regional indicators -> two graphemes (two pairs)",
        .codepoints = &[_]u21{ 0x1F1E6, 0x1F1E8, 0x1F1EA, 0x1F1EB },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 2, 2 },
    },

    // ---- Emoji ZWJ sequences (GB11) ----

    // ÷ 1F468 × 200D × 1F469 ÷  # Man + ZWJ + Woman (simplified ZWJ pair)
    // Note: 1F468 and 1F469 are Extended_Pictographic, 200D is ZWJ
    .{
        .desc = "Man + ZWJ + Woman -> one grapheme (GB11)",
        .codepoints = &[_]u21{ 0x1F468, 0x200D, 0x1F469 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{3},
    },
    // ÷ 1F468 × 200D × 1F469 × 200D × 1F467 ÷  # Family emoji
    .{
        .desc = "Man + ZWJ + Woman + ZWJ + Girl -> one grapheme",
        .codepoints = &[_]u21{ 0x1F468, 0x200D, 0x1F469, 0x200D, 0x1F467 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{5},
    },

    // ---- Extended_Pictographic + Extend ----

    // ÷ 2764 × FE0F ÷  # Heart + variation selector -> one grapheme
    .{
        .desc = "Heart + variation selector -> one grapheme",
        .codepoints = &[_]u21{ 0x2764, 0xFE0F },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },
    // ÷ 1F600 ÷ 1F600 ÷  # Two emoji -> two graphemes
    .{
        .desc = "Two emoji -> two graphemes",
        .codepoints = &[_]u21{ 0x1F600, 0x1F600 },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 1, 1 },
    },

    // ---- Control characters (GB4, GB5) ----

    // ÷ 0001 ÷ 0061 ÷  # SOH (control) + 'a' -> two graphemes
    .{
        .desc = "Control + 'a' -> two graphemes (GB4)",
        .codepoints = &[_]u21{ 0x0001, 0x0061 },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 1, 1 },
    },
    // ÷ 0061 ÷ 0001 ÷  # 'a' + SOH (control) -> two graphemes
    .{
        .desc = "'a' + control -> two graphemes (GB5)",
        .codepoints = &[_]u21{ 0x0061, 0x0001 },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 1, 1 },
    },

    // ---- Prepend characters (GB9b) ----
    // Note: U+0600 ARABIC NUMBER SIGN has Prepend property

    // ÷ 0600 × 0061 ÷  # Prepend + 'a' -> one grapheme (GB9b)
    .{
        .desc = "Prepend + 'a' -> one grapheme (GB9b)",
        .codepoints = &[_]u21{ 0x0600, 0x0061 },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },

    // ---- SpacingMark (GB9a) ----

    // ÷ 0915 × 093E ÷  # Devanagari KA + vowel sign AA -> one grapheme (GB9a)
    .{
        .desc = "Devanagari KA + spacing vowel sign -> one grapheme (GB9a)",
        .codepoints = &[_]u21{ 0x0915, 0x093E },
        .expected_clusters = 1,
        .cluster_lengths = &[_]usize{2},
    },

    // ---- Combining sequences ----

    // ÷ 0061 × 0308 × 0301 ÷ 0062 × 0308 ÷  # 'a' + diaeresis + acute + 'b' + diaeresis
    .{
        .desc = "Two base chars with multiple combiners",
        .codepoints = &[_]u21{ 0x0061, 0x0308, 0x0301, 0x0062, 0x0308 },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 3, 2 },
    },

    // ---- Mixed script with combining marks ----

    // ÷ 0041 ÷ 0042 ÷ 0043 ÷  # "ABC" -> three graphemes
    .{
        .desc = "ABC -> three graphemes",
        .codepoints = &[_]u21{ 0x0041, 0x0042, 0x0043 },
        .expected_clusters = 3,
        .cluster_lengths = &[_]usize{ 1, 1, 1 },
    },

    // ÷ 000D × 000A ÷ 0061 ÷  # CR+LF + 'a' -> two graphemes
    .{
        .desc = "CRLF + 'a' -> two graphemes",
        .codepoints = &[_]u21{ 0x000D, 0x000A, 0x0061 },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 2, 1 },
    },

    // ÷ 200D ÷ 0061 ÷  # ZWJ alone + 'a' -> two graphemes (ZWJ not after EP)
    .{
        .desc = "Standalone ZWJ + 'a' -> two graphemes",
        .codepoints = &[_]u21{ 0x200D, 0x0061 },
        .expected_clusters = 2,
        .cluster_lengths = &[_]usize{ 1, 1 },
    },
};

// ============================================================================
// Tests: NFC Normalization against official vectors
// ============================================================================

test "UAX #15 NormalizationTest.txt Part 1: NFC" {
    const allocator = testing.allocator;
    var src_buf: [64]u8 = undefined;

    for (norm_test_vectors) |vec| {
        const input = encodeCodepoints(vec.source, &src_buf) catch {
            std.debug.print("Failed to encode source for: {s}\n", .{vec.desc});
            return error.TestSetupFailed;
        };

        const result = strings.normalization.normalize(allocator, input, .nfc) catch |err| {
            std.debug.print("normalize NFC failed for '{s}': {}\n", .{ vec.desc, err });
            return err;
        };
        defer allocator.free(result);

        // Build expected UTF-8
        var expected_buf: [64]u8 = undefined;
        const expected = encodeCodepoints(vec.nfc, &expected_buf) catch {
            std.debug.print("Failed to encode NFC expected for: {s}\n", .{vec.desc});
            return error.TestSetupFailed;
        };

        if (!std.mem.eql(u8, result, expected)) {
            std.debug.print("\nNFC MISMATCH: {s}\n", .{vec.desc});
            std.debug.print("  input codepoints:", .{});
            for (vec.source) |cp| std.debug.print(" {X:0>4}", .{cp});
            std.debug.print("\n  expected codepoints:", .{});
            for (vec.nfc) |cp| std.debug.print(" {X:0>4}", .{cp});
            std.debug.print("\n  got bytes:", .{});
            for (result) |b| std.debug.print(" {X:0>2}", .{b});
            std.debug.print("\n  expected bytes:", .{});
            for (expected) |b| std.debug.print(" {X:0>2}", .{b});
            std.debug.print("\n", .{});
            return error.TestExpectedEqual;
        }
    }
}

// ============================================================================
// Tests: NFD Normalization against official vectors
// ============================================================================

test "UAX #15 NormalizationTest.txt Part 1: NFD" {
    const allocator = testing.allocator;
    var src_buf: [64]u8 = undefined;

    for (norm_test_vectors) |vec| {
        const input = encodeCodepoints(vec.source, &src_buf) catch {
            std.debug.print("Failed to encode source for: {s}\n", .{vec.desc});
            return error.TestSetupFailed;
        };

        const result = strings.normalization.normalize(allocator, input, .nfd) catch |err| {
            std.debug.print("normalize NFD failed for '{s}': {}\n", .{ vec.desc, err });
            return err;
        };
        defer allocator.free(result);

        var expected_buf: [64]u8 = undefined;
        const expected = encodeCodepoints(vec.nfd, &expected_buf) catch {
            std.debug.print("Failed to encode NFD expected for: {s}\n", .{vec.desc});
            return error.TestSetupFailed;
        };

        if (!std.mem.eql(u8, result, expected)) {
            std.debug.print("\nNFD MISMATCH: {s}\n", .{vec.desc});
            std.debug.print("  input codepoints:", .{});
            for (vec.source) |cp| std.debug.print(" {X:0>4}", .{cp});
            std.debug.print("\n  expected codepoints:", .{});
            for (vec.nfd) |cp| std.debug.print(" {X:0>4}", .{cp});
            std.debug.print("\n  got bytes:", .{});
            for (result) |b| std.debug.print(" {X:0>2}", .{b});
            std.debug.print("\n  expected bytes:", .{});
            for (expected) |b| std.debug.print(" {X:0>2}", .{b});
            std.debug.print("\n", .{});
            return error.TestExpectedEqual;
        }
    }
}

// ============================================================================
// Tests: NFKC Normalization against official vectors
// ============================================================================

test "UAX #15 NormalizationTest.txt Part 1: NFKC" {
    const allocator = testing.allocator;
    var src_buf: [64]u8 = undefined;

    for (norm_test_vectors) |vec| {
        const input = encodeCodepoints(vec.source, &src_buf) catch {
            std.debug.print("Failed to encode source for: {s}\n", .{vec.desc});
            return error.TestSetupFailed;
        };

        const result = strings.normalization.normalize(allocator, input, .nfkc) catch |err| {
            std.debug.print("normalize NFKC failed for '{s}': {}\n", .{ vec.desc, err });
            return err;
        };
        defer allocator.free(result);

        var expected_buf: [64]u8 = undefined;
        const expected = encodeCodepoints(vec.nfkc, &expected_buf) catch {
            std.debug.print("Failed to encode NFKC expected for: {s}\n", .{vec.desc});
            return error.TestSetupFailed;
        };

        if (!std.mem.eql(u8, result, expected)) {
            std.debug.print("\nNFKC MISMATCH: {s}\n", .{vec.desc});
            std.debug.print("  input codepoints:", .{});
            for (vec.source) |cp| std.debug.print(" {X:0>4}", .{cp});
            std.debug.print("\n  expected codepoints:", .{});
            for (vec.nfkc) |cp| std.debug.print(" {X:0>4}", .{cp});
            std.debug.print("\n  got bytes:", .{});
            for (result) |b| std.debug.print(" {X:0>2}", .{b});
            std.debug.print("\n  expected bytes:", .{});
            for (expected) |b| std.debug.print(" {X:0>2}", .{b});
            std.debug.print("\n", .{});
            return error.TestExpectedEqual;
        }
    }
}

// ============================================================================
// Tests: NFKD Normalization against official vectors
// ============================================================================

test "UAX #15 NormalizationTest.txt Part 1: NFKD" {
    const allocator = testing.allocator;
    var src_buf: [64]u8 = undefined;

    for (norm_test_vectors) |vec| {
        const input = encodeCodepoints(vec.source, &src_buf) catch {
            std.debug.print("Failed to encode source for: {s}\n", .{vec.desc});
            return error.TestSetupFailed;
        };

        const result = strings.normalization.normalize(allocator, input, .nfkd) catch |err| {
            std.debug.print("normalize NFKD failed for '{s}': {}\n", .{ vec.desc, err });
            return err;
        };
        defer allocator.free(result);

        var expected_buf: [64]u8 = undefined;
        const expected = encodeCodepoints(vec.nfkd, &expected_buf) catch {
            std.debug.print("Failed to encode NFKD expected for: {s}\n", .{vec.desc});
            return error.TestSetupFailed;
        };

        if (!std.mem.eql(u8, result, expected)) {
            std.debug.print("\nNFKD MISMATCH: {s}\n", .{vec.desc});
            std.debug.print("  input codepoints:", .{});
            for (vec.source) |cp| std.debug.print(" {X:0>4}", .{cp});
            std.debug.print("\n  expected codepoints:", .{});
            for (vec.nfkd) |cp| std.debug.print(" {X:0>4}", .{cp});
            std.debug.print("\n  got bytes:", .{});
            for (result) |b| std.debug.print(" {X:0>2}", .{b});
            std.debug.print("\n  expected bytes:", .{});
            for (expected) |b| std.debug.print(" {X:0>2}", .{b});
            std.debug.print("\n", .{});
            return error.TestExpectedEqual;
        }
    }
}

// ============================================================================
// Tests: NFC stability invariants
//
// From the Unicode Standard, Section 3.11:
//   toNFC(NFC_column)  == NFC_column   (idempotent)
//   toNFC(NFD_column)  == NFC_column   (NFD input -> same NFC result)
// ============================================================================

test "UAX #15 NormalizationTest.txt: NFC stability invariants" {
    const allocator = testing.allocator;

    for (norm_test_vectors) |vec| {
        // Invariant 1: toNFC(NFC) == NFC
        {
            var nfc_buf: [64]u8 = undefined;
            const nfc_input = encodeCodepoints(vec.nfc, &nfc_buf) catch continue;
            const result = try strings.normalization.normalize(allocator, nfc_input, .nfc);
            defer allocator.free(result);

            var expected_buf: [64]u8 = undefined;
            const expected = encodeCodepoints(vec.nfc, &expected_buf) catch continue;

            if (!std.mem.eql(u8, result, expected)) {
                std.debug.print("\nNFC IDEMPOTENT FAIL: {s} -- toNFC(NFC) != NFC\n", .{vec.desc});
                return error.TestExpectedEqual;
            }
        }

        // Invariant 2: toNFC(NFD) == NFC
        {
            var nfd_buf: [64]u8 = undefined;
            const nfd_input = encodeCodepoints(vec.nfd, &nfd_buf) catch continue;
            const result = try strings.normalization.normalize(allocator, nfd_input, .nfc);
            defer allocator.free(result);

            var expected_buf: [64]u8 = undefined;
            const expected = encodeCodepoints(vec.nfc, &expected_buf) catch continue;

            if (!std.mem.eql(u8, result, expected)) {
                std.debug.print("\nNFC ROUNDTRIP FAIL: {s} -- toNFC(NFD) != NFC\n", .{vec.desc});
                return error.TestExpectedEqual;
            }
        }
    }
}

// ============================================================================
// Tests: NFD stability invariants
//
//   toNFD(NFC_column)  == NFD_column
//   toNFD(NFD_column)  == NFD_column  (idempotent)
// ============================================================================

test "UAX #15 NormalizationTest.txt: NFD stability invariants" {
    const allocator = testing.allocator;

    for (norm_test_vectors) |vec| {
        // Invariant: toNFD(NFC) == NFD
        {
            var nfc_buf: [64]u8 = undefined;
            const nfc_input = encodeCodepoints(vec.nfc, &nfc_buf) catch continue;
            const result = try strings.normalization.normalize(allocator, nfc_input, .nfd);
            defer allocator.free(result);

            var expected_buf: [64]u8 = undefined;
            const expected = encodeCodepoints(vec.nfd, &expected_buf) catch continue;

            if (!std.mem.eql(u8, result, expected)) {
                std.debug.print("\nNFD FROM NFC FAIL: {s} -- toNFD(NFC) != NFD\n", .{vec.desc});
                return error.TestExpectedEqual;
            }
        }

        // Invariant: toNFD(NFD) == NFD (idempotent)
        {
            var nfd_buf: [64]u8 = undefined;
            const nfd_input = encodeCodepoints(vec.nfd, &nfd_buf) catch continue;
            const result = try strings.normalization.normalize(allocator, nfd_input, .nfd);
            defer allocator.free(result);

            var expected_buf: [64]u8 = undefined;
            const expected = encodeCodepoints(vec.nfd, &expected_buf) catch continue;

            if (!std.mem.eql(u8, result, expected)) {
                std.debug.print("\nNFD IDEMPOTENT FAIL: {s} -- toNFD(NFD) != NFD\n", .{vec.desc});
                return error.TestExpectedEqual;
            }
        }
    }
}

// ============================================================================
// Tests: NFKC/NFKD stability invariants
//
//   toNFKC(NFKC) == NFKC  (idempotent)
//   toNFKC(NFKD) == NFKC
//   toNFKD(NFKC) == NFKD
//   toNFKD(NFKD) == NFKD  (idempotent)
// ============================================================================

test "UAX #15 NormalizationTest.txt: NFKC/NFKD stability invariants" {
    const allocator = testing.allocator;

    for (norm_test_vectors) |vec| {
        // toNFKC(NFKC) == NFKC
        {
            var nfkc_buf: [64]u8 = undefined;
            const nfkc_input = encodeCodepoints(vec.nfkc, &nfkc_buf) catch continue;
            const result = try strings.normalization.normalize(allocator, nfkc_input, .nfkc);
            defer allocator.free(result);

            var expected_buf: [64]u8 = undefined;
            const expected = encodeCodepoints(vec.nfkc, &expected_buf) catch continue;

            if (!std.mem.eql(u8, result, expected)) {
                std.debug.print("\nNFKC IDEMPOTENT FAIL: {s}\n", .{vec.desc});
                return error.TestExpectedEqual;
            }
        }

        // toNFKC(NFKD) == NFKC
        {
            var nfkd_buf: [64]u8 = undefined;
            const nfkd_input = encodeCodepoints(vec.nfkd, &nfkd_buf) catch continue;
            const result = try strings.normalization.normalize(allocator, nfkd_input, .nfkc);
            defer allocator.free(result);

            var expected_buf: [64]u8 = undefined;
            const expected = encodeCodepoints(vec.nfkc, &expected_buf) catch continue;

            if (!std.mem.eql(u8, result, expected)) {
                std.debug.print("\nNFKC ROUNDTRIP FAIL: {s} -- toNFKC(NFKD) != NFKC\n", .{vec.desc});
                return error.TestExpectedEqual;
            }
        }

        // toNFKD(NFKC) == NFKD
        {
            var nfkc_buf: [64]u8 = undefined;
            const nfkc_input = encodeCodepoints(vec.nfkc, &nfkc_buf) catch continue;
            const result = try strings.normalization.normalize(allocator, nfkc_input, .nfkd);
            defer allocator.free(result);

            var expected_buf: [64]u8 = undefined;
            const expected = encodeCodepoints(vec.nfkd, &expected_buf) catch continue;

            if (!std.mem.eql(u8, result, expected)) {
                std.debug.print("\nNFKD FROM NFKC FAIL: {s}\n", .{vec.desc});
                return error.TestExpectedEqual;
            }
        }

        // toNFKD(NFKD) == NFKD
        {
            var nfkd_buf: [64]u8 = undefined;
            const nfkd_input = encodeCodepoints(vec.nfkd, &nfkd_buf) catch continue;
            const result = try strings.normalization.normalize(allocator, nfkd_input, .nfkd);
            defer allocator.free(result);

            var expected_buf: [64]u8 = undefined;
            const expected = encodeCodepoints(vec.nfkd, &expected_buf) catch continue;

            if (!std.mem.eql(u8, result, expected)) {
                std.debug.print("\nNFKD IDEMPOTENT FAIL: {s}\n", .{vec.desc});
                return error.TestExpectedEqual;
            }
        }
    }
}

// ============================================================================
// Tests: GraphemeBreakTest.txt -- Grapheme cluster count
// ============================================================================

test "UAX #29 GraphemeBreakTest.txt: cluster count" {
    var encode_buf: [128]u8 = undefined;

    for (grapheme_test_vectors) |vec| {
        const input = encodeCodepoints(vec.codepoints, &encode_buf) catch {
            std.debug.print("Failed to encode codepoints for: {s}\n", .{vec.desc});
            return error.TestSetupFailed;
        };

        const actual_count = strings.grapheme.count(input);

        if (actual_count != vec.expected_clusters) {
            std.debug.print("\nGRAPHEME COUNT MISMATCH: {s}\n", .{vec.desc});
            std.debug.print("  codepoints:", .{});
            for (vec.codepoints) |cp| std.debug.print(" {X:0>4}", .{cp});
            std.debug.print("\n  expected clusters: {d}\n", .{vec.expected_clusters});
            std.debug.print("  actual clusters:   {d}\n", .{actual_count});
            return error.TestExpectedEqual;
        }
    }
}

// ============================================================================
// Tests: GraphemeBreakTest.txt -- Grapheme cluster boundaries (iterator)
// ============================================================================

test "UAX #29 GraphemeBreakTest.txt: cluster boundaries via iterator" {
    var encode_buf: [128]u8 = undefined;

    for (grapheme_test_vectors) |vec| {
        const input = encodeCodepoints(vec.codepoints, &encode_buf) catch {
            std.debug.print("Failed to encode codepoints for: {s}\n", .{vec.desc});
            return error.TestSetupFailed;
        };

        var iter = strings.grapheme.iterator(input);
        var cluster_idx: usize = 0;

        while (iter.next()) |cluster| {
            if (cluster_idx >= vec.cluster_lengths.len) {
                std.debug.print("\nGRAPHEME BOUNDARY: {s} -- too many clusters\n", .{vec.desc});
                return error.TestExpectedEqual;
            }

            // Count codepoints in this cluster
            var cp_count: usize = 0;
            var cp_iter = std.unicode.Utf8Iterator{ .bytes = cluster, .i = 0 };
            while (cp_iter.nextCodepoint()) |_| {
                cp_count += 1;
            }

            if (cp_count != vec.cluster_lengths[cluster_idx]) {
                std.debug.print("\nGRAPHEME BOUNDARY: {s} -- cluster {d} has {d} codepoints, expected {d}\n", .{
                    vec.desc,
                    cluster_idx,
                    cp_count,
                    vec.cluster_lengths[cluster_idx],
                });
                return error.TestExpectedEqual;
            }

            cluster_idx += 1;
        }

        if (cluster_idx != vec.cluster_lengths.len) {
            std.debug.print("\nGRAPHEME BOUNDARY: {s} -- got {d} clusters, expected {d}\n", .{
                vec.desc,
                cluster_idx,
                vec.cluster_lengths.len,
            });
            return error.TestExpectedEqual;
        }
    }
}
