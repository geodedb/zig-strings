// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! UTF-8 backed String type with Small String Optimization (SSO).
//!
//! This module provides a high-level String type that wraps UTF-8 encoded
//! byte sequences with convenient methods for manipulation and access.
//! Strings <= 23 bytes are stored inline without heap allocation.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const utf8 = @import("utf8");
const utf16_mod = @import("utf16");
const iterator_mod = @import("iterator");
const search = @import("search");
const comparison = @import("comparison");
const manipulation = @import("manipulation");
const case_mod = @import("case");
const grapheme_mod = @import("grapheme");
const normalization = @import("normalization");

pub const Codepoint = types.Codepoint;
pub const StringError = types.StringError;
pub const CompareOptions = types.CompareOptions;

/// SSO capacity - strings up to this size are stored inline
pub const SSO_CAPACITY: usize = 23;

/// A UTF-8 encoded string with Small String Optimization (SSO)
///
/// Strings up to 23 bytes are stored inline without heap allocation.
/// Larger strings use heap allocation.
pub const String = struct {
    /// Storage union - either inline buffer or heap allocation
    storage: Storage,
    allocator: std.mem.Allocator,

    const Storage = union(enum) {
        inline_storage: InlineStorage,
        heap: HeapStorage,
    };

    const InlineStorage = struct {
        buf: [SSO_CAPACITY]u8,
        len: u8,
    };

    const HeapStorage = struct {
        ptr: [*]u8,
        len: usize,
        cap: usize,
    };

    /// Returns true if the string is using inline storage (SSO)
    pub fn isInline(self: String) bool {
        return self.storage == .inline_storage;
    }

    /// Creates a new empty String (uses inline storage)
    pub fn init(allocator: std.mem.Allocator) String {
        return .{
            .storage = .{
                .inline_storage = .{
                    .buf = undefined,
                    .len = 0,
                },
            },
            .allocator = allocator,
        };
    }

    /// Creates a String from a slice (makes a copy)
    pub fn fromSlice(allocator: std.mem.Allocator, slice: []const u8) !String {
        if (slice.len <= SSO_CAPACITY) {
            // Use inline storage
            var result: String = .{
                .storage = .{
                    .inline_storage = .{
                        .buf = undefined,
                        .len = @intCast(slice.len),
                    },
                },
                .allocator = allocator,
            };
            @memcpy(result.storage.inline_storage.buf[0..slice.len], slice);
            return result;
        } else {
            // Use heap storage
            const data = try allocator.alloc(u8, slice.len);
            @memcpy(data, slice);
            return .{
                .storage = .{
                    .heap = .{
                        .ptr = data.ptr,
                        .len = slice.len,
                        .cap = slice.len,
                    },
                },
                .allocator = allocator,
            };
        }
    }

    /// Creates a String by taking ownership of existing memory
    /// Note: The memory must have been allocated with the same allocator.
    /// This always uses heap storage regardless of size.
    pub fn fromOwned(allocator: std.mem.Allocator, data: []u8) String {
        if (data.len == 0) {
            return String.init(allocator);
        }
        return .{
            .storage = .{
                .heap = .{
                    .ptr = data.ptr,
                    .len = data.len,
                    .cap = data.len,
                },
            },
            .allocator = allocator,
        };
    }

    /// Frees the string's memory (only if heap-allocated)
    pub fn deinit(self: *String) void {
        switch (self.storage) {
            .inline_storage => {
                // Nothing to free for inline storage
            },
            .heap => |h| {
                if (h.cap > 0) {
                    self.allocator.free(h.ptr[0..h.cap]);
                }
            },
        }
        // Reset to empty inline string
        self.storage = .{ .inline_storage = .{ .buf = undefined, .len = 0 } };
    }

    /// Returns the underlying UTF-8 bytes
    pub fn bytes(self: *const String) []const u8 {
        return switch (self.storage) {
            .inline_storage => |*i| i.buf[0..i.len],
            .heap => |h| h.ptr[0..h.len],
        };
    }

    /// Returns a mutable slice to the underlying bytes
    pub fn mutableBytes(self: *String) []u8 {
        return switch (self.storage) {
            .inline_storage => |*i| i.buf[0..i.len],
            .heap => |h| h.ptr[0..h.len],
        };
    }

    /// Returns the byte length
    pub fn len(self: String) usize {
        return switch (self.storage) {
            .inline_storage => |i| i.len,
            .heap => |h| h.len,
        };
    }

    /// Returns the capacity (inline capacity or heap capacity)
    pub fn capacity(self: String) usize {
        return switch (self.storage) {
            .inline_storage => SSO_CAPACITY,
            .heap => |h| h.cap,
        };
    }

    /// Returns whether the string is empty
    pub fn isEmpty(self: String) bool {
        return self.len() == 0;
    }

    /// Returns the number of code points
    pub fn codepointCount(self: String) ?usize {
        return utf8.countCodepoints(self.bytes());
    }

    /// Returns the number of grapheme clusters
    pub fn graphemeCount(self: String) usize {
        return grapheme_mod.count(self.bytes());
    }

    // ============================================================
    // Iteration
    // ============================================================

    /// Returns an iterator over code points
    pub fn codepoints(self: String) utf8.Iterator {
        return utf8.iterator(self.bytes());
    }

    /// Returns an iterator over grapheme clusters
    pub fn graphemes(self: String) grapheme_mod.Iterator {
        return grapheme_mod.iterator(self.bytes());
    }

    /// Returns an iterator over lines
    pub fn lines(self: String) iterator_mod.LineIterator {
        return iterator_mod.lines(self.bytes());
    }

    // ============================================================
    // Search
    // ============================================================

    /// Finds the first occurrence of a substring
    pub fn indexOf(self: String, needle: []const u8) ?usize {
        return search.indexOf(self.bytes(), needle);
    }

    /// Finds the last occurrence of a substring
    pub fn lastIndexOf(self: String, needle: []const u8) ?usize {
        return search.lastIndexOf(self.bytes(), needle);
    }

    /// Checks if the string contains a substring
    pub fn contains(self: String, needle: []const u8) bool {
        return search.contains(self.bytes(), needle);
    }

    /// Checks if the string starts with a prefix
    pub fn startsWith(self: String, prefix: []const u8) bool {
        return search.startsWith(self.bytes(), prefix);
    }

    /// Checks if the string ends with a suffix
    pub fn endsWith(self: String, suffix: []const u8) bool {
        return search.endsWith(self.bytes(), suffix);
    }

    /// Counts occurrences of a substring
    pub fn count(self: String, needle: []const u8) usize {
        return search.count(self.bytes(), needle);
    }

    // ============================================================
    // Comparison
    // ============================================================

    /// Compares with another string
    pub fn compare(self: String, other: []const u8) std.math.Order {
        return comparison.compare(self.bytes(), other);
    }

    /// Checks equality with another string
    pub fn eql(self: String, other: []const u8) bool {
        return comparison.equals(self.bytes(), other);
    }

    /// Compares case-insensitively
    pub fn compareIgnoreCase(self: String, other: []const u8) std.math.Order {
        return comparison.compareIgnoreCase(self.bytes(), other);
    }

    /// Checks equality case-insensitively
    pub fn eqlIgnoreCase(self: String, other: []const u8) bool {
        return comparison.equalsIgnoreCase(self.bytes(), other);
    }

    // ============================================================
    // Manipulation (returns new String)
    // ============================================================

    /// Creates a new string with leading/trailing whitespace removed
    pub fn trimmed(self: String) !String {
        const trimmed_slice = manipulation.trim(self.bytes());
        return String.fromSlice(self.allocator, trimmed_slice);
    }

    /// Creates a new string converted to lowercase
    pub fn toLower(self: String) !String {
        const lower = try case_mod.toLowerString(self.allocator, self.bytes());
        return String.fromOwned(self.allocator, lower);
    }

    /// Creates a new string converted to uppercase
    pub fn toUpper(self: String) !String {
        const upper = try case_mod.toUpperString(self.allocator, self.bytes());
        return String.fromOwned(self.allocator, upper);
    }

    /// Creates a new string converted to title case
    pub fn toTitle(self: String) !String {
        const title = try case_mod.toTitleString(self.allocator, self.bytes());
        return String.fromOwned(self.allocator, title);
    }

    /// Creates a new string with replacements
    pub fn replaced(self: String, old: []const u8, new: []const u8) !String {
        const result = try manipulation.replace(self.allocator, self.bytes(), old, new);
        return String.fromOwned(self.allocator, result);
    }

    /// Creates a new reversed string
    pub fn reversed(self: String) !String {
        const result = try manipulation.reverse(self.allocator, self.bytes());
        return String.fromOwned(self.allocator, result);
    }

    /// Splits the string by a delimiter
    pub fn split(self: String, delimiter: []const u8) ![][]const u8 {
        return manipulation.split(self.allocator, self.bytes(), delimiter);
    }

    /// Returns a substring by code point indices
    pub fn substring(self: String, start: usize, end_opt: ?usize) []const u8 {
        return manipulation.substring(self.bytes(), start, end_opt);
    }

    // ============================================================
    // Concatenation
    // ============================================================

    /// Appends another string
    pub fn append(self: *String, other: []const u8) !void {
        if (other.len == 0) return;

        const current_len = self.len();
        const new_len = current_len + other.len;

        switch (self.storage) {
            .inline_storage => |*i| {
                if (new_len <= SSO_CAPACITY) {
                    // Can stay inline
                    @memcpy(i.buf[current_len..][0..other.len], other);
                    i.len = @intCast(new_len);
                } else {
                    // Must transition to heap
                    const new_data = try self.allocator.alloc(u8, new_len);
                    @memcpy(new_data[0..current_len], i.buf[0..current_len]);
                    @memcpy(new_data[current_len..], other);
                    self.storage = .{
                        .heap = .{
                            .ptr = new_data.ptr,
                            .len = new_len,
                            .cap = new_len,
                        },
                    };
                }
            },
            .heap => |*h| {
                // Already on heap
                if (new_len <= h.cap) {
                    // Fits in existing capacity
                    @memcpy(h.ptr[current_len..][0..other.len], other);
                    h.len = new_len;
                } else {
                    // Need to reallocate
                    const new_cap = @max(new_len, h.cap * 2);
                    const new_data = try self.allocator.alloc(u8, new_cap);
                    @memcpy(new_data[0..current_len], h.ptr[0..current_len]);
                    @memcpy(new_data[current_len..][0..other.len], other);
                    self.allocator.free(h.ptr[0..h.cap]);
                    h.ptr = new_data.ptr;
                    h.len = new_len;
                    h.cap = new_cap;
                }
            },
        }
    }

    /// Concatenates with another string, returning a new String
    pub fn concat(self: String, other: []const u8) !String {
        const parts = [_][]const u8{ self.bytes(), other };
        const result = try manipulation.concat(self.allocator, &parts);
        return String.fromOwned(self.allocator, result);
    }

    /// Repeats the string n times
    pub fn repeat(self: String, n: usize) !String {
        const result = try manipulation.repeat(self.allocator, self.bytes(), n);
        return String.fromOwned(self.allocator, result);
    }

    // ============================================================
    // Normalization
    // ============================================================

    /// Normalizes the string to the specified form
    pub fn normalize(self: String, form: types.NormalizationForm) !String {
        const result = try normalization.normalize(self.allocator, self.bytes(), form);
        return String.fromOwned(self.allocator, result);
    }

    // ============================================================
    // Conversion
    // ============================================================

    /// Creates a copy of the string
    pub fn clone(self: String) !String {
        return String.fromSlice(self.allocator, self.bytes());
    }

    /// Converts to a UTF-16 byte array
    pub fn toUtf16(self: String, endian: std.builtin.Endian) ![]u8 {
        const data = self.bytes();
        const utf16_len = utf8.utf16Length(data) orelse return StringError.InvalidUtf8;
        var result = try self.allocator.alloc(u8, utf16_len * 2);
        errdefer self.allocator.free(result);

        var iter = utf8.iterator(data);
        var offset: usize = 0;

        while (iter.next()) |cp| {
            var units: [2]u16 = undefined;
            const encoded = codepoint_mod.encodeUtf16(cp, &units);
            for (encoded) |unit| {
                std.mem.writeInt(u16, result[offset..][0..2], unit, endian);
                offset += 2;
            }
        }

        return result;
    }

    /// Creates a String from UTF-16 encoded bytes
    pub fn fromUtf16(allocator: std.mem.Allocator, utf16_bytes: []const u8, endian: std.builtin.Endian) !String {
        if (utf16_bytes.len % 2 != 0) {
            return StringError.InvalidEncoding;
        }

        // First pass: calculate UTF-8 length
        var utf8_len: usize = 0;
        var i: usize = 0;
        while (i < utf16_bytes.len) {
            const unit = std.mem.readInt(u16, utf16_bytes[i..][0..2], endian);
            i += 2;

            var cp: Codepoint = undefined;
            if (unit >= 0xD800 and unit <= 0xDBFF) {
                // High surrogate - need low surrogate
                if (i + 2 > utf16_bytes.len) return StringError.InvalidEncoding;
                const low = std.mem.readInt(u16, utf16_bytes[i..][0..2], endian);
                i += 2;
                if (low < 0xDC00 or low > 0xDFFF) return StringError.InvalidEncoding;
                const high: u32 = unit;
                const low32: u32 = low;
                cp = @intCast(((high - 0xD800) << 10) + (low32 - 0xDC00) + 0x10000);
            } else if (unit >= 0xDC00 and unit <= 0xDFFF) {
                return StringError.InvalidEncoding; // Lone low surrogate
            } else {
                cp = @intCast(unit);
            }

            utf8_len += codepoint_mod.utf8Length(cp);
        }

        // Allocate and encode
        const result = try allocator.alloc(u8, utf8_len);
        errdefer allocator.free(result);

        var out_idx: usize = 0;
        i = 0;
        var encode_buf: [4]u8 = undefined;
        while (i < utf16_bytes.len) {
            const unit = std.mem.readInt(u16, utf16_bytes[i..][0..2], endian);
            i += 2;

            var cp: Codepoint = undefined;
            if (unit >= 0xD800 and unit <= 0xDBFF) {
                const low = std.mem.readInt(u16, utf16_bytes[i..][0..2], endian);
                i += 2;
                const high: u32 = unit;
                const low32: u32 = low;
                cp = @intCast(((high - 0xD800) << 10) + (low32 - 0xDC00) + 0x10000);
            } else {
                cp = @intCast(unit);
            }

            const encoded = codepoint_mod.encodeUtf8(cp, &encode_buf);
            @memcpy(result[out_idx..][0..encoded.len], encoded);
            out_idx += encoded.len;
        }

        return String.fromOwned(allocator, result);
    }
};

