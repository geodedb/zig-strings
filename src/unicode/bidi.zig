// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode Bidirectional Algorithm (UAX #9)
//!
//! This module provides bidirectional text handling for Unicode.
//! It supports detection of text direction and basic BiDi properties.

const std = @import("std");
const types = @import("types");
const ucd_bidi = @import("ucd_bidi");

pub const Codepoint = types.Codepoint;

/// Unicode Bidirectional Character Types
pub const BidiClass = ucd_bidi.BidiClass;

/// Gets the Bidi Class for a code point
pub fn getBidiClass(cp: Codepoint) BidiClass {
    return ucd_bidi.getBidiClass(cp);
}

/// Checks if a bidi class is a strong type (L, R, AL)
pub fn isStrong(class: BidiClass) bool {
    return ucd_bidi.isStrong(class);
}

/// Checks if a bidi class is right-to-left (R, AL)
pub fn isRightToLeft(class: BidiClass) bool {
    return ucd_bidi.isRightToLeft(class);
}

/// Text direction
pub const Direction = enum {
    left_to_right,
    right_to_left,
    neutral,
};

/// Gets the base direction for a string (first strong character)
/// Returns null if no strong character is found
pub fn getBaseDirection(text: []const u8) ?Direction {
    if (ucd_bidi.getBaseDirection(text)) |class| {
        return if (isRightToLeft(class)) .right_to_left else .left_to_right;
    }
    return null;
}

/// Gets the paragraph direction with a default
pub fn getParagraphDirection(text: []const u8, default: Direction) Direction {
    return getBaseDirection(text) orelse default;
}

/// Checks if text is purely left-to-right
pub fn isLeftToRight(text: []const u8) bool {
    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        const class = getBidiClass(cp);
        if (isRightToLeft(class)) {
            return false;
        }
    }
    return true;
}

/// Checks if text is purely right-to-left
pub fn isPureRightToLeft(text: []const u8) bool {
    var has_rtl = false;
    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        const class = getBidiClass(cp);
        if (class == .L) {
            return false;
        }
        if (isRightToLeft(class)) {
            has_rtl = true;
        }
    }
    return has_rtl;
}

/// Checks if text contains any right-to-left characters
pub fn containsRightToLeft(text: []const u8) bool {
    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        if (isRightToLeft(getBidiClass(cp))) {
            return true;
        }
    }
    return false;
}

/// Checks if text is bidirectional (contains both LTR and RTL)
pub fn isBidirectional(text: []const u8) bool {
    var has_ltr = false;
    var has_rtl = false;

    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        const class = getBidiClass(cp);
        if (class == .L) {
            has_ltr = true;
        } else if (isRightToLeft(class)) {
            has_rtl = true;
        }

        if (has_ltr and has_rtl) {
            return true;
        }
    }

    return false;
}

/// BiDi embedding level (0 = LTR, 1 = RTL, etc.)
pub const EmbeddingLevel = u8;

/// Maximum embedding depth per UAX #9
pub const MAX_DEPTH: u8 = 125;

/// Gets the implicit embedding level for a character
pub fn getImplicitLevel(cp: Codepoint) EmbeddingLevel {
    const class = getBidiClass(cp);
    return if (isRightToLeft(class)) 1 else 0;
}

/// Result of BiDi analysis for a run of text
pub const BidiRun = struct {
    start: usize,
    end: usize,
    level: EmbeddingLevel,
    direction: Direction,
};

/// Simple BiDi run detection (without full reordering)
/// Returns runs of consecutive characters with the same directionality
pub fn detectRuns(allocator: std.mem.Allocator, text: []const u8) ![]BidiRun {
    var runs: std.ArrayList(BidiRun) = .empty;
    errdefer runs.deinit(allocator);

    if (text.len == 0) return runs.toOwnedSlice(allocator);

    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    var run_start: usize = 0;
    var current_level: EmbeddingLevel = 0;
    var first = true;

    while (iter.nextCodepoint()) |cp| {
        const level = getImplicitLevel(cp);

        if (first) {
            current_level = level;
            first = false;
        } else if (level != current_level) {
            // End current run
            try runs.append(allocator, .{
                .start = run_start,
                .end = iter.i - (std.unicode.utf8CodepointSequenceLength(cp) catch 1),
                .level = current_level,
                .direction = if (current_level % 2 == 0) .left_to_right else .right_to_left,
            });
            run_start = iter.i - (std.unicode.utf8CodepointSequenceLength(cp) catch 1);
            current_level = level;
        }
    }

    // Add final run
    if (!first) {
        try runs.append(allocator, .{
            .start = run_start,
            .end = text.len,
            .level = current_level,
            .direction = if (current_level % 2 == 0) .left_to_right else .right_to_left,
        });
    }

    return runs.toOwnedSlice(allocator);
}

test "bidi class - basic" {
    const testing = std.testing;

    // Latin letters are Left-to-Right
    try testing.expectEqual(BidiClass.L, getBidiClass('A'));
    try testing.expectEqual(BidiClass.L, getBidiClass('z'));

    // Arabic letters are Arabic Letter (Right-to-Left)
    try testing.expectEqual(BidiClass.AL, getBidiClass(0x0627)); // ا (alef)

    // Hebrew letters are Right-to-Left
    try testing.expectEqual(BidiClass.R, getBidiClass(0x05D0)); // א (alef)

    // Numbers are European Number
    try testing.expectEqual(BidiClass.EN, getBidiClass('0'));
}

test "bidi - direction detection" {
    const testing = std.testing;

    try testing.expectEqual(Direction.left_to_right, getBaseDirection("Hello World").?);
    try testing.expectEqual(Direction.right_to_left, getBaseDirection("שלום").?);
    try testing.expectEqual(@as(?Direction, null), getBaseDirection("123")); // No strong characters
}

test "bidi - contains RTL" {
    const testing = std.testing;

    try testing.expect(!containsRightToLeft("Hello World"));
    try testing.expect(containsRightToLeft("Hello שלום"));
    try testing.expect(containsRightToLeft("שלום"));
}

test "bidi - bidirectional text" {
    const testing = std.testing;

    try testing.expect(!isBidirectional("Hello World")); // Only LTR
    try testing.expect(!isBidirectional("שלום")); // Only RTL
    try testing.expect(isBidirectional("Hello שלום")); // Mixed
}
