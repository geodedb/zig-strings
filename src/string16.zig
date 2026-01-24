// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! UTF-16 backed String type.
//!
//! This module provides a String16 type that stores text in UTF-16 encoding,
//! useful for interoperability with systems that use UTF-16 (Windows APIs, etc.).

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const utf8 = @import("utf8");
const utf16 = @import("utf16");
const iterator_mod = @import("iterator");
const search = @import("search");
const comparison = @import("comparison");
const manipulation = @import("manipulation");
const case_mod = @import("case");
const grapheme_mod = @import("grapheme");
const normalization = @import("normalization");
const transcoding = @import("transcoding");

pub const Codepoint = types.Codepoint;
pub const StringError = types.StringError;

/// A UTF-16 encoded string with ownership semantics
pub const String16 = struct {
    data: []u16,
    allocator: std.mem.Allocator,

    /// Creates a new empty String16
    pub fn init(allocator: std.mem.Allocator) String16 {
        return .{
            .data = &.{},
            .allocator = allocator,
        };
    }

    /// Creates a String16 from a UTF-16 slice (makes a copy)
    pub fn fromSlice(allocator: std.mem.Allocator, slice: []const u16) !String16 {
        const data = try allocator.alloc(u16, slice.len);
        @memcpy(data, slice);
        return .{
            .data = data,
            .allocator = allocator,
        };
    }

    /// Creates a String16 from a UTF-8 string
    pub fn fromUtf8(allocator: std.mem.Allocator, utf8_str: []const u8) !String16 {
        const utf16_len = utf8.utf16Length(utf8_str) orelse return StringError.InvalidUtf8;
        var data = try allocator.alloc(u16, utf16_len);
        errdefer allocator.free(data);

        var iter = utf8.iterator(utf8_str);
        var offset: usize = 0;

        while (iter.next()) |cp| {
            var units_buf: [2]u16 = undefined;
            const encoded = codepoint_mod.encodeUtf16(cp, &units_buf);
            for (encoded) |unit| {
                data[offset] = unit;
                offset += 1;
            }
        }

        return .{
            .data = data,
            .allocator = allocator,
        };
    }

    /// Creates a String16 by taking ownership of existing memory
    pub fn fromOwned(allocator: std.mem.Allocator, data: []u16) String16 {
        return .{
            .data = data,
            .allocator = allocator,
        };
    }

    /// Frees the string's memory
    pub fn deinit(self: *String16) void {
        if (self.data.len > 0) {
            self.allocator.free(self.data);
        }
        self.data = &.{};
    }

    /// Returns the underlying UTF-16 code units
    pub fn units(self: String16) []const u16 {
        return self.data;
    }

    /// Returns the number of UTF-16 code units
    pub fn len(self: String16) usize {
        return self.data.len;
    }

    /// Returns whether the string is empty
    pub fn isEmpty(self: String16) bool {
        return self.data.len == 0;
    }

    /// Returns the number of code points
    pub fn codepointCount(self: String16) ?usize {
        return utf16.countCodepoints(self.data);
    }

    // ============================================================
    // Iteration
    // ============================================================

    /// Returns an iterator over code points
    pub fn codepoints(self: String16) utf16.Iterator {
        return utf16.iterator(self.data);
    }

    // ============================================================
    // Conversion
    // ============================================================

    /// Converts to UTF-8
    pub fn toUtf8(self: String16) ![]u8 {
        const utf8_len = utf16.utf8Length(self.data) orelse return StringError.InvalidUtf16;
        const result = try self.allocator.alloc(u8, utf8_len);
        errdefer self.allocator.free(result);

        const written = try utf16.toUtf8(self.data, result);
        return result[0..written];
    }

    /// Creates a copy of the string
    pub fn clone(self: String16) !String16 {
        return String16.fromSlice(self.allocator, self.data);
    }

    // ============================================================
    // Comparison
    // ============================================================

    /// Checks equality with another String16
    pub fn eql(self: String16, other: []const u16) bool {
        return std.mem.eql(u16, self.data, other);
    }

    // ============================================================
    // Manipulation
    // ============================================================

    /// Appends another UTF-16 string
    pub fn append(self: *String16, other: []const u16) !void {
        if (other.len == 0) return;

        const new_len = self.data.len + other.len;
        const new_data = try self.allocator.alloc(u16, new_len);
        @memcpy(new_data[0..self.data.len], self.data);
        @memcpy(new_data[self.data.len..], other);

        if (self.data.len > 0) {
            self.allocator.free(self.data);
        }
        self.data = new_data;
    }

    /// Appends a UTF-8 string
    pub fn appendUtf8(self: *String16, utf8_str: []const u8) !void {
        const utf16_len = utf8.utf16Length(utf8_str) orelse return StringError.InvalidUtf8;
        var temp = try self.allocator.alloc(u16, utf16_len);
        defer self.allocator.free(temp);

        var iter = utf8.iterator(utf8_str);
        var offset: usize = 0;

        while (iter.next()) |cp| {
            var units_buf: [2]u16 = undefined;
            const encoded = codepoint_mod.encodeUtf16(cp, &units_buf);
            for (encoded) |unit| {
                temp[offset] = unit;
                offset += 1;
            }
        }

        try self.append(temp[0..offset]);
    }

    /// Concatenates with another string
    pub fn concat(self: String16, other: []const u16) !String16 {
        const new_len = self.data.len + other.len;
        var result = try self.allocator.alloc(u16, new_len);
        @memcpy(result[0..self.data.len], self.data);
        @memcpy(result[self.data.len..], other);
        return String16.fromOwned(self.allocator, result);
    }

    // ============================================================
    // Byte representation
    // ============================================================

    /// Returns the UTF-16 data as little-endian bytes
    pub fn toBytesLE(self: String16) ![]u8 {
        var result = try self.allocator.alloc(u8, self.data.len * 2);
        for (self.data, 0..) |unit, i| {
            std.mem.writeInt(u16, result[i * 2 ..][0..2], unit, .little);
        }
        return result;
    }

    /// Returns the UTF-16 data as big-endian bytes
    pub fn toBytesBE(self: String16) ![]u8 {
        var result = try self.allocator.alloc(u8, self.data.len * 2);
        for (self.data, 0..) |unit, i| {
            std.mem.writeInt(u16, result[i * 2 ..][0..2], unit, .big);
        }
        return result;
    }

    /// Creates a String16 from little-endian bytes
    pub fn fromBytesLE(allocator: std.mem.Allocator, bytes: []const u8) !String16 {
        if (bytes.len % 2 != 0) return StringError.TruncatedSequence;

        const data = try allocator.alloc(u16, bytes.len / 2);
        errdefer allocator.free(data);

        for (data, 0..) |*unit, i| {
            unit.* = std.mem.readInt(u16, bytes[i * 2 ..][0..2], .little);
        }

        return .{
            .data = data,
            .allocator = allocator,
        };
    }

    /// Creates a String16 from big-endian bytes
    pub fn fromBytesBE(allocator: std.mem.Allocator, bytes: []const u8) !String16 {
        if (bytes.len % 2 != 0) return StringError.TruncatedSequence;

        const data = try allocator.alloc(u16, bytes.len / 2);
        errdefer allocator.free(data);

        for (data, 0..) |*unit, i| {
            unit.* = std.mem.readInt(u16, bytes[i * 2 ..][0..2], .big);
        }

        return .{
            .data = data,
            .allocator = allocator,
        };
    }
};

