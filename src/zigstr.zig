// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! ZigStr - Core string operations for the Zig string library.
//!
//! This is the core API entry point (module name: `zigstr`). It provides
//! essential Unicode string operations without extended features. For the
//! full API including regex, fuzzy matching, phonetic algorithms, locale
//! formatting, ICU compatibility, legacy encodings, and parallel operations,
//! use the `strings` module instead.
//!
//! ## Core features provided by this module
//!
//! - UTF-8, UTF-16, UTF-32, ASCII, and Latin-1 encoding/decoding
//! - Unicode normalization (NFC, NFD, NFKC, NFKD)
//! - Grapheme cluster segmentation
//! - Case folding and conversion
//! - Unicode Collation Algorithm (UCA) support
//! - Go-style string manipulation functions

const std = @import("std");

// Module imports (using build system module names)
const types_mod = @import("types");
const codepoint_mod = @import("codepoint");
const utf8_mod = @import("utf8");
const utf16_mod = @import("utf16");
const utf32_mod = @import("utf32");
const ascii_mod = @import("ascii");
const latin1_mod = @import("latin1");
const grapheme_mod = @import("grapheme");
const word_mod = @import("word");
const sentence_mod = @import("sentence");
const normalization_mod = @import("normalization");
const case_mod = @import("case");
const collation_mod = @import("collation");
const categories_mod = @import("categories");
const detection_mod = @import("detection");
const bom_mod = @import("bom");
const transcoding_mod = @import("transcoding");
const search_mod = @import("search");
const comparison_mod = @import("comparison");
const manipulation_mod = @import("manipulation");
const numeric_mod = @import("numeric");
const formatting_mod = @import("formatting");
const string_mod = @import("string");
const string16_mod = @import("string16");
const builder_mod = @import("builder");
const pool_mod = @import("pool");

// ============================================================================
// Core Types
// ============================================================================

/// The primary string type (UTF-8 backed)
pub const String = string_mod.String;

/// UTF-16 string type (alias for backward compatibility)
pub const String16 = string16_mod.String16;

/// String builder for efficient concatenation
pub const StringBuilder = builder_mod.StringBuilder;

/// String interning pool
pub const StringPool = pool_mod.StringPool;

/// Unicode code point type (u21)
pub const Codepoint = types_mod.Codepoint;

/// String error types
pub const StringError = types_mod.StringError;

// ============================================================================
// Encoding Types
// ============================================================================

/// Supported string encodings (re-exported from types)
pub const Encoding = types_mod.Encoding;

/// Unicode normalization forms (re-exported from types, UAX #15)
pub const NormalizationForm = types_mod.NormalizationForm;

/// Collation strength levels (re-exported from collation, UTS #10)
pub const CollationStrength = collation_mod.Strength;

// ============================================================================
// Encoding Modules
// ============================================================================

/// UTF-8 encoding/decoding utilities
pub const utf8 = utf8_mod;

/// UTF-16 encoding/decoding utilities
pub const utf16 = utf16_mod;

/// UTF-32 encoding/decoding utilities
pub const utf32 = utf32_mod;

/// ASCII utilities
pub const ascii = ascii_mod;

/// Latin-1 utilities
pub const latin1 = latin1_mod;

/// Code point utilities
pub const codepoint = codepoint_mod;

// ============================================================================
// Unicode Modules
// ============================================================================

/// Grapheme cluster segmentation (UAX #29)
pub const grapheme = grapheme_mod;

/// Word boundary detection (UAX #29)
pub const word = word_mod;

/// Sentence boundary detection (UAX #29)
pub const sentence = sentence_mod;

/// Unicode normalization (UAX #15)
pub const normalization = normalization_mod;

/// Unicode case mapping and folding
pub const case = case_mod;

/// Unicode collation (UTS #10)
pub const collation = collation_mod;

/// Unicode character categories (UAX #44)
pub const categories = categories_mod;

// ============================================================================
// Encoding Detection
// ============================================================================

/// Encoding detection utilities
pub const detection = detection_mod;

/// Byte Order Mark handling
pub const bom = bom_mod;

/// Encoding transcoding utilities
pub const transcoding = transcoding_mod;

// ============================================================================
// String Operations
// ============================================================================

/// String search operations
pub const search = search_mod;

/// String comparison operations
pub const comparison = comparison_mod;

/// String manipulation operations
pub const manipulation = manipulation_mod;

// ============================================================================
// Conversion Utilities
// ============================================================================

/// Numeric parsing and formatting
pub const numeric = numeric_mod;

/// String formatting utilities
pub const formatting = formatting_mod;

// ============================================================================
// Convenience Functions
// ============================================================================

/// Checks if a UTF-8 string is valid
pub fn isValidUtf8(bytes: []const u8) bool {
    return utf8_mod.isValid(bytes);
}

/// Counts the number of grapheme clusters in a string
pub fn countGraphemes(bytes: []const u8) usize {
    return grapheme_mod.count(bytes);
}

/// Counts the number of code points in a UTF-8 string
pub fn countCodepoints(bytes: []const u8) ?usize {
    return utf8_mod.countCodepoints(bytes);
}

