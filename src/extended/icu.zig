// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! ICU Compatibility Layer
//!
//! Provides an API compatible with ICU (International Components for Unicode)
//! naming conventions and patterns. This makes migration from ICU-based code easier.
//!
//! Maps ICU concepts to ZigStr functionality:
//! - UnicodeString -> String
//! - UChar/UChar32 -> u16/u21
//! - UNormalization -> normalization module
//! - UBreakIterator -> grapheme/word/sentence iterators
//! - UCollator -> collation module
//!
//! Usage:
//! ```zig
//! const icu = @import("icu");
//!
//! // ICU-style Unicode string operations
//! var ustr = try icu.UnicodeString.fromUtf8(allocator, "Hello");
//! defer ustr.deinit();
//!
//! // ICU-style normalization
//! const normalized = try icu.Normalizer2.getInstance(.NFC).normalize(allocator, text);
//!
//! // ICU-style break iteration
//! var bi = icu.BreakIterator.createCharacterInstance(text);
//! while (bi.next()) |boundary| { ... }
//! ```

const std = @import("std");

// Import ZigStr modules
const normalization = @import("normalization");
const grapheme_mod = @import("grapheme");
const word_mod = @import("word");
const sentence_mod = @import("sentence");
const collation_mod = @import("collation");
const case_mod = @import("case");
const types = @import("types");

/// ICU-compatible type aliases
pub const UChar = u16;
pub const UChar32 = u21;
pub const UBool = bool;
pub const UErrorCode = error{
    IllegalArgument,
    BufferOverflow,
    InvalidState,
    Unsupported,
    OutOfMemory,
    InternalError,
};

/// ICU-compatible normalization mode
pub const UNormalizationMode = enum {
    UNORM_NONE,
    UNORM_NFD,
    UNORM_NFKD,
    UNORM_NFC,
    UNORM_NFKC,
    UNORM_FCD,

    pub fn toZigStr(self: UNormalizationMode) ?types.NormalizationForm {
        return switch (self) {
            .UNORM_NFD => .nfd,
            .UNORM_NFC => .nfc,
            .UNORM_NFKD => .nfkd,
            .UNORM_NFKC => .nfkc,
            .UNORM_NONE, .UNORM_FCD => null,
        };
    }
};

/// ICU-compatible break iterator type
pub const UBreakIteratorType = enum {
    UBRK_CHARACTER,
    UBRK_WORD,
    UBRK_LINE,
    UBRK_SENTENCE,
};

/// ICU-compatible collation strength
pub const UCollationStrength = enum {
    UCOL_PRIMARY,
    UCOL_SECONDARY,
    UCOL_TERTIARY,
    UCOL_QUATERNARY,
    UCOL_IDENTICAL,

    pub fn toZigStr(self: UCollationStrength) collation_mod.Strength {
        return switch (self) {
            .UCOL_PRIMARY => .primary,
            .UCOL_SECONDARY => .secondary,
            .UCOL_TERTIARY => .tertiary,
            .UCOL_QUATERNARY => .quaternary,
            .UCOL_IDENTICAL => .identical,
        };
    }
};

/// ICU-compatible collation result
pub const UCollationResult = enum(i8) {
    UCOL_LESS = -1,
    UCOL_EQUAL = 0,
    UCOL_GREATER = 1,
};

// ============================================================
// UnicodeString - ICU-compatible string type
// ============================================================

