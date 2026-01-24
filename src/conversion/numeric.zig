// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Numeric parsing and formatting.
//!
//! This module provides functions for converting between strings and
//! numeric types (integers and floating-point numbers).

const std = @import("std");
const types = @import("types");
const utf8_mod = @import("utf8");
const ascii = @import("ascii");

pub const StringError = types.StringError;

/// Parses an integer from a string
pub fn parseInt(comptime T: type, str: []const u8, base: u8) ?T {
    if (str.len == 0) return null;

    // Handle sign
    var start: usize = 0;
    var negative = false;

    if (@typeInfo(T).int.signedness == .signed) {
        if (str[0] == '-') {
            negative = true;
            start = 1;
        } else if (str[0] == '+') {
            start = 1;
        }
    }

    if (start >= str.len) return null;

    // Handle base prefixes
    var actual_base = base;
    if (base == 0) {
        if (str.len > start + 2 and str[start] == '0') {
            switch (str[start + 1]) {
                'x', 'X' => {
                    actual_base = 16;
                    start += 2;
                },
                'o', 'O' => {
                    actual_base = 8;
                    start += 2;
                },
                'b', 'B' => {
                    actual_base = 2;
                    start += 2;
                },
                else => actual_base = 10,
            }
        } else {
            actual_base = 10;
        }
    }

    if (start >= str.len) return null;

    const result = std.fmt.parseInt(T, str[start..], actual_base) catch return null;

    if (negative) {
        return -result;
    }
    return result;
}

/// Parses a floating-point number from a string
pub fn parseFloat(comptime T: type, str: []const u8) ?T {
    if (str.len == 0) return null;
    return std.fmt.parseFloat(T, str) catch return null;
}

/// Formats an integer to a string
pub fn formatInt(allocator: std.mem.Allocator, value: anytype, base: u8) ![]u8 {
    return formatIntWithOptions(allocator, value, .{ .base = base });
}

/// Formats an integer with custom options
pub fn formatIntWithOptions(
    allocator: std.mem.Allocator,
    value: anytype,
    options: FormatIntOptions,
) ![]u8 {
    const T = @TypeOf(value);
    const is_signed = @typeInfo(T).int.signedness == .signed;

    // Calculate required buffer size
    var buf: [128]u8 = undefined;
    var pos: usize = 0;

    // Handle negative
    const negative = is_signed and value < 0;
    const abs_value = if (negative) @as(@TypeOf(value), 0) -% value else value;

    // Convert to unsigned for formatting
    const UnsignedT = if (is_signed) std.meta.Int(.unsigned, @typeInfo(T).int.bits) else T;
    var n: UnsignedT = @bitCast(abs_value);

    // Format digits (in reverse)
    var digit_buf: [128]u8 = undefined;
    var digit_count: usize = 0;

    if (n == 0) {
        digit_buf[0] = '0';
        digit_count = 1;
    } else {
        while (n > 0) {
            const digit = @as(u8, @truncate(n % options.base));
            digit_buf[digit_count] = if (digit < 10)
                '0' + digit
            else if (options.uppercase)
                'A' + (digit - 10)
            else
                'a' + (digit - 10);
            digit_count += 1;
            n /= options.base;
        }
    }

    // Add sign
    if (negative) {
        buf[pos] = '-';
        pos += 1;
    } else if (options.show_plus) {
        buf[pos] = '+';
        pos += 1;
    }

    // Add prefix
    if (options.prefix) |prefix| {
        @memcpy(buf[pos..][0..prefix.len], prefix);
        pos += prefix.len;
    }

    // Pad with zeros if needed
    if (options.min_digits > digit_count) {
        const zeros = options.min_digits - digit_count;
        @memset(buf[pos..][0..zeros], '0');
        pos += zeros;
    }

    // Copy digits (reversed)
    var i: usize = digit_count;
    while (i > 0) {
        i -= 1;
        buf[pos] = digit_buf[i];
        pos += 1;
    }

    const result = try allocator.alloc(u8, pos);
    @memcpy(result, buf[0..pos]);
    return result;
}

