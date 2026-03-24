// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String builder for efficient concatenation.
//!
//! This module provides a StringBuilder type for efficiently building
//! strings through multiple append operations.

const std = @import("std");
const types = @import("types");
const utf8_mod = @import("utf8");
const string_mod = @import("string");

pub const Codepoint = types.Codepoint;
pub const StringError = types.StringError;
pub const String = string_mod.String;

/// A buffer for efficiently building strings
pub const StringBuilder = struct {
    buffer: std.ArrayList(u8) = .empty,
    allocator: std.mem.Allocator,

    /// Creates a new empty StringBuilder
    pub fn init(allocator: std.mem.Allocator) StringBuilder {
        return .{
            .allocator = allocator,
        };
    }

    /// Creates a StringBuilder with pre-allocated capacity
    pub fn initCapacity(allocator: std.mem.Allocator, initial_capacity: usize) !StringBuilder {
        var builder = StringBuilder.init(allocator);
        try builder.buffer.ensureTotalCapacity(allocator, initial_capacity);
        return builder;
    }

    /// Frees the builder's memory
    pub fn deinit(self: *StringBuilder) void {
        self.buffer.deinit(self.allocator);
    }

    /// Returns the current length
    pub fn len(self: StringBuilder) usize {
        return self.buffer.items.len;
    }

    /// Returns the current capacity
    pub fn capacity(self: StringBuilder) usize {
        return self.buffer.capacity;
    }

    /// Returns whether the builder is empty
    pub fn isEmpty(self: StringBuilder) bool {
        return self.buffer.items.len == 0;
    }

    /// Appends a string
    pub fn append(self: *StringBuilder, str: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, str);
    }

    /// Appends a single byte
    pub fn appendByte(self: *StringBuilder, byte: u8) !void {
        try self.buffer.append(self.allocator, byte);
    }

    /// Appends a code point
    pub fn appendCodepoint(self: *StringBuilder, cp: Codepoint) !void {
        var buf: [4]u8 = undefined;
        const encoded_len = std.unicode.utf8Encode(cp, &buf) catch return StringError.InvalidCodepoint;
        try self.buffer.appendSlice(self.allocator, buf[0..encoded_len]);
    }

    /// Appends multiple code points
    pub fn appendCodepoints(self: *StringBuilder, cps: []const Codepoint) !void {
        for (cps) |cp| {
            try self.appendCodepoint(cp);
        }
    }

    /// Appends a character repeated n times
    pub fn appendRepeat(self: *StringBuilder, str: []const u8, n: usize) !void {
        const total = std.math.mul(usize, str.len, n) catch return error.OutOfMemory;
        try self.buffer.ensureUnusedCapacity(self.allocator, total);
        for (0..n) |_| {
            self.buffer.appendSliceAssumeCapacity(str);
        }
    }

    /// Appends a formatted string
    pub fn appendFmt(self: *StringBuilder, comptime fmt: []const u8, args: anytype) !void {
        try self.buffer.writer(self.allocator).print(fmt, args);
    }

    /// Appends a line (string + newline)
    pub fn appendLine(self: *StringBuilder, str: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, str);
        try self.buffer.append(self.allocator, '\n');
    }

    /// Appends an integer
    pub fn appendInt(self: *StringBuilder, value: anytype) !void {
        try self.buffer.writer(self.allocator).print("{}", .{value});
    }

    /// Appends a float
    pub fn appendFloat(self: *StringBuilder, value: anytype) !void {
        try self.buffer.writer(self.allocator).print("{d}", .{value});
    }

    /// Clears the builder
    pub fn clear(self: *StringBuilder) void {
        self.buffer.clearRetainingCapacity();
    }

    /// Resets and frees all memory
    pub fn reset(self: *StringBuilder) void {
        self.buffer.clearAndFree(self.allocator);
    }

    /// Returns the built string as a slice (view into buffer)
    pub fn slice(self: StringBuilder) []const u8 {
        return self.buffer.items;
    }

    /// Returns the built string, transferring ownership
    pub fn toOwnedSlice(self: *StringBuilder) ![]u8 {
        return self.buffer.toOwnedSlice(self.allocator);
    }

    /// Creates a String from the builder contents
    pub fn toString(self: StringBuilder) !String {
        return String.fromSlice(self.allocator, self.buffer.items);
    }

    /// Creates a String from the builder, transferring ownership
    pub fn toOwnedString(self: *StringBuilder) !String {
        const data = try self.buffer.toOwnedSlice(self.allocator);
        return String.fromOwned(self.allocator, data);
    }

    /// Ensures capacity for at least n more bytes
    pub fn ensureCapacity(self: *StringBuilder, additional: usize) !void {
        try self.buffer.ensureUnusedCapacity(self.allocator, additional);
    }

    /// Returns a writer interface
    pub fn writer(self: *StringBuilder) std.ArrayList(u8).Writer {
        return self.buffer.writer(self.allocator);
    }

    /// Replaces all occurrences of old with new
    pub fn replace(self: *StringBuilder, old: []const u8, new: []const u8) !void {
        if (old.len == 0) return;

        var new_buffer: std.ArrayList(u8) = .empty;
        errdefer new_buffer.deinit(self.allocator);

        // Pre-allocate roughly the same size as the current buffer
        try new_buffer.ensureTotalCapacity(self.allocator, self.buffer.items.len);

        var pos: usize = 0;
        while (pos < self.buffer.items.len) {
            if (std.mem.indexOf(u8, self.buffer.items[pos..], old)) |idx| {
                // Bulk-copy bytes before the match
                try new_buffer.appendSlice(self.allocator, self.buffer.items[pos .. pos + idx]);
                // Copy replacement
                try new_buffer.appendSlice(self.allocator, new);
                pos += idx + old.len;
            } else {
                // Bulk-copy all remaining bytes (no more matches)
                try new_buffer.appendSlice(self.allocator, self.buffer.items[pos..]);
                break;
            }
        }

        self.buffer.deinit(self.allocator);
        self.buffer = new_buffer;
    }

    /// Inserts a string at the specified position
    pub fn insert(self: *StringBuilder, pos: usize, str: []const u8) !void {
        try self.buffer.insertSlice(self.allocator, pos, str);
    }

    /// Removes characters from start to end
    pub fn remove(self: *StringBuilder, start: usize, end: usize) void {
        if (start >= self.buffer.items.len or start >= end) return;
        const actual_end = @min(end, self.buffer.items.len);
        std.mem.copyForwards(u8, self.buffer.items[start..], self.buffer.items[actual_end..]);
        self.buffer.items.len -= actual_end - start;
    }

    /// Sets a byte at the specified position
    pub fn set(self: *StringBuilder, pos: usize, byte: u8) void {
        if (pos < self.buffer.items.len) {
            self.buffer.items[pos] = byte;
        }
    }

    /// Gets a byte at the specified position
    pub fn get(self: StringBuilder, pos: usize) ?u8 {
        if (pos < self.buffer.items.len) {
            return self.buffer.items[pos];
        }
        return null;
    }
};

