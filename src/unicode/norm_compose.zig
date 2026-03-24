// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Composition and streaming helpers for Unicode normalization (UAX #15).
//!
//! Contains the canonical composition algorithm, CCC sorting, and the
//! streaming window flush routine. Separated from the main normalization
//! module to keep file sizes manageable.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const ucd_ccc = @import("ucd_ccc");
const ucd_comp = @import("ucd_composition");

pub const Codepoint = types.Codepoint;

/// Canonical Combining Class (CCC) values
pub const CombiningClass = ucd_ccc.CombiningClass;

/// Gets the Canonical Combining Class for a code point.
/// Uses generated Unicode 15.1 tables for complete coverage.
pub fn getCombiningClass(cp: Codepoint) CombiningClass {
    return ucd_ccc.getCombiningClass(cp);
}

/// Looks up a primary composite for a (starter, combiner) pair.
/// Uses generated Unicode 15.1 tables for complete coverage.
/// Returns null if no composite exists.
pub fn getComposite(starter: Codepoint, combiner: Codepoint) ?Codepoint {
    return ucd_comp.getComposite(starter, combiner);
}

/// Maximum allowed expansion ratio for normalization output.
/// Protects against pathological inputs (normalization bombs) where a small
/// input could expand into an extremely large output. Typical Unicode text
/// expands by at most 3x during decomposition; 10x provides ample headroom
/// for all legitimate use cases.
pub const MAX_EXPANSION_RATIO: usize = 10;

/// Fixed-size window buffer for streaming normalization.
/// CCC sequences between starters are typically 2-4 codepoints; Tibetan stacks
/// can reach ~30. A 64-element buffer covers all practical cases. If a CCC
/// sequence exceeds this, we fall back to dynamic allocation for that window only.
pub const WINDOW_BUF_SIZE: usize = 64;

/// Canonical composition algorithm (UAX #15)
/// Takes a decomposed buffer and composes it in-place
pub fn composeBuffer(buffer: []Codepoint) usize {
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

/// Flushes a single normalization window (starter + combining sequence) to the
/// output buffer. Sorts combining marks by CCC, optionally composes, and
/// encodes the result as UTF-8.
///
/// When `emit_last` is false (used for NFC/NFKC inter-window composition), the
/// last composed codepoint is NOT emitted to `result` but is returned via
/// `carry_out` so the caller can prepend it to the next window. This allows
/// consecutive starters (e.g. Hangul Jamo L+V, LV+T) to compose across window
/// boundaries.
pub fn flushWindow(
    window: []Codepoint,
    should_compose: bool,
    emit_last: bool,
    result: *std.ArrayList(u8),
    allocator: std.mem.Allocator,
    carry_out: *?Codepoint,
) !void {
    carry_out.* = null;
    if (window.len == 0) return;

    // Sort combining marks by CCC (only the marks after the first starter)
    if (window.len >= 2) {
        // Find the combining sequence start (skip the leading starter if present)
        const first_ccc = getCombiningClass(window[0]);
        const seq_start: usize = if (first_ccc == 0) 1 else 0;
        if (window.len > seq_start + 1) {
            sortCombiningSequence(window[seq_start..]);
        }
    }

    // Compose if NFC/NFKC
    var final_len = window.len;
    if (should_compose and window.len > 0) {
        final_len = composeBuffer(window);
    }

    // Determine how many codepoints to emit.
    const emit_end: usize = if (!emit_last and final_len > 0) final_len - 1 else final_len;

    // Encode to UTF-8
    var encode_buf: [4]u8 = undefined;
    for (window[0..emit_end]) |cp| {
        const encoded = codepoint_mod.encodeUtf8(cp, &encode_buf);
        try result.appendSlice(allocator, encoded);
    }

    // Carry the last codepoint forward for inter-window composition.
    if (!emit_last and final_len > 0) {
        carry_out.* = window[final_len - 1];
    }
}

/// Sorts combining marks by canonical combining class
/// This implements canonical ordering per UAX #15
pub fn sortByCombiningClass(codepoints: []Codepoint) void {
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

/// Stable insertion sort for combining characters by CCC.
/// Note: getCombiningClass is called per comparison rather than pre-computed into
/// a parallel array. This is intentional -- combining sequences between starters
/// are typically 1-5 elements, so the allocation overhead of a parallel CCC array
/// would exceed the cost of repeated table lookups for these short runs.
pub fn sortCombiningSequence(seq: []Codepoint) void {
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

// ============================================================================
// Tests
// ============================================================================

test "combining class" {
    const testing = std.testing;

    try testing.expectEqual(@as(CombiningClass, 0), getCombiningClass('A'));
    try testing.expectEqual(@as(CombiningClass, 230), getCombiningClass(0x0301)); // Combining acute

    // Starters have CCC = 0
    try testing.expectEqual(@as(CombiningClass, 0), getCombiningClass('Z'));
}

test "composition lookup" {
    const testing = std.testing;

    // e + combining acute -> e-acute
    try testing.expectEqual(@as(?Codepoint, 0x00E9), getComposite(0x0065, 0x0301));

    // A + combining grave -> A-grave
    try testing.expectEqual(@as(?Codepoint, 0x00C0), getComposite(0x0041, 0x0300));

    // A + combining dot below -> A-dot-below (U+1EA0) - now using full UCD tables
    try testing.expectEqual(@as(?Codepoint, 0x1EA0), getComposite(0x0041, 0x0323));

    // No composite for A + combining double breve below (U+035C)
    try testing.expectEqual(@as(?Codepoint, null), getComposite(0x0041, 0x035C));
}

test "Hangul composition" {
    const testing = std.testing;

    // U+1100 + U+1161 -> U+AC00
    try testing.expectEqual(@as(?Codepoint, 0xAC00), getComposite(0x1100, 0x1161));

    // U+AC00 + U+11AB -> U+AC04
    try testing.expectEqual(@as(?Codepoint, 0xAC04), getComposite(0xAC00, 0x11AB));
}
