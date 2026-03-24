// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Lazy Unicode Normalization
//!
//! Provides deferred normalization that only computes the normalized form
//! when it's actually needed. This is useful for performance when:
//!
//! - Strings may never need to be normalized (e.g., ASCII-only)
//! - Normalization form is checked before use
//! - Multiple operations can share cached normalized data
//!
//! Usage:
//! ```zig
//! var lazy = LazyString.init(allocator, "café");
//! defer lazy.deinit();
//!
//! // Original bytes accessed without normalization
//! _ = lazy.bytes();
//!
//! // Normalization happens only when requested
//! const nfc = try lazy.normalized(.nfc);
//! ```

const std = @import("std");
const normalization = @import("normalization");
const types = @import("types");

pub const NormalizationForm = types.NormalizationForm;
pub const Codepoint = types.Codepoint;

/// Normalization state
pub const NormState = enum {
    /// Not yet checked or normalized
    unknown,
    /// Known to already be in normalized form
    already_normalized,
    /// Normalized form is cached
    cached,
};

/// A lazily-normalized string wrapper
pub const LazyString = struct {
    /// Original string data
    original: []const u8,
    /// Whether we own the original data
    owns_original: bool,

    /// Cached NFC form
    nfc_cache: ?[]const u8,
    nfc_state: NormState,

    /// Cached NFD form
    nfd_cache: ?[]const u8,
    nfd_state: NormState,

    /// Cached NFKC form
    nfkc_cache: ?[]const u8,
    nfkc_state: NormState,

    /// Cached NFKD form
    nfkd_cache: ?[]const u8,
    nfkd_state: NormState,

    /// Allocator for normalized forms
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize with a borrowed string (does not take ownership)
    pub fn init(allocator: std.mem.Allocator, data: []const u8) Self {
        return Self{
            .original = data,
            .owns_original = false,
            .nfc_cache = null,
            .nfc_state = .unknown,
            .nfd_cache = null,
            .nfd_state = .unknown,
            .nfkc_cache = null,
            .nfkc_state = .unknown,
            .nfkd_cache = null,
            .nfkd_state = .unknown,
            .allocator = allocator,
        };
    }

    /// Initialize with an owned string (takes ownership)
    pub fn initOwned(allocator: std.mem.Allocator, data: []const u8) !Self {
        const owned = try allocator.dupe(u8, data);
        return Self{
            .original = owned,
            .owns_original = true,
            .nfc_cache = null,
            .nfc_state = .unknown,
            .nfd_cache = null,
            .nfd_state = .unknown,
            .nfkc_cache = null,
            .nfkc_state = .unknown,
            .nfkd_cache = null,
            .nfkd_state = .unknown,
            .allocator = allocator,
        };
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        if (self.nfc_cache) |cache| {
            self.allocator.free(cache);
            self.nfc_cache = null;
        }
        if (self.nfd_cache) |cache| {
            self.allocator.free(cache);
            self.nfd_cache = null;
        }
        if (self.nfkc_cache) |cache| {
            self.allocator.free(cache);
            self.nfkc_cache = null;
        }
        if (self.nfkd_cache) |cache| {
            self.allocator.free(cache);
            self.nfkd_cache = null;
        }
        if (self.owns_original) {
            self.allocator.free(self.original);
            self.original = "";
            self.owns_original = false;
        }
    }

    /// Get the original bytes (no normalization)
    pub fn bytes(self: Self) []const u8 {
        return self.original;
    }

    /// Get length of original data
    pub fn len(self: Self) usize {
        return self.original.len;
    }

    /// Check if the string is ASCII-only (never needs normalization)
    pub fn isAscii(self: Self) bool {
        for (self.original) |b| {
            if (b > 127) return false;
        }
        return true;
    }

    /// Quick check if already in a given normalization form
    pub fn isNormalized(self: *Self, form: NormalizationForm) bool {
        const state = self.getState(form);
        if (state == .already_normalized or state == .cached) {
            return true;
        }

        // ASCII strings are always normalized
        if (self.isAscii()) {
            self.setState(form, .already_normalized);
            return true;
        }

        // Do the actual check
        const result = normalization.isNormalized(self.original, form);
        if (result) {
            self.setState(form, .already_normalized);
        }
        return result;
    }

    /// Get the normalized form (lazy evaluation)
    pub fn normalized(self: *Self, form: NormalizationForm) ![]const u8 {
        // Check if already normalized
        const state = self.getState(form);
        switch (state) {
            .already_normalized => return self.original,
            .cached => return self.getCache(form).?,
            .unknown => {},
        }

        // ASCII strings don't need normalization
        if (self.isAscii()) {
            self.setState(form, .already_normalized);
            return self.original;
        }

        // Check if original is already in the requested form
        if (normalization.isNormalized(self.original, form)) {
            self.setState(form, .already_normalized);
            return self.original;
        }

        // Perform normalization
        const result = normalization.normalize(self.allocator, self.original, form) catch {
            return error.NormalizationFailed;
        };

        // Cache the result
        self.setCache(form, result);
        self.setState(form, .cached);

        return result;
    }

    /// Get NFC normalized form
    pub fn nfc(self: *Self) ![]const u8 {
        return self.normalized(.nfc);
    }

    /// Get NFD normalized form
    pub fn nfd(self: *Self) ![]const u8 {
        return self.normalized(.nfd);
    }

    /// Get NFKC normalized form
    pub fn nfkc(self: *Self) ![]const u8 {
        return self.normalized(.nfkc);
    }

    /// Get NFKD normalized form
    pub fn nfkd(self: *Self) ![]const u8 {
        return self.normalized(.nfkd);
    }

    /// Invalidate all cached normalized forms (call after modifying original)
    pub fn invalidate(self: *Self) void {
        if (self.nfc_cache) |cache| {
            self.allocator.free(cache);
            self.nfc_cache = null;
        }
        self.nfc_state = .unknown;

        if (self.nfd_cache) |cache| {
            self.allocator.free(cache);
            self.nfd_cache = null;
        }
        self.nfd_state = .unknown;

        if (self.nfkc_cache) |cache| {
            self.allocator.free(cache);
            self.nfkc_cache = null;
        }
        self.nfkc_state = .unknown;

        if (self.nfkd_cache) |cache| {
            self.allocator.free(cache);
            self.nfkd_cache = null;
        }
        self.nfkd_state = .unknown;
    }

    /// Compare two LazyStrings using a specific normalization form
    pub fn equals(self: *Self, other: *Self, form: NormalizationForm) !bool {
        const a = try self.normalized(form);
        const b = try other.normalized(form);
        return std.mem.eql(u8, a, b);
    }

    /// Compare with a regular string using a specific normalization form
    pub fn equalsString(self: *Self, other: []const u8, form: NormalizationForm) !bool {
        const a = try self.normalized(form);
        const b = normalization.normalize(self.allocator, other, form) catch return false;
        defer self.allocator.free(b);
        return std.mem.eql(u8, a, b);
    }

    // Internal helpers

    fn getState(self: Self, form: NormalizationForm) NormState {
        return switch (form) {
            .nfc => self.nfc_state,
            .nfd => self.nfd_state,
            .nfkc => self.nfkc_state,
            .nfkd => self.nfkd_state,
        };
    }

    fn setState(self: *Self, form: NormalizationForm, state: NormState) void {
        switch (form) {
            .nfc => self.nfc_state = state,
            .nfd => self.nfd_state = state,
            .nfkc => self.nfkc_state = state,
            .nfkd => self.nfkd_state = state,
        }
    }

    fn getCache(self: Self, form: NormalizationForm) ?[]const u8 {
        return switch (form) {
            .nfc => self.nfc_cache,
            .nfd => self.nfd_cache,
            .nfkc => self.nfkc_cache,
            .nfkd => self.nfkd_cache,
        };
    }

    fn setCache(self: *Self, form: NormalizationForm, data: []const u8) void {
        switch (form) {
            .nfc => self.nfc_cache = data,
            .nfd => self.nfd_cache = data,
            .nfkc => self.nfkc_cache = data,
            .nfkd => self.nfkd_cache = data,
        }
    }
};