test "String16.fromUtf8" {
    const testing = std.testing;

    var str = try String16.fromUtf8(testing.allocator, "Hello");
    defer str.deinit();

    try testing.expectEqual(@as(usize, 5), str.len());
    try testing.expectEqualSlices(u16, &[_]u16{ 'H', 'e', 'l', 'l', 'o' }, str.units());
}

test "String16.fromUtf8 with emoji" {
    const testing = std.testing;

    var str = try String16.fromUtf8(testing.allocator, "\xF0\x9F\x98\x80"); // emoji
    defer str.deinit();

    try testing.expectEqual(@as(usize, 2), str.len()); // Surrogate pair
    try testing.expectEqualSlices(u16, &[_]u16{ 0xD83D, 0xDE00 }, str.units());
}

test "String16.toUtf8" {
    const testing = std.testing;

    var str = try String16.fromSlice(testing.allocator, &[_]u16{ 'H', 'e', 'l', 'l', 'o' });
    defer str.deinit();

    const utf8_bytes = try str.toUtf8();
    defer testing.allocator.free(utf8_bytes);

    try testing.expectEqualSlices(u8, "Hello", utf8_bytes);
}

test "String16.codepointCount" {
    const testing = std.testing;

    var str = try String16.fromSlice(testing.allocator, &[_]u16{ 'A', 0xD83D, 0xDE00, 'B' });
    defer str.deinit();

    try testing.expectEqual(@as(?usize, 3), str.codepointCount()); // A, emoji, B
}

test "String16.append" {
    const testing = std.testing;

    var str = try String16.fromUtf8(testing.allocator, "Hello");
    defer str.deinit();

    try str.append(&[_]u16{ ',', ' ' });
    try str.appendUtf8("World!");

    const utf8_bytes = try str.toUtf8();
    defer testing.allocator.free(utf8_bytes);

    try testing.expectEqualSlices(u8, "Hello, World!", utf8_bytes);
}
