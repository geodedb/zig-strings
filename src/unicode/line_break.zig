// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode Line Breaking Algorithm (UAX #14)
//!
//! This module provides line breaking properties and algorithms for Unicode text.
//! It determines where line breaks are allowed or required in text.

const std = @import("std");
const types = @import("types");
const ucd_line_break = @import("ucd_line_break");

pub const Codepoint = types.Codepoint;

/// Unicode Line Break Classes
pub const LineBreakClass = ucd_line_break.LineBreakClass;

/// Gets the Line Break Class for a code point
pub fn getLineBreakClass(cp: Codepoint) LineBreakClass {
    return ucd_line_break.getLineBreakClass(cp);
}

/// Line break opportunity type
pub const BreakOpportunity = enum {
    /// No break allowed at this position
    no_break,
    /// Break allowed at this position
    allowed,
    /// Break required at this position (e.g., after newline)
    mandatory,
};

/// Finds line break opportunities in text
/// Returns an iterator that yields (byte_position, break_type) pairs
pub fn lineBreakIterator(text: []const u8) LineBreakIterator {
    return LineBreakIterator.init(text);
}

/// Iterator over line break opportunities
pub const LineBreakIterator = struct {
    text: []const u8,
    pos: usize,
    prev_class: ?LineBreakClass,

    /// Creates a new line break opportunity iterator over the given UTF-8 text.
    pub fn init(text: []const u8) LineBreakIterator {
        return .{
            .text = text,
            .pos = 0,
            .prev_class = null,
        };
    }

    /// Returns the next break opportunity: (byte_position, break_type)
    pub fn next(self: *LineBreakIterator) ?struct { pos: usize, opportunity: BreakOpportunity } {
        if (self.pos >= self.text.len) return null;

        var iter = std.unicode.Utf8Iterator{ .bytes = self.text, .i = self.pos };

        while (iter.nextCodepoint()) |cp| {
            const curr_class = getLineBreakClass(cp);
            const byte_pos = iter.i;

            defer {
                self.pos = byte_pos;
                self.prev_class = curr_class;
            }

            if (self.prev_class) |prev| {
                const opportunity = classifyBreak(prev, curr_class);
                if (opportunity != .no_break) {
                    return .{ .pos = self.pos, .opportunity = opportunity };
                }
            }
        }

        self.pos = self.text.len;
        return null;
    }

    /// Classify break opportunity between two classes using simplified UAX #14 rules
    fn classifyBreak(before: LineBreakClass, after: LineBreakClass) BreakOpportunity {
        // LB3: Always break at end of text (handled by caller)

        // LB4: Always break after hard line breaks
        if (before == .BK) return .mandatory;

        // LB5: Treat CR followed by LF as a single unit
        if (before == .CR and after == .LF) return .no_break;
        if (before == .CR or before == .LF or before == .NL) return .mandatory;

        // LB6: Do not break before hard line breaks
        if (after == .BK or after == .CR or after == .LF or after == .NL) return .no_break;

        // LB7: Do not break before spaces or zero width space
        if (after == .SP or after == .ZW) return .no_break;

        // LB8: Break before any character following zero-width space
        if (before == .ZW) return .allowed;

        // LB11: Do not break before or after Word joiner
        if (before == .WJ or after == .WJ) return .no_break;

        // LB12: Do not break after NBSP and related characters
        if (before == .GL) return .no_break;

        // LB13: Do not break before close punctuation
        if (after == .CL or after == .CP or after == .EX or after == .IS or after == .SY) {
            return .no_break;
        }

        // LB14: Do not break after opening punctuation
        if (before == .OP) return .no_break;

        // LB15: Do not break within quotation marks
        if (before == .QU and after == .OP) return .no_break;

        // LB16: Do not break between closing punctuation and nonstarter
        if ((before == .CL or before == .CP) and after == .NS) return .no_break;

        // LB17: Do not break within certain number sequences
        if (before == .B2 and after == .B2) return .no_break;

        // LB18: Break after spaces
        if (before == .SP) return .allowed;

        // LB19: Do not break before or after quotation marks
        if (before == .QU or after == .QU) return .no_break;

        // LB21: Do not break before hyphen-minus, other hyphens
        if (after == .BA or after == .HY or after == .NS) return .no_break;
        if (before == .BB) return .no_break;

        // LB22: Do not break between two ellipses or between digits and ellipsis
        if (after == .IN) return .no_break;

        // LB23: Do not break between digits and letters
        if ((before == .AL or before == .HL) and after == .NU) return .no_break;
        if (before == .NU and (after == .AL or after == .HL)) return .no_break;

        // LB24: Do not break between prefix and letters/ideographs
        if (before == .PR and (after == .AL or after == .HL)) return .no_break;
        if ((before == .AL or before == .HL) and after == .PO) return .no_break;

        // LB25: Number-related rules
        if (before == .CL and after == .PO) return .no_break;
        if (before == .CL and after == .PR) return .no_break;
        if (before == .NU and after == .PO) return .no_break;
        if (before == .NU and after == .PR) return .no_break;
        if (before == .PO and after == .OP) return .no_break;
        if (before == .PO and after == .NU) return .no_break;
        if (before == .PR and after == .OP) return .no_break;
        if (before == .PR and after == .NU) return .no_break;
        if (before == .HY and after == .NU) return .no_break;
        if (before == .IS and after == .NU) return .no_break;
        if (before == .NU and after == .NU) return .no_break;
        if (before == .SY and after == .NU) return .no_break;

        // LB26: Korean syllable blocks
        if (before == .JL and (after == .JL or after == .JV or after == .H2 or after == .H3)) {
            return .no_break;
        }
        if ((before == .JV or before == .H2) and (after == .JV or after == .JT)) {
            return .no_break;
        }
        if ((before == .JT or before == .H3) and after == .JT) return .no_break;

        // LB27: Treat Korean characters like AL
        if ((before == .JL or before == .JV or before == .JT or before == .H2 or before == .H3) and after == .PO) {
            return .no_break;
        }
        if (before == .PR and (after == .JL or after == .JV or after == .JT or after == .H2 or after == .H3)) {
            return .no_break;
        }

        // LB28: Do not break between alphabetics
        if ((before == .AL or before == .HL) and (after == .AL or after == .HL)) {
            return .no_break;
        }

        // LB29: Do not break between numeric punctuation and alphabetics
        if (before == .IS and (after == .AL or after == .HL)) return .no_break;

        // LB30: Do not break between letters, numbers, or ordinary symbols and opening/closing
        if ((before == .AL or before == .HL or before == .NU) and after == .OP) {
            return .no_break;
        }
        if (before == .CP and (after == .AL or after == .HL or after == .NU)) {
            return .no_break;
        }

        // LB31: Break everywhere else
        return .allowed;
    }
};

