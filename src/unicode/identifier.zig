// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode Identifier Syntax (UAX #31)
//!
//! This module provides Unicode identifier validation following UAX #31.
//! It supports XID_Start and XID_Continue properties for identifier parsing.

const std = @import("std");
const types = @import("types");
const ucd_identifier = @import("ucd_identifier");

pub const Codepoint = types.Codepoint;

/// Checks if a code point has the XID_Start property
/// XID_Start characters can begin an identifier
pub fn isXidStart(cp: Codepoint) bool {
    return ucd_identifier.isXidStart(cp);
}

/// Checks if a code point has the XID_Continue property
/// XID_Continue characters can continue an identifier
pub fn isXidContinue(cp: Codepoint) bool {
    return ucd_identifier.isXidContinue(cp);
}

/// Checks if a string is a valid Unicode identifier (UAX #31 Default Identifier)
pub fn isValidIdentifier(text: []const u8) bool {
    return ucd_identifier.isValidIdentifier(text);
}

/// Checks if a string starts with a valid identifier character
pub fn startsWithIdentifier(text: []const u8) bool {
    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    const first = iter.nextCodepoint() orelse return false;
    return isXidStart(first);
}

/// Gets the length of the identifier at the start of the text
/// Returns 0 if text doesn't start with a valid identifier
pub fn identifierLength(text: []const u8) usize {
    if (text.len == 0) return 0;

    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };

    // First character must be XID_Start
    const first = iter.nextCodepoint() orelse return 0;
    if (!isXidStart(first)) return 0;

    // Continue with XID_Continue
    while (iter.nextCodepoint()) |cp| {
        if (!isXidContinue(cp)) {
            return iter.i - (std.unicode.utf8CodepointSequenceLength(cp) catch 1);
        }
    }

    return text.len;
}

/// Extracts the identifier at the start of text
/// Returns null if text doesn't start with a valid identifier
pub fn extractIdentifier(text: []const u8) ?[]const u8 {
    const len = identifierLength(text);
    return if (len > 0) text[0..len] else null;
}

/// Validates and normalizes an identifier
/// Returns error if the identifier is invalid
pub fn validateIdentifier(text: []const u8) !void {
    if (!isValidIdentifier(text)) {
        return error.InvalidIdentifier;
    }
}

/// Checks if text is a valid C-style identifier (ASCII only)
pub fn isAsciiIdentifier(text: []const u8) bool {
    if (text.len == 0) return false;

    // First character: letter or underscore
    const first = text[0];
    if (!std.ascii.isAlphabetic(first) and first != '_') {
        return false;
    }

    // Remaining: letter, digit, or underscore
    for (text[1..]) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') {
            return false;
        }
    }

    return true;
}

/// Identifier type classification
pub const IdentifierType = enum {
    /// Not a valid identifier
    invalid,
    /// ASCII-only identifier (traditional C-style)
    ascii,
    /// Unicode identifier (UAX #31 compliant)
    unicode,
    /// Mixed ASCII and Unicode
    mixed,
};

/// Classifies the type of identifier
pub fn classifyIdentifier(text: []const u8) IdentifierType {
    if (!isValidIdentifier(text)) {
        return .invalid;
    }

    var has_non_ascii = false;
    for (text) |byte| {
        if (byte >= 0x80) {
            has_non_ascii = true;
            break;
        }
    }

    if (!has_non_ascii) {
        return .ascii;
    }

    // Check if it would also be valid ASCII identifier
    if (isAsciiIdentifier(text)) {
        return .mixed; // This shouldn't happen for pure ASCII
    }

    return .unicode;
}

/// Finds all identifiers in text
pub fn findIdentifiers(allocator: std.mem.Allocator, text: []const u8) ![][]const u8 {
    var identifiers: std.ArrayList([]const u8) = .empty;
    errdefer identifiers.deinit(allocator);
    // Heuristic: assume roughly 1 identifier per 8 bytes of text.
    try identifiers.ensureTotalCapacity(allocator, if (text.len > 0) text.len / 8 + 1 else 1);

    var pos: usize = 0;
    while (pos < text.len) {
        // Skip non-identifier characters
        var iter = std.unicode.Utf8Iterator{ .bytes = text[pos..], .i = 0 };
        while (iter.nextCodepoint()) |cp| {
            if (isXidStart(cp)) {
                break;
            }
            pos += std.unicode.utf8CodepointSequenceLength(cp) catch 1;
        }

        if (pos >= text.len) break;

        // Extract identifier
        if (extractIdentifier(text[pos..])) |id| {
            try identifiers.append(allocator, id);
            pos += id.len;
        } else {
            pos += 1;
        }
    }

    return identifiers.toOwnedSlice(allocator);
}

test "identifier - XID properties" {
    const testing = std.testing;

    // ASCII letters
    try testing.expect(isXidStart('A'));
    try testing.expect(isXidStart('z'));
    try testing.expect(isXidContinue('A'));
    try testing.expect(isXidContinue('z'));

    // Digits
    try testing.expect(!isXidStart('0'));
    try testing.expect(isXidContinue('0'));

    // Underscore - NOT XID_Start in Unicode, but IS XID_Continue
    // (Many programming languages extend XID_Start to include underscore)
    try testing.expect(!isXidStart('_'));
    try testing.expect(isXidContinue('_'));

    // Greek letters
    try testing.expect(isXidStart(0x03B1)); // α (alpha)
    try testing.expect(isXidContinue(0x03B1));

    // CJK
    try testing.expect(isXidStart(0x4E00)); // 一 (one)
    try testing.expect(isXidContinue(0x4E00));

    // Combining marks (not XID_Start but XID_Continue)
    try testing.expect(!isXidStart(0x0301)); // Combining acute
    try testing.expect(isXidContinue(0x0301));
}

test "identifier - validation" {
    const testing = std.testing;

    try testing.expect(isValidIdentifier("hello"));
    try testing.expect(isValidIdentifier("camelCase123"));
    try testing.expect(isValidIdentifier("αβγ")); // Greek
    try testing.expect(isValidIdentifier("変数")); // Japanese
    try testing.expect(isValidIdentifier("a_b")); // Underscore in middle is fine

    // Underscore at start is NOT valid per strict UAX #31
    // (but many languages extend this)
    try testing.expect(!isValidIdentifier("_private"));

    try testing.expect(!isValidIdentifier("")); // Empty
    try testing.expect(!isValidIdentifier("123abc")); // Starts with digit
    try testing.expect(!isValidIdentifier("hello world")); // Contains space
    try testing.expect(!isValidIdentifier("a+b")); // Contains operator
}

test "identifier - extraction" {
    const testing = std.testing;

    try testing.expectEqualStrings("hello", extractIdentifier("hello world").?);
    try testing.expectEqualStrings("foo123", extractIdentifier("foo123+bar").?);
    try testing.expectEqual(@as(?[]const u8, null), extractIdentifier("123abc"));
    try testing.expectEqual(@as(?[]const u8, null), extractIdentifier("+abc"));
}

test "identifier - classification" {
    const testing = std.testing;

    try testing.expectEqual(IdentifierType.ascii, classifyIdentifier("hello_world"));
    try testing.expectEqual(IdentifierType.unicode, classifyIdentifier("αβγ"));
    try testing.expectEqual(IdentifierType.invalid, classifyIdentifier("123"));
    try testing.expectEqual(IdentifierType.invalid, classifyIdentifier(""));
}
