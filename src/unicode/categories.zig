// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode character categories (UAX #44).
//!
//! This module provides functions for determining the Unicode General Category
//! of code points and other character properties.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const ucd_general_category = @import("ucd_general_category");

pub const Codepoint = types.Codepoint;
pub const GeneralCategory = types.GeneralCategory;

/// Gets the general category of a code point.
/// Uses the ASCII fast-path for cp < 128, then falls through to a
/// generated two-level trie for O(1) lookup across all of Unicode.
pub fn getCategory(cp: Codepoint) GeneralCategory {
    // ASCII optimization -- inline switch is faster than table lookup
    // for the hot ASCII path.
    if (cp <= 0x7F) {
        return getAsciiCategory(cp);
    }

    // Full Unicode lookup via generated two-stage trie table
    return ucd_general_category.getGeneralCategory(cp);
}

fn getAsciiCategory(cp: Codepoint) GeneralCategory {
    return switch (cp) {
        0x00...0x1F => .Cc, // Control characters
        0x20 => .Zs, // Space
        '!'...'#' => .Po, // Punctuation (! " #)
        '$' => .Sc, // Currency symbol
        '%'...'&' => .Po, // Punctuation (% &)
        '\'' => .Po, // Apostrophe
        '(' => .Ps, // Open parenthesis
        ')' => .Pe, // Close parenthesis
        '*' => .Po, // Asterisk
        '+' => .Sm, // Math symbol (plus)
        ',' => .Po, // Comma
        '-' => .Pd, // Dash punctuation
        '.'...'/' => .Po, // Punctuation (. /)
        '0'...'9' => .Nd, // Digits
        ':'...';' => .Po,
        '<'...'>' => .Sm, // Math symbols
        '?' => .Po,
        '@' => .Po,
        'A'...'Z' => .Lu, // Uppercase letters
        '[' => .Ps, // Open bracket
        '\\' => .Po,
        ']' => .Pe, // Close bracket
        '^' => .Sk, // Modifier symbol
        '_' => .Pc, // Connector punctuation
        '`' => .Sk,
        'a'...'z' => .Ll, // Lowercase letters
        '{' => .Ps,
        '|' => .Sm,
        '}' => .Pe,
        '~' => .Sm,
        0x7F => .Cc, // DEL
        else => .Cn,
    };
}

/// Checks if a code point is a CJK ideograph
pub fn isCjkIdeograph(cp: Codepoint) bool {
    return (cp >= 0x4E00 and cp <= 0x9FFF) or // CJK Unified Ideographs
        (cp >= 0x3400 and cp <= 0x4DBF) or // CJK Extension A
        (cp >= 0x20000 and cp <= 0x2A6DF) or // CJK Extension B
        (cp >= 0x2A700 and cp <= 0x2B73F) or // CJK Extension C
        (cp >= 0x2B740 and cp <= 0x2B81F) or // CJK Extension D
        (cp >= 0x2B820 and cp <= 0x2CEAF) or // CJK Extension E
        (cp >= 0x2CEB0 and cp <= 0x2EBEF) or // CJK Extension F
        (cp >= 0x30000 and cp <= 0x3134F) or // CJK Extension G
        (cp >= 0x31350 and cp <= 0x323AF); // CJK Extension H
}

/// Checks if a code point is a letter (L*)
pub fn isLetter(cp: Codepoint) bool {
    return getCategory(cp).isLetter();
}

/// Checks if a code point is a mark (M*)
pub fn isMark(cp: Codepoint) bool {
    return getCategory(cp).isMark();
}

/// Checks if a code point is a number (N*)
pub fn isNumber(cp: Codepoint) bool {
    return getCategory(cp).isNumber();
}

/// Checks if a code point is punctuation (P*)
pub fn isPunctuation(cp: Codepoint) bool {
    return getCategory(cp).isPunctuation();
}

/// Checks if a code point is a symbol (S*)
pub fn isSymbol(cp: Codepoint) bool {
    return getCategory(cp).isSymbol();
}