/// Pool of lazily-normalized strings with shared allocator
pub const LazyStringPool = struct {
    strings: std.ArrayList(LazyString),
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Creates an empty lazy string pool with the given allocator.
    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .strings = std.ArrayList(LazyString).init(allocator),
            .allocator = allocator,
        };
    }

    /// Frees all pooled strings and the pool itself.
    pub fn deinit(self: *Self) void {
        for (self.strings.items) |*s| {
            s.deinit();
        }
        self.strings.deinit();
    }

    /// Add a string to the pool (borrowed)
    pub fn add(self: *Self, data: []const u8) !*LazyString {
        try self.strings.append(LazyString.init(self.allocator, data));
        return &self.strings.items[self.strings.items.len - 1];
    }

    /// Add a string to the pool (owned copy)
    pub fn addOwned(self: *Self, data: []const u8) !*LazyString {
        try self.strings.append(try LazyString.initOwned(self.allocator, data));
        return &self.strings.items[self.strings.items.len - 1];
    }

    /// Get count of strings in pool
    pub fn count(self: Self) usize {
        return self.strings.items.len;
    }

    /// Normalize all strings in the pool to a given form
    pub fn normalizeAll(self: *Self, form: NormalizationForm) !void {
        for (self.strings.items) |*s| {
            _ = try s.normalized(form);
        }
    }

    /// Invalidate all caches in the pool
    pub fn invalidateAll(self: *Self) void {
        for (self.strings.items) |*s| {
            s.invalidate();
        }
    }
};

