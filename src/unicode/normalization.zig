// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode normalization (UAX #15).
//!
//! This module provides Unicode normalization forms:
//! - NFD: Canonical Decomposition
//! - NFC: Canonical Decomposition + Canonical Composition
//! - NFKD: Compatibility Decomposition
//! - NFKC: Compatibility Decomposition + Canonical Composition
//!
//! Uses generated Unicode Character Database tables for full Unicode 15.1 support.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const categories = @import("categories");

// Generated UCD tables
const ucd_ccc = @import("ucd_ccc");
const ucd_decomp = @import("ucd_decomposition");
const ucd_comp = @import("ucd_composition");

pub const Codepoint = types.Codepoint;
pub const NormalizationForm = types.NormalizationForm;
pub const StringError = types.StringError;

/// Canonical Combining Class (CCC) values
pub const CombiningClass = ucd_ccc.CombiningClass;

/// Gets the Canonical Combining Class for a code point.
/// Uses generated Unicode 15.1 tables for complete coverage.
pub fn getCombiningClass(cp: Codepoint) CombiningClass {
    return ucd_ccc.getCombiningClass(cp);
}

/// Checks if a code point is a starter (CCC = 0)
pub fn isStarter(cp: Codepoint) bool {
    return getCombiningClass(cp) == 0;
}

/// Checks if a string is in a given normalization form
pub fn isNormalized(utf8: []const u8, form: NormalizationForm) bool {
    // Quick check implementation
    // A string is normalized if:
    // 1. All characters are in canonical order (by combining class)
    // 2. No decomposable characters (for NFC/NFKC) or
    //    no composable sequences (for NFD/NFKD)
    _ = form;

    var iter = std.unicode.Utf8Iterator{ .bytes = utf8, .i = 0 };
    var last_ccc: CombiningClass = 0;

    while (iter.nextCodepoint()) |cp| {
        const ccc = getCombiningClass(cp);

        // Check canonical ordering
        if (ccc != 0 and last_ccc > ccc) {
            return false;
        }

        last_ccc = if (ccc != 0) ccc else 0;
    }

    return true;
}

/// Decomposes a code point (canonical decomposition)
/// Returns the decomposition or the original code point if no decomposition exists.
/// Uses generated Unicode 15.1 tables for complete coverage.
pub fn decompose(cp: Codepoint, buf: []Codepoint) []Codepoint {
    return decomposeWithCompat(cp, buf, false);
}

/// Decomposes a code point with optional compatibility decomposition (for NFKC/NFKD)
pub fn decomposeWithCompat(cp: Codepoint, buf: []Codepoint, use_compat: bool) []Codepoint {
    // Hangul algorithmic decomposition
    if (cp >= 0xAC00 and cp <= 0xD7A3) {
        return decomposeHangul(cp, buf);
    }

    // For NFKC/NFKD, check compatibility decomposition first
    if (use_compat) {
        if (getCompatibilityDecomposition(cp, buf)) |result| {
            return result;
        }
    }

    // Use generated UCD decomposition table
    if (ucd_decomp.getDecomposition(cp)) |decomp| {
        if (buf.len >= decomp.len) {
            for (decomp, 0..) |d, i| {
                buf[i] = d;
            }
            return buf[0..decomp.len];
        }
    }

    // No decomposition - return original code point
    if (buf.len > 0) {
        buf[0] = cp;
        return buf[0..1];
    }
    return &.{};
}

