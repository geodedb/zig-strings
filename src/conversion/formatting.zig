// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String formatting utilities.
//!
//! This module provides string formatting functions including
//! printf-style formatting, interpolation, and template rendering.

const std = @import("std");
const types = @import("types");
const utf8_mod = @import("utf8");
const numeric = @import("numeric");

pub const StringError = types.StringError;

/// Simple string interpolation using {} placeholders
pub fn interpolate(allocator: std.mem.Allocator, template: []const u8, args: []const []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, template.len);

    var arg_index: usize = 0;
    var i: usize = 0;
    var literal_start: usize = 0;

    while (i < template.len) {
        if (i + 1 < template.len and template[i] == '{' and template[i + 1] == '}') {
            // Flush literal span before placeholder
            if (i > literal_start) {
                try result.appendSlice(allocator, template[literal_start..i]);
            }
            // Replace {} with argument
            if (arg_index < args.len) {
                try result.appendSlice(allocator, args[arg_index]);
                arg_index += 1;
            }
            i += 2;
            literal_start = i;
        } else if (i + 1 < template.len and template[i] == '{' and template[i + 1] == '{') {
            // Flush literal span before escaped brace
            if (i > literal_start) {
                try result.appendSlice(allocator, template[literal_start..i]);
            }
            // Escaped {
            try result.append(allocator, '{');
            i += 2;
            literal_start = i;
        } else if (i + 1 < template.len and template[i] == '}' and template[i + 1] == '}') {
            // Flush literal span before escaped brace
            if (i > literal_start) {
                try result.appendSlice(allocator, template[literal_start..i]);
            }
            // Escaped }
            try result.append(allocator, '}');
            i += 2;
            literal_start = i;
        } else {
            i += 1;
        }
    }

    // Flush any remaining literal text
    if (literal_start < template.len) {
        try result.appendSlice(allocator, template[literal_start..]);
    }

    return result.toOwnedSlice(allocator);
}

/// Named interpolation using {name} placeholders
pub fn interpolateNamed(
    allocator: std.mem.Allocator,
    template: []const u8,
    values: []const NamedValue,
) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, template.len);

    var i: usize = 0;
    var literal_start: usize = 0;

    while (i < template.len) {
        if (template[i] == '{') {
            // Check for escaped brace
            if (i + 1 < template.len and template[i + 1] == '{') {
                // Flush literal span
                if (i > literal_start) {
                    try result.appendSlice(allocator, template[literal_start..i]);
                }
                try result.append(allocator, '{');
                i += 2;
                literal_start = i;
                continue;
            }

            // Find closing brace
            var end = i + 1;
            while (end < template.len and template[end] != '}') {
                end += 1;
            }

            if (end < template.len) {
                // Flush literal span before placeholder
                if (i > literal_start) {
                    try result.appendSlice(allocator, template[literal_start..i]);
                }

                const name = template[i + 1 .. end];

                // Find matching value
                var found = false;
                for (values) |v| {
                    if (std.mem.eql(u8, v.name, name)) {
                        try result.appendSlice(allocator, v.value);
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    // Keep the placeholder if not found
                    try result.appendSlice(allocator, template[i .. end + 1]);
                }

                i = end + 1;
                literal_start = i;
            } else {
                // No closing brace found; this '{' is literal, just advance
                i += 1;
            }
        } else if (template[i] == '}') {
            // Check for escaped brace
            if (i + 1 < template.len and template[i + 1] == '}') {
                // Flush literal span
                if (i > literal_start) {
                    try result.appendSlice(allocator, template[literal_start..i]);
                }
                try result.append(allocator, '}');
                i += 2;
                literal_start = i;
            } else {
                // Lone '}' is literal, just advance
                i += 1;
            }
        } else {
            i += 1;
        }
    }

    // Flush any remaining literal text
    if (literal_start < template.len) {
        try result.appendSlice(allocator, template[literal_start..]);
    }

    return result.toOwnedSlice(allocator);
}

/// Named value for interpolation
pub const NamedValue = struct {
    name: []const u8,
    value: []const u8,
};

/// Centers a string within a given width
pub fn center(allocator: std.mem.Allocator, str: []const u8, width: usize, fill: u8) ![]u8 {
    if (str.len >= width) {
        const result = try allocator.alloc(u8, str.len);
        @memcpy(result, str);
        return result;
    }

    const padding = width - str.len;
    const left_pad = padding / 2;
    const right_pad = padding - left_pad;

    var result = try allocator.alloc(u8, width);
    @memset(result[0..left_pad], fill);
    @memcpy(result[left_pad..][0..str.len], str);
    @memset(result[left_pad + str.len ..], fill);
    _ = right_pad;

    return result;
}

