// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! SIMD-accelerated string operations.
//!
//! This module provides SIMD-optimized implementations of common
//! string operations when available on the target platform.
//!
//! Supports multiple SIMD widths with automatic selection:
//! - AVX-512: 64-byte vectors (512 bits)
//! - AVX2: 32-byte vectors (256 bits)
//! - SSE2/NEON: 16-byte vectors (128 bits)
//!
//! Sub-modules:
//! - `simd_case`: ASCII case conversion (toLowerAscii, toUpperAscii)
//! - `simd_mem`: Memory operations (memcpySimd, memsetSimd)

const std = @import("std");
const types = @import("types");
const builtin = @import("builtin");

// Sub-module imports
const simd_case = @import("simd_case.zig");
const simd_mem = @import("simd_mem.zig");

// Re-export sub-module functions to preserve public API
pub const toLowerAscii = simd_case.toLowerAscii;
pub const toUpperAscii = simd_case.toUpperAscii;
pub const memcpySimd = simd_mem.memcpySimd;
pub const memsetSimd = simd_mem.memsetSimd;

// Ensure sub-module tests are included
comptime {
    _ = simd_case;
    _ = simd_mem;
}

// ============================================================
// SIMD Width Detection and Types
// ============================================================

/// SIMD instruction set levels
pub const SimdLevel = enum {
    none,
    sse2, // 128-bit
    avx2, // 256-bit
    avx512, // 512-bit
};

/// Detects the best available SIMD level at compile time
pub fn detectSimdLevel() SimdLevel {
    if (builtin.cpu.arch == .x86_64 or builtin.cpu.arch == .x86) {
        const features = builtin.cpu.features;
        if (std.Target.x86.featureSetHas(features, .avx512f) and
            std.Target.x86.featureSetHas(features, .avx512bw))
        {
            return .avx512;
        }
        if (std.Target.x86.featureSetHas(features, .avx2)) {
            return .avx2;
        }
        if (std.Target.x86.featureSetHas(features, .sse2)) {
            return .sse2;
        }
    } else if (builtin.cpu.arch == .aarch64) {
        if (std.Target.aarch64.featureSetHas(builtin.cpu.features, .neon)) {
            return .sse2; // NEON is 128-bit like SSE2
        }
    }
    return .none;
}

/// Current SIMD level (compile-time constant)
pub const simd_level = detectSimdLevel();

/// Vector sizes for different SIMD levels
pub const vector_size_128 = 16;
pub const vector_size_256 = 32;
pub const vector_size_512 = 64;

/// Default vector size based on detected SIMD level
pub const vector_size = switch (simd_level) {
    .avx512 => vector_size_512,
    .avx2 => vector_size_256,
    .sse2 => vector_size_128,
    .none => vector_size_128,
};

/// Vector types for different widths
pub const ByteVector16 = @Vector(vector_size_128, u8);
pub const ByteVector32 = @Vector(vector_size_256, u8);
pub const ByteVector64 = @Vector(vector_size_512, u8);

/// Default byte vector type
pub const ByteVector = @Vector(vector_size, u8);

/// Checks if SIMD acceleration is available for the target
pub fn isSimdAvailable() bool {
    return simd_level != .none;
}

/// Checks if AVX2 is available
pub fn isAvx2Available() bool {
    return simd_level == .avx2 or simd_level == .avx512;
}

/// Checks if AVX-512 is available
pub fn isAvx512Available() bool {
    return simd_level == .avx512;
}

// ============================================================
// Generic SIMD Operations (auto-selects best width)
// ============================================================

/// Finds the first occurrence of a byte using best available SIMD
pub fn findByte(haystack: []const u8, needle: u8) ?usize {
    if (haystack.len == 0) return null;

    // Use wider SIMD for larger inputs
    if (simd_level == .avx512 and haystack.len >= vector_size_512 * 2) {
        return findByte512(haystack, needle);
    } else if (simd_level == .avx2 and haystack.len >= vector_size_256 * 2) {
        return findByte256(haystack, needle);
    } else if (simd_level != .none and haystack.len >= vector_size_128 * 2) {
        return findByte128(haystack, needle);
    }

    return std.mem.indexOfScalar(u8, haystack, needle);
}

