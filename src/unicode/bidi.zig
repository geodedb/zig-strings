// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Basic BiDi Direction Detection
//!
//! This module provides basic bidirectional text handling for Unicode,
//! including detection of text direction, BiDi properties, and identification
//! of dangerous BiDi override/isolate characters (U+202A-U+202E, U+2066-U+2069).
//!
//! Note: This is NOT a full UAX #9 implementation. It provides direction detection
//! and simple run analysis but does not implement the full Bidirectional Algorithm.

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

/// Checks if a codepoint is a BiDi override or isolate character.
/// These characters (U+202A-U+202E, U+2066-U+2069) can be used for
/// text spoofing attacks (e.g., CVE-2021-42574 "Trojan Source").
fn isBidiOverride(cp: u21) bool {
    return switch (cp) {
        // BiDi embedding and override characters
        0x202A, // LEFT-TO-RIGHT EMBEDDING (LRE)
        0x202B, // RIGHT-TO-LEFT EMBEDDING (RLE)
        0x202C, // POP DIRECTIONAL FORMATTING (PDF)
        0x202D, // LEFT-TO-RIGHT OVERRIDE (LRO)
        0x202E, // RIGHT-TO-LEFT OVERRIDE (RLO)
        // BiDi isolate characters
        0x2066, // LEFT-TO-RIGHT ISOLATE (LRI)
        0x2067, // RIGHT-TO-LEFT ISOLATE (RLI)
        0x2068, // FIRST STRONG ISOLATE (FSI)
        0x2069, // POP DIRECTIONAL ISOLATE (PDI)
        => true,
        else => false,
    };
}

/// Checks if a codepoint is an invisible BiDi directional mark.
/// These marks (LRM U+200E, RLM U+200F, ALM U+061C) are zero-width
/// characters that influence text direction without visible output.
/// They can be used in spoofing attacks (e.g., homograph attacks,
/// filename/URL manipulation) to make text appear different from
/// its logical order.
fn isBidiMark(cp: u21) bool {
    return switch (cp) {
        0x200E, // LEFT-TO-RIGHT MARK (LRM)
        0x200F, // RIGHT-TO-LEFT MARK (RLM)
        0x061C, // ARABIC LETTER MARK (ALM)
        => true,
        else => false,
    };
}

/// Checks if a codepoint is any suspicious BiDi character -- either an
/// override/isolate (U+202A-U+202E, U+2066-U+2069) or an invisible
/// directional mark (LRM U+200E, RLM U+200F, ALM U+061C).
fn isSuspiciousBidiChar(cp: u21) bool {
    return isBidiOverride(cp) or isBidiMark(cp);
}

/// Checks if text contains any suspicious BiDi characters, including both
/// override/isolate characters (U+202A-U+202E, U+2066-U+2069) and invisible
/// directional marks (LRM U+200E, RLM U+200F, ALM U+061C).
/// These characters can be used for text spoofing attacks such as
/// "Trojan Source" (CVE-2021-42574) or homograph/filename manipulation.
pub fn containsSuspiciousBidiChars(text: []const u8) bool {
    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        if (isSuspiciousBidiChar(cp)) return true;
    }
    return false;
}

/// Checks if text contains any BiDi override or isolate characters
/// (U+202A-U+202E, U+2066-U+2069) that could be used for text spoofing.
/// These characters are used in "Trojan Source" attacks (CVE-2021-42574)
/// to make source code appear different from how it is compiled/interpreted.
pub fn containsBidiOverrides(text: []const u8) bool {
    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        if (isBidiOverride(cp)) return true;
    }
    return false;
}

/// Removes all suspicious BiDi characters -- overrides, isolates
/// (U+202A-U+202E, U+2066-U+2069) and invisible directional marks
/// (LRM U+200E, RLM U+200F, ALM U+061C) -- from the input text,
/// returning a newly allocated string.
/// Caller owns the returned memory and must free it with the same allocator.
pub fn stripBidiOverrides(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);
    // Most characters are kept; pre-allocate for the full input length.
    try result.ensureTotalCapacity(allocator, text.len);

    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    var prev_i: usize = 0;
    while (iter.nextCodepoint()) |cp| {
        if (isSuspiciousBidiChar(cp)) {
            // Append everything before this codepoint
            const cp_len = std.unicode.utf8CodepointSequenceLength(cp) catch 1;
            const cp_start = iter.i - cp_len;
            if (cp_start > prev_i) {
                try result.appendSlice(allocator, text[prev_i..cp_start]);
            }
            prev_i = iter.i;
        }
    }

    // Append remaining text after last override
    if (prev_i < text.len) {
        try result.appendSlice(allocator, text[prev_i..text.len]);
    }

    return result.toOwnedSlice(allocator);
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
    // Heuristic: most text has few direction changes; allocate a modest amount.
    try runs.ensureTotalCapacity(allocator, if (text.len > 0) text.len / 16 + 1 else 1);

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

