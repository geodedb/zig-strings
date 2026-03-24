// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Regular Expression Engine
//!
//! A Unicode-aware regular expression engine for Zig.
//! Supports common regex syntax with UTF-8 input.
//!
//! Supported syntax:
//! - Literals: `a`, `abc`
//! - Character classes: `[abc]`, `[a-z]`, `[^abc]`
//! - Predefined classes: `\d`, `\w`, `\s`, `\D`, `\W`, `\S`
//! - Unicode categories: `\p{L}`, `\p{N}`, `\P{L}`
//! - Anchors: `^`, `$`, `\b`, `\B`
//! - Quantifiers: `*`, `+`, `?`, `{n}`, `{n,}`, `{n,m}`
//! - Lazy quantifiers: `*?`, `+?`, `??`
//! - Groups: `(...)`, `(?:...)` (non-capturing)
//! - Alternation: `a|b`
//! - Escape sequences: `\.`, `\\`, `\n`, `\t`, `\r`
//! - Any character: `.` (matches any except newline)
//!
//! Usage:
//! ```zig
//! var re = try Regex.compile(allocator, "\\d+");
//! defer re.deinit();
//!
//! if (re.match("abc123def")) |m| {
//!     std.debug.print("Found: {s}\n", .{m.slice});
//! }
//!
//! // Find all matches
//! var iter = re.findAll("a1b2c3");
//! while (iter.next()) |m| {
//!     std.debug.print("{s}\n", .{m.slice});
//! }
//! ```

const std = @import("std");
const categories = @import("categories");

// Sub-module imports
const types = @import("regex_types.zig");
const compiler_mod = @import("regex_compiler.zig");
const vm_mod = @import("regex_vm.zig");

// Private type aliases used internally
const Compiler = compiler_mod.Compiler;
const VM = vm_mod.VM;
const Instruction = types.Instruction;
const Opcode = types.Opcode;
const CompiledPattern = types.CompiledPattern;

// Re-export public types so external callers see the same API as before:
//   const regex = @import("regex");
//   regex.Regex, regex.Match, regex.RegexError, etc.
pub const RegexError = types.RegexError;
pub const Match = types.Match;
pub const Options = types.Options;
pub const CharClass = types.CharClass;