/// Checks if a code point is a separator (Z*)
pub fn isSeparator(cp: Codepoint) bool {
    return getCategory(cp).isSeparator();
}

/// Checks if a code point is "other" (C*)
pub fn isOther(cp: Codepoint) bool {
    return getCategory(cp).isOther();
}

/// Checks if a code point is alphanumeric (letter or number)
pub fn isAlphanumeric(cp: Codepoint) bool {
    const cat = getCategory(cp);
    return cat.isLetter() or cat.isNumber();
}

/// Checks if a code point is a control character
pub fn isControl(cp: Codepoint) bool {
    return getCategory(cp) == .Cc;
}

/// Checks if a code point is a format character
pub fn isFormat(cp: Codepoint) bool {
    return getCategory(cp) == .Cf;
}

/// Checks if a code point is printable (not control, format, surrogate, or unassigned)
pub fn isPrintable(cp: Codepoint) bool {
    const cat = getCategory(cp);
    return switch (cat) {
        .Cc, .Cf, .Cs, .Co, .Cn => false,
        else => true,
    };
}

/// Checks if a code point is whitespace (general category Zs, Zl, Zp, or specific controls)
pub fn isWhitespace(cp: Codepoint) bool {
    return switch (cp) {
        // ASCII whitespace
        0x09...0x0D, 0x20 => true,
        // Unicode whitespace
        0x85, // NEL
        0xA0, // NBSP
        0x1680, // Ogham space
        0x2000...0x200A, // Various spaces
        0x2028,
        0x2029, // Line/paragraph separator
        0x202F, // Narrow NBSP
        0x205F, // Medium mathematical space
        0x3000, // Ideographic space
        => true,
        else => false,
    };
}

/// Checks if a code point is a decimal digit (Nd)
pub fn isDecimalDigit(cp: Codepoint) bool {
    return getCategory(cp) == .Nd;
}

/// Checks if a code point is uppercase (Lu)
pub fn isUppercase(cp: Codepoint) bool {
    return getCategory(cp) == .Lu;
}

/// Checks if a code point is lowercase (Ll)
pub fn isLowercase(cp: Codepoint) bool {
    return getCategory(cp) == .Ll;
}

/// Checks if a code point is titlecase (Lt)
pub fn isTitlecase(cp: Codepoint) bool {
    return getCategory(cp) == .Lt;
}

/// Checks if a code point has casing (Lu, Ll, or Lt)
pub fn isCased(cp: Codepoint) bool {
    const cat = getCategory(cp);
    return cat == .Lu or cat == .Ll or cat == .Lt;
}

test "ASCII categories" {
    const testing = std.testing;

    try testing.expectEqual(GeneralCategory.Lu, getCategory('A'));
    try testing.expectEqual(GeneralCategory.Ll, getCategory('a'));
    try testing.expectEqual(GeneralCategory.Nd, getCategory('5'));
    try testing.expectEqual(GeneralCategory.Zs, getCategory(' '));
    try testing.expectEqual(GeneralCategory.Cc, getCategory('\n'));
    try testing.expectEqual(GeneralCategory.Po, getCategory('!'));
}

test "Latin-1 categories" {
    const testing = std.testing;

    try testing.expectEqual(GeneralCategory.Lu, getCategory(0xC9)); // É
    try testing.expectEqual(GeneralCategory.Ll, getCategory(0xE9)); // é
    try testing.expectEqual(GeneralCategory.Sc, getCategory(0xA3)); // £
    try testing.expectEqual(GeneralCategory.Sm, getCategory(0xD7)); // ×
}

