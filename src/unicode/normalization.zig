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
//!
//! Internal helpers are split across sub-modules to keep file sizes manageable:
//! - `norm_decompose.zig`: canonical and compatibility decomposition
//! - `norm_compose.zig`: composition, CCC sorting, streaming window flush

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const categories = @import("categories");
const simd = @import("simd");

// Generated UCD tables
const ucd_ccc = @import("ucd_ccc");
const ucd_decomp = @import("ucd_decomposition");
const ucd_comp = @import("ucd_composition");
const ucd_nfc_qc = @import("ucd_nfc_qc");
const ucd_nfkc_qc = @import("ucd_nfkc_qc");

// Sub-modules
const norm_decompose = @import("norm_decompose.zig");
const norm_compose = @import("norm_compose.zig");

pub const Codepoint = types.Codepoint;
pub const NormalizationForm = types.NormalizationForm;
pub const StringError = types.StringError;

/// Canonical Combining Class (CCC) values
pub const CombiningClass = ucd_ccc.CombiningClass;

/// Gets the Canonical Combining Class for a code point.
/// Uses generated Unicode 15.1 tables for complete coverage.
pub fn getCombiningClass(cp: Codepoint) CombiningClass {
    return norm_compose.getCombiningClass(cp);
}

/// Checks if a code point is a starter (CCC = 0)
pub fn isStarter(cp: Codepoint) bool {
    return getCombiningClass(cp) == 0;
}

/// Checks if a string is in a given normalization form.
///
/// For NFC and NFKC, uses Unicode Quick_Check properties (NFC_QC and NFKC_QC)
/// from DerivedNormalizationProps.txt. Code points with a Quick_Check value of
/// "Maybe" are conservatively treated as not normalized.
///
/// For NFD and NFKD, checks that no code point has a canonical (or compatibility)
/// decomposition, and that combining marks are in canonical order (CCC monotonicity).
pub fn isNormalized(utf8: []const u8, form: NormalizationForm) bool {
    var iter = std.unicode.Utf8Iterator{ .bytes = utf8, .i = 0 };
    var last_ccc: CombiningClass = 0;

    while (iter.nextCodepoint()) |cp| {
        const current_ccc = getCombiningClass(cp);

        // Check canonical ordering: combining marks must be in non-decreasing CCC order
        if (current_ccc != 0 and last_ccc > current_ccc) {
            return false;
        }

        // Form-specific checks
        switch (form) {
            .nfc => {
                const qc = ucd_nfc_qc.getNfcQc(cp);
                if (qc == 1) return false; // No
                if (qc == 2) return false; // Maybe — conservative: treat as not normalized
            },
            .nfkc => {
                const qc = ucd_nfkc_qc.getNfkcQc(cp);
                if (qc == 1) return false; // No
                if (qc == 2) return false; // Maybe — conservative: treat as not normalized
            },
            .nfd, .nfkd => {
                // For NFD/NFKD: if a character has a decomposition (canonical or
                // compatibility), the string is not in decomposed form.
                if (form == .nfkd) {
                    // Check compatibility decomposition table
                    var compat_buf: [18]Codepoint = undefined;
                    if (norm_decompose.getCompatibilityDecomposition(cp, &compat_buf) != null) {
                        return false;
                    }
                }
                // Check canonical decomposition: if the UCD table has a
                // decomposition for this codepoint, it is not fully decomposed.
                if (ucd_decomp.getDecomposition(cp)) |decomp_result| {
                    if (decomp_result.len != 1 or decomp_result[0] != cp) {
                        return false;
                    }
                }
                // Hangul syllables always have an algorithmic decomposition
                if (cp >= 0xAC00 and cp <= 0xD7A3) {
                    return false;
                }
            },
        }

        last_ccc = if (current_ccc != 0) current_ccc else 0;
    }

    return true;
}

/// Decomposes a code point (canonical decomposition)
/// Returns the decomposition or the original code point if no decomposition exists.
/// Uses generated Unicode 15.1 tables for complete coverage.
pub fn decompose(cp: Codepoint, buf: []Codepoint) []Codepoint {
    return norm_decompose.decomposeWithCompat(cp, buf, false);
}

/// Decomposes a code point with optional compatibility decomposition (for NFKC/NFKD)
pub fn decomposeWithCompat(cp: Codepoint, buf: []Codepoint, use_compat: bool) []Codepoint {
    return norm_decompose.decomposeWithCompat(cp, buf, use_compat);
}