// ============================================================
// Tests
// ============================================================

test "String.init" {
    const testing = std.testing;

    const str = String.init(testing.allocator);
    try testing.expect(str.isInline());
    try testing.expect(str.isEmpty());
    try testing.expectEqual(@as(usize, 0), str.len());
}

test "String.fromSlice inline" {
    const testing = std.testing;

    var str = try String.fromSlice(testing.allocator, "Hello");
    defer str.deinit();

    try testing.expect(str.isInline());
    try testing.expectEqualSlices(u8, "Hello", str.bytes());
    try testing.expectEqual(@as(usize, 5), str.len());
}

test "String.fromSlice inline max" {
    const testing = std.testing;

    // Test at SSO threshold (23 bytes)
    const threshold_str = "12345678901234567890123"; // 23 bytes
    var str = try String.fromSlice(testing.allocator, threshold_str);
    defer str.deinit();

    try testing.expect(str.isInline());
    try testing.expectEqualSlices(u8, threshold_str, str.bytes());
    try testing.expectEqual(@as(usize, 23), str.len());
}

test "String.fromSlice heap" {
    const testing = std.testing;

    // Test beyond SSO threshold (24 bytes)
    const heap_str = "123456789012345678901234"; // 24 bytes
    var str = try String.fromSlice(testing.allocator, heap_str);
    defer str.deinit();

    try testing.expect(!str.isInline());
    try testing.expectEqualSlices(u8, heap_str, str.bytes());
    try testing.expectEqual(@as(usize, 24), str.len());
}