test "character properties" {
    const testing = std.testing;

    try testing.expect(isLetter('A'));
    try testing.expect(isLetter(0x4E2D)); // 中
    try testing.expect(!isLetter('5'));

    try testing.expect(isDecimalDigit('0'));
    try testing.expect(!isDecimalDigit('A'));

    try testing.expect(isWhitespace(' '));
    try testing.expect(isWhitespace('\t'));
    try testing.expect(isWhitespace(0x3000)); // Ideographic space
    try testing.expect(!isWhitespace('A'));

    try testing.expect(isUppercase('A'));
    try testing.expect(!isUppercase('a'));
    try testing.expect(isLowercase('a'));
    try testing.expect(!isLowercase('A'));
}

test "CJK detection" {
    const testing = std.testing;

    try testing.expect(isCjkIdeograph(0x4E2D)); // 中
    try testing.expect(isCjkIdeograph(0x6587)); // 文
    try testing.expect(!isCjkIdeograph('A'));
    try testing.expect(!isCjkIdeograph(0x3042)); // Hiragana あ
}

test "getAsciiCategory correctly classifies ASCII punctuation" {
    const testing = std.testing;

    // Verify the 5 characters that were previously misclassified as .Po
    try testing.expectEqual(GeneralCategory.Sc, getAsciiCategory('$'));
    try testing.expectEqual(GeneralCategory.Ps, getAsciiCategory('('));
    try testing.expectEqual(GeneralCategory.Pe, getAsciiCategory(')'));
    try testing.expectEqual(GeneralCategory.Sm, getAsciiCategory('+'));
    try testing.expectEqual(GeneralCategory.Pd, getAsciiCategory('-'));

    // Verify remaining chars in the old '!'...'/' range are still .Po
    try testing.expectEqual(GeneralCategory.Po, getAsciiCategory('!'));
    try testing.expectEqual(GeneralCategory.Po, getAsciiCategory('"'));
    try testing.expectEqual(GeneralCategory.Po, getAsciiCategory('#'));
    try testing.expectEqual(GeneralCategory.Po, getAsciiCategory('%'));
    try testing.expectEqual(GeneralCategory.Po, getAsciiCategory('&'));
    try testing.expectEqual(GeneralCategory.Po, getAsciiCategory('\''));
    try testing.expectEqual(GeneralCategory.Po, getAsciiCategory('*'));
    try testing.expectEqual(GeneralCategory.Po, getAsciiCategory(','));
    try testing.expectEqual(GeneralCategory.Po, getAsciiCategory('.'));
    try testing.expectEqual(GeneralCategory.Po, getAsciiCategory('/'));
}

test "trie-based getCategory covers full Unicode range" {
    const testing = std.testing;

    // ASCII (goes through fast-path, but verifies consistency)
    try testing.expectEqual(GeneralCategory.Sc, getCategory('$'));
    try testing.expectEqual(GeneralCategory.Lu, getCategory('A'));
    try testing.expectEqual(GeneralCategory.Ll, getCategory('a'));
    try testing.expectEqual(GeneralCategory.Nd, getCategory('0'));

    // Non-ASCII: combining grave accent (U+0300)
    try testing.expectEqual(GeneralCategory.Mn, getCategory(0x0300));

    // Non-ASCII: currency symbols
    try testing.expectEqual(GeneralCategory.Sc, getCategory(0x20AC)); // Euro sign
    try testing.expectEqual(GeneralCategory.Sc, getCategory(0x00A3)); // Pound sign

    // CJK ideographs
    try testing.expectEqual(GeneralCategory.Lo, getCategory(0x4E2D)); // 中

    // Hangul syllables
    try testing.expectEqual(GeneralCategory.Lo, getCategory(0xAC00)); // 가

    // Emoji / symbols
    try testing.expectEqual(GeneralCategory.So, getCategory(0x1F600)); // Grinning face

    // Surrogates
    try testing.expectEqual(GeneralCategory.Cs, getCategory(0xD800));

    // Private use area
    try testing.expectEqual(GeneralCategory.Co, getCategory(0xE000));

    // Line/paragraph separators
    try testing.expectEqual(GeneralCategory.Zl, getCategory(0x2028));
    try testing.expectEqual(GeneralCategory.Zp, getCategory(0x2029));
}