/// Looks up a primary composite for a (starter, combiner) pair
/// Uses generated Unicode 15.1 tables for complete coverage.
/// Returns null if no composite exists
pub fn getComposite(starter: Codepoint, combiner: Codepoint) ?Codepoint {
    return norm_compose.getComposite(starter, combiner);
}

/// Normalizes a UTF-8 string to the specified form using an allocator.
///
/// Uses a streaming approach with bounded memory: codepoints are processed in
/// windows delimited by starters (CCC=0). Each window is sorted, optionally
/// composed, and flushed to the output before the next window begins. A
/// fixed-size stack buffer handles the common case; dynamic allocation is used
/// only for exceptionally long combining sequences.
pub fn normalize(allocator: std.mem.Allocator, utf8: []const u8, form: NormalizationForm) ![]u8 {
    // ASCII fast-path: ASCII text is always in all normalization forms.
    // This avoids the full decompose-sort-compose pipeline for pure ASCII,
    // which is the common case for many workloads.
    if (simd.isAllAscii(utf8)) {
        const copy = try allocator.alloc(u8, utf8.len);
        @memcpy(copy, utf8);
        return copy;
    }

    const should_compose = (form == .nfc or form == .nfkc);
    const use_compat = (form == .nfkc or form == .nfkd);

    // Output buffer -- only the final UTF-8 result is accumulated here.
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    // Pre-allocate to avoid repeated reallocations during encoding.
    try result.ensureTotalCapacity(allocator, utf8.len);

    // Fixed-size window buffer for the current starter + combining sequence.
    var window_buf: [norm_compose.WINDOW_BUF_SIZE]Codepoint = undefined;
    var window_len: usize = 0;

    // Dynamic fallback for exceptionally long CCC sequences.
    var overflow: std.ArrayList(Codepoint) = .empty;
    defer overflow.deinit(allocator);
    var using_overflow = false;

    // Normalization bomb protection: track decomposed codepoint count vs input bytes.
    var total_codepoints: usize = 0;

    var iter = std.unicode.Utf8Iterator{ .bytes = utf8, .i = 0 };
    var decomp_buf: [18]Codepoint = undefined; // Max decomposition length

    while (iter.nextCodepoint()) |cp| {
        const decomposed = norm_decompose.decomposeWithCompat(cp, &decomp_buf, use_compat);

        for (decomposed) |dcp| {
            total_codepoints += 1;

            // Normalization bomb protection: reject inputs where decomposition
            // causes excessive expansion.
            if (total_codepoints > utf8.len * norm_compose.MAX_EXPANSION_RATIO) {
                return error.OutputTooLarge;
            }

            const dcp_ccc = norm_compose.getCombiningClass(dcp);

            // If this is a starter and we already have content in the window,
            // flush the previous window before starting a new one.
            if (dcp_ccc == 0 and (window_len > 0 or using_overflow)) {
                var new_carry: ?Codepoint = null;
                if (using_overflow) {
                    try norm_compose.flushWindow(overflow.items, should_compose, !should_compose, &result, allocator, &new_carry);
                    overflow.clearRetainingCapacity();
                    using_overflow = false;
                } else {
                    try norm_compose.flushWindow(window_buf[0..window_len], should_compose, !should_compose, &result, allocator, &new_carry);
                }
                window_len = 0;

                // When composing, carry the last codepoint into the next window
                // so consecutive starters can compose (e.g. Hangul Jamo L+V->LV).
                if (new_carry) |c| {
                    window_buf[0] = c;
                    window_len = 1;
                }
            }

            // Append the decomposed codepoint to the current window.
            if (using_overflow) {
                try overflow.append(allocator, dcp);
            } else if (window_len < norm_compose.WINDOW_BUF_SIZE) {
                window_buf[window_len] = dcp;
                window_len += 1;
            } else {
                // Fixed buffer exhausted -- move to dynamic allocation for this window.
                try overflow.ensureTotalCapacity(allocator, norm_compose.WINDOW_BUF_SIZE + 16);
                try overflow.appendSlice(allocator, window_buf[0..window_len]);
                try overflow.append(allocator, dcp);
                window_len = 0;
                using_overflow = true;
            }
        }
    }

    // Flush the final window -- emit everything (emit_last=true).
    var final_carry: ?Codepoint = null;
    if (using_overflow) {
        try norm_compose.flushWindow(overflow.items, should_compose, true, &result, allocator, &final_carry);
    } else if (window_len > 0) {
        try norm_compose.flushWindow(window_buf[0..window_len], should_compose, true, &result, allocator, &final_carry);
    }

    return result.toOwnedSlice(allocator);
}