test "StringBuilder basic operations" {
    const testing = std.testing;

    var builder = StringBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.append("Hello");
    try builder.append(", ");
    try builder.append("World!");

    try testing.expectEqualSlices(u8, "Hello, World!", builder.slice());
}

test "StringBuilder appendFmt" {
    const testing = std.testing;

    var builder = StringBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.appendFmt("Value: {d}", .{42});
    try testing.expectEqualSlices(u8, "Value: 42", builder.slice());
}

test "StringBuilder appendCodepoint" {
    const testing = std.testing;

    var builder = StringBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.appendCodepoint('A');
    try builder.appendCodepoint(0x00E9); // é
    try builder.appendCodepoint(0x4E2D); // 中

    try testing.expectEqualSlices(u8, "A\xC3\xA9\xE4\xB8\xAD", builder.slice());
}

test "StringBuilder replace" {
    const testing = std.testing;

    var builder = StringBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.append("Hello, World!");
    try builder.replace("World", "Zig");

    try testing.expectEqualSlices(u8, "Hello, Zig!", builder.slice());
}

test "StringBuilder insert and remove" {
    const testing = std.testing;

    var builder = StringBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.append("Hello!");
    try builder.insert(5, ", World");

    try testing.expectEqualSlices(u8, "Hello, World!", builder.slice());

    builder.remove(5, 12); // Remove ", World"
    try testing.expectEqualSlices(u8, "Hello!", builder.slice());
}

test "StringBuilder toOwnedSlice" {
    const testing = std.testing;

    var builder = StringBuilder.init(testing.allocator);

    try builder.append("Test");
    const owned = try builder.toOwnedSlice();
    defer testing.allocator.free(owned);

    try testing.expectEqualSlices(u8, "Test", owned);
    try testing.expectEqual(@as(usize, 0), builder.len());
}

test "StringBuilder appendRepeat" {
    const testing = std.testing;

    var builder = StringBuilder.init(testing.allocator);
    defer builder.deinit();

    try builder.appendRepeat("ab", 3);
    try testing.expectEqualSlices(u8, "ababab", builder.slice());
}
