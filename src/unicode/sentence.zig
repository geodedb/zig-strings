// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Sentence boundaries (UAX #29).
//!
//! This module provides sentence boundary detection for text segmentation.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const categories = @import("categories");

pub const Codepoint = types.Codepoint;

/// Sentence break property
pub const SentenceBreak = enum {
    Other,
    CR,
    LF,
    Extend,
    Sep,
    Format,
    Sp,
    Lower,
    Upper,
    OLetter,
    Numeric,
    ATerm,
    SContinue,
    STerm,
    Close,
};

/// Gets the sentence break property for a code point
pub fn getSentenceBreak(cp: Codepoint) SentenceBreak {
    // CR
    if (cp == 0x000D) return .CR;

    // LF
    if (cp == 0x000A) return .LF;

    // Sep (paragraph separator)
    if (cp == 0x0085 or cp == 0x2028 or cp == 0x2029) return .Sep;

    // Extend
    if (categories.isMark(cp)) return .Extend;
    if (cp == 0x200C or cp == 0x200D) return .Extend;
    if (cp >= 0xFE00 and cp <= 0xFE0F) return .Extend;

    // Format
    if (categories.isFormat(cp) and cp != 0x200C and cp != 0x200D) return .Format;

    // Sp (space)
    if (categories.isWhitespace(cp) and cp != 0x000A and cp != 0x000D and
        cp != 0x0085 and cp != 0x2028 and cp != 0x2029)
    {
        return .Sp;
    }

    // ATerm (.)
    if (cp == 0x002E or cp == 0x2024 or cp == 0xFE52 or cp == 0xFF0E) {
        return .ATerm;
    }

    // STerm (! ?)
    if (cp == 0x0021 or cp == 0x003F or cp == 0x0589 or cp == 0x061F or
        cp == 0x06D4 or cp == 0x0700 or cp == 0x0701 or cp == 0x0702 or
        cp == 0x07F9 or cp == 0x0964 or cp == 0x0965 or cp == 0x104A or
        cp == 0x104B or cp == 0x1362 or cp == 0x1367 or cp == 0x1368 or
        cp == 0x166E or cp == 0x1803 or cp == 0x1809 or cp == 0x1944 or
        cp == 0x1945 or cp == 0x2047 or cp == 0x2048 or cp == 0x2049 or
        cp == 0x203C or cp == 0x203D or cp == 0x2E2E or cp == 0x3002 or
        cp == 0xA4FF or cp == 0xA60E or cp == 0xA60F or cp == 0xA6F3 or
        cp == 0xA6F7 or cp == 0xA876 or cp == 0xA877 or cp == 0xA8CE or
        cp == 0xA8CF or cp == 0xA92F or cp == 0xA9C8 or cp == 0xA9C9 or
        cp == 0xAA5D or cp == 0xAA5E or cp == 0xAA5F or cp == 0xAAF0 or
        cp == 0xAAF1 or cp == 0xABEB or cp == 0xFE56 or cp == 0xFE57 or
        cp == 0xFF01 or cp == 0xFF1F or cp == 0xFF61 or cp == 0x10A56 or
        cp == 0x10A57 or cp == 0x11047 or cp == 0x11048 or cp == 0x110BE or
        cp == 0x110BF or cp == 0x110C0 or cp == 0x110C1 or cp == 0x11141 or
        cp == 0x11142 or cp == 0x11143 or cp == 0x111C5 or cp == 0x111C6)
    {
        return .STerm;
    }

    // SContinue (, ; :)
    if (cp == 0x002C or cp == 0x002D or cp == 0x003A or cp == 0x055D) {
        return .SContinue;
    }

    // Close
    const cat = categories.getCategory(cp);
    if (cat == .Pe or cat == .Ps) return .Close;
    if (cp == 0x0022 or cp == 0x0027 or cp == 0x00AB or cp == 0x00BB or
        cp == 0x2018 or cp == 0x2019 or cp == 0x201A or cp == 0x201B or
        cp == 0x201C or cp == 0x201D or cp == 0x201E or cp == 0x201F or
        cp == 0x2039 or cp == 0x203A or cp == 0x275B or cp == 0x275C or
        cp == 0x275D or cp == 0x275E)
    {
        return .Close;
    }

    // Upper
    if (cat == .Lu) return .Upper;

    // Lower
    if (cat == .Ll) return .Lower;

    // Numeric
    if (categories.isDecimalDigit(cp)) return .Numeric;

    // OLetter (other letters)
    if (cat.isLetter()) return .OLetter;

    return .Other;
}

/// State for sentence boundary iteration
pub const SentenceState = struct {
    last_property: SentenceBreak = .Other,
    after_aterm: bool = false,
    after_sterm: bool = false,
    seen_lower: bool = false,
};

