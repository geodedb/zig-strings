// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! SIMD-accelerated ASCII case conversion operations.
//!
//! Provides toLowerAscii and toUpperAscii with automatic SIMD width
//! selection (AVX-512, AVX2, SSE2/NEON).

const std = @import("std");
const simd_core = @import("simd.zig");

const ByteVector16 = simd_core.ByteVector16;
const ByteVector32 = simd_core.ByteVector32;
const ByteVector64 = simd_core.ByteVector64;
const vector_size_128 = simd_core.vector_size_128;
const vector_size_256 = simd_core.vector_size_256;
const vector_size_512 = simd_core.vector_size_512;
const simd_level = simd_core.simd_level;

// ============================================================
// Case Conversion
// ============================================================

/// Converts ASCII uppercase to lowercase using SIMD
pub fn toLowerAscii(dest: []u8, src: []const u8) void {
    if (dest.len < src.len) @panic("simd: destination buffer too small");

    if (simd_level == .avx512 and src.len >= vector_size_512) {
        toLowerAscii512(dest, src);
    } else if (simd_level == .avx2 and src.len >= vector_size_256) {
        toLowerAscii256(dest, src);
    } else if (simd_level != .none and src.len >= vector_size_128) {
        toLowerAscii128(dest, src);
    } else {
        for (src, 0..) |c, i| {
            dest[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
        }
    }
}

fn toLowerAscii128(dest: []u8, src: []const u8) void {
    const a_upper: ByteVector16 = @splat('A');
    const z_upper: ByteVector16 = @splat('Z');
    const case_diff: ByteVector16 = @splat(32);
    var i: usize = 0;

    while (i + vector_size_128 <= src.len) {
        const chunk: ByteVector16 = src[i..][0..vector_size_128].*;
        const ge_a = chunk >= a_upper;
        const le_z = chunk <= z_upper;
        const is_upper = ge_a & le_z;
        const converted = @select(u8, is_upper, chunk +% case_diff, chunk);
        dest[i..][0..vector_size_128].* = converted;
        i += vector_size_128;
    }

    while (i < src.len) {
        dest[i] = if (src[i] >= 'A' and src[i] <= 'Z') src[i] + 32 else src[i];
        i += 1;
    }
}

fn toLowerAscii256(dest: []u8, src: []const u8) void {
    const a_upper: ByteVector32 = @splat('A');
    const z_upper: ByteVector32 = @splat('Z');
    const case_diff: ByteVector32 = @splat(32);
    var i: usize = 0;

    while (i + vector_size_256 <= src.len) {
        const chunk: ByteVector32 = src[i..][0..vector_size_256].*;
        const ge_a = chunk >= a_upper;
        const le_z = chunk <= z_upper;
        const is_upper = ge_a & le_z;
        const converted = @select(u8, is_upper, chunk +% case_diff, chunk);
        dest[i..][0..vector_size_256].* = converted;
        i += vector_size_256;
    }

    if (i < src.len) {
        toLowerAscii128(dest[i..], src[i..]);
    }
}

fn toLowerAscii512(dest: []u8, src: []const u8) void {
    const a_upper: ByteVector64 = @splat('A');
    const z_upper: ByteVector64 = @splat('Z');
    const case_diff: ByteVector64 = @splat(32);
    var i: usize = 0;

    while (i + vector_size_512 <= src.len) {
        const chunk: ByteVector64 = src[i..][0..vector_size_512].*;
        const ge_a = chunk >= a_upper;
        const le_z = chunk <= z_upper;
        const is_upper = ge_a & le_z;
        const converted = @select(u8, is_upper, chunk +% case_diff, chunk);
        dest[i..][0..vector_size_512].* = converted;
        i += vector_size_512;
    }

    if (i < src.len) {
        toLowerAscii256(dest[i..], src[i..]);
    }
}

/// Converts ASCII lowercase to uppercase using SIMD
pub fn toUpperAscii(dest: []u8, src: []const u8) void {
    if (dest.len < src.len) @panic("simd: destination buffer too small");

    if (simd_level == .avx512 and src.len >= vector_size_512) {
        toUpperAscii512(dest, src);
    } else if (simd_level == .avx2 and src.len >= vector_size_256) {
        toUpperAscii256(dest, src);
    } else if (simd_level != .none and src.len >= vector_size_128) {
        toUpperAscii128(dest, src);
    } else {
        for (src, 0..) |c, i| {
            dest[i] = if (c >= 'a' and c <= 'z') c - 32 else c;
        }
    }
}

fn toUpperAscii128(dest: []u8, src: []const u8) void {
    const a_lower: ByteVector16 = @splat('a');
    const z_lower: ByteVector16 = @splat('z');
    const case_diff: ByteVector16 = @splat(32);
    var i: usize = 0;

    while (i + vector_size_128 <= src.len) {
        const chunk: ByteVector16 = src[i..][0..vector_size_128].*;
        const ge_a = chunk >= a_lower;
        const le_z = chunk <= z_lower;
        const is_lower = ge_a & le_z;
        const converted = @select(u8, is_lower, chunk -% case_diff, chunk);
        dest[i..][0..vector_size_128].* = converted;
        i += vector_size_128;
    }

    while (i < src.len) {
        dest[i] = if (src[i] >= 'a' and src[i] <= 'z') src[i] - 32 else src[i];
        i += 1;
    }
}

fn toUpperAscii256(dest: []u8, src: []const u8) void {
    const a_lower: ByteVector32 = @splat('a');
    const z_lower: ByteVector32 = @splat('z');
    const case_diff: ByteVector32 = @splat(32);
    var i: usize = 0;

    while (i + vector_size_256 <= src.len) {
        const chunk: ByteVector32 = src[i..][0..vector_size_256].*;
        const ge_a = chunk >= a_lower;
        const le_z = chunk <= z_lower;
        const is_lower = ge_a & le_z;
        const converted = @select(u8, is_lower, chunk -% case_diff, chunk);
        dest[i..][0..vector_size_256].* = converted;
        i += vector_size_256;
    }

    if (i < src.len) {
        toUpperAscii128(dest[i..], src[i..]);
    }
}

fn toUpperAscii512(dest: []u8, src: []const u8) void {
    const a_lower: ByteVector64 = @splat('a');
    const z_lower: ByteVector64 = @splat('z');
    const case_diff: ByteVector64 = @splat(32);
    var i: usize = 0;

    while (i + vector_size_512 <= src.len) {
        const chunk: ByteVector64 = src[i..][0..vector_size_512].*;
        const ge_a = chunk >= a_lower;
        const le_z = chunk <= z_lower;
        const is_lower = ge_a & le_z;
        const converted = @select(u8, is_lower, chunk -% case_diff, chunk);
        dest[i..][0..vector_size_512].* = converted;
        i += vector_size_512;
    }

    if (i < src.len) {
        toUpperAscii256(dest[i..], src[i..]);
    }
}

// ============================================================
// Tests
// ============================================================

test "toLowerAscii" {
    const testing = std.testing;

    var dest: [32]u8 = undefined;
    const src = "Hello, WORLD!";
    toLowerAscii(dest[0..src.len], src);
    try testing.expectEqualSlices(u8, "hello, world!", dest[0..src.len]);

    // Long string
    var long_dest: [100]u8 = undefined;
    const long_src = "A" ** 100;
    toLowerAscii(&long_dest, long_src);
    try testing.expectEqualSlices(u8, "a" ** 100, &long_dest);
}

test "toUpperAscii" {
    const testing = std.testing;

    var dest: [32]u8 = undefined;
    const src = "Hello, World!";
    toUpperAscii(dest[0..src.len], src);
    try testing.expectEqualSlices(u8, "HELLO, WORLD!", dest[0..src.len]);
}

test "toLowerAscii bounds check: exact fit" {
    // dest.len == src.len must succeed (boundary condition)
    var dest: [5]u8 = undefined;
    toLowerAscii(&dest, "HELLO");
    try std.testing.expectEqualSlices(u8, "hello", &dest);
}

test "toLowerAscii bounds check: dest larger than src" {
    // dest.len > src.len must succeed
    var dest: [32]u8 = undefined;
    toLowerAscii(dest[0..5], "HELLO");
    try std.testing.expectEqualSlices(u8, "hello", dest[0..5]);
}

test "toUpperAscii bounds check: exact fit" {
    var dest: [5]u8 = undefined;
    toUpperAscii(&dest, "hello");
    try std.testing.expectEqualSlices(u8, "HELLO", &dest);
}

test "toUpperAscii bounds check: dest larger than src" {
    var dest: [32]u8 = undefined;
    toUpperAscii(dest[0..5], "hello");
    try std.testing.expectEqualSlices(u8, "HELLO", dest[0..5]);
}