// ============================================================================
// Tests
// ============================================================================

test "NFC normalization: e + combining acute" {
    const testing = std.testing;

    // NFD input: e (U+0065) + combining acute (U+0301)
    const nfd = "e\xCC\x81";

    // NFC output: e-acute (U+00E9)
    const nfc = try normalize(testing.allocator, nfd, .nfc);
    defer testing.allocator.free(nfc);

    // e-acute in UTF-8 is 0xC3 0xA9
    try testing.expectEqualSlices(u8, "\xC3\xA9", nfc);
}

test "NFC normalization: already composed" {
    const testing = std.testing;

    // Already NFC: e-acute (U+00E9)
    const already_nfc = "\xC3\xA9";

    const result = try normalize(testing.allocator, already_nfc, .nfc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, already_nfc, result);
}

test "NFC normalization: multiple combining marks" {
    const testing = std.testing;

    // a + combining acute -> a-acute
    const input = "a\xCC\x81";

    const nfc = try normalize(testing.allocator, input, .nfc);
    defer testing.allocator.free(nfc);

    // a-acute in UTF-8 is 0xC3 0xA1
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

    // Start with precomposed e-acute
    const original = "\xC3\xA9";

    // Decompose to NFD
    const nfd = try normalize(testing.allocator, original, .nfd);
    defer testing.allocator.free(nfd);
    try testing.expectEqualSlices(u8, "e\xCC\x81", nfd); // e + combining acute

    // Compose back to NFC
    const nfc = try normalize(testing.allocator, nfd, .nfc);
    defer testing.allocator.free(nfc);
    try testing.expectEqualSlices(u8, original, nfc);
}

test "NFKC: Latin ligature fi" {
    const testing = std.testing;

    // U+FB01 -> fi
    const input = "\xEF\xAC\x81";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "fi", result);
}

test "NFKC: Latin ligature ffi" {
    const testing = std.testing;

    // U+FB03 -> ffi
    const input = "\xEF\xAC\x83";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "ffi", result);
}

test "NFKD: Latin ligature fl" {
    const testing = std.testing;

    // U+FB02 -> fl
    const input = "\xEF\xAC\x82";
    const result = try normalize(testing.allocator, input, .nfkd);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "fl", result);
}

test "NFKC: Fullwidth ASCII" {
    const testing = std.testing;

    // U+FF21 -> A
    const input = "\xEF\xBC\xA1";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "A", result);
}

test "NFKD: Fullwidth digit" {
    const testing = std.testing;

    // U+FF15 -> 5
    const input = "\xEF\xBC\x95";
    const result = try normalize(testing.allocator, input, .nfkd);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "5", result);
}

test "NFKC: Circled number" {
    const testing = std.testing;

    // U+2460 -> 1
    const input = "\xE2\x91\xA0";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "1", result);
}

test "NFKD: Circled letter" {
    const testing = std.testing;

    // U+24B6 -> A
    const input = "\xE2\x92\xB6";
    const result = try normalize(testing.allocator, input, .nfkd);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "A", result);
}

test "NFKC: Superscript digit" {
    const testing = std.testing;

    // U+00B2 -> 2
    const input = "\xC2\xB2";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "2", result);
}

test "NFKD: Subscript digit" {
    const testing = std.testing;

    // U+2085 -> 5
    const input = "\xE2\x82\x85";
    const result = try normalize(testing.allocator, input, .nfkd);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "5", result);
}

test "NFKC: Roman numeral" {
    const testing = std.testing;

    // U+2161 -> II
    const input = "\xE2\x85\xA1";
    const result = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "II", result);
}

test "NFC does not apply compatibility decomposition" {
    const testing = std.testing;

    // U+FB01 should remain unchanged in NFC (it's already canonical)
    const input = "\xEF\xAC\x81";
    const result = try normalize(testing.allocator, input, .nfc);
    defer testing.allocator.free(result);

    // NFC should preserve the ligature
    try testing.expectEqualSlices(u8, input, result);
}

test "NFD does not apply compatibility decomposition" {
    const testing = std.testing;

    // U+2460 should remain unchanged in NFD
    const input = "\xE2\x91\xA0";
    const result = try normalize(testing.allocator, input, .nfd);
    defer testing.allocator.free(result);

    // NFD should preserve the circled number
    try testing.expectEqualSlices(u8, input, result);
}