/// Determines if there should be a sentence break between positions
pub fn shouldBreak(prev: ?Codepoint, curr: Codepoint, state: *SentenceState) bool {
    const curr_prop = getSentenceBreak(curr);

    // SB1: Break at start
    if (prev == null) {
        state.last_property = curr_prop;
        return true;
    }

    const prev_prop = state.last_property;

    // SB3: Do not break within CRLF
    if (prev_prop == .CR and curr_prop == .LF) {
        state.last_property = curr_prop;
        return false;
    }

    // SB4: Break after paragraph separators
    if (prev_prop == .Sep or prev_prop == .CR or prev_prop == .LF) {
        state.last_property = curr_prop;
        state.after_aterm = false;
        state.after_sterm = false;
        return true;
    }

    // SB5: Ignore Format and Extend
    if (curr_prop == .Format or curr_prop == .Extend) {
        return false;
    }

    // SB6: Do not break after ATerm while there's no sentence ending
    if (prev_prop == .ATerm and curr_prop == .Numeric) {
        state.last_property = curr_prop;
        return false;
    }

    // SB7: Do not break if ATerm is between upper case letters
    if (state.after_aterm and prev_prop == .ATerm and curr_prop == .Upper) {
        // Check if there was an upper case before ATerm
        state.last_property = curr_prop;
        state.after_aterm = false;
        return false;
    }

    // Track ATerm
    if (prev_prop == .ATerm) {
        state.after_aterm = true;
    }

    // SB8: Do not break after ATerm followed by Close*, Sp*, and Lower
    if (state.after_aterm) {
        if (curr_prop == .Close or curr_prop == .Sp) {
            state.last_property = curr_prop;
            return false;
        }
        if (curr_prop == .Lower) {
            state.last_property = curr_prop;
            state.after_aterm = false;
            return false;
        }
    }

    // SB9: Do not break after [STerm | ATerm] Close*
    if ((state.after_aterm or state.after_sterm) and curr_prop == .Close) {
        state.last_property = curr_prop;
        return false;
    }

    // SB10: Do not break after [STerm | ATerm] Close* Sp*
    if ((state.after_aterm or state.after_sterm) and curr_prop == .Sp) {
        state.last_property = curr_prop;
        return false;
    }

    // SB11: Break after [STerm | ATerm] Close* Sp* [Sep | CR | LF]?
    if (state.after_aterm or state.after_sterm) {
        if (curr_prop != .Close and curr_prop != .Sp and
            curr_prop != .SContinue and curr_prop != .Numeric and
            curr_prop != .ATerm and curr_prop != .STerm)
        {
            state.last_property = curr_prop;
            state.after_aterm = false;
            state.after_sterm = false;
            state.seen_lower = false;
            return true;
        }
    }

    // Track STerm
    if (prev_prop == .STerm) {
        state.after_sterm = true;
    }

    // SB998: Do not break otherwise
    state.last_property = curr_prop;
    if (curr_prop == .Lower) state.seen_lower = true;
    return false;
}

/// Iterator over sentences in a UTF-8 string
pub const Iterator = struct {
    bytes: []const u8,
    index: usize,
    state: SentenceState,

    /// Creates a new sentence boundary iterator over the given UTF-8 bytes.
    pub fn init(bytes: []const u8) Iterator {
        return .{
            .bytes = bytes,
            .index = 0,
            .state = .{},
        };
    }

    /// Returns the next sentence as a UTF-8 slice
    pub fn next(self: *Iterator) ?[]const u8 {
        if (self.index >= self.bytes.len) {
            return null;
        }

        const start = self.index;
        var prev_cp: ?Codepoint = null;
        var found_content = false;

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
        found_content = true;

        // Continue until we find a break
        while (self.index < self.bytes.len) {
            const len = std.unicode.utf8ByteSequenceLength(self.bytes[self.index]) catch break;
            if (self.index + len > self.bytes.len) break;

            const cp = std.unicode.utf8Decode(self.bytes[self.index..][0..len]) catch break;

            if (shouldBreak(prev_cp, cp, &self.state) and found_content) {
                break;
            }

            prev_cp = cp;
            self.index += len;
            found_content = true;
        }

        return self.bytes[start..self.index];
    }

    /// Reset the iterator
    pub fn reset(self: *Iterator) void {
        self.index = 0;
        self.state = .{};
    }
};

/// Creates a sentence iterator
pub fn iterator(bytes: []const u8) Iterator {
    return Iterator.init(bytes);
}

/// Counts the number of sentences in a string
pub fn count(bytes: []const u8) usize {
    var iter = iterator(bytes);
    var n: usize = 0;
    while (iter.next()) |_| {
        n += 1;
    }
    return n;
}

test "sentence break properties" {
    const testing = std.testing;

    try testing.expectEqual(SentenceBreak.CR, getSentenceBreak(0x000D));
    try testing.expectEqual(SentenceBreak.LF, getSentenceBreak(0x000A));
    try testing.expectEqual(SentenceBreak.ATerm, getSentenceBreak('.'));
    try testing.expectEqual(SentenceBreak.STerm, getSentenceBreak('!'));
    try testing.expectEqual(SentenceBreak.STerm, getSentenceBreak('?'));
    try testing.expectEqual(SentenceBreak.Upper, getSentenceBreak('A'));
    try testing.expectEqual(SentenceBreak.Lower, getSentenceBreak('a'));
}

test "simple sentences" {
    const testing = std.testing;

    const text = "Hello. World!";
    var iter = iterator(text);
    try testing.expectEqualSlices(u8, "Hello. ", iter.next().?);
    try testing.expectEqualSlices(u8, "World!", iter.next().?);
    try testing.expect(iter.next() == null);
}