/// ICU-compatible Unicode string
pub const UnicodeString = struct {
    /// Internal UTF-16 storage (like ICU)
    data: std.ArrayListUnmanaged(u16),
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Create empty string
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .data = .{},
            .allocator = allocator,
        };
    }

    /// Create from UTF-8
    pub fn fromUtf8(allocator: std.mem.Allocator, utf8: []const u8) !Self {
        var self = init(allocator);
        errdefer self.deinit();

        var iter = std.unicode.Utf8Iterator{ .bytes = utf8, .i = 0 };
        while (iter.nextCodepoint()) |cp| {
            if (cp <= 0xFFFF) {
                try self.data.append(allocator, @intCast(cp));
            } else {
                // Surrogate pair
                const adjusted = cp - 0x10000;
                try self.data.append(allocator, @intCast(0xD800 + (adjusted >> 10)));
                try self.data.append(allocator, @intCast(0xDC00 + (adjusted & 0x3FF)));
            }
        }

        return self;
    }

    /// Create from UTF-16
    pub fn fromUtf16(allocator: std.mem.Allocator, utf16: []const u16) !Self {
        var self = init(allocator);
        try self.data.appendSlice(allocator, utf16);
        return self;
    }

    /// Clean up
    pub fn deinit(self: *Self) void {
        self.data.deinit(self.allocator);
    }

    /// Get length in UTF-16 code units
    pub fn length(self: Self) usize {
        return self.data.items.len;
    }

    /// Check if empty
    pub fn isEmpty(self: Self) bool {
        return self.data.items.len == 0;
    }

    /// Get character at index (ICU-style, returns UChar32)
    pub fn char32At(self: Self, offset: usize) ?UChar32 {
        if (offset >= self.data.items.len) return null;

        const high = self.data.items[offset];
        if (high >= 0xD800 and high <= 0xDBFF) {
            if (offset + 1 < self.data.items.len) {
                const low = self.data.items[offset + 1];
                if (low >= 0xDC00 and low <= 0xDFFF) {
                    return 0x10000 + ((@as(u21, high - 0xD800) << 10) | (low - 0xDC00));
                }
            }
        }

        return high;
    }

    /// Convert to UTF-8
    pub fn toUtf8String(self: Self, allocator: std.mem.Allocator) ![]u8 {
        var result: std.ArrayListUnmanaged(u8) = .{};
        errdefer result.deinit(allocator);

        var i: usize = 0;
        while (i < self.data.items.len) {
            const high = self.data.items[i];

            if (high >= 0xD800 and high <= 0xDBFF and i + 1 < self.data.items.len) {
                const low = self.data.items[i + 1];
                if (low >= 0xDC00 and low <= 0xDFFF) {
                    const cp: u21 = 0x10000 + ((@as(u21, high - 0xD800) << 10) | (low - 0xDC00));
                    var buf: [4]u8 = undefined;
                    const len = std.unicode.utf8Encode(cp, &buf) catch continue;
                    try result.appendSlice(allocator, buf[0..len]);
                    i += 2;
                    continue;
                }
            }

            var buf: [4]u8 = undefined;
            const len = std.unicode.utf8Encode(high, &buf) catch continue;
            try result.appendSlice(allocator, buf[0..len]);
            i += 1;
        }

        return result.toOwnedSlice(allocator);
    }

    /// Append another string
    pub fn append(self: *Self, other: Self) !*Self {
        try self.data.appendSlice(self.allocator, other.data.items);
        return self;
    }

    /// Append UTF-8 string
    pub fn appendUtf8(self: *Self, utf8: []const u8) !*Self {
        var iter = std.unicode.Utf8Iterator{ .bytes = utf8, .i = 0 };
        while (iter.nextCodepoint()) |cp| {
            if (cp <= 0xFFFF) {
                try self.data.append(self.allocator, @intCast(cp));
            } else {
                const adjusted = cp - 0x10000;
                try self.data.append(self.allocator, @intCast(0xD800 + (adjusted >> 10)));
                try self.data.append(self.allocator, @intCast(0xDC00 + (adjusted & 0x3FF)));
            }
        }
        return self;
    }

    /// Case fold (ICU-style)
    pub fn foldCase(self: Self, allocator: std.mem.Allocator) !Self {
        const utf8 = try self.toUtf8String(allocator);
        defer allocator.free(utf8);

        const folded = try case_mod.foldCase(allocator, utf8);
        defer allocator.free(folded);

        return fromUtf8(allocator, folded);
    }

    /// To lowercase
    pub fn toLower(self: Self, allocator: std.mem.Allocator) !Self {
        const utf8 = try self.toUtf8String(allocator);
        defer allocator.free(utf8);

        const lower = try case_mod.toLowerString(allocator, utf8);
        defer allocator.free(lower);

        return fromUtf8(allocator, lower);
    }

    /// To uppercase
    pub fn toUpper(self: Self, allocator: std.mem.Allocator) !Self {
        const utf8 = try self.toUtf8String(allocator);
        defer allocator.free(utf8);

        const upper = try case_mod.toUpperString(allocator, utf8);
        defer allocator.free(upper);

        return fromUtf8(allocator, upper);
    }

    /// Compare (case-sensitive)
    pub fn compare(self: Self, other: Self) i32 {
        const min_len = @min(self.data.items.len, other.data.items.len);
        for (self.data.items[0..min_len], other.data.items[0..min_len]) |a, b| {
            if (a != b) {
                return if (a < b) -1 else 1;
            }
        }
        if (self.data.items.len < other.data.items.len) return -1;
        if (self.data.items.len > other.data.items.len) return 1;
        return 0;
    }

    /// Case-insensitive compare
    pub fn caseCompare(self: Self, other: Self, allocator: std.mem.Allocator) !i32 {
        const folded_self = try self.foldCase(allocator);
        defer @constCast(&folded_self).deinit();
        const folded_other = try other.foldCase(allocator);
        defer @constCast(&folded_other).deinit();
        return folded_self.compare(folded_other);
    }
};