/// Options for integer formatting
pub const FormatIntOptions = struct {
    base: u8 = 10,
    uppercase: bool = false,
    min_digits: usize = 0,
    show_plus: bool = false,
    prefix: ?[]const u8 = null,
};

/// Formats a floating-point number to a string
pub fn formatFloat(allocator: std.mem.Allocator, value: anytype) ![]u8 {
    var buf: [128]u8 = undefined;
    const slice = std.fmt.bufPrint(&buf, "{d}", .{value}) catch return StringError.BufferTooSmall;

    const result = try allocator.alloc(u8, slice.len);
    @memcpy(result, slice);
    return result;
}

/// Formats a floating-point number with precision
pub fn formatFloatPrecision(allocator: std.mem.Allocator, value: anytype, precision: usize) ![]u8 {
    var buf: [128]u8 = undefined;
    var fbs = std.io.fixedBufferStream(&buf);
    const writer = fbs.writer();

    // Format the float with specified precision using std.fmt.format
    std.fmt.formatFloatDecimal(value, .{ .precision = precision }, writer) catch return StringError.BufferTooSmall;

    const slice = fbs.getWritten();
    const result = try allocator.alloc(u8, slice.len);
    @memcpy(result, slice);
    return result;
}

/// Parses a boolean from a string
pub fn parseBool(str: []const u8) ?bool {
    if (ascii.eqlIgnoreCase(str, "true") or
        ascii.eqlIgnoreCase(str, "yes") or
        ascii.eqlIgnoreCase(str, "1") or
        ascii.eqlIgnoreCase(str, "on"))
    {
        return true;
    }

    if (ascii.eqlIgnoreCase(str, "false") or
        ascii.eqlIgnoreCase(str, "no") or
        ascii.eqlIgnoreCase(str, "0") or
        ascii.eqlIgnoreCase(str, "off"))
    {
        return false;
    }

    return null;
}

/// Formats a boolean to a string
pub fn formatBool(value: bool, format: BoolFormat) []const u8 {
    return switch (format) {
        .true_false => if (value) "true" else "false",
        .yes_no => if (value) "yes" else "no",
        .one_zero => if (value) "1" else "0",
        .on_off => if (value) "on" else "off",
    };
}

/// Boolean formatting options
pub const BoolFormat = enum {
    true_false,
    yes_no,
    one_zero,
    on_off,
};

/// Formats bytes as a human-readable size (KB, MB, GB, etc.)
pub fn formatByteSize(allocator: std.mem.Allocator, bytes: u64) ![]u8 {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB", "PB", "EB" };
    var value: f64 = @floatFromInt(bytes);
    var unit_index: usize = 0;

    while (value >= 1024 and unit_index < units.len - 1) {
        value /= 1024;
        unit_index += 1;
    }

    var buf: [64]u8 = undefined;
    const slice = if (unit_index == 0)
        std.fmt.bufPrint(&buf, "{d} {s}", .{ @as(u64, bytes), units[unit_index] }) catch return StringError.BufferTooSmall
    else
        std.fmt.bufPrint(&buf, "{d:.2} {s}", .{ value, units[unit_index] }) catch return StringError.BufferTooSmall;

    const result = try allocator.alloc(u8, slice.len);
    @memcpy(result, slice);
    return result;
}

test "parseInt" {
    const testing = std.testing;

    try testing.expectEqual(@as(?i32, 123), parseInt(i32, "123", 10));
    try testing.expectEqual(@as(?i32, -456), parseInt(i32, "-456", 10));
    try testing.expectEqual(@as(?i32, 255), parseInt(i32, "ff", 16));
    try testing.expectEqual(@as(?i32, 255), parseInt(i32, "0xFF", 0));
    try testing.expectEqual(@as(?i32, 8), parseInt(i32, "0o10", 0));
    try testing.expectEqual(@as(?i32, 5), parseInt(i32, "0b101", 0));
    try testing.expectEqual(@as(?i32, null), parseInt(i32, "", 10));
    try testing.expectEqual(@as(?i32, null), parseInt(i32, "abc", 10));
}