/// Finds all valid line break positions in text
pub fn findLineBreaks(allocator: std.mem.Allocator, text: []const u8) ![]usize {
    var breaks: std.ArrayList(usize) = .empty;
    errdefer breaks.deinit(allocator);
    // Heuristic: roughly 1 break opportunity per 5 bytes (word boundaries).
    try breaks.ensureTotalCapacity(allocator, if (text.len > 0) text.len / 5 + 1 else 1);

    var iter = lineBreakIterator(text);
    while (iter.next()) |brk| {
        if (brk.opportunity != .no_break) {
            try breaks.append(allocator, brk.pos);
        }
    }

    return breaks.toOwnedSlice(allocator);
}

test "line break class - basic" {
    const testing = std.testing;

    // Space
    try testing.expectEqual(LineBreakClass.SP, getLineBreakClass(' '));

    // Alphabetic
    try testing.expectEqual(LineBreakClass.AL, getLineBreakClass('A'));

    // Numeric
    try testing.expectEqual(LineBreakClass.NU, getLineBreakClass('0'));

    // Line feed
    try testing.expectEqual(LineBreakClass.LF, getLineBreakClass('\n'));

    // Carriage return
    try testing.expectEqual(LineBreakClass.CR, getLineBreakClass('\r'));
}

test "line break - simple text" {
    const testing = std.testing;

    const breaks = try findLineBreaks(testing.allocator, "Hello World");
    defer testing.allocator.free(breaks);

    // Should have a break opportunity after "Hello " (before "World")
    try testing.expect(breaks.len >= 1);
}
