// SPDX-License-Identifier: Apache-2.0
// Unicode Normalization Example
//
// This example demonstrates Unicode normalization forms (NFC, NFD, NFKC, NFKD)
// as defined in UAX #15. Understanding normalization is critical for:
// - String comparison (especially user input)
// - Text processing and search
// - Database storage
// - Security (preventing homograph attacks)
//
// Run with: zig build-exe 03_unicode_normalization.zig --deps strings && ./03_unicode_normalization

const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // =========================================================================
    // Understanding Normalization
    // =========================================================================

    std.debug.print("=== Understanding Unicode Normalization ===\n\n", .{});

    std.debug.print("Unicode allows the same visual character to be represented\n", .{});
    std.debug.print("in multiple ways. For example, 'e' can be:\n", .{});
    std.debug.print("  - U+00E9: LATIN SMALL LETTER E WITH ACUTE (precomposed)\n", .{});
    std.debug.print("  - U+0065 U+0301: e + COMBINING ACUTE ACCENT (decomposed)\n\n", .{});

    // =========================================================================
    // NFD vs NFC
    // =========================================================================

    std.debug.print("=== NFD vs NFC ===\n\n", .{});

    // Precomposed form (NFC-like)
    const precomposed = "\xC3\xA9"; // e (U+00E9)
    // Decomposed form (NFD-like)
    const decomposed = "e\xCC\x81"; // e + combining acute (U+0065 U+0301)

    std.debug.print("Precomposed (e): {s}\n", .{precomposed});
    std.debug.print("  Bytes: ", .{});
    printBytes(precomposed);
    std.debug.print("  Length: {} bytes\n\n", .{precomposed.len});

    std.debug.print("Decomposed (e + combining acute): {s}\n", .{decomposed});
    std.debug.print("  Bytes: ", .{});
    printBytes(decomposed);
    std.debug.print("  Length: {} bytes\n\n", .{decomposed.len});

    // They look the same but are different byte sequences!
    std.debug.print("Byte-equal: {}\n", .{std.mem.eql(u8, precomposed, decomposed)});
    std.debug.print("They look the same but have different representations!\n\n", .{});

    // Normalize both to NFC
    const nfc1 = try strings.normalization.normalize(allocator, precomposed, .nfc);
    defer allocator.free(nfc1);
    const nfc2 = try strings.normalization.normalize(allocator, decomposed, .nfc);
    defer allocator.free(nfc2);

    std.debug.print("After NFC normalization:\n", .{});
    std.debug.print("  First: {s} (", .{nfc1});
    printBytes(nfc1);
    std.debug.print(")\n  Second: {s} (", .{nfc2});
    printBytes(nfc2);
    std.debug.print(")\n  Now byte-equal: {}\n\n", .{std.mem.eql(u8, nfc1, nfc2)});

    // Normalize both to NFD
    const nfd1 = try strings.normalization.normalize(allocator, precomposed, .nfd);
    defer allocator.free(nfd1);
    const nfd2 = try strings.normalization.normalize(allocator, decomposed, .nfd);
    defer allocator.free(nfd2);

    std.debug.print("After NFD normalization:\n", .{});
    std.debug.print("  First: {s} (", .{nfd1});
    printBytes(nfd1);
    std.debug.print(")\n  Second: {s} (", .{nfd2});
    printBytes(nfd2);
    std.debug.print(")\n  Now byte-equal: {}\n\n", .{std.mem.eql(u8, nfd1, nfd2)});

    // =========================================================================
    // Using String.normalize()
    // =========================================================================

    std.debug.print("=== Using String.normalize() ===\n\n", .{});

    var str = try strings.String.fromSlice(allocator, "cafe\xCC\x81"); // cafe + combining acute
    defer str.deinit();

    std.debug.print("Original: {s} ({} bytes)\n", .{ str.bytes(), str.len() });

    var normalized = try str.normalize(.nfc);
    defer normalized.deinit();

    std.debug.print("NFC: {s} ({} bytes)\n\n", .{ normalized.bytes(), normalized.len() });

    // =========================================================================
    // NFKC and NFKD: Compatibility Normalization
    // =========================================================================

    std.debug.print("=== Compatibility Normalization (NFKC/NFKD) ===\n\n", .{});

    std.debug.print("Compatibility normalization decomposes 'compatibility characters'\n", .{});
    std.debug.print("to their canonical equivalents. This includes:\n", .{});
    std.debug.print("  - Ligatures (fi -> fi)\n", .{});
    std.debug.print("  - Fullwidth characters (A -> A)\n", .{});
    std.debug.print("  - Circled numbers (1 -> 1)\n", .{});
    std.debug.print("  - Superscripts/subscripts (2 -> 2)\n\n", .{});

    // Latin ligature fi (U+FB01)
    const ligature = "\xEF\xAC\x81"; // fi ligature
    std.debug.print("Ligature: {s}\n", .{ligature});
    const nfkc_ligature = try strings.normalization.normalize(allocator, ligature, .nfkc);
    defer allocator.free(nfkc_ligature);
    std.debug.print("  NFKC: {s}\n\n", .{nfkc_ligature});

    // Fullwidth A (U+FF21)
    const fullwidth = "\xEF\xBC\xA1"; // A
    std.debug.print("Fullwidth A: {s}\n", .{fullwidth});
    const nfkc_fullwidth = try strings.normalization.normalize(allocator, fullwidth, .nfkc);
    defer allocator.free(nfkc_fullwidth);
    std.debug.print("  NFKC: {s}\n\n", .{nfkc_fullwidth});

    // Circled number 1 (U+2460)
    const circled = "\xE2\x91\xA0"; // (1)
    std.debug.print("Circled 1: {s}\n", .{circled});
    const nfkc_circled = try strings.normalization.normalize(allocator, circled, .nfkc);
    defer allocator.free(nfkc_circled);
    std.debug.print("  NFKC: {s}\n\n", .{nfkc_circled});

    // Superscript 2 (U+00B2)
    const superscript = "\xC2\xB2"; // 2
    std.debug.print("Superscript 2: {s}\n", .{superscript});
    const nfkc_super = try strings.normalization.normalize(allocator, superscript, .nfkc);
    defer allocator.free(nfkc_super);
    std.debug.print("  NFKC: {s}\n\n", .{nfkc_super});

    // Roman numeral II (U+2161)
    const roman = "\xE2\x85\xA1"; // II
    std.debug.print("Roman numeral II: {s}\n", .{roman});
    const nfkc_roman = try strings.normalization.normalize(allocator, roman, .nfkc);
    defer allocator.free(nfkc_roman);
    std.debug.print("  NFKC: {s}\n\n", .{nfkc_roman});

    // =========================================================================
    // NFC vs NFKC: When to Use Which
    // =========================================================================

    std.debug.print("=== NFC vs NFKC: When to Use Which ===\n\n", .{});

    const fi_text = "office"; // Contains fi ligature
    const fi_compat = "of\xEF\xAC\x81ce"; // office with fi ligature (U+FB01)

    std.debug.print("Regular: {s}\n", .{fi_text});
    std.debug.print("With ligature: {s}\n\n", .{fi_compat});

    // NFC preserves the ligature
    const nfc_fi = try strings.normalization.normalize(allocator, fi_compat, .nfc);
    defer allocator.free(nfc_fi);
    std.debug.print("NFC result: {s}\n", .{nfc_fi});
    std.debug.print("  Matches regular: {}\n", .{std.mem.eql(u8, nfc_fi, fi_text)});

    // NFKC decomposes the ligature
    const nfkc_fi = try strings.normalization.normalize(allocator, fi_compat, .nfkc);
    defer allocator.free(nfkc_fi);
    std.debug.print("NFKC result: {s}\n", .{nfkc_fi});
    std.debug.print("  Matches regular: {}\n\n", .{std.mem.eql(u8, nfkc_fi, fi_text)});

    std.debug.print("Recommendation:\n", .{});
    std.debug.print("  - Use NFC for general text storage and display\n", .{});
    std.debug.print("  - Use NFKC for search and comparison (more matches)\n", .{});
    std.debug.print("  - Use NFD for linguistic analysis\n", .{});
    std.debug.print("  - Web: NFC is recommended (W3C)\n\n", .{});

    // =========================================================================
    // Combining Characters and Canonical Ordering
    // =========================================================================

    std.debug.print("=== Combining Characters ===\n\n", .{});

    // Get the combining class for combining acute accent
    const acute = 0x0301; // Combining acute accent
    const ccc = strings.normalization.getCombiningClass(acute);
    std.debug.print("Combining class of U+0301 (acute): {}\n", .{ccc});
    std.debug.print("Is starter (CCC=0): {}\n\n", .{strings.normalization.isStarter(acute)});

    // Regular characters have CCC=0
    const a_ccc = strings.normalization.getCombiningClass('a');
    std.debug.print("Combining class of 'a': {}\n", .{a_ccc});
    std.debug.print("Is starter: {}\n\n", .{strings.normalization.isStarter('a')});

    // =========================================================================
    // Hangul Composition/Decomposition
    // =========================================================================

    std.debug.print("=== Hangul Composition/Decomposition ===\n\n", .{});

    // Korean Hangul uses algorithmic composition/decomposition
    // (U+AC00) = (U+1100) + (U+1161)
    const hangul = "\xEA\xB0\x80"; // (ga)
    std.debug.print("Hangul syllable: {s}\n", .{hangul});

    const nfd_hangul = try strings.normalization.normalize(allocator, hangul, .nfd);
    defer allocator.free(nfd_hangul);
    std.debug.print("NFD decomposed: {s} (", .{nfd_hangul});
    printBytes(nfd_hangul);
    std.debug.print(")\n", .{});

    const nfc_hangul = try strings.normalization.normalize(allocator, nfd_hangul, .nfc);
    defer allocator.free(nfc_hangul);
    std.debug.print("NFC recomposed: {s} (", .{nfc_hangul});
    printBytes(nfc_hangul);
    std.debug.print(")\n\n", .{});

    // =========================================================================
    // Practical Example: User Input Comparison
    // =========================================================================

    std.debug.print("=== Practical: Comparing User Input ===\n\n", .{});

    const user_input_1 = "cafe\xCC\x81"; // User typed cafe + combining accent
    const user_input_2 = "caf\xC3\xA9"; // User copied cafe with precomposed e

    std.debug.print("User 1 entered: {s}\n", .{user_input_1});
    std.debug.print("User 2 entered: {s}\n", .{user_input_2});
    std.debug.print("Raw comparison: {}\n\n", .{std.mem.eql(u8, user_input_1, user_input_2)});

    // Normalize before comparing
    const norm1 = try strings.normalization.normalize(allocator, user_input_1, .nfc);
    defer allocator.free(norm1);
    const norm2 = try strings.normalization.normalize(allocator, user_input_2, .nfc);
    defer allocator.free(norm2);

    std.debug.print("After NFC normalization:\n", .{});
    std.debug.print("  Normalized 1: {s}\n", .{norm1});
    std.debug.print("  Normalized 2: {s}\n", .{norm2});
    std.debug.print("  Now equal: {}\n\n", .{std.mem.eql(u8, norm1, norm2)});

    // =========================================================================
    // Security: Homograph Detection
    // =========================================================================

    std.debug.print("=== Security: Normalization for Homograph Detection ===\n\n", .{});

    std.debug.print("NFKC can help detect some visual spoofing:\n", .{});

    // Fullwidth characters could be used to spoof
    const normal_ab = "AB";
    const fullwidth_ab = "\xEF\xBC\xA1\xEF\xBC\xA2"; // AB

    std.debug.print("Normal: {s}\n", .{normal_ab});
    std.debug.print("Fullwidth: {s}\n", .{fullwidth_ab});
    std.debug.print("Raw comparison: {}\n", .{std.mem.eql(u8, normal_ab, fullwidth_ab)});

    const nfkc_fw = try strings.normalization.normalize(allocator, fullwidth_ab, .nfkc);
    defer allocator.free(nfkc_fw);
    std.debug.print("NFKC fullwidth: {s}\n", .{nfkc_fw});
    std.debug.print("After NFKC comparison: {}\n\n", .{std.mem.eql(u8, normal_ab, nfkc_fw)});

    std.debug.print("=== Example Complete ===\n", .{});
}

fn printBytes(str: []const u8) void {
    for (str) |byte| {
        std.debug.print("{X:0>2} ", .{byte});
    }
}
