// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Shared types for the regex engine.
//!
//! This module defines the data structures used across the regex compiler,
//! virtual machine, and public API. It is extracted from `regex.zig` to
//! allow `regex_compiler.zig` and `regex_vm.zig` to share types without
//! circular imports.

const std = @import("std");

/// Regex compilation/runtime errors
pub const RegexError = error{
    InvalidPattern,
    UnmatchedParenthesis,
    UnmatchedBracket,
    InvalidEscape,
    InvalidQuantifier,
    InvalidRange,
    InvalidUnicodeProperty,
    PatternTooComplex,
    OutOfMemory,
};

/// A match result
pub const Match = struct {
    /// Maximum number of capture groups (including group 0 = full match).
    pub const MAX_GROUPS: usize = 32;

    /// The matched slice
    slice: []const u8,
    /// Start byte index in the input
    start: usize,
    /// End byte index in the input (exclusive)
    end: usize,
    /// Number of valid entries in `group_data` (including group 0)
    group_count: usize,
    /// Backing storage for captured groups
    group_data: [MAX_GROUPS]?Group,

    pub const Group = struct {
        slice: []const u8,
        start: usize,
        end: usize,
    };

    /// Captured groups (index 0 is the full match).
    /// Returns a slice of length `group_count`.
    pub fn groups(self: *const Match) []const ?Group {
        return self.group_data[0..self.group_count];
    }
};

/// Compiled instruction opcodes
pub const Opcode = enum(u8) {
    // Matching
    literal, // Match exact byte
    literal_insensitive, // Match byte case-insensitive
    any, // Match any byte (except newline)
    any_all, // Match any byte (including newline)

    // Character classes
    char_class, // Match character class
    // Note: negation is handled by CharClass.negated field; char_class_negated
    // opcode exists for clarity but both are handled identically in the VM
    // (the VM dispatches both to the same handler, which delegates to
    // CharClass.contains() where the .negated field controls the logic).
    char_class_negated, // Match negated character class

    // Predefined classes
    digit, // \d
    not_digit, // \D
    word, // \w
    not_word, // \W
    whitespace, // \s
    not_whitespace, // \S

    // Unicode properties
    unicode_prop, // \p{...}
    unicode_prop_neg, // \P{...}

    // Anchors
    line_start, // ^
    line_end, // $
    word_boundary, // \b
    not_word_boundary, // \B
    input_start, // \A
    input_end, // \z

    // Control flow
    jump, // Unconditional jump
    split, // Fork execution (for alternation/quantifiers)
    save, // Save position for group capture
    match, // Successful match

    // Quantifier helpers
    repeat_greedy, // Greedy repeat
    repeat_lazy, // Lazy repeat
};

/// A compiled instruction
pub const Instruction = struct {
    op: Opcode,
    // Operand data (meaning depends on opcode)
    a: u32 = 0, // Often: jump target, char value, class index
    b: u32 = 0, // Often: secondary jump, max repeat count
};

/// Character class (set of character ranges).
/// Ranges are sorted by `lo` at construction time so that `contains` can
/// use binary search for O(log r) lookups instead of O(r) linear scans.
pub const CharClass = struct {
    ranges: []const Range,
    negated: bool = false,

    pub const Range = struct {
        lo: u21,
        hi: u21,
    };

    /// Threshold below which a linear scan is faster than binary search
    /// due to branch-prediction and cache-line effects on small arrays.
    pub const LINEAR_SCAN_THRESHOLD: usize = 8;

    pub fn contains(self: CharClass, cp: u21) bool {
        const found = if (self.ranges.len <= LINEAR_SCAN_THRESHOLD)
            linearContains(self.ranges, cp)
        else
            binaryContains(self.ranges, cp);
        return if (self.negated) !found else found;
    }

    pub fn linearContains(ranges: []const Range, cp: u21) bool {
        for (ranges) |r| {
            if (cp >= r.lo and cp <= r.hi) {
                return true;
            }
        }
        return false;
    }

    pub fn binaryContains(ranges: []const Range, cp: u21) bool {
        var lo: usize = 0;
        var hi: usize = ranges.len;
        while (lo < hi) {
            const mid = lo + (hi - lo) / 2;
            if (cp > ranges[mid].hi) {
                lo = mid + 1;
            } else if (cp < ranges[mid].lo) {
                hi = mid;
            } else {
                return true; // ranges[mid].lo <= cp <= ranges[mid].hi
            }
        }
        return false;
    }

    /// Sorts ranges by `lo` in-place. Called once at compile time after
    /// all ranges for a character class have been collected.
    pub fn sortRanges(ranges: []Range) void {
        std.sort.block(Range, ranges, {}, struct {
            fn lessThan(_: void, a: Range, b: Range) bool {
                return a.lo < b.lo;
            }
        }.lessThan);
    }
};