// ============================================================================
// Gap closure tests
// ============================================================================

test "ASCII fast-path: pure ASCII returns identical copy" {
    const testing = std.testing;

    const input = "Hello World 123!";
    const result = try normalize(testing.allocator, input, .nfc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, input, result);

    // Verify it also works for other normalization forms
    const nfd = try normalize(testing.allocator, input, .nfd);
    defer testing.allocator.free(nfd);
    try testing.expectEqualSlices(u8, input, nfd);

    const nfkc = try normalize(testing.allocator, input, .nfkc);
    defer testing.allocator.free(nfkc);
    try testing.expectEqualSlices(u8, input, nfkc);

    const nfkd = try normalize(testing.allocator, input, .nfkd);
    defer testing.allocator.free(nfkd);
    try testing.expectEqualSlices(u8, input, nfkd);
}

test "ASCII fast-path: empty string" {
    const testing = std.testing;

    const result = try normalize(testing.allocator, "", .nfc);
    defer testing.allocator.free(result);

    try testing.expectEqualSlices(u8, "", result);
}

test "ASCII fast-path: non-ASCII bypasses fast path" {
    const testing = std.testing;

    // This contains non-ASCII (e + combining acute), must go through full pipeline
    const input = "e\xCC\x81";
    const result = try normalize(testing.allocator, input, .nfc);
    defer testing.allocator.free(result);

    // Should produce composed e-acute, not the original input
    try testing.expectEqualSlices(u8, "\xC3\xA9", result);
}

test "normalization bomb protection: normal text within ratio" {
    const testing = std.testing;

    // Normal text should never trigger the expansion limit.
    // e-acute decomposes to 2 codepoints from 2 bytes -- well within 10x.
    const input = "\xC3\xA9"; // e-acute (2 bytes)
    const result = try normalize(testing.allocator, input, .nfd);
    defer testing.allocator.free(result);

    // NFD of e-acute is e + combining acute (3 bytes)
    try testing.expectEqualSlices(u8, "e\xCC\x81", result);
}

test "normalization bomb protection: repeated combining marks within ratio" {
    const testing = std.testing;

    // A string with many combining marks. Each combining acute is 2 bytes in UTF-8
    // and decomposes to 1 codepoint. So 50 combining marks = 100 bytes -> 50 codepoints.
    // Ratio: 50 / 100 = 0.5, well within 10x.
    var input: [102]u8 = undefined;
    input[0] = 'a'; // starter
    input[1] = 'b'; // starter
    var pos: usize = 2;
    var count: usize = 0;
    while (count < 50) : (count += 1) {
        input[pos] = 0xCC;
        input[pos + 1] = 0x81; // combining acute
        pos += 2;
    }

    const result = try normalize(testing.allocator, input[0..pos], .nfc);
    defer testing.allocator.free(result);

    // Should succeed without error
    try testing.expect(result.len > 0);
}

test "isNormalized: NFD detects composed characters" {
    const testing = std.testing;

    // e-acute (U+00E9) is precomposed -- it has a canonical decomposition
    // to e + combining acute, so it is NOT in NFD form.
    const composed = "\xC3\xA9"; // e-acute
    try testing.expect(!isNormalized(composed, .nfd));

    // e + combining acute IS in NFD form
    const decomposed = "e\xCC\x81";
    try testing.expect(isNormalized(decomposed, .nfd));
}

test "isNormalized: NFD detects Hangul syllables" {
    const testing = std.testing;

    // Hangul syllable U+AC00 should not be considered NFD-normalized
    // because it can be decomposed to Jamo.
    const hangul = "\xEA\xB0\x80"; // U+AC00
    try testing.expect(!isNormalized(hangul, .nfd));
}

test "isNormalized: pure ASCII is normalized in all forms" {
    const testing = std.testing;

    const ascii = "Hello World 123!";
    try testing.expect(isNormalized(ascii, .nfc));
    try testing.expect(isNormalized(ascii, .nfd));
    try testing.expect(isNormalized(ascii, .nfkc));
    try testing.expect(isNormalized(ascii, .nfkd));
}

test "isNormalized: CCC ordering violation detected" {
    const testing = std.testing;

    // Two combining marks in wrong order: CCC 220 (below) then CCC 230 (above) is correct,
    // but CCC 230 then CCC 220 would be wrong.
    // U+0323 (combining dot below, CCC 220)
    // U+0301 (combining acute accent, CCC 230)
    // Correct order: dot below first, then acute
    const correct_order = "a\xCC\xA3\xCC\x81"; // a + dot below + acute
    try testing.expect(isNormalized(correct_order, .nfd));

    // Wrong order: acute first, then dot below
    const wrong_order = "a\xCC\x81\xCC\xA3"; // a + acute + dot below
    try testing.expect(!isNormalized(wrong_order, .nfd));
}