test "bidi - isBidiOverride" {
    const testing = std.testing;

    // Override/isolate characters
    try testing.expect(isBidiOverride(0x202A)); // LRE
    try testing.expect(isBidiOverride(0x202B)); // RLE
    try testing.expect(isBidiOverride(0x202C)); // PDF
    try testing.expect(isBidiOverride(0x202D)); // LRO
    try testing.expect(isBidiOverride(0x202E)); // RLO
    try testing.expect(isBidiOverride(0x2066)); // LRI
    try testing.expect(isBidiOverride(0x2067)); // RLI
    try testing.expect(isBidiOverride(0x2068)); // FSI
    try testing.expect(isBidiOverride(0x2069)); // PDI

    // Normal characters should not match
    try testing.expect(!isBidiOverride('A'));
    try testing.expect(!isBidiOverride(0x0627)); // Arabic alef
    try testing.expect(!isBidiOverride(0x2029)); // Just before range
    try testing.expect(!isBidiOverride(0x202F)); // Just after first range
    try testing.expect(!isBidiOverride(0x2065)); // Just before second range
    try testing.expect(!isBidiOverride(0x206A)); // Just after second range
}

test "bidi - containsBidiOverrides" {
    const testing = std.testing;

    // Clean text should return false
    try testing.expect(!containsBidiOverrides("Hello World"));
    try testing.expect(!containsBidiOverrides("שלום"));
    try testing.expect(!containsBidiOverrides(""));

    // RLO (U+202E) embedded in text
    try testing.expect(containsBidiOverrides("Hello\xe2\x80\xaeWorld"));
    // LRI (U+2066) embedded in text
    try testing.expect(containsBidiOverrides("Hello\xe2\x81\xa6World"));
    // PDI (U+2069) embedded in text
    try testing.expect(containsBidiOverrides("Hello\xe2\x81\xa9World"));
    // RLE (U+202B) at start
    try testing.expect(containsBidiOverrides("\xe2\x80\xabHello"));
}

test "bidi - stripBidiOverrides" {
    const testing = std.testing;

    // Clean text is unchanged
    {
        const result = try stripBidiOverrides(testing.allocator, "Hello World");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("Hello World", result);
    }

    // Empty text
    {
        const result = try stripBidiOverrides(testing.allocator, "");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("", result);
    }

    // Strip RLO (U+202E)
    {
        const result = try stripBidiOverrides(testing.allocator, "Hello\xe2\x80\xaeWorld");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("HelloWorld", result);
    }

    // Strip multiple overrides
    {
        const result = try stripBidiOverrides(testing.allocator, "\xe2\x80\xabHello\xe2\x80\xaeWorld\xe2\x81\xa9");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("HelloWorld", result);
    }

    // Strip from text that also contains normal multi-byte characters
    {
        const result = try stripBidiOverrides(testing.allocator, "Hello\xe2\x80\xae שלום");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("Hello שלום", result);
    }

    // Strip LRM (U+200E) mark
    {
        const result = try stripBidiOverrides(testing.allocator, "Hello\xe2\x80\x8eWorld");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("HelloWorld", result);
    }

    // Strip RLM (U+200F) mark
    {
        const result = try stripBidiOverrides(testing.allocator, "Hello\xe2\x80\x8fWorld");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("HelloWorld", result);
    }

    // Strip ALM (U+061C) mark
    {
        const result = try stripBidiOverrides(testing.allocator, "Hello\xd8\x9cWorld");
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("HelloWorld", result);
    }
}

test "bidi - isBidiMark" {
    const testing = std.testing;

    // Directional marks
    try testing.expect(isBidiMark(0x200E)); // LRM
    try testing.expect(isBidiMark(0x200F)); // RLM
    try testing.expect(isBidiMark(0x061C)); // ALM

    // Normal characters should not match
    try testing.expect(!isBidiMark('A'));
    try testing.expect(!isBidiMark(0x0627)); // Arabic alef
    try testing.expect(!isBidiMark(0x200D)); // ZWJ (not a bidi mark)
    try testing.expect(!isBidiMark(0x2010)); // Hyphen (not a bidi mark)

    // Overrides are not marks
    try testing.expect(!isBidiMark(0x202A)); // LRE
    try testing.expect(!isBidiMark(0x202E)); // RLO
}

test "bidi - containsSuspiciousBidiChars" {
    const testing = std.testing;

    // Clean text should return false
    try testing.expect(!containsSuspiciousBidiChars("Hello World"));
    try testing.expect(!containsSuspiciousBidiChars("שלום"));
    try testing.expect(!containsSuspiciousBidiChars(""));

    // Override characters (same as containsBidiOverrides)
    try testing.expect(containsSuspiciousBidiChars("Hello\xe2\x80\xaeWorld")); // RLO
    try testing.expect(containsSuspiciousBidiChars("\xe2\x80\xabHello")); // RLE

    // LRM (U+200E) - UTF-8: 0xE2 0x80 0x8E
    try testing.expect(containsSuspiciousBidiChars("Hello\xe2\x80\x8eWorld"));

    // RLM (U+200F) - UTF-8: 0xE2 0x80 0x8F
    try testing.expect(containsSuspiciousBidiChars("Hello\xe2\x80\x8fWorld"));

    // ALM (U+061C) - UTF-8: 0xD8 0x9C
    try testing.expect(containsSuspiciousBidiChars("Hello\xd8\x9cWorld"));

    // Multiple marks in text
    try testing.expect(containsSuspiciousBidiChars("\xe2\x80\x8eHello\xe2\x80\x8fWorld"));
}