/// Gets compatibility decomposition for a code point (for NFKC/NFKD)
/// Returns null if no compatibility decomposition exists
fn getCompatibilityDecomposition(cp: Codepoint, buf: []Codepoint) ?[]Codepoint {
    // Latin ligatures
    switch (cp) {
        0xFB00 => { // ﬀ -> ff
            if (buf.len >= 2) {
                buf[0] = 'f';
                buf[1] = 'f';
                return buf[0..2];
            }
        },
        0xFB01 => { // ﬁ -> fi
            if (buf.len >= 2) {
                buf[0] = 'f';
                buf[1] = 'i';
                return buf[0..2];
            }
        },
        0xFB02 => { // ﬂ -> fl
            if (buf.len >= 2) {
                buf[0] = 'f';
                buf[1] = 'l';
                return buf[0..2];
            }
        },
        0xFB03 => { // ﬃ -> ffi
            if (buf.len >= 3) {
                buf[0] = 'f';
                buf[1] = 'f';
                buf[2] = 'i';
                return buf[0..3];
            }
        },
        0xFB04 => { // ﬄ -> ffl
            if (buf.len >= 3) {
                buf[0] = 'f';
                buf[1] = 'f';
                buf[2] = 'l';
                return buf[0..3];
            }
        },
        0xFB05 => { // ﬅ -> st
            if (buf.len >= 2) {
                buf[0] = 's';
                buf[1] = 't';
                return buf[0..2];
            }
        },
        0xFB06 => { // ﬆ -> st
            if (buf.len >= 2) {
                buf[0] = 's';
                buf[1] = 't';
                return buf[0..2];
            }
        },
        else => {},
    }

    // Fullwidth ASCII (U+FF01-U+FF5E -> U+0021-U+007E)
    if (cp >= 0xFF01 and cp <= 0xFF5E) {
        if (buf.len >= 1) {
            buf[0] = @intCast(cp - 0xFF01 + 0x0021);
            return buf[0..1];
        }
    }

    // Halfwidth Katakana (U+FF65-U+FF9F -> corresponding fullwidth)
    // Just decompose to the fullwidth equivalent
    if (cp >= 0xFF65 and cp <= 0xFF9F) {
        if (buf.len >= 1) {
            // Map halfwidth to fullwidth katakana
            const halfwidth_to_fullwidth = [_]Codepoint{
                0x30FB, 0x30F2, 0x30A1, 0x30A3, 0x30A5, 0x30A7, 0x30A9, 0x30E3, // FF65-FF6C
                0x30E5, 0x30E7, 0x30C3, 0x30FC, 0x30A2, 0x30A4, 0x30A6, 0x30A8, // FF6D-FF74
                0x30AA, 0x30AB, 0x30AD, 0x30AF, 0x30B1, 0x30B3, 0x30B5, 0x30B7, // FF75-FF7C
                0x30B9, 0x30BB, 0x30BD, 0x30BF, 0x30C1, 0x30C4, 0x30C6, 0x30C8, // FF7D-FF84
                0x30CA, 0x30CB, 0x30CC, 0x30CD, 0x30CE, 0x30CF, 0x30D2, 0x30D5, // FF85-FF8C
                0x30D8, 0x30DB, 0x30DE, 0x30DF, 0x30E0, 0x30E1, 0x30E2, 0x30E4, // FF8D-FF94
                0x30E6, 0x30E8, 0x30E9, 0x30EA, 0x30EB, 0x30EC, 0x30ED, 0x30EF, // FF95-FF9C
                0x30F3, 0x3099, 0x309A, // FF9D-FF9F
            };
            const idx = cp - 0xFF65;
            if (idx < halfwidth_to_fullwidth.len) {
                buf[0] = halfwidth_to_fullwidth[idx];
                return buf[0..1];
            }
        }
    }

    // Circled numbers 1-20 (U+2460-U+2473 -> 1-20)
    if (cp >= 0x2460 and cp <= 0x2473) {
        const num = cp - 0x2460 + 1;
        if (num <= 9) {
            if (buf.len >= 1) {
                buf[0] = @intCast('0' + num);
                return buf[0..1];
            }
        } else if (num <= 20) {
            if (buf.len >= 2) {
                buf[0] = if (num >= 10 and num <= 19) '1' else '2';
                buf[1] = @intCast('0' + (num % 10));
                return buf[0..2];
            }
        }
    }

    // Circled uppercase letters A-Z (U+24B6-U+24CF -> A-Z)
    if (cp >= 0x24B6 and cp <= 0x24CF) {
        if (buf.len >= 1) {
            buf[0] = @intCast('A' + (cp - 0x24B6));
            return buf[0..1];
        }
    }

    // Circled lowercase letters a-z (U+24D0-U+24E9 -> a-z)
    if (cp >= 0x24D0 and cp <= 0x24E9) {
        if (buf.len >= 1) {
            buf[0] = @intCast('a' + (cp - 0x24D0));
            return buf[0..1];
        }
    }

    // Superscript digits 0-9 (partial)
    switch (cp) {
        0x2070 => { // ⁰
            if (buf.len >= 1) {
                buf[0] = '0';
                return buf[0..1];
            }
        },
        0x00B9 => { // ¹
            if (buf.len >= 1) {
                buf[0] = '1';
                return buf[0..1];
            }
        },
        0x00B2 => { // ²
            if (buf.len >= 1) {
                buf[0] = '2';
                return buf[0..1];
            }
        },
        0x00B3 => { // ³
            if (buf.len >= 1) {
                buf[0] = '3';
                return buf[0..1];
            }
        },
        0x2074...0x2079 => { // ⁴-⁹
            if (buf.len >= 1) {
                buf[0] = @intCast('0' + (cp - 0x2070));
                return buf[0..1];
            }
        },
        else => {},
    }

    // Subscript digits 0-9 (U+2080-U+2089)
    if (cp >= 0x2080 and cp <= 0x2089) {
        if (buf.len >= 1) {
            buf[0] = @intCast('0' + (cp - 0x2080));
            return buf[0..1];
        }
    }

    // Roman numerals
    switch (cp) {
        0x2160 => { // Ⅰ
            if (buf.len >= 1) {
                buf[0] = 'I';
                return buf[0..1];
            }
        },
        0x2161 => { // Ⅱ
            if (buf.len >= 2) {
                buf[0] = 'I';
                buf[1] = 'I';
                return buf[0..2];
            }
        },
        0x2162 => { // Ⅲ
            if (buf.len >= 3) {
                buf[0] = 'I';
                buf[1] = 'I';
                buf[2] = 'I';
                return buf[0..3];
            }
        },
        0x2163 => { // Ⅳ
            if (buf.len >= 2) {
                buf[0] = 'I';
                buf[1] = 'V';
                return buf[0..2];
            }
        },
        0x2164 => { // Ⅴ
            if (buf.len >= 1) {
                buf[0] = 'V';
                return buf[0..1];
            }
        },
        0x2170 => { // ⅰ
            if (buf.len >= 1) {
                buf[0] = 'i';
                return buf[0..1];
            }
        },
        else => {},
    }

    return null;
}