test "isNormalized: NFC detects decomposed sequences via Quick_Check" {
    const testing = std.testing;

    // e + combining acute (U+0301) is in NFD form, NOT NFC form.
    // The combining acute accent has NFC_QC=Maybe, so isNormalized
    // conservatively returns false.
    const nfd_input = "e\xCC\x81"; // e + combining acute (NFD form)
    try testing.expect(!isNormalized(nfd_input, .nfc));

    // Precomposed e-acute (U+00E9) IS in NFC form.
    const nfc_input = "\xC3\xA9"; // e-acute (NFC form)
    try testing.expect(isNormalized(nfc_input, .nfc));
}

test "isNormalized: NFKC detects decomposed sequences via Quick_Check" {
    const testing = std.testing;

    // e + combining acute should not be NFKC either
    const nfd_input = "e\xCC\x81";
    try testing.expect(!isNormalized(nfd_input, .nfkc));

    // Fullwidth A (U+FF21) has NFKC_QC=No
    const fullwidth_a = "\xEF\xBC\xA1"; // U+FF21
    try testing.expect(!isNormalized(fullwidth_a, .nfkc));
}

test "isNormalized: NFC and NFKC accept ASCII" {
    const testing = std.testing;

    const ascii = "hello";
    try testing.expect(isNormalized(ascii, .nfc));
    try testing.expect(isNormalized(ascii, .nfd));
    try testing.expect(isNormalized(ascii, .nfkc));
    try testing.expect(isNormalized(ascii, .nfkd));
}

test "isNormalized: NFC accepts precomposed, NFD accepts decomposed" {
    const testing = std.testing;

    // e-acute precomposed (U+00E9) - NFC form
    const composed = "\xC3\xA9";
    try testing.expect(isNormalized(composed, .nfc));
    try testing.expect(!isNormalized(composed, .nfd));

    // e + combining acute - NFD form
    const decomposed = "e\xCC\x81";
    try testing.expect(!isNormalized(decomposed, .nfc));
    try testing.expect(isNormalized(decomposed, .nfd));
}

test "isNormalized: NFKD detects compatibility decomposable characters" {
    const testing = std.testing;

    // Fullwidth A (U+FF21) has a compatibility decomposition to A.
    // It should NOT be considered NFKD-normalized.
    const fullwidth_a = "\xEF\xBC\xA1"; // U+FF21
    try testing.expect(!isNormalized(fullwidth_a, .nfkd));
}

// ============================================================================
// Streaming normalization tests (P2-3)
// ============================================================================

test "streaming: large input with many starter+combining windows" {
    const testing = std.testing;

    // Build a large input: 1000 repetitions of "a" + combining acute (NFC -> a-acute)
    // This exercises the streaming path with many small windows.
    const reps = 1000;
    var input: [reps * 3]u8 = undefined;
    var i: usize = 0;
    for (0..reps) |_| {
        input[i] = 'a'; // starter
        input[i + 1] = 0xCC;
        input[i + 2] = 0x81; // combining acute
        i += 3;
    }

    const nfc = try normalize(testing.allocator, input[0..i], .nfc);
    defer testing.allocator.free(nfc);

    // Each a + combining acute should compose to a-acute (U+00E1, 2 bytes UTF-8)
    try testing.expectEqual(@as(usize, reps * 2), nfc.len);

    // Verify each composed character is a-acute
    var j: usize = 0;
    for (0..reps) |_| {
        try testing.expectEqual(@as(u8, 0xC3), nfc[j]);
        try testing.expectEqual(@as(u8, 0xA1), nfc[j + 1]);
        j += 2;
    }

    // Also test NFD: should decompose each composed char back
    const nfd = try normalize(testing.allocator, input[0..i], .nfd);
    defer testing.allocator.free(nfd);
    try testing.expectEqualSlices(u8, input[0..i], nfd);
}

test "streaming: mixed ASCII and combining marks" {
    const testing = std.testing;

    // "Hello" + e + combining acute + " World"
    // The ASCII portions should pass through; the combining sequence should compose.
    const input = "Hello e\xCC\x81 World";
    const nfc = try normalize(testing.allocator, input, .nfc);
    defer testing.allocator.free(nfc);

    try testing.expectEqualSlices(u8, "Hello \xC3\xA9 World", nfc);
}

