// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Decomposition helpers for Unicode normalization (UAX #15).
//!
//! Contains canonical and compatibility decomposition routines used by
//! the main normalization module. Separated to keep file sizes manageable.

const types = @import("types");
const ucd_decomp = @import("ucd_decomposition");

pub const Codepoint = types.Codepoint;

/// Decomposes a single code point one level (no recursion).
/// Used as the building block for the recursive decomposer.
fn decomposeOneLevel(cp: Codepoint, buf: []Codepoint, use_compat: bool) []Codepoint {
    // Hangul algorithmic decomposition (already fully decomposed)
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

/// Decomposes a code point with optional compatibility decomposition (for NFKC/NFKD).
///
/// Performs recursive decomposition as required by UAX #15: each code point
/// in the initial decomposition is itself decomposed until no further
/// decomposition applies. This ensures characters like U+01D5 (which
/// decomposes to U+00DC + U+0304, where U+00DC further decomposes to
/// U+0055 + U+0308) are fully decomposed in a single call.
pub fn decomposeWithCompat(cp: Codepoint, buf: []Codepoint, use_compat: bool) []Codepoint {
    // First level decomposition
    var tmp_buf: [18]Codepoint = undefined;
    const first_level = decomposeOneLevel(cp, &tmp_buf, use_compat);

    // If no decomposition occurred (single cp returned unchanged), short-circuit
    if (first_level.len == 1 and first_level[0] == cp) {
        if (buf.len > 0) {
            buf[0] = cp;
            return buf[0..1];
        }
        return &.{};
    }

    // Recursively decompose each code point in the result.
    // We use buf as the output accumulator and a second temp buffer for
    // nested decomposition. Maximum canonical decomposition depth in Unicode
    // is 3 levels; the recursion handles any depth.
    var out_len: usize = 0;
    for (first_level) |dcp| {
        // Hangul Jamo L/V/T do not decompose further
        if ((dcp >= 0x1100 and dcp <= 0x115F) or
            (dcp >= 0x1160 and dcp <= 0x11A7) or
            (dcp >= 0x11A8 and dcp <= 0x11FF))
        {
            if (out_len < buf.len) {
                buf[out_len] = dcp;
                out_len += 1;
            }
            continue;
        }

        var sub_buf: [18]Codepoint = undefined;
        const sub = decomposeOneLevel(dcp, &sub_buf, use_compat);

        // Check if further recursion is needed
        if (sub.len == 1 and sub[0] == dcp) {
            // No further decomposition
            if (out_len < buf.len) {
                buf[out_len] = dcp;
                out_len += 1;
            }
        } else {
            // Recurse one more level (covers depth > 2, rare but possible)
            for (sub) |sub_cp| {
                var deep_buf: [18]Codepoint = undefined;
                const deep = decomposeOneLevel(sub_cp, &deep_buf, use_compat);
                for (deep) |deep_cp| {
                    if (out_len < buf.len) {
                        buf[out_len] = deep_cp;
                        out_len += 1;
                    }
                }
            }
        }
    }

    return buf[0..out_len];
}

/// Gets compatibility decomposition for a code point (for NFKC/NFKD)
/// Returns null if no compatibility decomposition exists
pub fn getCompatibilityDecomposition(cp: Codepoint, buf: []Codepoint) ?[]Codepoint {
    // Latin ligatures
    switch (cp) {
        0xFB00 => { // ff -> ff
            if (buf.len >= 2) {
                buf[0] = 'f';
                buf[1] = 'f';
                return buf[0..2];
            }
        },
        0xFB01 => { // fi -> fi
            if (buf.len >= 2) {
                buf[0] = 'f';
                buf[1] = 'i';
                return buf[0..2];
            }
        },
        0xFB02 => { // fl -> fl
            if (buf.len >= 2) {
                buf[0] = 'f';
                buf[1] = 'l';
                return buf[0..2];
            }
        },
        0xFB03 => { // ffi -> ffi
            if (buf.len >= 3) {
                buf[0] = 'f';
                buf[1] = 'f';
                buf[2] = 'i';
                return buf[0..3];
            }
        },
        0xFB04 => { // ffl -> ffl
            if (buf.len >= 3) {
                buf[0] = 'f';
                buf[1] = 'f';
                buf[2] = 'l';
                return buf[0..3];
            }
        },
        0xFB05 => { // st -> st
            if (buf.len >= 2) {
                buf[0] = 's';
                buf[1] = 't';
                return buf[0..2];
            }
        },
        0xFB06 => { // st -> st
            if (buf.len >= 2) {
                buf[0] = 's';
                buf[1] = 't';
                return buf[0..2];
            }
        },

        // Spacing modifier letters -> SPACE + combining mark (compat decomposition)
        // Per UnicodeData.txt, these all have <compat> 0020 XXXX decompositions.
        0x02B0 => { // MODIFIER LETTER SMALL H -> <super> 0068
            if (buf.len >= 1) {
                buf[0] = 0x0068;
                return buf[0..1];
            }
        },
        0x00A8 => { // DIAERESIS -> SPACE + COMBINING DIAERESIS
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x0308;
                return buf[0..2];
            }
        },
        0x00AF => { // MACRON -> SPACE + COMBINING MACRON
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x0304;
                return buf[0..2];
            }
        },
        0x00B4 => { // ACUTE ACCENT -> SPACE + COMBINING ACUTE ACCENT
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x0301;
                return buf[0..2];
            }
        },
        0x00B8 => { // CEDILLA -> SPACE + COMBINING CEDILLA
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x0327;
                return buf[0..2];
            }
        },
        0x02C7 => { // CARON -> SPACE + COMBINING CARON
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x030C;
                return buf[0..2];
            }
        },
        0x02D8 => { // BREVE -> SPACE + COMBINING BREVE
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x0306;
                return buf[0..2];
            }
        },
        0x02D9 => { // DOT ABOVE -> SPACE + COMBINING DOT ABOVE
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x0307;
                return buf[0..2];
            }
        },
        0x02DA => { // RING ABOVE -> SPACE + COMBINING RING ABOVE
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x030A;
                return buf[0..2];
            }
        },
        0x02DB => { // OGONEK -> SPACE + COMBINING OGONEK
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x0328;
                return buf[0..2];
            }
        },
        0x02DC => { // SMALL TILDE -> SPACE + COMBINING TILDE
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x0303;
                return buf[0..2];
            }
        },
        0x02DD => { // DOUBLE ACUTE ACCENT -> SPACE + COMBINING DOUBLE ACUTE
            if (buf.len >= 2) {
                buf[0] = 0x0020;
                buf[1] = 0x030B;
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
        0x2070 => { // superscript 0
            if (buf.len >= 1) {
                buf[0] = '0';
                return buf[0..1];
            }
        },
        0x00B9 => { // superscript 1
            if (buf.len >= 1) {
                buf[0] = '1';
                return buf[0..1];
            }
        },
        0x00B2 => { // superscript 2
            if (buf.len >= 1) {
                buf[0] = '2';
                return buf[0..1];
            }
        },
        0x00B3 => { // superscript 3
            if (buf.len >= 1) {
                buf[0] = '3';
                return buf[0..1];
            }
        },
        0x2074...0x2079 => { // superscript 4-9
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
        0x2160 => { // Roman numeral I
            if (buf.len >= 1) {
                buf[0] = 'I';
                return buf[0..1];
            }
        },
        0x2161 => { // Roman numeral II
            if (buf.len >= 2) {
                buf[0] = 'I';
                buf[1] = 'I';
                return buf[0..2];
            }
        },
        0x2162 => { // Roman numeral III
            if (buf.len >= 3) {
                buf[0] = 'I';
                buf[1] = 'I';
                buf[2] = 'I';
                return buf[0..3];
            }
        },
        0x2163 => { // Roman numeral IV
            if (buf.len >= 2) {
                buf[0] = 'I';
                buf[1] = 'V';
                return buf[0..2];
            }
        },
        0x2164 => { // Roman numeral V
            if (buf.len >= 1) {
                buf[0] = 'V';
                return buf[0..1];
            }
        },
        0x2170 => { // Roman numeral i (lowercase)
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
pub fn decomposeHangul(cp: Codepoint, buf: []Codepoint) []Codepoint {
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
// Tests
// ============================================================================

const std = @import("std");

test "decomposition" {
    const testing = std.testing;

    var buf: [4]Codepoint = undefined;

    // Simple character
    const simple = decomposeWithCompat('A', &buf, false);
    try testing.expectEqual(@as(usize, 1), simple.len);
    try testing.expectEqual(@as(Codepoint, 'A'), simple[0]);

    // Precomposed character (e-acute)
    const decomposed = decomposeWithCompat(0x00E9, &buf, false);
    try testing.expectEqual(@as(usize, 2), decomposed.len);
    try testing.expectEqual(@as(Codepoint, 0x0065), decomposed[0]); // e
    try testing.expectEqual(@as(Codepoint, 0x0301), decomposed[1]); // combining acute
}

test "Hangul decomposition" {
    const testing = std.testing;

    var buf: [4]Codepoint = undefined;

    // U+AC00 = U+1100 + U+1161
    const ga = decomposeHangul(0xAC00, &buf);
    try testing.expectEqual(@as(usize, 2), ga.len);
    try testing.expectEqual(@as(Codepoint, 0x1100), ga[0]);
    try testing.expectEqual(@as(Codepoint, 0x1161), ga[1]);

    // U+D55C = U+1112 + U+1161 + U+11AB
    const han = decomposeHangul(0xD55C, &buf);
    try testing.expectEqual(@as(usize, 3), han.len);
    try testing.expectEqual(@as(Codepoint, 0x1112), han[0]);
    try testing.expectEqual(@as(Codepoint, 0x1161), han[1]);
    try testing.expectEqual(@as(Codepoint, 0x11AB), han[2]);
}
