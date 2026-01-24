// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Core type definitions for the strings library.
//!
//! This module defines fundamental types, enums, and constants used throughout
//! the library for string manipulation, encoding handling, and Unicode operations.

const std = @import("std");

/// Unicode code point type (U+0000 to U+10FFFF)
pub const Codepoint = u21;

/// Maximum valid Unicode code point
pub const max_codepoint: Codepoint = 0x10FFFF;

/// Unicode replacement character (U+FFFD)
pub const replacement_character: Codepoint = 0xFFFD;

/// UTF-16 code unit type
pub const Utf16Unit = u16;

/// UTF-32 code unit type (same as Codepoint)
pub const Utf32Unit = u32;

/// Text encoding types supported by this library
pub const Encoding = enum {
    /// UTF-8 encoding (RFC 3629)
    utf8,
    /// UTF-16 Little Endian
    utf16_le,
    /// UTF-16 Big Endian
    utf16_be,
    /// UTF-32 Little Endian
    utf32_le,
    /// UTF-32 Big Endian
    utf32_be,
    /// 7-bit ASCII
    ascii,
    /// ISO-8859-1 / Latin-1
    latin1,

    /// Returns the native endianness variant for multi-byte encodings
    pub fn native(self: Encoding) Encoding {
        return switch (self) {
            .utf16_le, .utf16_be => if (native_endian == .little) .utf16_le else .utf16_be,
            .utf32_le, .utf32_be => if (native_endian == .little) .utf32_le else .utf32_be,
            else => self,
        };
    }

    /// Returns the byte order for this encoding
    pub fn endianness(self: Encoding) ?std.builtin.Endian {
        return switch (self) {
            .utf16_le, .utf32_le => .little,
            .utf16_be, .utf32_be => .big,
            else => null,
        };
    }

    /// Returns bytes per code unit for this encoding
    pub fn bytesPerUnit(self: Encoding) u8 {
        return switch (self) {
            .utf8, .ascii, .latin1 => 1,
            .utf16_le, .utf16_be => 2,
            .utf32_le, .utf32_be => 4,
        };
    }
};

/// Native byte order of the system
pub const native_endian: std.builtin.Endian = @import("builtin").cpu.arch.endian();

/// Unicode normalization forms (UAX #15)
pub const NormalizationForm = enum {
    /// Canonical Decomposition
    nfd,
    /// Canonical Decomposition followed by Canonical Composition
    nfc,
    /// Compatibility Decomposition
    nfkd,
    /// Compatibility Decomposition followed by Canonical Composition
    nfkc,
};

/// Unicode General Category (UAX #44)
pub const GeneralCategory = enum(u8) {
    // Letters
    Lu = 0, // Letter, uppercase
    Ll = 1, // Letter, lowercase
    Lt = 2, // Letter, titlecase
    Lm = 3, // Letter, modifier
    Lo = 4, // Letter, other

    // Marks
    Mn = 5, // Mark, nonspacing
    Mc = 6, // Mark, spacing combining
    Me = 7, // Mark, enclosing

    // Numbers
    Nd = 8, // Number, decimal digit
    Nl = 9, // Number, letter
    No = 10, // Number, other

    // Punctuation
    Pc = 11, // Punctuation, connector
    Pd = 12, // Punctuation, dash
    Ps = 13, // Punctuation, open
    Pe = 14, // Punctuation, close
    Pi = 15, // Punctuation, initial quote
    Pf = 16, // Punctuation, final quote
    Po = 17, // Punctuation, other

    // Symbols
    Sm = 18, // Symbol, math
    Sc = 19, // Symbol, currency
    Sk = 20, // Symbol, modifier
    So = 21, // Symbol, other

    // Separators
    Zs = 22, // Separator, space
    Zl = 23, // Separator, line
    Zp = 24, // Separator, paragraph

    // Other
    Cc = 25, // Other, control
    Cf = 26, // Other, format
    Cs = 27, // Other, surrogate
    Co = 28, // Other, private use
    Cn = 29, // Other, not assigned

    /// Check if this category is a letter (L*)
    pub fn isLetter(self: GeneralCategory) bool {
        return @intFromEnum(self) <= @intFromEnum(GeneralCategory.Lo);
    }

    /// Check if this category is a mark (M*)
    pub fn isMark(self: GeneralCategory) bool {
        const val = @intFromEnum(self);
        return val >= @intFromEnum(GeneralCategory.Mn) and val <= @intFromEnum(GeneralCategory.Me);
    }

    /// Check if this category is a number (N*)
    pub fn isNumber(self: GeneralCategory) bool {
        const val = @intFromEnum(self);
        return val >= @intFromEnum(GeneralCategory.Nd) and val <= @intFromEnum(GeneralCategory.No);
    }

    /// Check if this category is punctuation (P*)
    pub fn isPunctuation(self: GeneralCategory) bool {
        const val = @intFromEnum(self);
        return val >= @intFromEnum(GeneralCategory.Pc) and val <= @intFromEnum(GeneralCategory.Po);
    }

    /// Check if this category is a symbol (S*)
    pub fn isSymbol(self: GeneralCategory) bool {
        const val = @intFromEnum(self);
        return val >= @intFromEnum(GeneralCategory.Sm) and val <= @intFromEnum(GeneralCategory.So);
    }

    /// Check if this category is a separator (Z*)
    pub fn isSeparator(self: GeneralCategory) bool {
        const val = @intFromEnum(self);
        return val >= @intFromEnum(GeneralCategory.Zs) and val <= @intFromEnum(GeneralCategory.Zp);
    }

    /// Check if this category is "other" (C*)
    pub fn isOther(self: GeneralCategory) bool {
        const val = @intFromEnum(self);
        return val >= @intFromEnum(GeneralCategory.Cc);
    }
};