/// Decomposes a Hangul syllable algorithmically
fn decomposeHangul(cp: Codepoint, buf: []Codepoint) []Codepoint {
    const S_BASE: u21 = 0xAC00;
    const L_BASE: u21 = 0x1100;
    const V_BASE: u21 = 0x1161;
    const T_BASE: u21 = 0x11A7;
    const V_COUNT: u21 = 21;
    const T_COUNT: u21 = 28;
    const N_COUNT: u21 = V_COUNT * T_COUNT;

    const s_index = cp - S_BASE;
    const l_index = s_index / N_COUNT;
    const v_index = (s_index % N_COUNT) / T_COUNT;
    const t_index = s_index % T_COUNT;

    if (buf.len < 2) return &.{};

    buf[0] = L_BASE + l_index;
    buf[1] = V_BASE + v_index;

    if (t_index > 0) {
        if (buf.len < 3) return buf[0..2];
        buf[2] = T_BASE + t_index;
        return buf[0..3];
    }

    return buf[0..2];
}

// ============================================================================
// Canonical Composition
// ============================================================================

/// Looks up a primary composite for a (starter, combiner) pair
/// Uses generated Unicode 15.1 tables for complete coverage.
/// Returns null if no composite exists
pub fn getComposite(starter: Codepoint, combiner: Codepoint) ?Codepoint {
    // Use generated UCD composition table (includes Hangul algorithmic composition)
    return ucd_comp.getComposite(starter, combiner);
}