/// Left-justifies a string within a given width
pub fn leftJustify(allocator: std.mem.Allocator, str: []const u8, width: usize, fill: u8) ![]u8 {
    if (str.len >= width) {
        const result = try allocator.alloc(u8, str.len);
        @memcpy(result, str);
        return result;
    }

    var result = try allocator.alloc(u8, width);
    @memcpy(result[0..str.len], str);
    @memset(result[str.len..], fill);

    return result;
}

/// Right-justifies a string within a given width
pub fn rightJustify(allocator: std.mem.Allocator, str: []const u8, width: usize, fill: u8) ![]u8 {
    if (str.len >= width) {
        const result = try allocator.alloc(u8, str.len);
        @memcpy(result, str);
        return result;
    }

    const padding = width - str.len;

    var result = try allocator.alloc(u8, width);
    @memset(result[0..padding], fill);
    @memcpy(result[padding..], str);

    return result;
}

/// Truncates a string to a maximum length with optional ellipsis
pub fn truncate(allocator: std.mem.Allocator, str: []const u8, max_len: usize, ellipsis: ?[]const u8) ![]u8 {
    if (str.len <= max_len) {
        const result = try allocator.alloc(u8, str.len);
        @memcpy(result, str);
        return result;
    }

    const suffix = ellipsis orelse "";
    if (max_len <= suffix.len) {
        const result = try allocator.alloc(u8, max_len);
        @memcpy(result, suffix[0..max_len]);
        return result;
    }

    const content_len = max_len - suffix.len;
    var result = try allocator.alloc(u8, max_len);
    @memcpy(result[0..content_len], str[0..content_len]);
    @memcpy(result[content_len..], suffix);

    return result;
}

/// Wraps text at a given width
pub fn wrap(allocator: std.mem.Allocator, text: []const u8, width: usize) ![]u8 {
    if (width == 0) {
        const result = try allocator.alloc(u8, text.len);
        @memcpy(result, text);
        return result;
    }

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, text.len);

    var line_start: usize = 0;
    var last_space: ?usize = null;
    var col: usize = 0;

    for (text, 0..) |c, i| {
        if (c == ' ') {
            last_space = i;
        }

        if (c == '\n') {
            try result.appendSlice(allocator, text[line_start .. i + 1]);
            line_start = i + 1;
            last_space = null;
            col = 0;
        } else if (col >= width) {
            // Need to wrap
            if (last_space) |space| {
                try result.appendSlice(allocator, text[line_start..space]);
                try result.append(allocator, '\n');
                line_start = space + 1;
                col = i - space - 1;
                last_space = null;
            } else {
                // No space to break at, force break
                try result.appendSlice(allocator, text[line_start..i]);
                try result.append(allocator, '\n');
                line_start = i;
                col = 0;
            }
        } else {
            col += 1;
        }
    }

    // Append remaining
    if (line_start < text.len) {
        try result.appendSlice(allocator, text[line_start..]);
    }

    return result.toOwnedSlice(allocator);
}

/// Indents each line of text
pub fn indent(allocator: std.mem.Allocator, text: []const u8, prefix: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, text.len + prefix.len);

    var line_start: usize = 0;
    var at_line_start = true;

    for (text, 0..) |c, i| {
        if (at_line_start and c != '\n') {
            try result.appendSlice(allocator, prefix);
            at_line_start = false;
        }

        if (c == '\n') {
            try result.appendSlice(allocator, text[line_start .. i + 1]);
            line_start = i + 1;
            at_line_start = true;
        }
    }

    // Append remaining line
    if (line_start < text.len) {
        if (at_line_start) {
            try result.appendSlice(allocator, prefix);
        }
        try result.appendSlice(allocator, text[line_start..]);
    }

    return result.toOwnedSlice(allocator);
}