/// 128-bit SIMD findByte
fn findByte128(haystack: []const u8, needle: u8) ?usize {
    const needle_vec: ByteVector16 = @splat(needle);
    var i: usize = 0;

    while (i + vector_size_128 <= haystack.len) {
        const chunk: ByteVector16 = haystack[i..][0..vector_size_128].*;
        const matches = chunk == needle_vec;
        const mask = @as(u16, @bitCast(matches));

        if (mask != 0) {
            return i + @ctz(mask);
        }
        i += vector_size_128;
    }

    // Handle remaining bytes
    while (i < haystack.len) {
        if (haystack[i] == needle) return i;
        i += 1;
    }

    return null;
}

/// 256-bit SIMD findByte (AVX2)
fn findByte256(haystack: []const u8, needle: u8) ?usize {
    const needle_vec: ByteVector32 = @splat(needle);
    var i: usize = 0;

    while (i + vector_size_256 <= haystack.len) {
        const chunk: ByteVector32 = haystack[i..][0..vector_size_256].*;
        const matches = chunk == needle_vec;
        const mask = @as(u32, @bitCast(matches));

        if (mask != 0) {
            return i + @ctz(mask);
        }
        i += vector_size_256;
    }

    // Fall back to 128-bit for remainder
    if (i < haystack.len) {
        if (findByte128(haystack[i..], needle)) |pos| {
            return i + pos;
        }
    }

    return null;
}

/// 512-bit SIMD findByte (AVX-512)
fn findByte512(haystack: []const u8, needle: u8) ?usize {
    const needle_vec: ByteVector64 = @splat(needle);
    var i: usize = 0;

    while (i + vector_size_512 <= haystack.len) {
        const chunk: ByteVector64 = haystack[i..][0..vector_size_512].*;
        const matches = chunk == needle_vec;
        const mask = @as(u64, @bitCast(matches));

        if (mask != 0) {
            return i + @ctz(mask);
        }
        i += vector_size_512;
    }

    // Fall back to 256-bit for remainder
    if (i < haystack.len) {
        if (findByte256(haystack[i..], needle)) |pos| {
            return i + pos;
        }
    }

    return null;
}

/// Checks if all bytes in a slice are ASCII using best available SIMD
pub fn isAllAscii(bytes: []const u8) bool {
    if (bytes.len == 0) return true;

    if (simd_level == .avx512 and bytes.len >= vector_size_512) {
        return isAllAscii512(bytes);
    } else if (simd_level == .avx2 and bytes.len >= vector_size_256) {
        return isAllAscii256(bytes);
    } else if (simd_level != .none and bytes.len >= vector_size_128) {
        return isAllAscii128(bytes);
    }

    // Scalar fallback
    for (bytes) |b| {
        if (b & 0x80 != 0) return false;
    }
    return true;
}

fn isAllAscii128(bytes: []const u8) bool {
    const high_bit_mask: ByteVector16 = @splat(0x80);
    const zero_vec: ByteVector16 = @splat(0);
    var i: usize = 0;

    while (i + vector_size_128 <= bytes.len) {
        const chunk: ByteVector16 = bytes[i..][0..vector_size_128].*;
        const high_bits = chunk & high_bit_mask;

        if (@reduce(.Or, high_bits != zero_vec)) {
            return false;
        }
        i += vector_size_128;
    }

    while (i < bytes.len) {
        if (bytes[i] & 0x80 != 0) return false;
        i += 1;
    }

    return true;
}

fn isAllAscii256(bytes: []const u8) bool {
    const high_bit_mask: ByteVector32 = @splat(0x80);
    const zero_vec: ByteVector32 = @splat(0);
    var i: usize = 0;

    while (i + vector_size_256 <= bytes.len) {
        const chunk: ByteVector32 = bytes[i..][0..vector_size_256].*;
        const high_bits = chunk & high_bit_mask;

        if (@reduce(.Or, high_bits != zero_vec)) {
            return false;
        }
        i += vector_size_256;
    }

    // Handle remainder with 128-bit
    if (i < bytes.len) {
        return isAllAscii128(bytes[i..]);
    }

    return true;
}