/// Compiled regular expression
pub const Regex = struct {
    /// Compiled instructions
    code: []Instruction,
    /// Character class data
    char_classes: []const CharClass,
    /// Number of capture groups
    num_groups: u32,
    /// Original pattern (for debugging)
    pattern: []const u8,
    /// Allocator
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Compile a regex pattern
    pub fn compile(allocator: std.mem.Allocator, pat: []const u8) RegexError!Self {
        var compiler = Compiler.init(allocator);
        defer compiler.deinit();
        const result = try compiler.compile(pat);
        return Self{
            .code = result.code,
            .char_classes = result.char_classes,
            .num_groups = result.num_groups,
            .pattern = result.pattern,
            .allocator = allocator,
        };
    }

    /// Compile with options
    pub fn compileWithOptions(allocator: std.mem.Allocator, pat: []const u8, opts: Options) RegexError!Self {
        var compiler = Compiler.init(allocator);
        defer compiler.deinit();
        compiler.options = opts;
        const result = try compiler.compile(pat);
        return Self{
            .code = result.code,
            .char_classes = result.char_classes,
            .num_groups = result.num_groups,
            .pattern = result.pattern,
            .allocator = allocator,
        };
    }

    /// Free compiled regex
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.code);
        for (self.char_classes) |cc| {
            self.allocator.free(cc.ranges);
        }
        self.allocator.free(self.char_classes);
        self.allocator.free(self.pattern);
    }

    /// Convert to the CompiledPattern view used by the VM.
    fn toCompiledPattern(self: Self) CompiledPattern {
        return .{
            .code = self.code,
            .char_classes = self.char_classes,
            .num_groups = self.num_groups,
        };
    }

    /// Check if pattern matches anywhere in input
    pub fn isMatch(self: Self, input: []const u8) bool {
        return self.find(input) != null;
    }

    /// Find first match in input
    pub fn find(self: Self, input: []const u8) ?Match {
        var vm = VM.init(self.toCompiledPattern(), input);
        return vm.execute();
    }

    /// Find match at exact position
    pub fn matchAt(self: Self, input: []const u8, pos: usize) ?Match {
        var vm = VM.init(self.toCompiledPattern(), input);
        vm.anchored = true;
        vm.start_pos = pos;
        return vm.execute();
    }

    /// Check if entire input matches pattern
    pub fn fullMatch(self: Self, input: []const u8) ?Match {
        if (self.matchAt(input, 0)) |m| {
            if (m.end == input.len) {
                return m;
            }
        }
        return null;
    }

    /// Find all non-overlapping matches
    pub fn findAll(self: Self, input: []const u8) MatchIterator {
        return MatchIterator{
            .regex = self,
            .input = input,
            .pos = 0,
        };
    }

    /// Replace first match
    pub fn replaceFirst(self: Self, allocator: std.mem.Allocator, input: []const u8, replacement: []const u8) ![]u8 {
        if (self.find(input)) |m| {
            var result: std.ArrayListUnmanaged(u8) = .{};
            errdefer result.deinit(allocator);

            try result.appendSlice(allocator, input[0..m.start]);
            try result.appendSlice(allocator, replacement);
            try result.appendSlice(allocator, input[m.end..]);

            return result.toOwnedSlice(allocator);
        }
        return allocator.dupe(u8, input);
    }

    /// Replace all matches
    pub fn replaceAll(self: Self, allocator: std.mem.Allocator, input: []const u8, replacement: []const u8) ![]u8 {
        var result: std.ArrayListUnmanaged(u8) = .{};
        errdefer result.deinit(allocator);

        var last_end: usize = 0;
        var iter = self.findAll(input);

        while (iter.next()) |m| {
            try result.appendSlice(allocator, input[last_end..m.start]);
            try result.appendSlice(allocator, replacement);
            last_end = m.end;
        }

        try result.appendSlice(allocator, input[last_end..]);
        return result.toOwnedSlice(allocator);
    }

    /// Split input by pattern
    pub fn split(self: Self, allocator: std.mem.Allocator, input: []const u8) ![][]const u8 {
        var parts: std.ArrayListUnmanaged([]const u8) = .{};
        errdefer parts.deinit(allocator);

        var last_end: usize = 0;
        var iter = self.findAll(input);

        while (iter.next()) |m| {
            try parts.append(allocator, input[last_end..m.start]);
            last_end = m.end;
        }

        try parts.append(allocator, input[last_end..]);
        return parts.toOwnedSlice(allocator);
    }
};

/// Match iterator for findAll
pub const MatchIterator = struct {
    regex: Regex,
    input: []const u8,
    pos: usize,

    /// Returns the next non-overlapping match, or null when exhausted.
    pub fn next(self: *MatchIterator) ?Match {
        if (self.pos > self.input.len) return null;

        var vm = VM.init(self.regex.toCompiledPattern(), self.input);
        vm.start_pos = self.pos;

        if (vm.execute()) |m| {
            // Move past this match (at least 1 byte to avoid infinite loop on empty matches)
            self.pos = if (m.end > m.start) m.end else m.start + 1;
            return m;
        }

        return null;
    }
};

// ============================================================
// Tests
// ============================================================

test "Regex literal match" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "hello");
    defer re.deinit();

    try testing.expect(re.isMatch("hello world"));
    try testing.expect(re.isMatch("say hello"));
    try testing.expect(!re.isMatch("HELLO"));
    try testing.expect(!re.isMatch("helo"));
}

test "Regex digit class" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\d\\d\\d");
    defer re.deinit();

    try testing.expect(re.isMatch("abc123def"));
    try testing.expect(re.isMatch("123"));
    try testing.expect(!re.isMatch("12"));
    try testing.expect(!re.isMatch("abc"));
}

test "Regex character class" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "[abc]");
    defer re.deinit();

    try testing.expect(re.isMatch("a"));
    try testing.expect(re.isMatch("b"));
    try testing.expect(re.isMatch("c"));
    try testing.expect(!re.isMatch("d"));
}

