// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Strings - A comprehensive string manipulation library for Zig.
//!
//! This is the full API entry point (module name: `strings`). It includes all
//! core Unicode operations plus extended features such as regex, fuzzy matching,
//! phonetic algorithms, locale-aware formatting, ICU compatibility, legacy
//! encoding support, and parallel string operations.
//!
//! For core string operations without extended features, use the `zigstr` module
//! instead. Prefer `strings` when you need the complete feature set.
//!
//! ## Features
//!
//! - **Multiple Encodings**: UTF-8, UTF-16 (LE/BE), UTF-32 (LE/BE), ASCII, Latin-1
//! - **Unicode Support**: Full Unicode 15.1 character properties and algorithms
//! - **Normalization**: NFC, NFD, NFKC, NFKD normalization forms (UAX #15)
//! - **Segmentation**: Grapheme clusters, words, sentences (UAX #29)
//! - **Case Conversion**: Full upper/lower/title case mapping (Unicode-aware)
//! - **Collation**: Unicode Collation Algorithm (UTS #10)
//! - **String Types**: Managed String and String16 types with allocation
//! - **String Builder**: Efficient string construction
//! - **SIMD Acceleration**: Vectorized operations where available
//! - **Extended**: Regex, fuzzy matching, phonetic algorithms, locale formatting
//! - **Legacy Encodings**: Windows code pages, ISO-8859, CJK encodings, Big5
//! - **Parallel Operations**: Spice-based parallel string processing
//! - **Minimal Dependencies**: Pure Zig with optional spice parallelism dependency
//!
//! ## Quick Start
//!
//! ```zig
//! const strings = @import("strings");
//!
//! // Use UTF-8 operations directly
//! const valid = strings.utf8.isValid("Hello, 世界!");
//!
//! // Use the managed String type
//! var str = try strings.String.fromSlice(allocator, "Hello");
//! defer str.deinit();
//! try str.append(", World!");
//! ```

const std = @import("std");

// ============================================================
// Core Types
// ============================================================

/// Core type definitions and constants
pub const types = @import("types");

/// Unicode code point operations
pub const codepoint = @import("codepoint");

// ============================================================
// Encodings
// ============================================================

/// UTF-8 encoding operations (RFC 3629)
pub const utf8 = @import("utf8");

/// UTF-16 encoding operations (RFC 2781)
pub const utf16 = @import("utf16");

/// UTF-32 encoding operations
pub const utf32 = @import("utf32");

/// ASCII operations
pub const ascii = @import("ascii");

/// Latin-1/ISO-8859-1 operations
pub const latin1 = @import("latin1");

// ============================================================
// Unicode
// ============================================================

/// Unicode character categories (UAX #44)
pub const categories = @import("categories");

/// Unicode normalization (UAX #15)
pub const normalization = @import("normalization");

/// Grapheme cluster boundaries (UAX #29)
pub const grapheme = @import("grapheme");

/// Word boundaries (UAX #29)
pub const word = @import("word");

/// Sentence boundaries (UAX #29)
pub const sentence = @import("sentence");

/// Case mapping and folding
pub const case = @import("case");

/// Unicode Collation Algorithm (UTS #10)
pub const collation = @import("collation");

// ============================================================
// Encoding Utilities
// ============================================================

/// Encoding detection
pub const detection = @import("detection");

/// Byte Order Mark handling
pub const bom = @import("bom");

/// Encoding transcoding
pub const transcoding = @import("transcoding");

// ============================================================
// Iterators
// ============================================================

/// String iterators
pub const iterator = @import("iterator");

// ============================================================
// Operations
// ============================================================

/// Search operations
pub const search = @import("search");

/// Comparison operations
pub const comparison = @import("comparison");

/// String manipulation
pub const manipulation = @import("manipulation");

// ============================================================
// Conversion
// ============================================================

/// Numeric parsing and formatting
pub const numeric = @import("numeric");

/// String formatting
pub const formatting = @import("formatting");

// ============================================================
// String Types
// ============================================================

/// UTF-8 backed String type
pub const string = @import("string");

/// UTF-16 backed String16 type
pub const string16 = @import("string16");

/// String builder for efficient concatenation
pub const builder = @import("builder");

// ============================================================
// Utilities
// ============================================================

/// SIMD-accelerated operations
pub const simd = @import("simd");

/// String interning pool
pub const pool = @import("pool");

/// Rope data structure for large strings
pub const rope = @import("rope");

/// Memory-mapped string support
pub const mmap = @import("mmap");

/// Lazy Unicode normalization
pub const lazy_norm = @import("lazy_norm");

/// Parallel string operations (spice-based)
pub const parallel = @import("parallel");

// ============================================================
// Extended Features
// ============================================================

/// Regular expression support
pub const regex = @import("regex");

/// Fuzzy matching algorithms
pub const fuzzy = @import("fuzzy");

/// Phonetic algorithms
pub const phonetic = @import("phonetic");

/// Locale-specific formatting
pub const locale = @import("locale");

/// ICU compatibility layer
pub const icu = @import("icu");

// ============================================================
// Legacy Encodings
// ============================================================

/// Windows code pages (CP1250-1258, CP437, CP850)
pub const windows_codepage = @import("windows_codepage");

/// ISO-8859 family (1-16)
pub const iso8859 = @import("iso8859");

/// Chinese encodings (GB2312, GBK, GB18030)
pub const chinese_encoding = @import("chinese_encoding");

/// Japanese encodings (Shift_JIS, EUC-JP)
pub const japanese_encoding = @import("japanese_encoding");

