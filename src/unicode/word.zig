// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Word boundaries (UAX #29).
//!
//! This module provides word boundary detection for text segmentation.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const categories = @import("categories");

pub const Codepoint = types.Codepoint;

/// Word break property
pub const WordBreak = enum {
    Other,
    CR,
    LF,
    Newline,
    Extend,
    ZWJ,
    Regional_Indicator,
    Format,
    Katakana,
    Hebrew_Letter,
    ALetter,
    Single_Quote,
    Double_Quote,
    MidNumLet,
    MidLetter,
    MidNum,
    Numeric,
    ExtendNumLet,
    WSegSpace,
};

/// Gets the word break property for a code point
pub fn getWordBreak(cp: Codepoint) WordBreak {
    // CR
    if (cp == 0x000D) return .CR;

    // LF
    if (cp == 0x000A) return .LF;

    // Newline
    if (cp == 0x000B or cp == 0x000C or cp == 0x0085 or cp == 0x2028 or cp == 0x2029) {
        return .Newline;
    }

    // ZWJ
    if (cp == 0x200D) return .ZWJ;

    // Extend
    if (categories.isMark(cp)) return .Extend;
    if (cp == 0x200C) return .Extend; // ZWNJ
    if (cp >= 0xFE00 and cp <= 0xFE0F) return .Extend; // Variation selectors

    // Format
    if (categories.isFormat(cp) and cp != 0x200C and cp != 0x200D) return .Format;

    // Regional Indicator
    if (cp >= 0x1F1E6 and cp <= 0x1F1FF) return .Regional_Indicator;

    // Katakana
    if ((cp >= 0x30A0 and cp <= 0x30FF) or
        (cp >= 0x31F0 and cp <= 0x31FF) or
        (cp >= 0xFF65 and cp <= 0xFF9F) or
        cp == 0x3031 or cp == 0x3032 or cp == 0x3033 or
        cp == 0x3034 or cp == 0x3035)
    {
        return .Katakana;
    }

    // Hebrew Letter
    if (categories.getCategory(cp) == .Lo and cp >= 0x0590 and cp <= 0x05FF) {
        return .Hebrew_Letter;
    }

    // Single Quote
    if (cp == 0x0027) return .Single_Quote;

    // Double Quote
    if (cp == 0x0022) return .Double_Quote;

    // MidNumLet
    if (cp == 0x002E or cp == 0x2018 or cp == 0x2019 or cp == 0x2024 or
        cp == 0xFE52 or cp == 0xFF07 or cp == 0xFF0E)
    {
        return .MidNumLet;
    }

    // MidLetter
    if (cp == 0x003A or cp == 0x00B7 or cp == 0x0387 or cp == 0x055F or
        cp == 0x05F4 or cp == 0x2027 or cp == 0xFE13 or cp == 0xFE55 or cp == 0xFF1A)
    {
        return .MidLetter;
    }

    // MidNum
    if (cp == 0x002C or cp == 0x003B or cp == 0x037E or cp == 0x0589 or
        cp == 0x060C or cp == 0x060D or cp == 0x066C or cp == 0x07F8 or
        cp == 0x2044 or cp == 0xFE10 or cp == 0xFE14 or cp == 0xFE50 or
        cp == 0xFE54 or cp == 0xFF0C or cp == 0xFF1B)
    {
        return .MidNum;
    }

    // Numeric
    if (categories.isDecimalDigit(cp)) return .Numeric;

    // ExtendNumLet
    if (cp == 0x005F or cp == 0x203F or cp == 0x2040 or cp == 0x2054 or cp == 0xFE33 or
        cp == 0xFE34 or cp == 0xFE4D or cp == 0xFE4E or cp == 0xFE4F or cp == 0xFF3F)
    {
        return .ExtendNumLet;
    }

    // WSegSpace (whitespace that's not newline)
    if (categories.isWhitespace(cp) and cp != 0x000A and cp != 0x000D and
        cp != 0x000B and cp != 0x000C and cp != 0x0085 and
        cp != 0x2028 and cp != 0x2029)
    {
        return .WSegSpace;
    }

    // ALetter (alphabetic)
    if (categories.isLetter(cp) and !categories.isCjkIdeograph(cp)) {
        return .ALetter;
    }

    return .Other;
}

/// State for word boundary iteration
pub const WordState = struct {
    last_property: WordBreak = .Other,
    prev_prev_property: ?WordBreak = null,
    ri_count: usize = 0,
};