test "Regex anchors" {
    const testing = std.testing;

    var re_start = try Regex.compile(testing.allocator, "^hello");
    defer re_start.deinit();

    try testing.expect(re_start.isMatch("hello world"));
    try testing.expect(!re_start.isMatch("say hello"));

    var re_end = try Regex.compile(testing.allocator, "world$");
    defer re_end.deinit();

    try testing.expect(re_end.isMatch("hello world"));
    try testing.expect(!re_end.isMatch("world hello"));
}

test "Regex word boundary" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\bword\\b");
    defer re.deinit();

    try testing.expect(re.isMatch("a word here"));
    try testing.expect(re.isMatch("word"));
    try testing.expect(!re.isMatch("words"));
    try testing.expect(!re.isMatch("keyword"));
}

test "Regex find" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\d+");
    defer re.deinit();

    if (re.find("abc123def")) |m| {
        try testing.expectEqualStrings("123", m.slice);
        try testing.expectEqual(@as(usize, 3), m.start);
        try testing.expectEqual(@as(usize, 6), m.end);
    } else {
        try testing.expect(false);
    }
}

test "Regex replaceAll" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\d");
    defer re.deinit();

    const result = try re.replaceAll(testing.allocator, "a1b2c3", "X");
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("aXbXcX", result);
}

test "Regex split" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, ",");
    defer re.deinit();

    const parts = try re.split(testing.allocator, "a,b,c");
    defer testing.allocator.free(parts);

    try testing.expectEqual(@as(usize, 3), parts.len);
    try testing.expectEqualStrings("a", parts[0]);
    try testing.expectEqualStrings("b", parts[1]);
    try testing.expectEqualStrings("c", parts[2]);
}

// ============================================================
// Gap Closure Tests
// ============================================================

test "Unicode property \\p{Nd} matches digits" {
    // GAP-0005: unicode_prop opcode handler
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\p{Nd}");
    defer re.deinit();

    try testing.expect(re.isMatch("5"));
    try testing.expect(re.isMatch("0"));
    try testing.expect(!re.isMatch("a"));
    try testing.expect(!re.isMatch("!"));
}

test "Unicode property \\P{Nd} matches non-digits" {
    // GAP-0005: unicode_prop_neg opcode handler
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\P{Nd}");
    defer re.deinit();

    try testing.expect(re.isMatch("a"));
    try testing.expect(re.isMatch("!"));
    try testing.expect(!re.isMatch("5"));
}

test "Unicode property \\p{L} matches letters" {
    // GAP-0005: Letter property
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\p{L}");
    defer re.deinit();

    try testing.expect(re.isMatch("a"));
    try testing.expect(re.isMatch("Z"));
    try testing.expect(!re.isMatch("5"));
    try testing.expect(!re.isMatch("!"));
}

test "Capture groups wired into Match result" {
    // GAP: groups field was hardcoded to empty
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "(a)(b)");
    defer re.deinit();

    if (re.find("ab")) |m| {
        const grps = m.groups();
        // Group 0 = full match "ab"
        try testing.expect(grps[0] != null);
        try testing.expectEqualStrings("ab", grps[0].?.slice);
        // Group 1 = "a"
        try testing.expect(grps[1] != null);
        try testing.expectEqualStrings("a", grps[1].?.slice);
        try testing.expectEqual(@as(usize, 0), grps[1].?.start);
        try testing.expectEqual(@as(usize, 1), grps[1].?.end);
        // Group 2 = "b"
        try testing.expect(grps[2] != null);
        try testing.expectEqualStrings("b", grps[2].?.slice);
        try testing.expectEqual(@as(usize, 1), grps[2].?.start);
        try testing.expectEqual(@as(usize, 2), grps[2].?.end);
    } else {
        try testing.expect(false); // should have matched
    }
}

test "Capture group with alternation" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "(a|b)c");
    defer re.deinit();

    if (re.find("ac")) |m| {
        const grps = m.groups();
        try testing.expect(grps[0] != null);
        try testing.expectEqualStrings("ac", grps[0].?.slice);
        try testing.expect(grps[1] != null);
        try testing.expectEqualStrings("a", grps[1].?.slice);
    } else {
        try testing.expect(false);
    }
}