test "streaming: single codepoint input" {
    const testing = std.testing;

    // Single ASCII character
    const result = try normalize(testing.allocator, "X", .nfc);
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "X", result);
}

test "streaming: input ending mid-CCC-sequence" {
    const testing = std.testing;

    // Input: a + combining acute + combining dot below (two combining marks, no trailing starter)
    // CCC: acute=230, dot below=220. Canonical order is dot below first.
    const input = "a\xCC\x81\xCC\xA3";
    const nfd = try normalize(testing.allocator, input, .nfd);
    defer testing.allocator.free(nfd);

    // After CCC sort: a + dot below (220) + acute (230)
    try testing.expectEqualSlices(u8, "a\xCC\xA3\xCC\x81", nfd);
}

test "streaming: input starting with combining marks (no initial starter)" {
    const testing = std.testing;

    // Combining acute at the start (orphan combining mark, CCC=230)
    const input = "\xCC\x81" ++ "a";
    const nfd = try normalize(testing.allocator, input, .nfd);
    defer testing.allocator.free(nfd);

    // The combining mark should be preserved, then the starter follows in a new window.
    try testing.expectEqualSlices(u8, "\xCC\x81" ++ "a", nfd);
}

test "streaming: overflow path with >64 combining marks" {
    const testing = std.testing;

    // Build a pathological input: a starter followed by 70 combining marks.
    // This exceeds WINDOW_BUF_SIZE (64) and exercises the dynamic fallback.
    // Use combining acute (CCC 230, U+0301 = 0xCC 0x81) for all marks.
    const num_marks = 70;
    var input: [1 + num_marks * 2]u8 = undefined;
    input[0] = 'a'; // starter
    for (0..num_marks) |k| {
        input[1 + k * 2] = 0xCC;
        input[1 + k * 2 + 1] = 0x81;
    }

    const nfc = try normalize(testing.allocator, &input, .nfc);
    defer testing.allocator.free(nfc);

    // Since all combining marks have the same CCC (230) and compose with 'a'
    // only once (only the first composes to a-acute, rest stay as combining acute),
    // verify the output starts with a-acute followed by 69 combining acutes.
    // a + first combining acute -> a-acute (0xC3 0xA1)
    try testing.expectEqual(@as(u8, 0xC3), nfc[0]);
    try testing.expectEqual(@as(u8, 0xA1), nfc[1]);

    // Remaining 69 combining acutes
    const expected_len = 2 + (num_marks - 1) * 2;
    try testing.expectEqual(expected_len, nfc.len);

    var pos: usize = 2;
    for (0..num_marks - 1) |_| {
        try testing.expectEqual(@as(u8, 0xCC), nfc[pos]);
        try testing.expectEqual(@as(u8, 0x81), nfc[pos + 1]);
        pos += 2;
    }
}

test "streaming: multiple windows with CCC reordering" {
    const testing = std.testing;

    // Two windows, each requiring CCC reordering:
    // Window 1: a + acute(230) + dot_below(220) -> sorted: a + dot_below(220) + acute(230)
    // Window 2: b + acute(230) + dot_below(220) -> sorted: b + dot_below(220) + acute(230)
    const input = "a\xCC\x81\xCC\xA3" ++ "b\xCC\x81\xCC\xA3";
    const nfd = try normalize(testing.allocator, input, .nfd);
    defer testing.allocator.free(nfd);

    const expected = "a\xCC\xA3\xCC\x81" ++ "b\xCC\xA3\xCC\x81";
    try testing.expectEqualSlices(u8, expected, nfd);
}

test "streaming: Hangul decomposition and composition windows" {
    const testing = std.testing;

    // U+AC00 (ga) decomposes to U+1100 + U+1161.
    // In NFC, it should recompose back to U+AC00.
    const input = "\xEA\xB0\x80"; // U+AC00
    const nfc = try normalize(testing.allocator, input, .nfc);
    defer testing.allocator.free(nfc);
    try testing.expectEqualSlices(u8, "\xEA\xB0\x80", nfc);

    // NFD should decompose to Jamo
    const nfd = try normalize(testing.allocator, input, .nfd);
    defer testing.allocator.free(nfd);
    // U+1100 = E1 84 80, U+1161 = E1 85 A1
    try testing.expectEqualSlices(u8, "\xE1\x84\x80\xE1\x85\xA1", nfd);
}
