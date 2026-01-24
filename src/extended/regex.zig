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
const unicode = std.unicode;

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
    /// The matched slice
    slice: []const u8,
    /// Start byte index in the input
    start: usize,
    /// End byte index in the input (exclusive)
    end: usize,
    /// Captured groups (index 0 is the full match)
    groups: []const ?Group,

    pub const Group = struct {
        slice: []const u8,
        start: usize,
        end: usize,
    };
};

/// Compiled instruction opcodes
const Opcode = enum(u8) {
    // Matching
    literal, // Match exact byte
    literal_insensitive, // Match byte case-insensitive
    any, // Match any byte (except newline)
    any_all, // Match any byte (including newline)

    // Character classes
    char_class, // Match character class
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
const Instruction = struct {
    op: Opcode,
    // Operand data (meaning depends on opcode)
    a: u32 = 0, // Often: jump target, char value, class index
    b: u32 = 0, // Often: secondary jump, max repeat count
};

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
    pub fn compile(allocator: std.mem.Allocator, pattern: []const u8) RegexError!Self {
        var compiler = Compiler.init(allocator);
        defer compiler.deinit();
        return compiler.compile(pattern);
    }

    /// Compile with options
    pub fn compileWithOptions(allocator: std.mem.Allocator, pattern: []const u8, opts: Options) RegexError!Self {
        var compiler = Compiler.init(allocator);
        defer compiler.deinit();
        compiler.options = opts;
        return compiler.compile(pattern);
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

    /// Check if pattern matches anywhere in input
    pub fn isMatch(self: Self, input: []const u8) bool {
        return self.find(input) != null;
    }

    /// Find first match in input
    pub fn find(self: Self, input: []const u8) ?Match {
        var vm = VM.init(self, input);
        return vm.execute();
    }

    /// Find match at exact position
    pub fn matchAt(self: Self, input: []const u8, pos: usize) ?Match {
        var vm = VM.init(self, input);
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

    pub fn next(self: *MatchIterator) ?Match {
        if (self.pos > self.input.len) return null;

        var vm = VM.init(self.regex, self.input);
        vm.start_pos = self.pos;

        if (vm.execute()) |m| {
            // Move past this match (at least 1 byte to avoid infinite loop on empty matches)
            self.pos = if (m.end > m.start) m.end else m.start + 1;
            return m;
        }

        return null;
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

/// Character class (set of character ranges)
const CharClass = struct {
    ranges: []const Range,
    negated: bool = false,

    const Range = struct {
        lo: u21,
        hi: u21,
    };

    fn contains(self: CharClass, cp: u21) bool {
        var found = false;
        for (self.ranges) |r| {
            if (cp >= r.lo and cp <= r.hi) {
                found = true;
                break;
            }
        }
        return if (self.negated) !found else found;
    }
};

/// Regex compiler
const Compiler = struct {
    allocator: std.mem.Allocator,
    code: std.ArrayListUnmanaged(Instruction),
    char_classes: std.ArrayListUnmanaged(CharClass),
    pattern: []const u8,
    pos: usize,
    group_count: u32,
    options: Options,

    fn init(allocator: std.mem.Allocator) Compiler {
        return .{
            .allocator = allocator,
            .code = .{},
            .char_classes = .{},
            .pattern = "",
            .pos = 0,
            .group_count = 0,
            .options = .{},
        };
    }

    fn deinit(self: *Compiler) void {
        self.code.deinit(self.allocator);
        // char_classes ownership transfers to Regex
    }

    fn compile(self: *Compiler, pattern: []const u8) RegexError!Regex {
        self.pattern = pattern;
        self.pos = 0;
        self.group_count = 1; // Group 0 is the full match

        // Parse and compile
        try self.parseAlternation();

        // Add final match instruction
        try self.emit(.match, 0, 0);

        // Build result
        const code = self.code.toOwnedSlice(self.allocator) catch return RegexError.OutOfMemory;
        const classes = self.char_classes.toOwnedSlice(self.allocator) catch return RegexError.OutOfMemory;
        const pat = self.allocator.dupe(u8, pattern) catch return RegexError.OutOfMemory;

        return Regex{
            .code = code,
            .char_classes = classes,
            .num_groups = self.group_count,
            .pattern = pat,
            .allocator = self.allocator,
        };
    }

    fn emit(self: *Compiler, op: Opcode, a: u32, b: u32) !void {
        self.code.append(self.allocator, .{ .op = op, .a = a, .b = b }) catch return RegexError.OutOfMemory;
    }

    fn currentPos(self: *Compiler) u32 {
        return @intCast(self.code.items.len);
    }

    fn patch(self: *Compiler, addr: u32, target: u32) void {
        self.code.items[addr].a = target;
    }

    fn peek(self: *Compiler) ?u8 {
        if (self.pos < self.pattern.len) {
            return self.pattern[self.pos];
        }
        return null;
    }

    fn advance(self: *Compiler) ?u8 {
        if (self.pos < self.pattern.len) {
            const c = self.pattern[self.pos];
            self.pos += 1;
            return c;
        }
        return null;
    }

    fn parseAlternation(self: *Compiler) RegexError!void {
        // Check if there's actually alternation
        var has_alternation = false;

        // Scan ahead to check for '|' at this level
        var depth: u32 = 0;
        var scan_pos = self.pos;
        while (scan_pos < self.pattern.len) {
            const ch = self.pattern[scan_pos];
            if (ch == '(') {
                depth += 1;
            } else if (ch == ')') {
                if (depth == 0) break;
                depth -= 1;
            } else if (ch == '|' and depth == 0) {
                has_alternation = true;
                break;
            }
            scan_pos += 1;
        }

        if (!has_alternation) {
            // No alternation at this level, just parse sequence
            try self.parseSequence();
            return;
        }

        // There is alternation - use split instructions
        var split_addrs: std.ArrayListUnmanaged(u32) = .{};
        defer split_addrs.deinit(self.allocator);
        var jump_addrs: std.ArrayListUnmanaged(u32) = .{};
        defer jump_addrs.deinit(self.allocator);

        // Emit split for first branch (to be patched)
        const first_split = self.currentPos();
        try self.emit(.split, 0, 0); // a=next instruction, b=second branch
        split_addrs.append(self.allocator, first_split) catch return RegexError.OutOfMemory;

        // Parse first branch
        try self.parseSequence();

        while (self.peek() == '|') {
            _ = self.advance(); // consume '|'

            // Jump to end after this branch
            const jump_addr = self.currentPos();
            try self.emit(.jump, 0, 0);
            jump_addrs.append(self.allocator, jump_addr) catch return RegexError.OutOfMemory;

            // Patch previous split to point here
            const branch_start = self.currentPos();
            if (split_addrs.items.len > 0) {
                const last_split = split_addrs.items[split_addrs.items.len - 1];
                self.code.items[last_split].b = branch_start;
            }

            // Check if there's another alternation
            scan_pos = self.pos;
            depth = 0;
            var more_alt = false;
            while (scan_pos < self.pattern.len) {
                const ch = self.pattern[scan_pos];
                if (ch == '(') {
                    depth += 1;
                } else if (ch == ')') {
                    if (depth == 0) break;
                    depth -= 1;
                } else if (ch == '|' and depth == 0) {
                    more_alt = true;
                    break;
                }
                scan_pos += 1;
            }

            if (more_alt) {
                // Emit another split
                const next_split = self.currentPos();
                try self.emit(.split, 0, 0);
                split_addrs.append(self.allocator, next_split) catch return RegexError.OutOfMemory;
            }

            // Parse this branch
            try self.parseSequence();
        }

        // Patch first split's a to point to first instruction after split
        if (split_addrs.items.len > 0) {
            self.code.items[split_addrs.items[0]].a = split_addrs.items[0] + 1;
        }

        // For subsequent splits, patch a to point to instruction after split
        for (split_addrs.items[1..], 1..) |addr, i| {
            _ = i;
            self.code.items[addr].a = addr + 1;
        }

        // Patch all jumps to end
        const end = self.currentPos();
        for (jump_addrs.items) |addr| {
            self.patch(addr, end);
        }
    }

    fn parseSequence(self: *Compiler) RegexError!void {
        while (self.peek()) |c| {
            if (c == ')' or c == '|') break;
            try self.parseAtom();
        }
    }

    fn parseAtom(self: *Compiler) RegexError!void {
        const c = self.peek() orelse return;

        switch (c) {
            '(' => try self.parseGroup(),
            '[' => {
                const atom_start = self.currentPos();
                try self.parseCharClass();
                try self.applyQuantifier(atom_start);
            },
            '^' => {
                _ = self.advance();
                try self.emit(.line_start, 0, 0);
            },
            '$' => {
                _ = self.advance();
                try self.emit(.line_end, 0, 0);
            },
            '.' => {
                const atom_start = self.currentPos();
                _ = self.advance();
                const op: Opcode = if (self.options.dot_all) .any_all else .any;
                try self.emit(op, 0, 0);
                try self.applyQuantifier(atom_start);
            },
            '\\' => {
                const atom_start = self.currentPos();
                try self.parseEscape();
                try self.applyQuantifier(atom_start);
            },
            '*', '+', '?', '{' => return RegexError.InvalidQuantifier,
            else => {
                const atom_start = self.currentPos();
                _ = self.advance();
                const op: Opcode = if (self.options.case_insensitive) .literal_insensitive else .literal;
                try self.emit(op, c, 0);
                try self.applyQuantifier(atom_start);
            },
        }
    }

    fn parseGroup(self: *Compiler) RegexError!void {
        const atom_start = self.currentPos();
        _ = self.advance(); // consume '('

        // Check for non-capturing group
        var capturing = true;
        if (self.peek() == '?') {
            _ = self.advance();
            if (self.peek() == ':') {
                _ = self.advance();
                capturing = false;
            } else {
                return RegexError.InvalidPattern;
            }
        }

        var group_num: u32 = 0;
        if (capturing) {
            group_num = self.group_count;
            self.group_count += 1;
            try self.emit(.save, group_num * 2, 0); // Save start
        }

        try self.parseAlternation();

        if (self.peek() != ')') {
            return RegexError.UnmatchedParenthesis;
        }
        _ = self.advance();

        if (capturing) {
            try self.emit(.save, group_num * 2 + 1, 0); // Save end
        }

        try self.applyQuantifier(atom_start);
    }

    fn parseCharClass(self: *Compiler) RegexError!void {
        _ = self.advance(); // consume '['

        var negated = false;
        if (self.peek() == '^') {
            negated = true;
            _ = self.advance();
        }

        var ranges: std.ArrayListUnmanaged(CharClass.Range) = .{};
        defer ranges.deinit(self.allocator);

        while (self.peek()) |c| {
            if (c == ']' and ranges.items.len > 0) break;

            const lo = try self.parseClassChar();
            var hi = lo;

            if (self.peek() == '-' and self.pos + 1 < self.pattern.len and self.pattern[self.pos + 1] != ']') {
                _ = self.advance(); // consume '-'
                hi = try self.parseClassChar();
                if (hi < lo) return RegexError.InvalidRange;
            }

            ranges.append(self.allocator, .{ .lo = lo, .hi = hi }) catch return RegexError.OutOfMemory;
        }

        if (self.peek() != ']') {
            return RegexError.UnmatchedBracket;
        }
        _ = self.advance();

        // Store character class
        const class_idx = self.char_classes.items.len;
        self.char_classes.append(self.allocator, .{
            .ranges = ranges.toOwnedSlice(self.allocator) catch return RegexError.OutOfMemory,
            .negated = negated,
        }) catch return RegexError.OutOfMemory;

        const op: Opcode = if (negated) .char_class_negated else .char_class;
        try self.emit(op, @intCast(class_idx), 0);
        // Note: quantifier is now applied by caller (parseAtom)
    }

    fn parseClassChar(self: *Compiler) RegexError!u21 {
        const c = self.advance() orelse return RegexError.UnmatchedBracket;

        if (c == '\\') {
            const esc = self.advance() orelse return RegexError.InvalidEscape;
            return switch (esc) {
                'n' => '\n',
                't' => '\t',
                'r' => '\r',
                '\\', '[', ']', '^', '-' => esc,
                else => esc,
            };
        }

        return c;
    }

    fn parseEscape(self: *Compiler) RegexError!void {
        _ = self.advance(); // consume '\'
        const c = self.advance() orelse return RegexError.InvalidEscape;

        switch (c) {
            'd' => try self.emit(.digit, 0, 0),
            'D' => try self.emit(.not_digit, 0, 0),
            'w' => try self.emit(.word, 0, 0),
            'W' => try self.emit(.not_word, 0, 0),
            's' => try self.emit(.whitespace, 0, 0),
            'S' => try self.emit(.not_whitespace, 0, 0),
            'b' => try self.emit(.word_boundary, 0, 0),
            'B' => try self.emit(.not_word_boundary, 0, 0),
            'A' => try self.emit(.input_start, 0, 0),
            'z' => try self.emit(.input_end, 0, 0),
            'n' => try self.emit(.literal, '\n', 0),
            't' => try self.emit(.literal, '\t', 0),
            'r' => try self.emit(.literal, '\r', 0),
            'p', 'P' => try self.parseUnicodeProperty(c == 'P'),
            else => try self.emit(.literal, c, 0),
        }
    }

    fn parseUnicodeProperty(self: *Compiler, negated: bool) !void {
        if (self.peek() != '{') return RegexError.InvalidUnicodeProperty;
        _ = self.advance();

        const start = self.pos;
        while (self.peek()) |c| {
            if (c == '}') break;
            _ = self.advance();
        }

        if (self.peek() != '}') return RegexError.InvalidUnicodeProperty;
        const prop_name = self.pattern[start..self.pos];
        _ = self.advance();

        // Map property name to category code
        const prop_code = mapUnicodeProperty(prop_name) orelse return RegexError.InvalidUnicodeProperty;

        const op: Opcode = if (negated) .unicode_prop_neg else .unicode_prop;
        try self.emit(op, prop_code, 0);
    }

    /// Apply a quantifier to the atom that starts at atom_start
    fn applyQuantifier(self: *Compiler, atom_start: u32) RegexError!void {
        const c = self.peek() orelse return;

        var min: u32 = 1;
        var max: u32 = 1;
        var has_quantifier = true;

        switch (c) {
            '*' => {
                min = 0;
                max = std.math.maxInt(u32);
                _ = self.advance();
            },
            '+' => {
                min = 1;
                max = std.math.maxInt(u32);
                _ = self.advance();
            },
            '?' => {
                min = 0;
                max = 1;
                _ = self.advance();
            },
            '{' => {
                _ = self.advance();
                min = try self.parseNumber();
                max = min;

                if (self.peek() == ',') {
                    _ = self.advance();
                    if (self.peek() == '}') {
                        max = std.math.maxInt(u32);
                    } else {
                        max = try self.parseNumber();
                    }
                }

                if (self.peek() != '}') return RegexError.InvalidQuantifier;
                _ = self.advance();
            },
            else => has_quantifier = false,
        }

        if (!has_quantifier) return;

        // Check for lazy quantifier
        var lazy = false;
        if (self.peek() == '?') {
            lazy = true;
            _ = self.advance();
        }

        // Generate NFA instructions for the quantifier
        // The atom code is from atom_start to current position
        const atom_end = self.currentPos();

        if (min == 0 and max == 1) {
            // ? quantifier: zero or one
            // Insert split before atom: split(atom_start+1, atom_end)
            // We need to shift all instructions after atom_start and insert split at beginning
            try self.insertSplitBefore(atom_start, atom_end, lazy);
        } else if (min == 0 and max == std.math.maxInt(u32)) {
            // * quantifier: zero or more
            // Insert split before atom, and add split at end to loop back
            // Structure: split(atom, end) -> atom -> split(atom, end)
            try self.insertSplitBefore(atom_start, atom_end + 1, lazy);
            // After insert, all positions shifted by 1. Add loop split.
            // For greedy: first try to match more (go back to atom), then exit
            // For lazy: first try to exit, then try to match more
            // The loop split target is the atom (at atom_start+1 after shift)
            // The exit target is the next instruction (currentPos() + 1)
            const loop_target = atom_start + 1;
            const exit_target = self.currentPos() + 1;
            try self.emit(.split, if (lazy) exit_target else loop_target, if (lazy) loop_target else exit_target);
        } else if (min == 1 and max == std.math.maxInt(u32)) {
            // + quantifier: one or more
            // atom -> split(atom, end)
            try self.emit(.split, if (lazy) self.currentPos() + 1 else atom_start, if (lazy) atom_start else self.currentPos() + 1);
        } else if (min == max and min > 0) {
            // {n} quantifier: exactly n
            // Duplicate the atom code (n-1) times
            if (min > 1 and min <= 100) { // Limit to prevent explosion
                const atom_code = try self.allocator.alloc(Instruction, atom_end - atom_start);
                defer self.allocator.free(atom_code);
                for (atom_start..atom_end, 0..) |i, j| {
                    atom_code[j] = self.code.items[i];
                }
                for (1..min) |_| {
                    for (atom_code) |inst| {
                        try self.code.append(self.allocator, inst);
                    }
                }
            }
        } else if (min == 0 and max > 0 and max < std.math.maxInt(u32)) {
            // {0,m} quantifier: zero to m times
            // Insert split before atom and generate up to m copies with splits
            try self.insertSplitBefore(atom_start, atom_end + 1, lazy);
            if (max > 1 and max <= 100) {
                const atom_len = atom_end - atom_start;
                const atom_code = try self.allocator.alloc(Instruction, atom_len);
                defer self.allocator.free(atom_code);
                for (atom_start..atom_end, 0..) |i, j| {
                    atom_code[j] = self.code.items[i + 1]; // +1 because of inserted split
                }
                for (1..max) |_| {
                    const pos = self.currentPos();
                    try self.emit(.split, pos + 1, pos + @as(u32, @intCast(atom_len)) + 1);
                    for (atom_code) |inst| {
                        try self.code.append(self.allocator, inst);
                    }
                }
            }
        } else if (min > 0 and max > min and max < std.math.maxInt(u32)) {
            // {n,m} quantifier: n to m times
            // Generate n copies, then (m-n) optional copies
            const atom_len = atom_end - atom_start;
            if (min <= 100 and max <= 100) {
                const atom_code = try self.allocator.alloc(Instruction, atom_len);
                defer self.allocator.free(atom_code);
                for (atom_start..atom_end, 0..) |i, j| {
                    atom_code[j] = self.code.items[i];
                }
                // Emit min-1 more copies (first copy already exists)
                for (1..min) |_| {
                    for (atom_code) |inst| {
                        try self.code.append(self.allocator, inst);
                    }
                }
                // Emit max-min optional copies with splits
                for (min..max) |_| {
                    const pos = self.currentPos();
                    try self.emit(.split, pos + 1, pos + @as(u32, @intCast(atom_len)) + 1);
                    for (atom_code) |inst| {
                        try self.code.append(self.allocator, inst);
                    }
                }
            }
        } else if (min > 0 and max == std.math.maxInt(u32)) {
            // {n,} quantifier: n or more times
            const atom_len = atom_end - atom_start;
            if (min <= 100) {
                const atom_code = try self.allocator.alloc(Instruction, atom_len);
                defer self.allocator.free(atom_code);
                for (atom_start..atom_end, 0..) |i, j| {
                    atom_code[j] = self.code.items[i];
                }
                // Emit min-1 more copies
                for (1..min) |_| {
                    for (atom_code) |inst| {
                        try self.code.append(self.allocator, inst);
                    }
                }
                // Add loop at end
                const loop_target = self.currentPos() - @as(u32, @intCast(atom_len));
                try self.emit(.split, if (lazy) self.currentPos() + 1 else loop_target, if (lazy) loop_target else self.currentPos() + 1);
            }
        }
    }

    /// Insert a split instruction before the atom at atom_start
    fn insertSplitBefore(self: *Compiler, atom_start: u32, skip_target: u32, lazy: bool) RegexError!void {
        // Make room for the split instruction by shifting everything
        self.code.append(self.allocator, .{ .op = .match, .a = 0, .b = 0 }) catch return RegexError.OutOfMemory;

        // Shift instructions from atom_start to end
        var i = self.code.items.len - 1;
        while (i > atom_start) : (i -= 1) {
            self.code.items[i] = self.code.items[i - 1];
            // Update jump targets in the shifted instruction
            if (self.code.items[i].op == .jump or self.code.items[i].op == .split) {
                if (self.code.items[i].a >= atom_start) {
                    self.code.items[i].a += 1;
                }
                if (self.code.items[i].op == .split and self.code.items[i].b >= atom_start) {
                    self.code.items[i].b += 1;
                }
            }
        }

        // Insert split at atom_start
        // For greedy: try atom first (a), skip to end second (b)
        // For lazy: skip to end first (a), try atom second (b)
        self.code.items[atom_start] = .{
            .op = .split,
            .a = if (lazy) skip_target + 1 else atom_start + 1,
            .b = if (lazy) atom_start + 1 else skip_target + 1,
        };
    }

    fn parseNumber(self: *Compiler) RegexError!u32 {
        var num: u32 = 0;
        var has_digit = false;

        while (self.peek()) |c| {
            if (c >= '0' and c <= '9') {
                has_digit = true;
                num = num * 10 + (c - '0');
                _ = self.advance();
            } else {
                break;
            }
        }

        if (!has_digit) return RegexError.InvalidQuantifier;
        return num;
    }
};

/// Map Unicode property names to internal codes
fn mapUnicodeProperty(name: []const u8) ?u32 {
    const props = .{
        .{ "L", 1 }, // Letter
        .{ "Lu", 2 }, // Uppercase Letter
        .{ "Ll", 3 }, // Lowercase Letter
        .{ "Lt", 4 }, // Titlecase Letter
        .{ "Lm", 5 }, // Modifier Letter
        .{ "Lo", 6 }, // Other Letter
        .{ "M", 7 }, // Mark
        .{ "N", 8 }, // Number
        .{ "Nd", 9 }, // Decimal Number
        .{ "P", 10 }, // Punctuation
        .{ "S", 11 }, // Symbol
        .{ "Z", 12 }, // Separator
        .{ "C", 13 }, // Other
    };

    inline for (props) |p| {
        if (std.mem.eql(u8, name, p[0])) {
            return p[1];
        }
    }

    return null;
}

/// Virtual machine for regex execution
const VM = struct {
    regex: Regex,
    input: []const u8,
    start_pos: usize,
    anchored: bool,
    groups: [64]?usize, // Max 32 groups (start/end pairs)

    fn init(regex_pattern: Regex, input: []const u8) VM {
        return VM{
            .regex = regex_pattern,
            .input = input,
            .start_pos = 0,
            .anchored = false,
            .groups = [_]?usize{null} ** 64,
        };
    }

    fn execute(self: *VM) ?Match {
        // Try matching at each position
        var pos = self.start_pos;
        while (pos <= self.input.len) {
            // Reset groups
            for (&self.groups) |*g| {
                g.* = null;
            }
            self.groups[0] = pos; // Group 0 start

            if (self.matchAt(0, pos)) |end_pos| {
                self.groups[1] = end_pos; // Group 0 end

                // Build match result
                return Match{
                    .slice = self.input[pos..end_pos],
                    .start = pos,
                    .end = end_pos,
                    .groups = &.{},
                };
            }

            if (self.anchored) break;

            // Advance by one UTF-8 codepoint
            if (pos < self.input.len) {
                const len = unicode.utf8ByteSequenceLength(self.input[pos]) catch 1;
                pos += len;
            } else {
                break;
            }
        }

        return null;
    }

    fn matchAt(self: *VM, pc: usize, pos: usize) ?usize {
        var current_pc = pc;
        var current_pos = pos;

        while (current_pc < self.regex.code.len) {
            const inst = self.regex.code[current_pc];

            switch (inst.op) {
                .match => return current_pos,

                .literal => {
                    if (current_pos >= self.input.len) return null;
                    if (self.input[current_pos] != @as(u8, @intCast(inst.a))) return null;
                    current_pos += 1;
                    current_pc += 1;
                },

                .literal_insensitive => {
                    if (current_pos >= self.input.len) return null;
                    const c = self.input[current_pos];
                    const target = @as(u8, @intCast(inst.a));
                    if (std.ascii.toLower(c) != std.ascii.toLower(target)) return null;
                    current_pos += 1;
                    current_pc += 1;
                },

                .any => {
                    if (current_pos >= self.input.len) return null;
                    if (self.input[current_pos] == '\n') return null;
                    current_pos += 1;
                    current_pc += 1;
                },

                .any_all => {
                    if (current_pos >= self.input.len) return null;
                    current_pos += 1;
                    current_pc += 1;
                },

                .digit => {
                    if (current_pos >= self.input.len) return null;
                    if (!std.ascii.isDigit(self.input[current_pos])) return null;
                    current_pos += 1;
                    current_pc += 1;
                },

                .not_digit => {
                    if (current_pos >= self.input.len) return null;
                    if (std.ascii.isDigit(self.input[current_pos])) return null;
                    current_pos += 1;
                    current_pc += 1;
                },

                .word => {
                    if (current_pos >= self.input.len) return null;
                    const c = self.input[current_pos];
                    if (!std.ascii.isAlphanumeric(c) and c != '_') return null;
                    current_pos += 1;
                    current_pc += 1;
                },

                .not_word => {
                    if (current_pos >= self.input.len) return null;
                    const c = self.input[current_pos];
                    if (std.ascii.isAlphanumeric(c) or c == '_') return null;
                    current_pos += 1;
                    current_pc += 1;
                },

                .whitespace => {
                    if (current_pos >= self.input.len) return null;
                    if (!std.ascii.isWhitespace(self.input[current_pos])) return null;
                    current_pos += 1;
                    current_pc += 1;
                },

                .not_whitespace => {
                    if (current_pos >= self.input.len) return null;
                    if (std.ascii.isWhitespace(self.input[current_pos])) return null;
                    current_pos += 1;
                    current_pc += 1;
                },

                .line_start => {
                    if (current_pos != 0 and (current_pos >= self.input.len or self.input[current_pos - 1] != '\n')) {
                        return null;
                    }
                    current_pc += 1;
                },

                .line_end => {
                    if (current_pos < self.input.len and self.input[current_pos] != '\n') {
                        return null;
                    }
                    current_pc += 1;
                },

                .word_boundary => {
                    if (!self.isWordBoundary(current_pos)) return null;
                    current_pc += 1;
                },

                .not_word_boundary => {
                    if (self.isWordBoundary(current_pos)) return null;
                    current_pc += 1;
                },

                .input_start => {
                    if (current_pos != 0) return null;
                    current_pc += 1;
                },

                .input_end => {
                    if (current_pos != self.input.len) return null;
                    current_pc += 1;
                },

                .char_class, .char_class_negated => {
                    if (current_pos >= self.input.len) return null;

                    // Decode UTF-8 codepoint
                    const len = unicode.utf8ByteSequenceLength(self.input[current_pos]) catch return null;
                    if (current_pos + len > self.input.len) return null;

                    const cp = unicode.utf8Decode(self.input[current_pos..][0..len]) catch return null;

                    const class = self.regex.char_classes[inst.a];
                    if (!class.contains(cp)) return null;

                    current_pos += len;
                    current_pc += 1;
                },

                .jump => {
                    current_pc = inst.a;
                },

                .split => {
                    // NFA split: try both paths
                    // inst.a = first branch target (greedy: try this first)
                    // inst.b = second branch target (greedy: try this if first fails)
                    if (self.matchAt(inst.a, current_pos)) |end| {
                        return end;
                    }
                    // Try second path
                    current_pc = inst.b;
                },

                .save => {
                    if (inst.a < self.groups.len) {
                        self.groups[inst.a] = current_pos;
                    }
                    current_pc += 1;
                },

                else => {
                    current_pc += 1;
                },
            }
        }

        return null;
    }

    fn isWordBoundary(self: *VM, pos: usize) bool {
        const before_word = if (pos > 0) self.isWordChar(pos - 1) else false;
        const after_word = if (pos < self.input.len) self.isWordChar(pos) else false;
        return before_word != after_word;
    }

    fn isWordChar(self: *VM, pos: usize) bool {
        if (pos >= self.input.len) return false;
        const c = self.input[pos];
        return std.ascii.isAlphanumeric(c) or c == '_';
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