/// Determines if there should be a word break between positions
pub fn shouldBreak(prev: ?Codepoint, curr: Codepoint, state: *WordState) bool {
    const curr_prop = getWordBreak(curr);

    // WB1: Break at start
    if (prev == null) {
        state.last_property = curr_prop;
        return true;
    }

    const prev_prop = state.last_property;

    // WB3: Do not break within CRLF
    if (prev_prop == .CR and curr_prop == .LF) {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return false;
    }

    // WB3a/WB3b: Break before and after newlines
    if (prev_prop == .Newline or prev_prop == .CR or prev_prop == .LF) {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return true;
    }
    if (curr_prop == .Newline or curr_prop == .CR or curr_prop == .LF) {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return true;
    }

    // WB3c: Do not break within emoji ZWJ sequences
    if (prev_prop == .ZWJ) {
        // Check if current is Extended_Pictographic (simplified)
        const curr_cat = categories.getCategory(curr);
        if (curr_cat == .So) {
            state.prev_prev_property = prev_prop;
            state.last_property = curr_prop;
            return false;
        }
    }

    // WB3d: Keep horizontal whitespace together
    if (prev_prop == .WSegSpace and curr_prop == .WSegSpace) {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return false;
    }

    // WB4: Ignore Format and Extend
    if (curr_prop == .Format or curr_prop == .Extend or curr_prop == .ZWJ) {
        // Don't update state
        return false;
    }

    // WB5: Do not break between most letters
    if ((prev_prop == .ALetter or prev_prop == .Hebrew_Letter) and
        (curr_prop == .ALetter or curr_prop == .Hebrew_Letter))
    {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return false;
    }

    // WB6/WB7: Do not break letters across certain punctuation
    if ((prev_prop == .ALetter or prev_prop == .Hebrew_Letter) and
        (curr_prop == .MidLetter or curr_prop == .MidNumLet or curr_prop == .Single_Quote))
    {
        // Need to look ahead - simplified: allow the break
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return false;
    }

    // WB8: Do not break within numeric sequences
    if (prev_prop == .Numeric and curr_prop == .Numeric) {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return false;
    }

    // WB9/WB10: Do not break between letters and numbers
    if ((prev_prop == .ALetter or prev_prop == .Hebrew_Letter) and curr_prop == .Numeric) {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return false;
    }
    if (prev_prop == .Numeric and (curr_prop == .ALetter or curr_prop == .Hebrew_Letter)) {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return false;
    }

    // WB13: Do not break between Katakana
    if (prev_prop == .Katakana and curr_prop == .Katakana) {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return false;
    }

    // WB13a/WB13b: ExtendNumLet
    if ((prev_prop == .ALetter or prev_prop == .Hebrew_Letter or prev_prop == .Numeric or
        prev_prop == .Katakana or prev_prop == .ExtendNumLet) and curr_prop == .ExtendNumLet)
    {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return false;
    }
    if (prev_prop == .ExtendNumLet and (curr_prop == .ALetter or curr_prop == .Hebrew_Letter or
        curr_prop == .Numeric or curr_prop == .Katakana))
    {
        state.prev_prev_property = prev_prop;
        state.last_property = curr_prop;
        return false;
    }

    // WB15/WB16: Regional indicators (pairs)
    if (prev_prop == .Regional_Indicator and curr_prop == .Regional_Indicator) {
        state.ri_count += 1;
        if (state.ri_count % 2 == 1) {
            state.prev_prev_property = prev_prop;
            state.last_property = curr_prop;
            return false;
        }
    } else {
        state.ri_count = 0;
    }

    // WB999: Otherwise, break everywhere
    state.prev_prev_property = prev_prop;
    state.last_property = curr_prop;
    return true;
}

/// Iterator over words in a UTF-8 string
pub const Iterator = struct {
    bytes: []const u8,
    index: usize,
    state: WordState,

    pub fn init(bytes: []const u8) Iterator {
        return .{
            .bytes = bytes,
            .index = 0,
            .state = .{},
        };
    }

    /// Returns the next word as a UTF-8 slice
    pub fn next(self: *Iterator) ?[]const u8 {
        if (self.index >= self.bytes.len) {
            return null;
        }

        const start = self.index;
        var prev_cp: ?Codepoint = null;

        // Get first code point
        const first_len = std.unicode.utf8ByteSequenceLength(self.bytes[self.index]) catch {
            self.index += 1;
            return self.bytes[start..self.index];
        };
        if (self.index + first_len > self.bytes.len) {
            self.index = self.bytes.len;
            return self.bytes[start..];
        }
        prev_cp = std.unicode.utf8Decode(self.bytes[self.index..][0..first_len]) catch {
            self.index += 1;
            return self.bytes[start..self.index];
        };
        self.index += first_len;

        // Initial state update
        _ = shouldBreak(null, prev_cp.?, &self.state);

        // Continue until we find a break
        while (self.index < self.bytes.len) {
            const len = std.unicode.utf8ByteSequenceLength(self.bytes[self.index]) catch break;
            if (self.index + len > self.bytes.len) break;

            const cp = std.unicode.utf8Decode(self.bytes[self.index..][0..len]) catch break;

            if (shouldBreak(prev_cp, cp, &self.state)) {
                break;
            }

            prev_cp = cp;
            self.index += len;
        }

        return self.bytes[start..self.index];
    }

    /// Reset the iterator
    pub fn reset(self: *Iterator) void {
        self.index = 0;
        self.state = .{};
    }
};

/// Creates a word iterator
pub fn iterator(bytes: []const u8) Iterator {
    return Iterator.init(bytes);
}

/// Counts the number of words in a string
pub fn count(bytes: []const u8) usize {
    var iter = iterator(bytes);
    var n: usize = 0;
    while (iter.next()) |_| {
        n += 1;
    }
    return n;
}

test "word break properties" {
    const testing = std.testing;

    try testing.expectEqual(WordBreak.CR, getWordBreak(0x000D));
    try testing.expectEqual(WordBreak.LF, getWordBreak(0x000A));
    try testing.expectEqual(WordBreak.ALetter, getWordBreak('a'));
    try testing.expectEqual(WordBreak.Numeric, getWordBreak('5'));
    try testing.expectEqual(WordBreak.Single_Quote, getWordBreak('\''));
}

test "simple words" {
    const testing = std.testing;

    var iter = iterator("hello world");
    try testing.expectEqualSlices(u8, "hello", iter.next().?);
    try testing.expectEqualSlices(u8, " ", iter.next().?);
    try testing.expectEqualSlices(u8, "world", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "numbers in words" {
    const testing = std.testing;

    var iter = iterator("test123");
    try testing.expectEqualSlices(u8, "test123", iter.next().?);
    try testing.expect(iter.next() == null);
}