test "parseFloat" {
    const testing = std.testing;

    try testing.expectEqual(@as(?f64, 3.14), parseFloat(f64, "3.14"));
    try testing.expectEqual(@as(?f64, -2.5), parseFloat(f64, "-2.5"));
    try testing.expectEqual(@as(?f64, null), parseFloat(f64, "abc"));
}

test "formatInt" {
    const testing = std.testing;

    const result = try formatInt(testing.allocator, @as(i32, 42), 10);
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "42", result);

    // Test with different bases
    const hex = try formatInt(testing.allocator, @as(u32, 255), 16);
    defer testing.allocator.free(hex);
    try testing.expectEqualSlices(u8, "ff", hex);

    const binary = try formatInt(testing.allocator, @as(u8, 5), 2);
    defer testing.allocator.free(binary);
    try testing.expectEqualSlices(u8, "101", binary);
}

test "formatFloatPrecision" {
    const testing = std.testing;

    // Test precision 2
    const result2 = try formatFloatPrecision(testing.allocator, @as(f64, 3.14159), 2);
    defer testing.allocator.free(result2);
    try testing.expectEqualSlices(u8, "3.14", result2);

    // Test precision 4
    const result4 = try formatFloatPrecision(testing.allocator, @as(f64, 3.14159), 4);
    defer testing.allocator.free(result4);
    try testing.expectEqualSlices(u8, "3.1416", result4);

    // Test precision 0
    const result0 = try formatFloatPrecision(testing.allocator, @as(f64, 3.7), 0);
    defer testing.allocator.free(result0);
    try testing.expectEqualSlices(u8, "4", result0);
}

test "formatIntWithOptions" {
    const testing = std.testing;

    const hex = try formatIntWithOptions(testing.allocator, @as(u32, 255), .{
        .base = 16,
        .uppercase = true,
        .prefix = "0x",
    });
    defer testing.allocator.free(hex);
    try testing.expectEqualSlices(u8, "0xFF", hex);

    const padded = try formatIntWithOptions(testing.allocator, @as(u32, 42), .{
        .min_digits = 5,
    });
    defer testing.allocator.free(padded);
    try testing.expectEqualSlices(u8, "00042", padded);
}

test "parseBool" {
    const testing = std.testing;

    try testing.expectEqual(@as(?bool, true), parseBool("true"));
    try testing.expectEqual(@as(?bool, true), parseBool("TRUE"));
    try testing.expectEqual(@as(?bool, true), parseBool("yes"));
    try testing.expectEqual(@as(?bool, true), parseBool("1"));
    try testing.expectEqual(@as(?bool, false), parseBool("false"));
    try testing.expectEqual(@as(?bool, false), parseBool("no"));
    try testing.expectEqual(@as(?bool, null), parseBool("maybe"));
}

test "formatBool" {
    const testing = std.testing;

    try testing.expectEqualSlices(u8, "true", formatBool(true, .true_false));
    try testing.expectEqualSlices(u8, "no", formatBool(false, .yes_no));
    try testing.expectEqualSlices(u8, "1", formatBool(true, .one_zero));
}

test "formatByteSize" {
    const testing = std.testing;

    const bytes = try formatByteSize(testing.allocator, 512);
    defer testing.allocator.free(bytes);
    try testing.expectEqualSlices(u8, "512 B", bytes);

    const kb = try formatByteSize(testing.allocator, 1536);
    defer testing.allocator.free(kb);
    try testing.expectEqualSlices(u8, "1.50 KB", kb);

    const mb = try formatByteSize(testing.allocator, 1048576);
    defer testing.allocator.free(mb);
    try testing.expectEqualSlices(u8, "1.00 MB", mb);
}