// ============================================================
// Normalizer2 - ICU-compatible normalizer
// ============================================================

/// ICU-compatible normalizer
pub const Normalizer2 = struct {
    mode: UNormalizationMode,

    const Self = @This();

    /// Get normalizer instance
    pub fn getInstance(mode: UNormalizationMode) Self {
        return .{ .mode = mode };
    }

    /// Get NFC instance
    pub fn getNFCInstance() Self {
        return getInstance(.UNORM_NFC);
    }

    /// Get NFD instance
    pub fn getNFDInstance() Self {
        return getInstance(.UNORM_NFD);
    }

    /// Get NFKC instance
    pub fn getNFKCInstance() Self {
        return getInstance(.UNORM_NFKC);
    }

    /// Get NFKD instance
    pub fn getNFKDInstance() Self {
        return getInstance(.UNORM_NFKD);
    }

    /// Normalize a string
    pub fn normalize(self: Self, allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        if (self.mode.toZigStr()) |form| {
            return normalization.normalize(allocator, input, form);
        }
        // UNORM_NONE - return copy
        return allocator.dupe(u8, input);
    }

    /// Check if string is normalized
    pub fn isNormalized(self: Self, input: []const u8) bool {
        if (self.mode.toZigStr()) |form| {
            return normalization.isNormalized(input, form);
        }
        return true;
    }

    /// Quick check normalization
    pub fn quickCheck(self: Self, input: []const u8) enum { YES, NO, MAYBE } {
        if (self.isNormalized(input)) {
            return .YES;
        }
        return .NO;
    }
};

// ============================================================
// BreakIterator - ICU-compatible break iterator
// ============================================================

/// ICU-compatible break iterator
pub const BreakIterator = struct {
    iter_type: UBreakIteratorType,
    text: []const u8,
    pos: usize,

    const Self = @This();
    pub const DONE: i32 = -1;

    /// Create character (grapheme) break iterator
    pub fn createCharacterInstance(text: []const u8) Self {
        return .{
            .iter_type = .UBRK_CHARACTER,
            .text = text,
            .pos = 0,
        };
    }

    /// Create word break iterator
    pub fn createWordInstance(text: []const u8) Self {
        return .{
            .iter_type = .UBRK_WORD,
            .text = text,
            .pos = 0,
        };
    }

    /// Create sentence break iterator
    pub fn createSentenceInstance(text: []const u8) Self {
        return .{
            .iter_type = .UBRK_SENTENCE,
            .text = text,
            .pos = 0,
        };
    }

    /// Get first boundary
    pub fn first(self: *Self) i32 {
        self.pos = 0;
        return 0;
    }

    /// Get last boundary
    pub fn last(self: *Self) i32 {
        self.pos = self.text.len;
        return @intCast(self.text.len);
    }

    /// Get next boundary
    pub fn next(self: *Self) i32 {
        if (self.pos >= self.text.len) return DONE;

        switch (self.iter_type) {
            .UBRK_CHARACTER => {
                var iter = grapheme_mod.Iterator.init(self.text[self.pos..]);
                if (iter.next()) |g| {
                    self.pos += g.len;
                    return @intCast(self.pos);
                }
                return DONE;
            },
            .UBRK_WORD => {
                var iter = word_mod.Iterator.init(self.text[self.pos..]);
                if (iter.next()) |w| {
                    self.pos += w.len;
                    return @intCast(self.pos);
                }
                return DONE;
            },
            .UBRK_SENTENCE => {
                var iter = sentence_mod.Iterator.init(self.text[self.pos..]);
                if (iter.next()) |s| {
                    self.pos += s.len;
                    return @intCast(self.pos);
                }
                return DONE;
            },
            .UBRK_LINE => {
                // Simple line break - find next newline
                var i = self.pos;
                while (i < self.text.len and self.text[i] != '\n') : (i += 1) {}
                if (i < self.text.len) i += 1;
                const old_pos = self.pos;
                self.pos = i;
                return if (i > old_pos) @intCast(i) else DONE;
            },
        }
    }

    /// Get previous boundary
    pub fn previous(self: *Self) i32 {
        if (self.pos == 0) return DONE;

        // Simple implementation - go back one UTF-8 character
        var new_pos = self.pos - 1;
        while (new_pos > 0 and (self.text[new_pos] & 0xC0) == 0x80) {
            new_pos -= 1;
        }
        self.pos = new_pos;
        return @intCast(new_pos);
    }

    /// Get current position
    pub fn current(self: Self) i32 {
        return @intCast(self.pos);
    }

    /// Check if position is a boundary
    pub fn isBoundary(self: Self, offset: usize) bool {
        if (offset == 0 or offset >= self.text.len) return true;

        // Check if we're at a grapheme boundary
        var iter = grapheme_mod.Iterator{ .bytes = self.text, .offset = 0 };
        while (iter.next()) |g| {
            if (g.offset == offset) return true;
            if (g.offset > offset) return false;
        }
        return false;
    }
};

