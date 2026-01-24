// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String interning pool.
//!
//! This module provides a string interning pool that deduplicates
//! strings and provides stable references for efficient comparison.

const std = @import("std");
const types = @import("types");
const string_mod = @import("string");

pub const String = string_mod.String;

/// A string interning pool that deduplicates strings
pub const StringPool = struct {
    allocator: std.mem.Allocator,
    strings: std.StringHashMapUnmanaged(void),
    entries: std.ArrayList([]const u8) = .empty,

    /// Creates a new string pool
    pub fn init(allocator: std.mem.Allocator) StringPool {
        return .{
            .allocator = allocator,
            .strings = .{},
        };
    }

    /// Frees all memory used by the pool
    pub fn deinit(self: *StringPool) void {
        // Free all interned strings
        for (self.entries.items) |entry| {
            self.allocator.free(entry);
        }
        self.entries.deinit(self.allocator);
        self.strings.deinit(self.allocator);
    }

    /// Interns a string, returning a stable pointer to it.
    /// If the string already exists, returns the existing pointer.
    pub fn intern(self: *StringPool, str: []const u8) ![]const u8 {
        // Check if already interned
        if (self.strings.getKey(str)) |existing| {
            return existing;
        }

        // Create new interned string
        const owned = try self.allocator.dupe(u8, str);
        errdefer self.allocator.free(owned);

        try self.strings.put(self.allocator, owned, {});
        try self.entries.append(self.allocator, owned);

        return owned;
    }

    /// Checks if a string is interned
    pub fn contains(self: *const StringPool, str: []const u8) bool {
        return self.strings.contains(str);
    }

    /// Gets the interned version of a string if it exists
    pub fn get(self: *const StringPool, str: []const u8) ?[]const u8 {
        return self.strings.getKey(str);
    }

    /// Returns the number of interned strings
    pub fn count(self: *const StringPool) usize {
        return self.entries.items.len;
    }

    /// Clears all interned strings
    pub fn clear(self: *StringPool) void {
        for (self.entries.items) |entry| {
            self.allocator.free(entry);
        }
        self.entries.clearRetainingCapacity();
        self.strings.clearRetainingCapacity();
    }

    /// Returns an iterator over all interned strings
    pub fn iterator(self: *const StringPool) []const []const u8 {
        return self.entries.items;
    }
};

/// A simple symbol table using string interning
pub const SymbolTable = struct {
    pool: StringPool,
    symbols: std.StringHashMapUnmanaged(usize),
    next_id: usize,

    /// Creates a new symbol table
    pub fn init(allocator: std.mem.Allocator) SymbolTable {
        return .{
            .pool = StringPool.init(allocator),
            .symbols = .{},
            .next_id = 0,
        };
    }

    /// Frees all memory used by the symbol table
    pub fn deinit(self: *SymbolTable) void {
        self.symbols.deinit(self.pool.allocator);
        self.pool.deinit();
    }

    /// Gets or creates a symbol ID for a string
    pub fn getOrPut(self: *SymbolTable, name: []const u8) !usize {
        // Check if symbol already exists
        if (self.symbols.get(name)) |id| {
            return id;
        }

        // Intern the string and create new symbol
        const interned = try self.pool.intern(name);
        const id = self.next_id;
        self.next_id += 1;

        try self.symbols.put(self.pool.allocator, interned, id);
        return id;
    }

    /// Gets the symbol ID if it exists
    pub fn get(self: *const SymbolTable, name: []const u8) ?usize {
        return self.symbols.get(name);
    }

    /// Checks if a symbol exists
    pub fn contains(self: *const SymbolTable, name: []const u8) bool {
        return self.symbols.contains(name);
    }

    /// Returns the number of symbols
    pub fn count(self: *const SymbolTable) usize {
        return self.next_id;
    }
};

test "StringPool basic operations" {
    const testing = std.testing;

    var pool = StringPool.init(testing.allocator);
    defer pool.deinit();

    const str1 = try pool.intern("hello");
    const str2 = try pool.intern("world");
    const str3 = try pool.intern("hello"); // Should return same pointer

    try testing.expect(str1.ptr == str3.ptr);
    try testing.expect(str1.ptr != str2.ptr);
    try testing.expectEqual(@as(usize, 2), pool.count());
}

test "StringPool contains" {
    const testing = std.testing;

    var pool = StringPool.init(testing.allocator);
    defer pool.deinit();

    _ = try pool.intern("hello");
    try testing.expect(pool.contains("hello"));
    try testing.expect(!pool.contains("world"));
}

test "StringPool get" {
    const testing = std.testing;

    var pool = StringPool.init(testing.allocator);
    defer pool.deinit();

    const interned = try pool.intern("hello");
    const retrieved = pool.get("hello");

    try testing.expect(retrieved != null);
    try testing.expect(interned.ptr == retrieved.?.ptr);
    try testing.expect(pool.get("world") == null);
}

test "SymbolTable basic operations" {
    const testing = std.testing;

    var table = SymbolTable.init(testing.allocator);
    defer table.deinit();

    const id1 = try table.getOrPut("foo");
    const id2 = try table.getOrPut("bar");
    const id3 = try table.getOrPut("foo"); // Should return same ID

    try testing.expectEqual(id1, id3);
    try testing.expect(id1 != id2);
    try testing.expectEqual(@as(usize, 2), table.count());
}

test "SymbolTable get" {
    const testing = std.testing;

    var table = SymbolTable.init(testing.allocator);
    defer table.deinit();

    const id = try table.getOrPut("foo");
    try testing.expectEqual(id, table.get("foo").?);
    try testing.expect(table.get("bar") == null);
}