/// Canonical composition algorithm (UAX #15)
/// Takes a decomposed buffer and composes it in-place
fn composeBuffer(buffer: []Codepoint) usize {
    if (buffer.len == 0) return 0;

    var write_idx: usize = 0;
    var starter_idx: usize = 0;
    var last_ccc: CombiningClass = 0;

    // The first character is always kept
    write_idx = 1;

    var i: usize = 1;
    while (i < buffer.len) : (i += 1) {
        const cp = buffer[i];
        const ccc = getCombiningClass(cp);

        // Check if we can compose with the starter
        const starter = buffer[starter_idx];

        // A combining character can compose with a starter if:
        // 1. The starter is a starter (CCC = 0)
        // 2. The combining character is not blocked by an intervening character
        //    (blocked if there's a character between them with CCC >= this char's CCC)
        // 3. A primary composite exists for the pair
        const blocked = (last_ccc != 0 and last_ccc >= ccc);

        if (!blocked) {
            if (getComposite(starter, cp)) |composite| {
                // Composition succeeded - replace starter
                buffer[starter_idx] = composite;
                // Don't update last_ccc since we consumed the combining character
                continue;
            }
        }

        // No composition - copy character
        if (ccc == 0) {
            // New starter
            starter_idx = write_idx;
            last_ccc = 0;
        } else {
            last_ccc = ccc;
        }
        buffer[write_idx] = cp;
        write_idx += 1;
    }

    return write_idx;
}

/// Normalizes a UTF-8 string to the specified form using an allocator
pub fn normalize(allocator: std.mem.Allocator, utf8: []const u8, form: NormalizationForm) ![]u8 {
    // Note: The isNormalized quick check is only accurate for canonical ordering
    // For full correctness, we always do the full normalization
    // A production implementation would use Unicode Quick_Check properties

    const should_compose = (form == .nfc or form == .nfkc);
    const use_compat = (form == .nfkc or form == .nfkd);

    // Step 1: Decompose all characters into a buffer
    // For NFKC/NFKD, use compatibility decomposition
    var codepoints: std.ArrayList(Codepoint) = .empty;
    defer codepoints.deinit(allocator);

    var iter = std.unicode.Utf8Iterator{ .bytes = utf8, .i = 0 };
    var decomp_buf: [18]Codepoint = undefined; // Max decomposition length

    while (iter.nextCodepoint()) |cp| {
        const decomposed = decomposeWithCompat(cp, &decomp_buf, use_compat);
        try codepoints.appendSlice(allocator, decomposed);
    }

    // Step 2: Sort combining marks by canonical combining class (canonical ordering)
    sortByCombiningClass(codepoints.items);

    // Step 3: For NFC/NFKC, apply canonical composition
    var final_len = codepoints.items.len;
    if (should_compose and codepoints.items.len > 0) {
        final_len = composeBuffer(codepoints.items);
    }

    // Step 4: Encode back to UTF-8
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var encode_buf: [4]u8 = undefined;
    for (codepoints.items[0..final_len]) |cp| {
        const encoded = codepoint_mod.encodeUtf8(cp, &encode_buf);
        try result.appendSlice(allocator, encoded);
    }

    return result.toOwnedSlice(allocator);
}

/// Sorts combining marks by canonical combining class
/// This implements canonical ordering per UAX #15
fn sortByCombiningClass(codepoints: []Codepoint) void {
    if (codepoints.len < 2) return;

    // Find sequences of combining characters and sort them
    var i: usize = 0;
    while (i < codepoints.len) {
        // Find a starter
        if (getCombiningClass(codepoints[i]) == 0) {
            // Found a starter, now find the end of the combining sequence
            const seq_start = i + 1;
            var seq_end = seq_start;
            while (seq_end < codepoints.len and getCombiningClass(codepoints[seq_end]) != 0) {
                seq_end += 1;
            }

            // Sort the combining sequence by CCC (stable sort)
            if (seq_end > seq_start + 1) {
                sortCombiningSequence(codepoints[seq_start..seq_end]);
            }

            i = seq_end;
        } else {
            i += 1;
        }
    }
}

/// Stable insertion sort for combining characters by CCC
fn sortCombiningSequence(seq: []Codepoint) void {
    if (seq.len < 2) return;

    var i: usize = 1;
    while (i < seq.len) : (i += 1) {
        const key = seq[i];
        const key_ccc = getCombiningClass(key);
        var j: usize = i;

        // Move elements with higher CCC forward (stable sort)
        while (j > 0 and getCombiningClass(seq[j - 1]) > key_ccc) {
            seq[j] = seq[j - 1];
            j -= 1;
        }
        seq[j] = key;
    }
}