// ============================================================
// Collator - ICU-compatible collator
// ============================================================

/// ICU-compatible collator
pub const Collator = struct {
    strength: UCollationStrength,

    const Self = @This();

    /// Create collator instance
    pub fn createInstance() Self {
        return .{ .strength = .UCOL_TERTIARY };
    }

    /// Set collation strength
    pub fn setStrength(self: *Self, strength: UCollationStrength) void {
        self.strength = strength;
    }

    /// Get collation strength
    pub fn getStrength(self: Self) UCollationStrength {
        return self.strength;
    }

    /// Compare two strings
    pub fn compare(self: Self, source: []const u8, target: []const u8) UCollationResult {
        const result = collation_mod.compare(source, target, .{
            .strength = self.strength.toZigStr(),
        });

        return switch (result) {
            .lt => .UCOL_LESS,
            .eq => .UCOL_EQUAL,
            .gt => .UCOL_GREATER,
        };
    }

    /// Check equality
    pub fn equals(self: Self, source: []const u8, target: []const u8) bool {
        return self.compare(source, target) == .UCOL_EQUAL;
    }

    /// Get sort key (for efficient repeated comparisons)
    pub fn getSortKey(self: Self, allocator: std.mem.Allocator, source: []const u8) ![]u8 {
        _ = self;
        return collation_mod.getSortKey(allocator, source, .{});
    }
};

// ============================================================
// Character Properties - ICU-compatible
// ============================================================

/// ICU-compatible character property functions
pub const UCharacter = struct {
    /// Check if character is alphabetic
    pub fn isAlphabetic(c: UChar32) bool {
        // Simplified - check ASCII range
        if (c <= 127) {
            return std.ascii.isAlphabetic(@intCast(c));
        }
        return true; // Assume non-ASCII letters are alphabetic
    }

    /// Check if character is digit
    pub fn isDigit(c: UChar32) bool {
        if (c <= 127) {
            return std.ascii.isDigit(@intCast(c));
        }
        return c >= 0x0660 and c <= 0x0669; // Arabic-Indic digits
    }

    /// Check if character is whitespace
    pub fn isWhitespace(c: UChar32) bool {
        return switch (c) {
            ' ', '\t', '\n', '\r', 0x0B, 0x0C => true,
            0x00A0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000 => true,
            else => false,
        };
    }

    /// Check if character is uppercase
    pub fn isUpperCase(c: UChar32) bool {
        if (c <= 127) {
            return std.ascii.isUpper(@intCast(c));
        }
        return false;
    }

    /// Check if character is lowercase
    pub fn isLowerCase(c: UChar32) bool {
        if (c <= 127) {
            return std.ascii.isLower(@intCast(c));
        }
        return false;
    }

    /// Get uppercase equivalent
    pub fn toUpperCase(c: UChar32) UChar32 {
        return case_mod.toUpper(c);
    }

    /// Get lowercase equivalent
    pub fn toLowerCase(c: UChar32) UChar32 {
        return case_mod.toLower(c);
    }

    /// Get titlecase equivalent
    pub fn toTitleCase(c: UChar32) UChar32 {
        return case_mod.toTitle(c);
    }

    /// Get numeric value
    pub fn getNumericValue(c: UChar32) i32 {
        if (c >= '0' and c <= '9') {
            return @intCast(c - '0');
        }
        return -1;
    }
};

// ============================================================
// Utility Functions
// ============================================================