/// Helper to batch-normalize multiple strings efficiently
pub fn batchNormalize(
    allocator: std.mem.Allocator,
    strings: []const []const u8,
    form: NormalizationForm,
) ![][]const u8 {
    const results = try allocator.alloc([]const u8, strings.len);
    errdefer allocator.free(results);

    for (strings, 0..) |s, i| {
        // ASCII strings don't need normalization
        var is_ascii = true;
        for (s) |b| {
            if (b > 127) {
                is_ascii = false;
                break;
            }
        }

        if (is_ascii or normalization.isNormalized(s, form)) {
            results[i] = s;
        } else {
            results[i] = normalization.normalize(allocator, s, form) catch {
                // Free already allocated results on error
                var j: usize = 0;
                while (j < i) : (j += 1) {
                    if (results[j].ptr != strings[j].ptr) {
                        allocator.free(results[j]);
                    }
                }
                return error.NormalizationFailed;
            };
        }
    }

    return results;
}

/// Free results from batchNormalize
pub fn freeBatchResults(
    allocator: std.mem.Allocator,
    results: [][]const u8,
    originals: []const []const u8,
) void {
    for (results, 0..) |r, i| {
        if (r.ptr != originals[i].ptr) {
            allocator.free(r);
        }
    }
    allocator.free(results);
}

// ============================================================
// Tests
// ============================================================

test "LazyString basic operations" {
    const testing = std.testing;

    const data = "Hello, World!";
    var lazy = LazyString.init(testing.allocator, data);
    defer lazy.deinit();

    try testing.expectEqualStrings(data, lazy.bytes());
    try testing.expectEqual(data.len, lazy.len());
    try testing.expect(lazy.isAscii());
}

test "LazyString ASCII normalization" {
    const testing = std.testing;

    const data = "Hello, World!";
    var lazy = LazyString.init(testing.allocator, data);
    defer lazy.deinit();

    // ASCII is always already normalized
    try testing.expect(lazy.isNormalized(.nfc));
    try testing.expect(lazy.isNormalized(.nfd));

    // Should return original for ASCII
    const nfc = try lazy.nfc();
    try testing.expectEqualStrings(data, nfc);
    try testing.expectEqual(NormState.already_normalized, lazy.nfc_state);
}

test "LazyString caching" {
    const testing = std.testing;

    // NFD text: e + combining acute
    const nfd_text = "e\xCC\x81";
    var lazy = LazyString.init(testing.allocator, nfd_text);
    defer lazy.deinit();

    // First access triggers normalization
    const nfc1 = try lazy.nfc();
    try testing.expectEqual(NormState.cached, lazy.nfc_state);

    // Second access uses cache
    const nfc2 = try lazy.nfc();
    try testing.expectEqual(nfc1.ptr, nfc2.ptr);
}

test "LazyString invalidation" {
    const testing = std.testing;

    const data = "test";
    var lazy = LazyString.init(testing.allocator, data);
    defer lazy.deinit();

    // Build up cache
    _ = try lazy.nfc();
    try testing.expectEqual(NormState.already_normalized, lazy.nfc_state);

    // Invalidate
    lazy.invalidate();
    try testing.expectEqual(NormState.unknown, lazy.nfc_state);
}

test "LazyStringPool" {
    const testing = std.testing;

    var pool = LazyStringPool.init(testing.allocator);
    defer pool.deinit();

    _ = try pool.add("Hello");
    _ = try pool.add("World");

    try testing.expectEqual(@as(usize, 2), pool.count());

    // Normalize all to NFC
    try pool.normalizeAll(.nfc);
}

test "LazyString owned vs borrowed" {
    const testing = std.testing;

    // Borrowed (does not own)
    var borrowed_data = "borrowed".*;
    var borrowed = LazyString.init(testing.allocator, &borrowed_data);
    defer borrowed.deinit();
    try testing.expect(!borrowed.owns_original);

    // Owned (takes ownership)
    var owned = try LazyString.initOwned(testing.allocator, "owned");
    defer owned.deinit();
    try testing.expect(owned.owns_original);
}