/// Dedents text by removing common leading whitespace
pub fn dedent(allocator: std.mem.Allocator, text: []const u8) ![]u8 {
    // Find minimum indentation (ignoring empty lines)
    var min_indent: ?usize = null;
    var line_start: usize = 0;

    for (text, 0..) |c, i| {
        if (c == '\n') {
            if (line_start < i) {
                var indent_count: usize = 0;
                for (text[line_start..i]) |lc| {
                    if (lc == ' ' or lc == '\t') {
                        indent_count += 1;
                    } else {
                        break;
                    }
                }
                if (indent_count < i - line_start) { // Non-empty line
                    if (min_indent == null or indent_count < min_indent.?) {
                        min_indent = indent_count;
                    }
                }
            }
            line_start = i + 1;
        }
    }

    // Handle last line
    if (line_start < text.len) {
        var indent_count: usize = 0;
        for (text[line_start..]) |lc| {
            if (lc == ' ' or lc == '\t') {
                indent_count += 1;
            } else {
                break;
            }
        }
        if (indent_count < text.len - line_start) {
            if (min_indent == null or indent_count < min_indent.?) {
                min_indent = indent_count;
            }
        }
    }

    const remove = min_indent orelse 0;
    if (remove == 0) {
        const result = try allocator.alloc(u8, text.len);
        @memcpy(result, text);
        return result;
    }

    // Build result with indentation removed
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);
    try result.ensureTotalCapacity(allocator, text.len);

    line_start = 0;
    for (text, 0..) |c, i| {
        if (c == '\n') {
            const line = text[line_start..i];
            const skip = @min(remove, line.len);
            try result.appendSlice(allocator, line[skip..]);
            try result.append(allocator, '\n');
            line_start = i + 1;
        }
    }

    // Handle last line
    if (line_start < text.len) {
        const line = text[line_start..];
        const skip = @min(remove, line.len);
        try result.appendSlice(allocator, line[skip..]);
    }

    return result.toOwnedSlice(allocator);
}

test "interpolate" {
    const testing = std.testing;

    const result = try interpolate(testing.allocator, "Hello, {}!", &[_][]const u8{"World"});
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "Hello, World!", result);
}

test "interpolate escaped" {
    const testing = std.testing;

    const result = try interpolate(testing.allocator, "Use {{}} for placeholders", &[_][]const u8{});
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "Use {} for placeholders", result);
}

test "interpolateNamed" {
    const testing = std.testing;

    const result = try interpolateNamed(testing.allocator, "Hello, {name}!", &[_]NamedValue{
        .{ .name = "name", .value = "Alice" },
    });
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "Hello, Alice!", result);
}

test "center" {
    const testing = std.testing;

    const result = try center(testing.allocator, "hi", 6, '-');
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "--hi--", result);
}

test "leftJustify" {
    const testing = std.testing;

    const result = try leftJustify(testing.allocator, "hi", 5, '.');
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "hi...", result);
}

test "rightJustify" {
    const testing = std.testing;

    const result = try rightJustify(testing.allocator, "hi", 5, '.');
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "...hi", result);
}

test "truncate" {
    const testing = std.testing;

    const result = try truncate(testing.allocator, "Hello, World!", 10, "...");
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "Hello, ...", result);
}

test "indent" {
    const testing = std.testing;

    const result = try indent(testing.allocator, "line1\nline2", "  ");
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "  line1\n  line2", result);
}

test "interpolate empty template" {
    const testing = std.testing;

    const result = try interpolate(testing.allocator, "", &[_][]const u8{});
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "", result);
}

test "interpolate pure literal no placeholders" {
    const testing = std.testing;

    const result = try interpolate(testing.allocator, "no placeholders here", &[_][]const u8{});
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "no placeholders here", result);
}

test "interpolate adjacent placeholders" {
    const testing = std.testing;

    const result = try interpolate(testing.allocator, "{}{}{}", &[_][]const u8{ "a", "b", "c" });
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "abc", result);
}

test "interpolateNamed empty template" {
    const testing = std.testing;

    const result = try interpolateNamed(testing.allocator, "", &[_]NamedValue{});
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "", result);
}

test "interpolateNamed pure literal no placeholders" {
    const testing = std.testing;

    const result = try interpolateNamed(testing.allocator, "no placeholders here", &[_]NamedValue{});
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "no placeholders here", result);
}

test "interpolateNamed adjacent placeholders" {
    const testing = std.testing;

    const result = try interpolateNamed(testing.allocator, "{x}{y}{z}", &[_]NamedValue{
        .{ .name = "x", .value = "1" },
        .{ .name = "y", .value = "2" },
        .{ .name = "z", .value = "3" },
    });
    defer testing.allocator.free(result);
    try testing.expectEqualSlices(u8, "123", result);
}