/// Convert UTF-8 to UTF-16 (ICU-style)
pub fn u_strFromUTF8(
    allocator: std.mem.Allocator,
    src: []const u8,
) ![]u16 {
    var result: std.ArrayListUnmanaged(u16) = .{};
    errdefer result.deinit(allocator);

    var iter = std.unicode.Utf8Iterator{ .bytes = src, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        if (cp <= 0xFFFF) {
            try result.append(allocator, @intCast(cp));
        } else {
            const adjusted = cp - 0x10000;
            try result.append(allocator, @intCast(0xD800 + (adjusted >> 10)));
            try result.append(allocator, @intCast(0xDC00 + (adjusted & 0x3FF)));
        }
    }

    return result.toOwnedSlice(allocator);
}

/// Convert UTF-16 to UTF-8 (ICU-style)
pub fn u_strToUTF8(
    allocator: std.mem.Allocator,
    src: []const u16,
) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    var i: usize = 0;
    while (i < src.len) {
        const high = src[i];

        var cp: u21 = undefined;
        if (high >= 0xD800 and high <= 0xDBFF and i + 1 < src.len) {
            const low = src[i + 1];
            if (low >= 0xDC00 and low <= 0xDFFF) {
                cp = 0x10000 + ((@as(u21, high - 0xD800) << 10) | (low - 0xDC00));
                i += 2;
            } else {
                cp = high;
                i += 1;
            }
        } else {
            cp = high;
            i += 1;
        }

        var buf: [4]u8 = undefined;
        const len = std.unicode.utf8Encode(cp, &buf) catch continue;
        try result.appendSlice(allocator, buf[0..len]);
    }

    return result.toOwnedSlice(allocator);
}

/// Count codepoints in UTF-8 string
pub fn u_countChar32(s: []const u8) usize {
    var count: usize = 0;
    var iter = std.unicode.Utf8Iterator{ .bytes = s, .i = 0 };
    while (iter.nextCodepoint()) |_| {
        count += 1;
    }
    return count;
}

// ============================================================
// Tests
// ============================================================

test "UnicodeString basic" {
    const testing = std.testing;

    var ustr = try UnicodeString.fromUtf8(testing.allocator, "Hello, World!");
    defer ustr.deinit();

    try testing.expectEqual(@as(usize, 13), ustr.length());
    try testing.expect(!ustr.isEmpty());
}

test "UnicodeString UTF-8 roundtrip" {
    const testing = std.testing;

    const original = "Hello, \xE4\xB8\x96\xE7\x95\x8C!"; // "Hello, 世界!"
    var ustr = try UnicodeString.fromUtf8(testing.allocator, original);
    defer ustr.deinit();

    const back = try ustr.toUtf8String(testing.allocator);
    defer testing.allocator.free(back);

    try testing.expectEqualStrings(original, back);
}

test "Normalizer2" {
    const testing = std.testing;

    const nfc = Normalizer2.getNFCInstance();

    // NFD text: e + combining acute
    const nfd_text = "e\xCC\x81";
    try testing.expect(!nfc.isNormalized(nfd_text));

    const normalized = try nfc.normalize(testing.allocator, nfd_text);
    defer testing.allocator.free(normalized);

    try testing.expect(nfc.isNormalized(normalized));
}

test "BreakIterator character" {
    const testing = std.testing;

    var bi = BreakIterator.createCharacterInstance("hello");

    try testing.expectEqual(@as(i32, 0), bi.first());
    try testing.expect(bi.next() != BreakIterator.DONE);
}

test "Collator" {
    const testing = std.testing;

    var col = Collator.createInstance();
    col.setStrength(.UCOL_PRIMARY);

    try testing.expect(col.equals("hello", "hello"));
}

test "UCharacter" {
    const testing = std.testing;

    try testing.expect(UCharacter.isAlphabetic('A'));
    try testing.expect(UCharacter.isDigit('5'));
    try testing.expect(UCharacter.isWhitespace(' '));
    try testing.expect(UCharacter.isUpperCase('A'));
    try testing.expect(!UCharacter.isUpperCase('a'));
}

test "u_strFromUTF8" {
    const testing = std.testing;

    const utf8 = "Hello";
    const utf16 = try u_strFromUTF8(testing.allocator, utf8);
    defer testing.allocator.free(utf16);

    try testing.expectEqual(@as(usize, 5), utf16.len);
    try testing.expectEqual(@as(u16, 'H'), utf16[0]);
}

test "u_countChar32" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 5), u_countChar32("Hello"));
    try testing.expectEqual(@as(usize, 2), u_countChar32("\xE4\xB8\x96\xE7\x95\x8C")); // 世界
}