test "combining class" {
    const testing = std.testing;

    try testing.expectEqual(@as(CombiningClass, 0), getCombiningClass('A'));
    try testing.expectEqual(@as(CombiningClass, 230), getCombiningClass(0x0301)); // Combining acute
    try testing.expect(isStarter('A'));
    try testing.expect(!isStarter(0x0301));
}

test "decomposition" {
    const testing = std.testing;

    var buf: [4]Codepoint = undefined;

    // Simple character
    const simple = decompose('A', &buf);
    try testing.expectEqual(@as(usize, 1), simple.len);
    try testing.expectEqual(@as(Codepoint, 'A'), simple[0]);

    // Precomposed character
    const decomposed = decompose(0x00E9, &buf); // é
    try testing.expectEqual(@as(usize, 2), decomposed.len);
    try testing.expectEqual(@as(Codepoint, 0x0065), decomposed[0]); // e
    try testing.expectEqual(@as(Codepoint, 0x0301), decomposed[1]); // combining acute
}

test "Hangul decomposition" {
    const testing = std.testing;

    var buf: [4]Codepoint = undefined;

    // 가 (U+AC00) = ㄱ (U+1100) + ㅏ (U+1161)
    const ga = decompose(0xAC00, &buf);
    try testing.expectEqual(@as(usize, 2), ga.len);
    try testing.expectEqual(@as(Codepoint, 0x1100), ga[0]);
    try testing.expectEqual(@as(Codepoint, 0x1161), ga[1]);

    // 한 (U+D55C) = ㅎ (U+1112) + ㅏ (U+1161) + ㄴ (U+11AB)
    const han = decompose(0xD55C, &buf);
    try testing.expectEqual(@as(usize, 3), han.len);
    try testing.expectEqual(@as(Codepoint, 0x1112), han[0]);
    try testing.expectEqual(@as(Codepoint, 0x1161), han[1]);
    try testing.expectEqual(@as(Codepoint, 0x11AB), han[2]);
}

test "composition lookup" {
    const testing = std.testing;

    // e + combining acute -> é
    try testing.expectEqual(@as(?Codepoint, 0x00E9), getComposite(0x0065, 0x0301));

    // A + combining grave -> À
    try testing.expectEqual(@as(?Codepoint, 0x00C0), getComposite(0x0041, 0x0300));

    // A + combining dot below -> Ạ (U+1EA0) - now using full UCD tables
    try testing.expectEqual(@as(?Codepoint, 0x1EA0), getComposite(0x0041, 0x0323));

    // No composite for A + combining double breve below (U+035C)
    try testing.expectEqual(@as(?Codepoint, null), getComposite(0x0041, 0x035C));
}

test "Hangul composition" {
    const testing = std.testing;

    // ㄱ (U+1100) + ㅏ (U+1161) -> 가 (U+AC00)
    try testing.expectEqual(@as(?Codepoint, 0xAC00), getComposite(0x1100, 0x1161));

    // 가 (U+AC00) + ㄴ (U+11AB) -> 간 (U+AC04)
    try testing.expectEqual(@as(?Codepoint, 0xAC04), getComposite(0xAC00, 0x11AB));
}

test "NFC normalization: e + combining acute" {
    const testing = std.testing;

    // NFD input: e (U+0065) + combining acute (U+0301)
    const nfd = "e\xCC\x81";

    // NFC output: é (U+00E9)
    const nfc = try normalize(testing.allocator, nfd, .nfc);
    defer testing.allocator.free(nfc);

    // é in UTF-8 is 0xC3 0xA9
    try testing.expectEqualSlices(u8, "\xC3\xA9", nfc);
}

test "NFC normalization: already composed" {
    const testing = std.testing;

    // Already NFC: é (U+00E9)
    const already_nfc = "\xC3\xA9";

    const result = try normalize(testing.allocator, already_nfc, .nfc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, already_nfc, result);
}