fn isAllAscii512(bytes: []const u8) bool {
    const high_bit_mask: ByteVector64 = @splat(0x80);
    const zero_vec: ByteVector64 = @splat(0);
    var i: usize = 0;

    while (i + vector_size_512 <= bytes.len) {
        const chunk: ByteVector64 = bytes[i..][0..vector_size_512].*;
        const high_bits = chunk & high_bit_mask;

        if (@reduce(.Or, high_bits != zero_vec)) {
            return false;
        }
        i += vector_size_512;
    }

    // Handle remainder with 256-bit
    if (i < bytes.len) {
        return isAllAscii256(bytes[i..]);
    }

    return true;
}

// ============================================================
// Count and Compare Operations
// ============================================================

/// Counts occurrences of a byte using SIMD
pub fn countByte(haystack: []const u8, needle: u8) usize {
    if (haystack.len == 0) return 0;

    if (simd_level == .avx512 and haystack.len >= vector_size_512) {
        return countByte512(haystack, needle);
    } else if (simd_level == .avx2 and haystack.len >= vector_size_256) {
        return countByte256(haystack, needle);
    } else if (simd_level != .none and haystack.len >= vector_size_128) {
        return countByte128(haystack, needle);
    }

    var count: usize = 0;
    for (haystack) |b| {
        if (b == needle) count += 1;
    }
    return count;
}

fn countByte128(haystack: []const u8, needle: u8) usize {
    const needle_vec: ByteVector16 = @splat(needle);
    var count: usize = 0;
    var i: usize = 0;

    while (i + vector_size_128 <= haystack.len) {
        const chunk: ByteVector16 = haystack[i..][0..vector_size_128].*;
        const matches = chunk == needle_vec;
        count += @popCount(@as(u16, @bitCast(matches)));
        i += vector_size_128;
    }

    while (i < haystack.len) {
        if (haystack[i] == needle) count += 1;
        i += 1;
    }

    return count;
}

fn countByte256(haystack: []const u8, needle: u8) usize {
    const needle_vec: ByteVector32 = @splat(needle);
    var count: usize = 0;
    var i: usize = 0;

    while (i + vector_size_256 <= haystack.len) {
        const chunk: ByteVector32 = haystack[i..][0..vector_size_256].*;
        const matches = chunk == needle_vec;
        count += @popCount(@as(u32, @bitCast(matches)));
        i += vector_size_256;
    }

    if (i < haystack.len) {
        count += countByte128(haystack[i..], needle);
    }

    return count;
}

fn countByte512(haystack: []const u8, needle: u8) usize {
    const needle_vec: ByteVector64 = @splat(needle);
    var count: usize = 0;
    var i: usize = 0;

    while (i + vector_size_512 <= haystack.len) {
        const chunk: ByteVector64 = haystack[i..][0..vector_size_512].*;
        const matches = chunk == needle_vec;
        count += @popCount(@as(u64, @bitCast(matches)));
        i += vector_size_512;
    }

    if (i < haystack.len) {
        count += countByte256(haystack[i..], needle);
    }

    return count;
}

/// Compares two byte slices for equality using SIMD
pub fn equal(a: []const u8, b: []const u8) bool {
    if (a.len != b.len) return false;
    if (a.len == 0) return true;

    if (simd_level == .avx512 and a.len >= vector_size_512) {
        return equal512(a, b);
    } else if (simd_level == .avx2 and a.len >= vector_size_256) {
        return equal256(a, b);
    } else if (simd_level != .none and a.len >= vector_size_128) {
        return equal128(a, b);
    }

    return std.mem.eql(u8, a, b);
}

fn equal128(a: []const u8, b: []const u8) bool {
    var i: usize = 0;

    while (i + vector_size_128 <= a.len) {
        const chunk_a: ByteVector16 = a[i..][0..vector_size_128].*;
        const chunk_b: ByteVector16 = b[i..][0..vector_size_128].*;

        if (@reduce(.Or, chunk_a != chunk_b)) {
            return false;
        }
        i += vector_size_128;
    }

    while (i < a.len) {
        if (a[i] != b[i]) return false;
        i += 1;
    }

    return true;
}