test "String.codepointCount" {
    const testing = std.testing;

    var str = try String.fromSlice(testing.allocator, "A\xC3\xA9B"); // "AéB"
    defer str.deinit();

    try testing.expectEqual(@as(?usize, 3), str.codepointCount());
}

test "String.contains" {
    const testing = std.testing;

    var str = try String.fromSlice(testing.allocator, "Hello, World!");
    defer str.deinit();

    try testing.expect(str.contains("World"));
    try testing.expect(!str.contains("xyz"));
}

test "String.toLower" {
    const testing = std.testing;

    var str = try String.fromSlice(testing.allocator, "HELLO");
    defer str.deinit();

    var lower = try str.toLower();
    defer lower.deinit();

    try testing.expectEqualSlices(u8, "hello", lower.bytes());
}

test "String.replaced" {
    const testing = std.testing;

    var str = try String.fromSlice(testing.allocator, "Hello, World!");
    defer str.deinit();

    var replaced_str = try str.replaced("World", "Zig");
    defer replaced_str.deinit();

    try testing.expectEqualSlices(u8, "Hello, Zig!", replaced_str.bytes());
}

test "String.append inline to inline" {
    const testing = std.testing;

    var str = try String.fromSlice(testing.allocator, "Hello");
    defer str.deinit();

    try str.append(", Hi");
    try testing.expect(str.isInline());
    try testing.expectEqualSlices(u8, "Hello, Hi", str.bytes());
}

