// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! SIMD-accelerated memory operations.
//!
//! Provides memcpySimd and memsetSimd with automatic SIMD width
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
// Memory Operations with SIMD
// ============================================================

/// Fast memory copy using SIMD (for aligned data)
pub fn memcpySimd(dest: []u8, src: []const u8) void {
    if (dest.len < src.len) @panic("simd: destination buffer too small");

    if (simd_level == .avx512 and src.len >= vector_size_512) {
        memcpy512(dest, src);
    } else if (simd_level == .avx2 and src.len >= vector_size_256) {
        memcpy256(dest, src);
    } else if (simd_level != .none and src.len >= vector_size_128) {
        memcpy128(dest, src);
    } else {
        @memcpy(dest[0..src.len], src);
    }
}

fn memcpy128(dest: []u8, src: []const u8) void {
    var i: usize = 0;

    while (i + vector_size_128 <= src.len) {
        const chunk: ByteVector16 = src[i..][0..vector_size_128].*;
        dest[i..][0..vector_size_128].* = chunk;
        i += vector_size_128;
    }

    while (i < src.len) {
        dest[i] = src[i];
        i += 1;
    }
}

fn memcpy256(dest: []u8, src: []const u8) void {
    var i: usize = 0;

    while (i + vector_size_256 <= src.len) {
        const chunk: ByteVector32 = src[i..][0..vector_size_256].*;
        dest[i..][0..vector_size_256].* = chunk;
        i += vector_size_256;
    }

    if (i < src.len) {
        memcpy128(dest[i..], src[i..]);
    }
}

fn memcpy512(dest: []u8, src: []const u8) void {
    var i: usize = 0;

    while (i + vector_size_512 <= src.len) {
        const chunk: ByteVector64 = src[i..][0..vector_size_512].*;
        dest[i..][0..vector_size_512].* = chunk;
        i += vector_size_512;
    }

    if (i < src.len) {
        memcpy256(dest[i..], src[i..]);
    }
}

/// Fast memory set using SIMD
pub fn memsetSimd(dest: []u8, value: u8) void {
    if (simd_level == .avx512 and dest.len >= vector_size_512) {
        memset512(dest, value);
    } else if (simd_level == .avx2 and dest.len >= vector_size_256) {
        memset256(dest, value);
    } else if (simd_level != .none and dest.len >= vector_size_128) {
        memset128(dest, value);
    } else {
        @memset(dest, value);
    }
}

fn memset128(dest: []u8, value: u8) void {
    const vec: ByteVector16 = @splat(value);
    var i: usize = 0;

    while (i + vector_size_128 <= dest.len) {
        dest[i..][0..vector_size_128].* = vec;
        i += vector_size_128;
    }

    while (i < dest.len) {
        dest[i] = value;
        i += 1;
    }
}

fn memset256(dest: []u8, value: u8) void {
    const vec: ByteVector32 = @splat(value);
    var i: usize = 0;

    while (i + vector_size_256 <= dest.len) {
        dest[i..][0..vector_size_256].* = vec;
        i += vector_size_256;
    }

    if (i < dest.len) {
        memset128(dest[i..], value);
    }
}

fn memset512(dest: []u8, value: u8) void {
    const vec: ByteVector64 = @splat(value);
    var i: usize = 0;

    while (i + vector_size_512 <= dest.len) {
        dest[i..][0..vector_size_512].* = vec;
        i += vector_size_512;
    }

    if (i < dest.len) {
        memset256(dest[i..], value);
    }
}

// ============================================================
// Tests
// ============================================================

test "memcpySimd basic" {
    var dest: [13]u8 = undefined;
    const src = "Hello, World!";
    memcpySimd(&dest, src);
    try std.testing.expectEqualSlices(u8, src, &dest);
}

test "memcpySimd bounds check: exact fit" {
    var dest: [5]u8 = undefined;
    memcpySimd(&dest, "abcde");
    try std.testing.expectEqualSlices(u8, "abcde", &dest);
}

test "memcpySimd bounds check: dest larger than src" {
    var dest: [32]u8 = undefined;
    memcpySimd(dest[0..5], "abcde");
    try std.testing.expectEqualSlices(u8, "abcde", dest[0..5]);
}

test "memcpySimd long string" {
    // Test with a string long enough to trigger SIMD paths
    const src = "A" ** 256;
    var dest: [256]u8 = undefined;
    memcpySimd(&dest, src);
    try std.testing.expectEqualSlices(u8, src, &dest);
}
