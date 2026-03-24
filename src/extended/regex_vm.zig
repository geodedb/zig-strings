// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Regex virtual machine -- executes compiled regex bytecode against input.
//!
//! Extracted from `regex.zig` as part of Q49 file-size refactoring.
//! The VM interprets the `Instruction` sequence produced by the compiler
//! (in `regex_compiler.zig`) using backtracking with ReDoS and recursion
//! depth protection.

const std = @import("std");
const unicode = std.unicode;

const types = @import("regex_types.zig");
const compiler_mod = @import("regex_compiler.zig");

const Opcode = types.Opcode;
const Instruction = types.Instruction;
const CharClass = types.CharClass;
const Match = types.Match;
const CompiledPattern = types.CompiledPattern;

const matchesUnicodeProperty = compiler_mod.matchesUnicodeProperty;

/// Virtual machine for regex execution
pub const VM = struct {
    /// Maximum number of steps before the VM aborts to prevent ReDoS.
    /// Patterns that cause exponential backtracking (e.g., `(a+)+b` against
    /// a long string of 'a's) will hit this limit and return null instead
    /// of hanging.
    pub const MAX_STEPS: usize = 1_000_000;

    /// Maximum recursion depth for matchAt() to prevent stack overflow.
    /// Deeply nested patterns like `(((...)))` with nested quantifiers
    /// generate cascading `split` opcodes that recurse in matchAt().
    /// Without this limit, O(1000+) nested groups could overflow the
    /// call stack before MAX_STEPS is reached.
    pub const MAX_RECURSION_DEPTH: usize = 500;

    pattern: CompiledPattern,
    input: []const u8,
    start_pos: usize,
    anchored: bool,
    groups: [64]?usize, // Max 32 groups (start/end pairs)
    step_count: usize,
    recursion_depth: usize,

    pub fn init(pattern: CompiledPattern, input: []const u8) VM {
        return VM{
            .pattern = pattern,
            .input = input,
            .start_pos = 0,
            .anchored = false,
            .groups = [_]?usize{null} ** 64,
            .step_count = 0,
            .recursion_depth = 0,
        };
    }

    pub fn execute(self: *VM) ?Match {
        // Global step budget for this execute() call -- NOT reset per position.
        // This prevents ReDoS where O(N * MAX_STEPS) total work is possible
        // when the counter resets at each starting position (S17).
        self.step_count = 0;

        // Try matching at each position
        var pos = self.start_pos;
        while (pos <= self.input.len) {
            // Reset groups for this starting position
            for (&self.groups) |*g| {
                g.* = null;
            }
            self.groups[0] = pos; // Group 0 start

            if (self.matchAt(0, pos)) |end_pos| {
                self.groups[1] = end_pos; // Group 0 end

                // Build match result with captured groups
                const num_groups = self.pattern.num_groups;
                var match_result = Match{
                    .slice = self.input[pos..end_pos],
                    .start = pos,
                    .end = end_pos,
                    .group_count = num_groups,
                    .group_data = [_]?Match.Group{null} ** Match.MAX_GROUPS,
                };

                // Populate group data from the VM's saved positions.
                // Each group i has start at groups[i*2] and end at groups[i*2+1].
                var gi: usize = 0;
                while (gi < num_groups and gi < Match.MAX_GROUPS) : (gi += 1) {
                    const start_slot = gi * 2;
                    const end_slot = gi * 2 + 1;
                    if (start_slot < self.groups.len and end_slot < self.groups.len) {
                        if (self.groups[start_slot]) |gs| {
                            if (self.groups[end_slot]) |ge| {
                                match_result.group_data[gi] = Match.Group{
                                    .slice = self.input[gs..ge],
                                    .start = gs,
                                    .end = ge,
                                };
                            }
                        }
                    }
                }

                return match_result;
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

        while (current_pc < self.pattern.code.len) {
            // Increment step counter and bail out if budget exceeded (ReDoS protection)
            self.step_count += 1;
            if (self.step_count > MAX_STEPS) return null;

            const inst = self.pattern.code[current_pc];

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

                    const class = self.pattern.char_classes[inst.a];
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

                    // Guard against stack overflow from deeply nested patterns
                    if (self.recursion_depth >= MAX_RECURSION_DEPTH) return null;

                    self.recursion_depth += 1;
                    const result = self.matchAt(inst.a, current_pos);
                    self.recursion_depth -= 1;

                    if (result) |end| {
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

                .unicode_prop => {
                    if (current_pos >= self.input.len) return null;

                    // Decode UTF-8 codepoint
                    const len = unicode.utf8ByteSequenceLength(self.input[current_pos]) catch return null;
                    if (current_pos + len > self.input.len) return null;
                    const cp = unicode.utf8Decode(self.input[current_pos..][0..len]) catch return null;

                    if (!matchesUnicodeProperty(cp, inst.a)) return null;

                    current_pos += len;
                    current_pc += 1;
                },

                .unicode_prop_neg => {
                    if (current_pos >= self.input.len) return null;

                    // Decode UTF-8 codepoint
                    const len = unicode.utf8ByteSequenceLength(self.input[current_pos]) catch return null;
                    if (current_pos + len > self.input.len) return null;
                    const cp = unicode.utf8Decode(self.input[current_pos..][0..len]) catch return null;

                    if (matchesUnicodeProperty(cp, inst.a)) return null;

                    current_pos += len;
                    current_pc += 1;
                },

                // repeat_greedy and repeat_lazy are compiled away into split/jump
                // instructions during compilation and should never appear at runtime.
                .repeat_greedy, .repeat_lazy => unreachable,
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

const Compiler = @import("regex_compiler.zig").Compiler;

/// Helper: compile a pattern and return the CompiledPattern for VM tests.
/// Caller must call freeCompiled when done.
const TestCompiled = struct {
    pattern: CompiledPattern,
    code_slice: []Instruction,
    char_classes_slice: []const types.CharClass,
    pat_slice: []const u8,
    allocator: std.mem.Allocator,

    fn deinit(self: *TestCompiled) void {
        self.allocator.free(self.code_slice);
        for (self.char_classes_slice) |cc| {
            self.allocator.free(cc.ranges);
        }
        self.allocator.free(self.char_classes_slice);
        self.allocator.free(self.pat_slice);
    }
};

fn testCompile(allocator: std.mem.Allocator, pat: []const u8) !TestCompiled {
    var compiler = Compiler.init(allocator);
    defer compiler.deinit();
    const result = try compiler.compile(pat);
    return TestCompiled{
        .pattern = .{
            .code = result.code,
            .char_classes = result.char_classes,
            .num_groups = result.num_groups,
        },
        .code_slice = result.code,
        .char_classes_slice = result.char_classes,
        .pat_slice = result.pattern,
        .allocator = allocator,
    };
}

test "ReDoS protection: (a+)+b against many a's completes quickly" {
    // GAP-0004: Pattern (a+)+b causes exponential backtracking without step limit.
    // With the step counter, the VM aborts and returns null instead of hanging.
    const testing = std.testing;

    var compiled = try testCompile(testing.allocator, "(a+)+b");
    defer compiled.deinit();

    // 25 a's with no trailing 'b' -- classic ReDoS trigger
    const input = "aaaaaaaaaaaaaaaaaaaaaaaaa";
    var vm = VM.init(compiled.pattern, input);
    try testing.expect(vm.execute() == null);
}

test "S17: global step budget prevents ReDoS across starting positions" {
    // S17: With the per-position step_count reset, a pathological pattern like
    // (a+)+b on a long input of 'a' characters could take O(N * MAX_STEPS) total
    // steps. With the global budget (step_count set once per execute()), the VM
    // exhausts its budget quickly and returns null without hanging.
    const testing = std.testing;

    var compiled = try testCompile(testing.allocator, "(a+)+b");
    defer compiled.deinit();

    // Use a 10,000-byte input of 'a' with no trailing 'b'.
    // Old behavior: O(10_000 * 1_000_000) = 10 billion steps (hangs).
    // New behavior: 1_000_000 steps total, then abort. Should complete in <1s.
    const input = "a" ** 10_000;

    const start = std.time.nanoTimestamp();
    var vm = VM.init(compiled.pattern, input);
    const result = vm.execute();
    const elapsed_ns = std.time.nanoTimestamp() - start;

    // Must not match (no trailing 'b')
    try testing.expect(result == null);

    // Must complete within 5 seconds (generous bound; typically <100ms)
    const five_seconds_ns: i128 = 5 * std.time.ns_per_s;
    try testing.expect(elapsed_ns < five_seconds_ns);
}

test "R4: deeply nested groups do not cause stack overflow" {
    // Deeply nested quantified groups like (?:(?:(?:...a...)+)+)+ generate
    // cascading split opcodes that recurse in matchAt(). Without a recursion
    // depth limit, O(1000+) levels could overflow the call stack.
    const testing = std.testing;

    const depth = 200;
    var pattern_buf: [depth * 4 + 1 + depth * 2]u8 = undefined;
    var offset: usize = 0;

    for (0..depth) |_| {
        @memcpy(pattern_buf[offset..][0..4], "(?:.");
        offset += 4;
    }

    pattern_buf[offset] = 'a';
    offset += 1;

    for (0..depth) |_| {
        @memcpy(pattern_buf[offset..][0..2], ")+");
        offset += 2;
    }

    const pattern = pattern_buf[0..offset];

    // The pattern may hit PatternTooComplex, which is acceptable.
    const compile_result = testCompile(testing.allocator, pattern);
    if (compile_result) |*c| {
        var compiled = c.*;
        defer compiled.deinit();

        // Try matching -- should complete without stack overflow.
        var vm1 = VM.init(compiled.pattern, "aaa");
        _ = vm1.execute();

        var vm2 = VM.init(compiled.pattern, "a");
        _ = vm2.execute();
    } else |err| {
        try testing.expect(err == types.RegexError.PatternTooComplex);
    }
}

test "R4: MAX_RECURSION_DEPTH prevents stack overflow on pathological split chains" {
    const testing = std.testing;

    var compiled = try testCompile(testing.allocator, "(a+)+b");
    defer compiled.deinit();

    // Build a string of 500 'a's with no 'b' -- forces maximum backtracking.
    var input: [500]u8 = undefined;
    @memset(&input, 'a');

    var vm = VM.init(compiled.pattern, &input);
    // Must not crash; returns null because there is no 'b'
    try testing.expect(vm.execute() == null);
}