/// Case type for characters
pub const CaseType = enum {
    upper,
    lower,
    title,
    none,
};

/// Comparison options for string operations
pub const CompareOptions = struct {
    /// Ignore case differences
    case_insensitive: bool = false,
    /// Apply Unicode normalization before comparison
    normalize: ?NormalizationForm = null,
    /// Use locale-aware collation
    collation: bool = false,
};

/// Trim options for string manipulation
pub const TrimOptions = struct {
    /// Trim from the start
    left: bool = true,
    /// Trim from the end
    right: bool = true,
    /// Characters to trim (null means whitespace)
    chars: ?[]const u8 = null,
};

/// Split options for string manipulation
pub const SplitOptions = struct {
    /// Maximum number of splits (0 = unlimited)
    max_splits: usize = 0,
    /// Keep empty segments
    keep_empty: bool = true,
};

/// Error types for string operations
pub const StringError = error{
    /// Invalid UTF-8 sequence
    InvalidUtf8,
    /// Invalid UTF-16 sequence (unpaired surrogate)
    InvalidUtf16,
    /// Invalid code point (out of range or surrogate)
    InvalidCodepoint,
    /// Truncated multi-byte sequence
    TruncatedSequence,
    /// Buffer too small for operation
    BufferTooSmall,
    /// Index out of bounds
    IndexOutOfBounds,
    /// Memory allocation failed
    OutOfMemory,
    /// Invalid encoding
    InvalidEncoding,
    /// Encoding mismatch
    EncodingMismatch,
};

/// Result type for decode operations that may fail
pub fn DecodeResult(comptime T: type) type {
    return struct {
        value: T,
        bytes_consumed: usize,
    };
}

/// UTF-16 surrogate pair range constants
pub const surrogate = struct {
    pub const high_start: u21 = 0xD800;
    pub const high_end: u21 = 0xDBFF;
    pub const low_start: u21 = 0xDC00;
    pub const low_end: u21 = 0xDFFF;

    /// Check if a code point is in the surrogate range
    pub fn isSurrogate(cp: u21) bool {
        return cp >= high_start and cp <= low_end;
    }

    /// Check if a code point is a high surrogate
    pub fn isHighSurrogate(cp: u21) bool {
        return cp >= high_start and cp <= high_end;
    }

    /// Check if a code point is a low surrogate
    pub fn isLowSurrogate(cp: u21) bool {
        return cp >= low_start and cp <= low_end;
    }
};

/// BOM (Byte Order Mark) constants
pub const bom = struct {
    pub const utf8: []const u8 = "\xEF\xBB\xBF";
    pub const utf16_le: []const u8 = "\xFF\xFE";
    pub const utf16_be: []const u8 = "\xFE\xFF";
    pub const utf32_le: []const u8 = "\xFF\xFE\x00\x00";
    pub const utf32_be: []const u8 = "\x00\x00\xFE\xFF";
};

test "Encoding properties" {
    const testing = std.testing;

    try testing.expectEqual(@as(u8, 1), Encoding.utf8.bytesPerUnit());
    try testing.expectEqual(@as(u8, 2), Encoding.utf16_le.bytesPerUnit());
    try testing.expectEqual(@as(u8, 4), Encoding.utf32_be.bytesPerUnit());

    try testing.expectEqual(std.builtin.Endian.little, Encoding.utf16_le.endianness().?);
    try testing.expectEqual(std.builtin.Endian.big, Encoding.utf16_be.endianness().?);
    try testing.expect(Encoding.utf8.endianness() == null);
}

test "GeneralCategory classification" {
    const testing = std.testing;

    try testing.expect(GeneralCategory.Lu.isLetter());
    try testing.expect(GeneralCategory.Ll.isLetter());
    try testing.expect(!GeneralCategory.Nd.isLetter());

    try testing.expect(GeneralCategory.Nd.isNumber());
    try testing.expect(!GeneralCategory.Lu.isNumber());

    try testing.expect(GeneralCategory.Zs.isSeparator());
    try testing.expect(!GeneralCategory.Sm.isSeparator());
}

test "surrogate detection" {
    const testing = std.testing;

    try testing.expect(surrogate.isSurrogate(0xD800));
    try testing.expect(surrogate.isSurrogate(0xDFFF));
    try testing.expect(!surrogate.isSurrogate(0x0041));
    try testing.expect(!surrogate.isSurrogate(0x10000));

    try testing.expect(surrogate.isHighSurrogate(0xD800));
    try testing.expect(surrogate.isHighSurrogate(0xDBFF));
    try testing.expect(!surrogate.isHighSurrogate(0xDC00));

    try testing.expect(surrogate.isLowSurrogate(0xDC00));
    try testing.expect(surrogate.isLowSurrogate(0xDFFF));
    try testing.expect(!surrogate.isLowSurrogate(0xD800));
}