test "String.append inline to heap" {
    const testing = std.testing;

    var str = try String.fromSlice(testing.allocator, "Hello");
    defer str.deinit();

    try str.append(", World! This is longer!");
    try testing.expect(!str.isInline());
    try testing.expectEqualSlices(u8, "Hello, World! This is longer!", str.bytes());
}

test "String.split" {
    const testing = std.testing;

    var str = try String.fromSlice(testing.allocator, "a,b,c");
    defer str.deinit();

    const parts = try str.split(",");
    defer testing.allocator.free(parts);

    try testing.expectEqual(@as(usize, 3), parts.len);
    try testing.expectEqualSlices(u8, "a", parts[0]);
    try testing.expectEqualSlices(u8, "b", parts[1]);
    try testing.expectEqualSlices(u8, "c", parts[2]);
}

test "String.clone" {
    const testing = std.testing;

    var original = try String.fromSlice(testing.allocator, "Hello");
    defer original.deinit();

    var cloned = try original.clone();
    defer cloned.deinit();

    try testing.expectEqualSlices(u8, "Hello", cloned.bytes());
    try testing.expect(cloned.isInline());
}

test "String SSO transition" {
    const testing = std.testing;

    var str = String.init(testing.allocator);
    defer str.deinit();

    // Start empty (inline)
    try testing.expect(str.isInline());

    // Append small amount (still inline)
    try str.append("Hello");
    try testing.expect(str.isInline());

    // Append more (transition to heap)
    try str.append(" World! This is a long string that exceeds SSO.");
    try testing.expect(!str.isInline());
    try testing.expect(std.mem.startsWith(u8, str.bytes(), "Hello World!"));
}