fn equal256(a: []const u8, b: []const u8) bool {
    var i: usize = 0;

    while (i + vector_size_256 <= a.len) {
        const chunk_a: ByteVector32 = a[i..][0..vector_size_256].*;
        const chunk_b: ByteVector32 = b[i..][0..vector_size_256].*;

        if (@reduce(.Or, chunk_a != chunk_b)) {
            return false;
        }
        i += vector_size_256;
    }

    if (i < a.len) {
        return equal128(a[i..], b[i..]);
    }

    return true;
}

fn equal512(a: []const u8, b: []const u8) bool {
    var i: usize = 0;

    while (i + vector_size_512 <= a.len) {
        const chunk_a: ByteVector64 = a[i..][0..vector_size_512].*;
        const chunk_b: ByteVector64 = b[i..][0..vector_size_512].*;

        if (@reduce(.Or, chunk_a != chunk_b)) {
            return false;
        }
        i += vector_size_512;
    }

    if (i < a.len) {
        return equal256(a[i..], b[i..]);
    }

    return true;
}

// ============================================================
// UTF-8 Validation with SIMD
// ============================================================

/// Fast UTF-8 validation using SIMD
/// Returns true if the input is valid UTF-8
pub fn validateUtf8(bytes: []const u8) bool {
    if (bytes.len == 0) return true;

    // Fast path: if all ASCII, it's valid
    if (isAllAscii(bytes)) return true;

    // Fall back to standard validation for non-ASCII
    return std.unicode.utf8ValidateSlice(bytes);
}

/// Counts UTF-8 continuation bytes using SIMD
/// Useful for estimating codepoint count: len - continuations = codepoints
pub fn countContinuationBytes(bytes: []const u8) usize {
    if (bytes.len == 0) return 0;

    // Continuation bytes match pattern 10xxxxxx (0x80-0xBF)
    // We count bytes where (byte & 0xC0) == 0x80

    if (simd_level == .avx512 and bytes.len >= vector_size_512) {
        return countContinuation512(bytes);
    } else if (simd_level == .avx2 and bytes.len >= vector_size_256) {
        return countContinuation256(bytes);
    } else if (simd_level != .none and bytes.len >= vector_size_128) {
        return countContinuation128(bytes);
    }

    var count: usize = 0;
    for (bytes) |b| {
        if ((b & 0xC0) == 0x80) count += 1;
    }
    return count;
}

fn countContinuation128(bytes: []const u8) usize {
    const mask: ByteVector16 = @splat(0xC0);
    const pattern: ByteVector16 = @splat(0x80);
    var count: usize = 0;
    var i: usize = 0;

    while (i + vector_size_128 <= bytes.len) {
        const chunk: ByteVector16 = bytes[i..][0..vector_size_128].*;
        const masked = chunk & mask;
        const matches = masked == pattern;
        count += @popCount(@as(u16, @bitCast(matches)));
        i += vector_size_128;
    }

    while (i < bytes.len) {
        if ((bytes[i] & 0xC0) == 0x80) count += 1;
        i += 1;
    }

    return count;
}

fn countContinuation256(bytes: []const u8) usize {
    const mask: ByteVector32 = @splat(0xC0);
    const pattern: ByteVector32 = @splat(0x80);
    var count: usize = 0;
    var i: usize = 0;

    while (i + vector_size_256 <= bytes.len) {
        const chunk: ByteVector32 = bytes[i..][0..vector_size_256].*;
        const masked = chunk & mask;
        const matches = masked == pattern;
        count += @popCount(@as(u32, @bitCast(matches)));
        i += vector_size_256;
    }

    if (i < bytes.len) {
        count += countContinuation128(bytes[i..]);
    }

    return count;
}

fn countContinuation512(bytes: []const u8) usize {
    const mask: ByteVector64 = @splat(0xC0);
    const pattern: ByteVector64 = @splat(0x80);
    var count: usize = 0;
    var i: usize = 0;

    while (i + vector_size_512 <= bytes.len) {
        const chunk: ByteVector64 = bytes[i..][0..vector_size_512].*;
        const masked = chunk & mask;
        const matches = masked == pattern;
        count += @popCount(@as(u64, @bitCast(matches)));
        i += vector_size_512;
    }

    if (i < bytes.len) {
        count += countContinuation256(bytes[i..]);
    }

    return count;
}