/// Korean encodings (EUC-KR, CP949)
pub const korean_encoding = @import("korean_encoding");

/// Big5 encodings (Big5, Big5-HKSCS)
pub const big5 = @import("big5");

// ============================================================
// Convenience Re-exports
// ============================================================

/// The main UTF-8 String type
pub const String = string.String;

/// The UTF-16 String type
pub const String16 = string16.String16;

/// String builder
pub const StringBuilder = builder.StringBuilder;

/// String interning pool
pub const StringPool = pool.StringPool;

/// Symbol table
pub const SymbolTable = pool.SymbolTable;

/// Unicode code point type
pub const Codepoint = types.Codepoint;

/// Text encoding enum
pub const Encoding = types.Encoding;

/// Normalization forms
pub const NormalizationForm = types.NormalizationForm;

/// General categories
pub const GeneralCategory = types.GeneralCategory;

/// String errors
pub const StringError = types.StringError;

/// Comparison options
pub const CompareOptions = types.CompareOptions;

// ============================================================
// Convenience Functions
// ============================================================

/// Validates a UTF-8 string
pub fn isValidUtf8(bytes: []const u8) bool {
    return utf8.isValid(bytes);
}

/// Counts code points in a UTF-8 string
pub fn countCodepoints(bytes: []const u8) ?usize {
    return utf8.countCodepoints(bytes);
}

/// Counts grapheme clusters in a UTF-8 string
pub fn countGraphemes(bytes: []const u8) usize {
    return grapheme.count(bytes);
}

/// Converts UTF-8 to lowercase
pub fn toLower(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    return case.toLowerString(allocator, str);
}

/// Converts UTF-8 to uppercase
pub fn toUpper(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    return case.toUpperString(allocator, str);
}

/// Converts UTF-8 to title case
pub fn toTitle(allocator: std.mem.Allocator, str: []const u8) ![]u8 {
    return case.toTitleString(allocator, str);
}

/// Compares two strings case-insensitively
pub fn equalsIgnoreCase(a: []const u8, b: []const u8) bool {
    return case.equalsIgnoreCase(a, b);
}

/// Trims whitespace from both ends
pub fn trim(str: []const u8) []const u8 {
    return manipulation.trim(str);
}

/// Splits a string by a delimiter
pub fn split(allocator: std.mem.Allocator, str: []const u8, delimiter: []const u8) ![][]const u8 {
    return manipulation.split(allocator, str, delimiter);
}

/// Joins strings with a separator
pub fn join(allocator: std.mem.Allocator, parts: []const []const u8, separator: []const u8) ![]u8 {
    return manipulation.join(allocator, parts, separator);
}

/// Replaces all occurrences
pub fn replace(allocator: std.mem.Allocator, str: []const u8, old: []const u8, new: []const u8) ![]u8 {
    return manipulation.replace(allocator, str, old, new);
}

/// Checks if a string contains a substring
pub fn contains(haystack: []const u8, needle: []const u8) bool {
    return search.contains(haystack, needle);
}

/// Finds the index of a substring
pub fn indexOf(haystack: []const u8, needle: []const u8) ?usize {
    return search.indexOf(haystack, needle);
}

/// Checks if a string starts with a prefix
pub fn startsWith(haystack: []const u8, prefix: []const u8) bool {
    return search.startsWith(haystack, prefix);
}

/// Checks if a string ends with a suffix
pub fn endsWith(haystack: []const u8, suffix: []const u8) bool {
    return search.endsWith(haystack, suffix);
}

// ============================================================
// Tests
// ============================================================

test {
    // Import all public modules so their inline tests are discovered.
    // Core types
    _ = types;
    _ = codepoint;
    // Encodings
    _ = utf8;
    _ = utf16;
    _ = utf32;
    _ = ascii;
    _ = latin1;
    // Unicode
    _ = categories;
    _ = normalization;
    _ = grapheme;
    _ = word;
    _ = sentence;
    _ = case;
    _ = collation;
    // Encoding utilities
    _ = detection;
    _ = bom;
    _ = transcoding;
    // Iterators
    _ = iterator;
    // Operations
    _ = search;
    _ = comparison;
    _ = manipulation;
    // Conversion
    _ = numeric;
    _ = formatting;
    // String types
    _ = string;
    _ = string16;
    _ = builder;
    // Utilities
    _ = simd;
    _ = pool;
    _ = rope;
    _ = mmap;
    _ = lazy_norm;
    _ = parallel;
    // Extended features
    _ = regex;
    _ = fuzzy;
    _ = phonetic;
    _ = locale;
    _ = icu;
    // Legacy encodings
    _ = windows_codepage;
    _ = iso8859;
    _ = chinese_encoding;
    _ = japanese_encoding;
    _ = korean_encoding;
    _ = big5;
}

test "convenience functions" {
    const testing = std.testing;

    try testing.expect(isValidUtf8("Hello, 世界!"));
    // "Hello, 世界!" = H e l l o , (space) 世 界 ! = 10 codepoints/graphemes
    try testing.expectEqual(@as(?usize, 10), countCodepoints("Hello, 世界!"));
    try testing.expectEqual(@as(usize, 10), countGraphemes("Hello, 世界!"));

    try testing.expect(equalsIgnoreCase("Hello", "HELLO"));
    try testing.expect(contains("Hello, World!", "World"));
    try testing.expect(startsWith("Hello", "Hel"));
    try testing.expect(endsWith("Hello", "llo"));

    try testing.expectEqualSlices(u8, "hello", trim("  hello  "));
}