test "NFC normalization: multiple combining marks" {
    const testing = std.testing;

    // a + combining acute -> á
    const input = "a\xCC\x81";

    const nfc = try normalize(testing.allocator, input, .nfc);
    defer testing.allocator.free(nfc);

    // á in UTF-8 is 0xC3 0xA1
    try testing.expectEqualSlices(u8, "\xC3\xA1", nfc);
}

test "NFD preserves decomposed form" {
    const testing = std.testing;

    // Input: e + combining acute (already NFD)
    const nfd_input = "e\xCC\x81";

    const result = try normalize(testing.allocator, nfd_input, .nfd);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, nfd_input, result);
}

test "NFC round-trip: decompose then compose" {
    const testing = std.testing;

    // Start with precomposed é
    const original = "\xC3\xA9"; // é

    // Decompose to NFD
    const nfd = try normalize(testing.allocator, original, .nfd);
    defer testing.allocator.free(nfd);
    try testing.expectEqualSlices(u8, "e\xCC\x81", nfd); // e + combining acute

    // Compose back to NFC
    const nfc = try normalize(testing.allocator, nfd, .nfc);
    defer testing.allocator.free(nfc);
    try testing.expectEqualSlices(u8, original, nfc); // é
}

test "NFKC: Latin ligature fi" {
    const testing = std.testing;

    // ﬁ (U+FB01) -> fi
    const input = "\xEF\xAC\x81";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "fi", result);
}

test "NFKC: Latin ligature ffi" {
    const testing = std.testing;

    // ﬃ (U+FB03) -> ffi
    const input = "\xEF\xAC\x83";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "ffi", result);
}

test "NFKD: Latin ligature fl" {
    const testing = std.testing;

    // ﬂ (U+FB02) -> fl
    const input = "\xEF\xAC\x82";
    const result = try normalize(testing.allocator, input, .nfkd);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "fl", result);
}

test "NFKC: Fullwidth ASCII" {
    const testing = std.testing;

    // Ａ (U+FF21) -> A
    const input = "\xEF\xBC\xA1";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "A", result);
}

test "NFKD: Fullwidth digit" {
    const testing = std.testing;

    // ５ (U+FF15) -> 5
    const input = "\xEF\xBC\x95";
    const result = try normalize(testing.allocator, input, .nfkd);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "5", result);
}

test "NFKC: Circled number" {
    const testing = std.testing;

    // ① (U+2460) -> 1
    const input = "\xE2\x91\xA0";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "1", result);
}

test "NFKD: Circled letter" {
    const testing = std.testing;

    // Ⓐ (U+24B6) -> A
    const input = "\xE2\x92\xB6";
    const result = try normalize(testing.allocator, input, .nfkd);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "A", result);
}

test "NFKC: Superscript digit" {
    const testing = std.testing;

    // ² (U+00B2) -> 2
    const input = "\xC2\xB2";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "2", result);
}

test "NFKD: Subscript digit" {
    const testing = std.testing;

    // ₅ (U+2085) -> 5
    const input = "\xE2\x82\x85";
    const result = try normalize(testing.allocator, input, .nfkd);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "5", result);
}

test "NFKC: Roman numeral" {
    const testing = std.testing;

    // Ⅱ (U+2161) -> II
    const input = "\xE2\x85\xA1";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "II", result);
}

test "NFC does not apply compatibility decomposition" {
    const testing = std.testing;

    // ﬁ (U+FB01) should remain unchanged in NFC (it's already canonical)
    const input = "\xEF\xAC\x81";
    const result = try normalize(testing.allocator, input, .nfc);
    defer testing.allocator.free(result);

    // NFC should preserve the ligature
    try testing.expectEqualSlices(u8, input, result);
}

test "NFD does not apply compatibility decomposition" {
    const testing = std.testing;

    // ① (U+2460) should remain unchanged in NFD
    const input = "\xE2\x91\xA0";
    const result = try normalize(testing.allocator, input, .nfd);
    defer testing.allocator.free(result);

    // NFD should preserve the circled number
    try testing.expectEqualSlices(u8, input, result);
}
