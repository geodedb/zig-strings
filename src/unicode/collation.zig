// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode collation (UTS #10).
//!
//! This module provides Unicode Collation Algorithm (UCA) support for
//! locale-aware string comparison and sorting.
//!
//! Note: This is a simplified collation implementation covering ASCII and
//! Latin-1 characters only. Non-Latin text (e.g., CJK, Arabic, Cyrillic
//! beyond basic mappings) falls back to raw codepoint ordering rather than
//! proper DUCET (Default Unicode Collation Element Table) weights. This is
//! not a complete UTS #10 implementation.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const categories = @import("categories");
const normalization = @import("normalization");

pub const Codepoint = types.Codepoint;

/// Collation strength levels
pub const Strength = enum {
    /// Primary: Base character differences (a vs b)
    primary,
    /// Secondary: Accent differences (a vs á)
    secondary,
    /// Tertiary: Case differences (a vs A)
    tertiary,
    /// Quaternary: Punctuation differences
    quaternary,
    /// Identical: Code point differences
    identical,
};

/// Collation options
pub const CollationOptions = struct {
    /// Comparison strength
    strength: Strength = .tertiary,
    /// Case-first ordering (upper before lower or vice versa)
    case_first: CaseFirst = .off,
    /// Ignore punctuation
    alternate: Alternate = .non_ignorable,
    /// Normalize before comparison
    normalize: bool = true,
};

/// Case ordering preference
pub const CaseFirst = enum {
    off,
    upper_first,
    lower_first,
};

/// Alternate handling for variable characters
pub const Alternate = enum {
    non_ignorable,
    shifted,
};

/// Collation element (simplified)
pub const CollationElement = struct {
    primary: u16,
    secondary: u16,
    tertiary: u16,
};

/// Gets the collation elements for a code point (simplified DUCET mapping)
pub fn getCollationElement(cp: Codepoint) CollationElement {
    // Simplified implementation - full UCA would use DUCET (Default Unicode Collation Element Table)

    // ASCII letters
    if (cp >= 'A' and cp <= 'Z') {
        return .{
            .primary = @truncate(0x0F00 + (cp - 'A')),
            .secondary = 0x0020,
            .tertiary = 0x0008, // Uppercase
        };
    }
    if (cp >= 'a' and cp <= 'z') {
        return .{
            .primary = @truncate(0x0F00 + (cp - 'a')),
            .secondary = 0x0020,
            .tertiary = 0x0002, // Lowercase
        };
    }

    // ASCII digits
    if (cp >= '0' and cp <= '9') {
        return .{
            .primary = @truncate(0x0E00 + (cp - '0')),
            .secondary = 0x0020,
            .tertiary = 0x0002,
        };
    }

    // Space and punctuation - variable weight
    if (cp == ' ') {
        return .{
            .primary = 0x0209,
            .secondary = 0x0020,
            .tertiary = 0x0002,
        };
    }

    // Accented Latin letters (simplified)
    // á, à, â, ä, etc. have same primary as 'a'
    const base = getBaseCharacter(cp);
    if (base != cp and base >= 'a' and base <= 'z') {
        return .{
            .primary = @truncate(0x0F00 + (base - 'a')),
            .secondary = getAccentWeight(cp),
            .tertiary = 0x0002,
        };
    }
    if (base != cp and base >= 'A' and base <= 'Z') {
        return .{
            .primary = @truncate(0x0F00 + (base - 'A')),
            .secondary = getAccentWeight(cp),
            .tertiary = 0x0008,
        };
    }

    // Default: use code point as primary
    return .{
        .primary = @truncate(cp),
        .secondary = 0x0020,
        .tertiary = 0x0002,
    };
}