/// Counts UTF-8 codepoints using SIMD. Assumes input is valid UTF-8.
/// For untrusted input, use `utf8.countCodepoints()` which validates and
/// returns `null` on invalid sequences. This function is a fast-path that
/// skips validation: it counts non-continuation bytes (bytes where the top
/// two bits are not `10`), which gives the correct codepoint count only
/// when the input is well-formed UTF-8.
pub fn countCodepoints(bytes: []const u8) usize {
    return bytes.len - countContinuationBytes(bytes);
}

// ============================================================
// Tests
// ============================================================

test "findByte" {
    const testing = std.testing;

    try testing.expectEqual(@as(?usize, 0), findByte("hello", 'h'));
    try testing.expectEqual(@as(?usize, 4), findByte("hello", 'o'));
    try testing.expectEqual(@as(?usize, null), findByte("hello", 'x'));

    // Longer string to trigger SIMD path
    const long_str = "a" ** 100 ++ "b";
    try testing.expectEqual(@as(?usize, 100), findByte(long_str, 'b'));

    // Very long string for wider SIMD
    const very_long = "a" ** 1000 ++ "b";
    try testing.expectEqual(@as(?usize, 1000), findByte(very_long, 'b'));
}

test "isAllAscii" {
    const testing = std.testing;

    try testing.expect(isAllAscii("Hello, World!"));
    try testing.expect(!isAllAscii("Hello, \xC3\xA9")); // Contains e with accent
    try testing.expect(isAllAscii("")); // Empty string

    // Longer strings to trigger different SIMD widths
    const long_ascii = "a" ** 100;
    try testing.expect(isAllAscii(long_ascii));

    const very_long_ascii = "a" ** 1000;
    try testing.expect(isAllAscii(very_long_ascii));
}

test "countByte" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 2), countByte("hello", 'l'));
    try testing.expectEqual(@as(usize, 0), countByte("hello", 'x'));

    // Longer string
    const long_str = "a" ** 50 ++ "b" ** 50;
    try testing.expectEqual(@as(usize, 50), countByte(long_str, 'a'));

    // Very long
    const very_long = "a" ** 500 ++ "b" ** 500;
    try testing.expectEqual(@as(usize, 500), countByte(very_long, 'b'));
}

test "equal" {
    const testing = std.testing;

    try testing.expect(equal("hello", "hello"));
    try testing.expect(!equal("hello", "world"));
    try testing.expect(!equal("hello", "hell"));

    // Longer strings
    const a = "a" ** 100;
    const b = "a" ** 100;
    try testing.expect(equal(a, b));

    const c = "a" ** 1000;
    const d = "a" ** 1000;
    try testing.expect(equal(c, d));
}

test "countContinuationBytes" {
    const testing = std.testing;

    // Pure ASCII - no continuation bytes
    try testing.expectEqual(@as(usize, 0), countContinuationBytes("Hello"));

    // UTF-8 with 2-byte chars (1 continuation each)
    try testing.expectEqual(@as(usize, 2), countContinuationBytes("\xC3\xA9\xC3\xA0")); // 2 chars, 4 bytes, 2 continuations

    // UTF-8 with 3-byte chars (2 continuations each)
    try testing.expectEqual(@as(usize, 2), countContinuationBytes("\xE4\xB8\xAD")); // 1 char, 3 bytes, 2 continuations
}

test "countCodepoints" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 5), countCodepoints("Hello"));
    try testing.expectEqual(@as(usize, 2), countCodepoints("\xC3\xA9\xC3\xA0"));
    try testing.expectEqual(@as(usize, 1), countCodepoints("\xE4\xB8\xAD"));
}

test "simd level detection" {
    const testing = std.testing;

    // Just verify it doesn't crash and returns a valid level
    const level = detectSimdLevel();
    try testing.expect(level == .none or level == .sse2 or level == .avx2 or level == .avx512);
}