/// Normalizes a string to the specified form
pub fn normalize(allocator: std.mem.Allocator, str: []const u8, form: NormalizationForm) ![]u8 {
    return normalization_mod.normalize(allocator, str, form);
}

/// Converts a string to lowercase
pub fn toLower(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    return case_mod.toLowerString(allocator, str);
}

/// Converts a string to uppercase
pub fn toUpper(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    return case_mod.toUpperString(allocator, str);
}

/// Converts a string to title case
pub fn toTitle(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    return case_mod.toTitleString(allocator, str);
}

/// Compares two strings using Unicode collation
pub fn compare(a: []const u8, b: []const u8, strength: CollationStrength) std.math.Order {
    return collation_mod.compare(a, b, .{ .strength = strength });
}

/// Checks if two strings are equal using Unicode collation
pub fn equals(a: []const u8, b: []const u8, strength: CollationStrength) bool {
    return compare(a, b, strength) == .eq;
}

/// Detects the encoding of a byte sequence
pub fn detectEncoding(bytes: []const u8) detection_mod.DetectionResult {
    return detection_mod.detect(bytes);
}

// ============================================================================
// Go-style String Functions (re-exports for convenience)
// ============================================================================

/// Slices str around the first instance of sep
pub const cut = manipulation_mod.cut;

/// Returns str without the provided leading prefix
pub const cutPrefix = manipulation_mod.cutPrefix;

/// Returns str without the provided trailing suffix
pub const cutSuffix = manipulation_mod.cutSuffix;

/// Returns str without the provided leading prefix (always returns a slice)
pub const trimPrefix = manipulation_mod.trimPrefix;

/// Returns str without the provided trailing suffix (always returns a slice)
pub const trimSuffix = manipulation_mod.trimSuffix;

/// Splits the string around runs of whitespace
pub const fields = manipulation_mod.fields;

/// Splits the string at each run of code points satisfying predicate
pub const fieldsFunc = manipulation_mod.fieldsFunc;

/// Splits string into at most n substrings
pub const splitN = manipulation_mod.splitN;

/// Splits after each instance of sep
pub const splitAfter = manipulation_mod.splitAfter;

/// Splits after each instance of sep, at most n times
pub const splitAfterN = manipulation_mod.splitAfterN;

/// Applies a mapping function to each codepoint
pub const mapFunc = manipulation_mod.mapFunc;

/// Trims by predicate function
pub const trimFunc = manipulation_mod.trimFunc;

/// Replaces invalid UTF-8 sequences
pub const toValidUtf8 = manipulation_mod.toValidUtf8;

/// Checks if string contains any of the specified characters
pub const containsAny = manipulation_mod.containsAny;

/// Checks if string contains any code point satisfying predicate
pub const containsFunc = manipulation_mod.containsFunc;

/// Finds the first occurrence of a byte
pub const indexByte = search_mod.indexByte;

/// Finds the last occurrence of a byte
pub const lastIndexByte = search_mod.lastIndexByte;

/// Finds the first occurrence of any byte in chars
pub const indexAny = search_mod.indexAny;

/// Finds the last occurrence of any byte in chars
pub const lastIndexAny = search_mod.lastIndexAny;

/// Finds the first code point satisfying predicate
pub const indexFunc = search_mod.indexFunc;

/// Finds the last code point satisfying predicate
pub const lastIndexFunc = search_mod.lastIndexFunc;

// ============================================================================
// Tests
// ============================================================================

test "zigstr basics" {
    const testing = std.testing;

    // Test UTF-8 validation
    try testing.expect(isValidUtf8("Hello, World!"));
    try testing.expect(isValidUtf8("Hello, \xE4\xB8\x96\xE7\x95\x8C!")); // "Hello, 世界!"
    try testing.expect(!isValidUtf8("Invalid\xFF\xFE"));

    // Test grapheme counting
    try testing.expectEqual(@as(usize, 5), countGraphemes("hello"));
    try testing.expectEqual(@as(usize, 1), countGraphemes("e\xCC\x81")); // e + combining acute

    // Test codepoint counting
    try testing.expectEqual(@as(?usize, 5), countCodepoints("hello"));
    try testing.expectEqual(@as(?usize, 2), countCodepoints("e\xCC\x81")); // 2 codepoints
}

test "zigstr case conversion" {
    const testing = std.testing;

    const lower = try toLower(testing.allocator, "HELLO");
    defer testing.allocator.free(lower);
    try testing.expectEqualSlices(u8, "hello", lower);

    const upper = try toUpper(testing.allocator, "hello");
    defer testing.allocator.free(upper);
    try testing.expectEqualSlices(u8, "HELLO", upper);
}

test "zigstr collation" {
    const testing = std.testing;

    // Primary strength ignores case
    try testing.expect(equals("hello", "HELLO", .primary));

    // Tertiary strength distinguishes case
    try testing.expect(!equals("hello", "HELLO", .tertiary));

    // Basic ordering
    try testing.expectEqual(std.math.Order.lt, compare("apple", "banana", .primary));
}