/// Gets the base character (strips accents) - simplified
fn getBaseCharacter(cp: Codepoint) Codepoint {
    return switch (cp) {
        // Lowercase accented
        0x00E0...0x00E5 => 'a', // à á â ã ä å
        0x00E7 => 'c', // ç
        0x00E8...0x00EB => 'e', // è é ê ë
        0x00EC...0x00EF => 'i', // ì í î ï
        0x00F1 => 'n', // ñ
        0x00F2...0x00F6 => 'o', // ò ó ô õ ö
        0x00F9...0x00FC => 'u', // ù ú û ü
        0x00FD, 0x00FF => 'y', // ý ÿ

        // Uppercase accented
        0x00C0...0x00C5 => 'A', // À Á Â Ã Ä Å
        0x00C7 => 'C', // Ç
        0x00C8...0x00CB => 'E', // È É Ê Ë
        0x00CC...0x00CF => 'I', // Ì Í Î Ï
        0x00D1 => 'N', // Ñ
        0x00D2...0x00D6 => 'O', // Ò Ó Ô Õ Ö
        0x00D9...0x00DC => 'U', // Ù Ú Û Ü
        0x00DD => 'Y', // Ý

        else => cp,
    };
}

/// Gets accent weight for secondary comparison
fn getAccentWeight(cp: Codepoint) u16 {
    // Simplified - just distinguish some common accents
    return switch (cp) {
        0x00E0, 0x00C0 => 0x0025, // grave
        0x00E1, 0x00C1 => 0x0024, // acute
        0x00E2, 0x00C2 => 0x0026, // circumflex
        0x00E3, 0x00C3 => 0x0027, // tilde
        0x00E4, 0x00C4 => 0x0028, // diaeresis
        0x00E5, 0x00C5 => 0x0029, // ring
        0x00E7, 0x00C7 => 0x002A, // cedilla
        else => 0x0020, // no accent
    };
}

/// Compares two code points for collation
fn compareElements(a: CollationElement, b: CollationElement, strength: Strength) std.math.Order {
    // Primary comparison
    if (a.primary != b.primary) {
        return std.math.order(a.primary, b.primary);
    }

    if (strength == .primary) return .eq;

    // Secondary comparison
    if (a.secondary != b.secondary) {
        return std.math.order(a.secondary, b.secondary);
    }

    if (strength == .secondary) return .eq;

    // Tertiary comparison
    if (a.tertiary != b.tertiary) {
        return std.math.order(a.tertiary, b.tertiary);
    }

    return .eq;
}

/// Compares two UTF-8 strings using Unicode collation
pub fn compare(a: []const u8, b: []const u8, options: CollationOptions) std.math.Order {
    var iter_a = std.unicode.Utf8Iterator{ .bytes = a, .i = 0 };
    var iter_b = std.unicode.Utf8Iterator{ .bytes = b, .i = 0 };

    // Collect collation elements
    while (true) {
        const cp_a = iter_a.nextCodepoint();
        const cp_b = iter_b.nextCodepoint();

        if (cp_a == null and cp_b == null) {
            return .eq;
        }

        if (cp_a == null) return .lt;
        if (cp_b == null) return .gt;

        const elem_a = getCollationElement(cp_a.?);
        const elem_b = getCollationElement(cp_b.?);

        const cmp = compareElements(elem_a, elem_b, options.strength);
        if (cmp != .eq) return cmp;
    }
}

/// Checks if two strings are equal under collation rules
pub fn equals(a: []const u8, b: []const u8, options: CollationOptions) bool {
    return compare(a, b, options) == .eq;
}