test "\\P{Nd} full match excludes digits" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\P{Nd}");
    defer re.deinit();

    // Single digit should not match \\P{Nd} as a full match
    try testing.expect(re.fullMatch("5") == null);
    // Letter should match
    try testing.expect(re.fullMatch("a") != null);
}

// ============================================================
// Q5 Gap Closure Tests -- Expanded Regex Test Coverage
// ============================================================

test "Q5: Unicode property \\p{Lu} matches uppercase letters" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\p{Lu}+");
    defer re.deinit();

    try testing.expect(re.isMatch("ABC"));
    try testing.expect(re.isMatch("Hello")); // H is uppercase
    try testing.expect(!re.isMatch("abc"));
    try testing.expect(!re.isMatch("123"));
}

test "Q5: Unicode property \\p{Ll} matches lowercase letters" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\p{Ll}+");
    defer re.deinit();

    try testing.expect(re.isMatch("abc"));
    try testing.expect(re.isMatch("Hello")); // ello is lowercase
    try testing.expect(!re.isMatch("ABC"));
    try testing.expect(!re.isMatch("123"));
}

test "Q5: Negated Unicode property \\P{Lu} matches non-uppercase" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "^\\P{Lu}+$");
    defer re.deinit();

    // Fully lowercase / digits / punct should match
    try testing.expect(re.fullMatch("abc") != null);
    try testing.expect(re.fullMatch("123") != null);
    // Contains uppercase -- should not fullMatch
    try testing.expect(re.fullMatch("Hello") == null);
    try testing.expect(re.fullMatch("A") == null);
}

test "Q5: Character class range [a-z] matches lowercase ASCII" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "^[a-z]+$");
    defer re.deinit();

    try testing.expect(re.fullMatch("hello") != null);
    try testing.expect(re.fullMatch("abc") != null);
    try testing.expect(re.fullMatch("Hello") == null); // H is uppercase
    try testing.expect(re.fullMatch("123") == null);
    try testing.expect(re.fullMatch("") == null); // + requires at least 1
}

test "Q5: Negated character class [^0-9] matches non-digits" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "^[^0-9]+$");
    defer re.deinit();

    try testing.expect(re.fullMatch("hello") != null);
    try testing.expect(re.fullMatch("abc!@#") != null);
    try testing.expect(re.fullMatch("123") == null);
    try testing.expect(re.fullMatch("abc123") == null);
}

test "Q5: Quantifier with explicit count {n}" {
    const testing = std.testing;

    // a{1} requires exactly one 'a'
    var re1 = try Regex.compile(testing.allocator, "a{1}");
    defer re1.deinit();
    try testing.expect(re1.isMatch("a"));
    try testing.expect(re1.isMatch("bab")); // 'a' in the middle
    try testing.expect(!re1.isMatch("b"));

    // a{3} requires exactly three consecutive a's
    var re3 = try Regex.compile(testing.allocator, "a{3}");
    defer re3.deinit();
    try testing.expect(re3.isMatch("aaa"));
    try testing.expect(re3.isMatch("xaaay"));
    try testing.expect(!re3.isMatch("aa")); // only two
}

test "Q5: Empty match with star quantifier" {
    const testing = std.testing;

    // x* can match zero x's
    var re = try Regex.compile(testing.allocator, "x*");
    defer re.deinit();

    try testing.expect(re.isMatch("")); // zero x's
    try testing.expect(re.isMatch("xxx"));
    try testing.expect(re.isMatch("abc")); // zero x's at start

    // Verify the match slice
    if (re.find("abc")) |m| {
        // Empty match at position 0 (zero x's)
        try testing.expectEqual(@as(usize, 0), m.start);
    } else {
        try testing.expect(false);
    }
}

test "Q5: Exact anchor match ^...$" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "^exact$");
    defer re.deinit();

    try testing.expect(re.isMatch("exact"));
    try testing.expect(!re.isMatch("not exact"));
    try testing.expect(!re.isMatch("exact not"));
    try testing.expect(!re.isMatch(""));
}