/// Regex options
pub const Options = struct {
    /// Case insensitive matching
    case_insensitive: bool = false,
    /// Multiline mode (^ and $ match line boundaries)
    multiline: bool = false,
    /// Dot matches newline
    dot_all: bool = false,
    /// Unicode mode (use Unicode properties)
    unicode: bool = true,
};

/// The compiled representation of a regex pattern, containing the
/// instruction bytecode, character class data, and capture group count.
/// This is the output of the compiler and input to the VM.
pub const CompiledPattern = struct {
    /// Compiled instructions
    code: []Instruction,
    /// Character class data
    char_classes: []const CharClass,
    /// Number of capture groups
    num_groups: u32,
};

// ============================================================
// Tests
// ============================================================

test "P2-15: CharClass.binaryContains correctness" {
    // Direct unit test of the binary search helper
    const Range = CharClass.Range;
    const ranges = [_]Range{
        .{ .lo = 'A', .hi = 'C' },
        .{ .lo = 'M', .hi = 'P' },
        .{ .lo = 'X', .hi = 'Z' },
        .{ .lo = 'a', .hi = 'f' },
        .{ .lo = 'm', .hi = 'r' },
        .{ .lo = 'x', .hi = 'z' },
        .{ .lo = 0x0100, .hi = 0x0105 },
        .{ .lo = 0x0200, .hi = 0x0250 },
        .{ .lo = 0x1000, .hi = 0x1100 },
    };

    // Matches at boundaries and mid-range
    try std.testing.expect(CharClass.binaryContains(&ranges, 'A'));
    try std.testing.expect(CharClass.binaryContains(&ranges, 'B'));
    try std.testing.expect(CharClass.binaryContains(&ranges, 'C'));
    try std.testing.expect(CharClass.binaryContains(&ranges, 'N'));
    try std.testing.expect(CharClass.binaryContains(&ranges, 'Z'));
    try std.testing.expect(CharClass.binaryContains(&ranges, 'a'));
    try std.testing.expect(CharClass.binaryContains(&ranges, 'f'));
    try std.testing.expect(CharClass.binaryContains(&ranges, 0x0100));
    try std.testing.expect(CharClass.binaryContains(&ranges, 0x0103));
    try std.testing.expect(CharClass.binaryContains(&ranges, 0x1050));

    // Non-matches in gaps
    try std.testing.expect(!CharClass.binaryContains(&ranges, 'D'));
    try std.testing.expect(!CharClass.binaryContains(&ranges, 'L'));
    try std.testing.expect(!CharClass.binaryContains(&ranges, 'Q'));
    try std.testing.expect(!CharClass.binaryContains(&ranges, 'W'));
    try std.testing.expect(!CharClass.binaryContains(&ranges, 'g'));
    try std.testing.expect(!CharClass.binaryContains(&ranges, 'l'));
    try std.testing.expect(!CharClass.binaryContains(&ranges, 's'));
    try std.testing.expect(!CharClass.binaryContains(&ranges, 'w'));
    try std.testing.expect(!CharClass.binaryContains(&ranges, 0x0060)); // between 'Z'+1...'a'-1 gap
    try std.testing.expect(!CharClass.binaryContains(&ranges, 0x1200));

    // Edge: before first and after last
    try std.testing.expect(!CharClass.binaryContains(&ranges, 0x0000));
    try std.testing.expect(!CharClass.binaryContains(&ranges, 0x10FFFF));
}