/// Gets a sort key for a string (for efficient repeated comparisons)
pub fn getSortKey(allocator: std.mem.Allocator, str: []const u8, options: CollationOptions) ![]u8 {
    const strength = options.strength;
    const need_secondary = @intFromEnum(strength) >= @intFromEnum(Strength.secondary);
    const need_tertiary = @intFromEnum(strength) >= @intFromEnum(Strength.tertiary);

    // Single pass: collect all weight levels simultaneously
    // Pre-allocate based on input byte length as upper-bound estimate of codepoint count.
    // Primary weights use 2 bytes per codepoint; secondary and tertiary use 1 byte each.
    var primary_weights: std.ArrayList(u8) = .empty;
    defer primary_weights.deinit(allocator);
    try primary_weights.ensureTotalCapacity(allocator, str.len * 2);
    var secondary_weights: std.ArrayList(u8) = .empty;
    defer secondary_weights.deinit(allocator);
    if (need_secondary) try secondary_weights.ensureTotalCapacity(allocator, str.len);
    var tertiary_weights: std.ArrayList(u8) = .empty;
    defer tertiary_weights.deinit(allocator);
    if (need_tertiary) try tertiary_weights.ensureTotalCapacity(allocator, str.len);

    var iter = std.unicode.Utf8Iterator{ .bytes = str, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        const elem = getCollationElement(cp);
        if (elem.primary != 0) {
            try primary_weights.append(allocator, @truncate(elem.primary >> 8));
            try primary_weights.append(allocator, @truncate(elem.primary & 0xFF));
        }
        if (need_secondary and elem.secondary != 0x0020) {
            try secondary_weights.append(allocator, @truncate(elem.secondary & 0xFF));
        }
        if (need_tertiary) {
            try tertiary_weights.append(allocator, @truncate(elem.tertiary & 0xFF));
        }
    }

    // Build the final key: primary [+ separator + secondary [+ separator + tertiary]]
    var key: std.ArrayList(u8) = .empty;
    errdefer key.deinit(allocator);

    const secondary_len: usize = if (need_secondary) 1 + secondary_weights.items.len else 0;
    const tertiary_len: usize = if (need_tertiary) 1 + tertiary_weights.items.len else 0;
    const total_len = primary_weights.items.len + secondary_len + tertiary_len;
    try key.ensureTotalCapacity(allocator, total_len);

    key.appendSliceAssumeCapacity(primary_weights.items);

    if (need_secondary) {
        key.appendAssumeCapacity(0); // Separator
        key.appendSliceAssumeCapacity(secondary_weights.items);
    }

    if (need_tertiary) {
        key.appendAssumeCapacity(0); // Separator
        key.appendSliceAssumeCapacity(tertiary_weights.items);
    }

    return key.toOwnedSlice(allocator);
}

test "basic collation" {
    const testing = std.testing;

    const options = CollationOptions{};

    // Same strings
    try testing.expectEqual(std.math.Order.eq, compare("hello", "hello", options));

    // Different strings
    try testing.expectEqual(std.math.Order.lt, compare("apple", "banana", options));
    try testing.expectEqual(std.math.Order.gt, compare("zebra", "apple", options));
}

test "case sensitivity" {
    const testing = std.testing;

    // Tertiary strength distinguishes case
    const tertiary = CollationOptions{ .strength = .tertiary };
    try testing.expect(compare("a", "A", tertiary) != .eq);

    // Primary strength ignores case
    const primary = CollationOptions{ .strength = .primary };
    try testing.expectEqual(std.math.Order.eq, compare("a", "A", primary));
}

test "accent sensitivity" {
    const testing = std.testing;

    // Secondary strength distinguishes accents
    const secondary = CollationOptions{ .strength = .secondary };
    try testing.expect(compare("cafe", "caf\xC3\xA9", secondary) != .eq);

    // Primary strength ignores accents
    const primary = CollationOptions{ .strength = .primary };
    try testing.expectEqual(std.math.Order.eq, compare("cafe", "caf\xC3\xA9", primary));
}

test "sort key" {
    const testing = std.testing;

    const options = CollationOptions{};

    const key1 = try getSortKey(testing.allocator, "apple", options);
    defer testing.allocator.free(key1);

    const key2 = try getSortKey(testing.allocator, "banana", options);
    defer testing.allocator.free(key2);

    // Keys should compare same as strings
    try testing.expect(std.mem.lessThan(u8, key1, key2));
}