test "Q5: Alternation cat|dog" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "cat|dog");
    defer re.deinit();

    try testing.expect(re.isMatch("I have a cat"));
    try testing.expect(re.isMatch("I have a dog"));
    try testing.expect(!re.isMatch("I have a bird"));

    // Verify which alternative matched
    if (re.find("I have a dog")) |m| {
        try testing.expectEqualStrings("dog", m.slice);
    } else {
        try testing.expect(false);
    }
}

test "Q5: Grouped alternation (a|b|c)+" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "^(a|b|c)+$");
    defer re.deinit();

    try testing.expect(re.fullMatch("abc") != null);
    try testing.expect(re.fullMatch("aaa") != null);
    try testing.expect(re.fullMatch("bca") != null);
    try testing.expect(re.fullMatch("abcd") == null); // 'd' not in group
    try testing.expect(re.fullMatch("") == null); // + requires 1+
}

test "Q5: Multiple capture groups (foo)(bar)" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "(foo)(bar)");
    defer re.deinit();

    if (re.find("foobar")) |m| {
        const grps = m.groups();
        // Group 0 = full match
        try testing.expect(grps[0] != null);
        try testing.expectEqualStrings("foobar", grps[0].?.slice);
        // Group 1 = "foo"
        try testing.expect(grps[1] != null);
        try testing.expectEqualStrings("foo", grps[1].?.slice);
        try testing.expectEqual(@as(usize, 0), grps[1].?.start);
        try testing.expectEqual(@as(usize, 3), grps[1].?.end);
        // Group 2 = "bar"
        try testing.expect(grps[2] != null);
        try testing.expectEqualStrings("bar", grps[2].?.slice);
        try testing.expectEqual(@as(usize, 3), grps[2].?.start);
        try testing.expectEqual(@as(usize, 6), grps[2].?.end);
    } else {
        try testing.expect(false);
    }
}

test "Q5: Empty input edge cases" {
    const testing = std.testing;

    // Pattern that can match empty string
    var re_star = try Regex.compile(testing.allocator, "a*");
    defer re_star.deinit();
    try testing.expect(re_star.isMatch("")); // zero a's

    // Pattern that requires at least one character
    var re_plus = try Regex.compile(testing.allocator, "a+");
    defer re_plus.deinit();
    try testing.expect(!re_plus.isMatch("")); // needs at least one 'a'

    // Anchored empty pattern
    var re_anchored = try Regex.compile(testing.allocator, "^$");
    defer re_anchored.deinit();
    try testing.expect(re_anchored.isMatch("")); // empty string matches ^$
    try testing.expect(!re_anchored.isMatch("x"));
}

test "Q5: Escaped special characters" {
    const testing = std.testing;

    // Match a literal dot
    var re_dot = try Regex.compile(testing.allocator, "\\.");
    defer re_dot.deinit();
    try testing.expect(re_dot.isMatch("a.b"));
    try testing.expect(!re_dot.isMatch("axb")); // unescaped dot would match

    // Match literal brackets
    var re_bracket = try Regex.compile(testing.allocator, "\\[x\\]");
    defer re_bracket.deinit();
    try testing.expect(re_bracket.isMatch("[x]"));
    try testing.expect(!re_bracket.isMatch("x"));

    // Match literal parentheses
    var re_paren = try Regex.compile(testing.allocator, "\\(ok\\)");
    defer re_paren.deinit();
    try testing.expect(re_paren.isMatch("(ok)"));
    try testing.expect(!re_paren.isMatch("ok"));

    // Match literal backslash
    var re_bs = try Regex.compile(testing.allocator, "\\\\");
    defer re_bs.deinit();
    try testing.expect(re_bs.isMatch("a\\b"));
    try testing.expect(!re_bs.isMatch("ab"));
}

test "Q5: findAll returns multiple non-overlapping matches" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\d+");
    defer re.deinit();

    var iter = re.findAll("a1b23c456");
    var count: usize = 0;

    // First match: "1"
    if (iter.next()) |m| {
        try testing.expectEqualStrings("1", m.slice);
        try testing.expectEqual(@as(usize, 1), m.start);
        count += 1;
    }
    // Second match: "23"
    if (iter.next()) |m| {
        try testing.expectEqualStrings("23", m.slice);
        try testing.expectEqual(@as(usize, 3), m.start);
        count += 1;
    }
    // Third match: "456"
    if (iter.next()) |m| {
        try testing.expectEqualStrings("456", m.slice);
        try testing.expectEqual(@as(usize, 6), m.start);
        count += 1;
    }
    // No more matches
    try testing.expect(iter.next() == null);
    try testing.expectEqual(@as(usize, 3), count);
}

test "Q5: Non-capturing group (?:...)" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "(?:abc)+");
    defer re.deinit();

    try testing.expect(re.isMatch("abc"));
    try testing.expect(re.isMatch("abcabc"));
    try testing.expect(!re.isMatch("ab")); // incomplete group

    // Non-capturing group should not produce a capture
    if (re.find("abcabc")) |m| {
        try testing.expectEqualStrings("abcabc", m.slice);
        const grps = m.groups();
        // Group 0 = full match; no group 1 since (?:...) is non-capturing
        try testing.expect(grps[0] != null);
        try testing.expectEqual(@as(usize, 1), m.group_count);
    } else {
        try testing.expect(false);
    }
}

test "Q5: Predefined classes \\w \\s \\D" {
    const testing = std.testing;

    // \\w matches word characters [a-zA-Z0-9_]
    var re_w = try Regex.compile(testing.allocator, "^\\w+$");
    defer re_w.deinit();
    try testing.expect(re_w.fullMatch("hello_123") != null);
    try testing.expect(re_w.fullMatch("test") != null);
    try testing.expect(re_w.fullMatch("hello world") == null); // space is not \\w

    // \\s matches whitespace
    var re_s = try Regex.compile(testing.allocator, "\\s");
    defer re_s.deinit();
    try testing.expect(re_s.isMatch("hello world")); // space
    try testing.expect(re_s.isMatch("a\tb")); // tab
    try testing.expect(!re_s.isMatch("nospace"));

    // \\D matches non-digit
    var re_D = try Regex.compile(testing.allocator, "^\\D+$");
    defer re_D.deinit();
    try testing.expect(re_D.fullMatch("hello") != null);
    try testing.expect(re_D.fullMatch("abc123") == null); // contains digits
}

test "Q5: Repetition with explicit counts {n} and {n,m}" {
    const testing = std.testing;

    // Exactly 3 digits
    var re_exact = try Regex.compile(testing.allocator, "^\\d{3}$");
    defer re_exact.deinit();
    try testing.expect(re_exact.fullMatch("123") != null);
    try testing.expect(re_exact.fullMatch("12") == null);
    try testing.expect(re_exact.fullMatch("1234") == null);

    // Between 2 and 4 digits
    var re_range = try Regex.compile(testing.allocator, "^\\d{2,4}$");
    defer re_range.deinit();
    try testing.expect(re_range.fullMatch("12") != null);
    try testing.expect(re_range.fullMatch("123") != null);
    try testing.expect(re_range.fullMatch("1234") != null);
    try testing.expect(re_range.fullMatch("1") == null);
    try testing.expect(re_range.fullMatch("12345") == null);
}

test "Q5: Dot matches any character except newline" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "^a.b$");
    defer re.deinit();

    try testing.expect(re.fullMatch("axb") != null);
    try testing.expect(re.fullMatch("a b") != null);
    try testing.expect(re.fullMatch("a1b") != null);
    try testing.expect(re.fullMatch("a\nb") == null); // dot does not match newline by default
    try testing.expect(re.fullMatch("ab") == null); // dot requires exactly one char
}

test "Q5: Unicode property \\p{N} matches any number category" {
    const testing = std.testing;

    var re = try Regex.compile(testing.allocator, "\\p{N}");
    defer re.deinit();

    try testing.expect(re.isMatch("5")); // ASCII digit (Nd)
    try testing.expect(re.isMatch("0"));
    try testing.expect(!re.isMatch("a"));
    try testing.expect(!re.isMatch("!"));
}
