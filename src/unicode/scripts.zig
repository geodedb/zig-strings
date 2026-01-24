// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode Script Detection (UAX #24)
//!
//! This module provides script detection for Unicode code points.
//! Scripts identify which writing system a character belongs to (Latin, Cyrillic, Han, etc.).

const std = @import("std");
const types = @import("types");
const ucd_scripts = @import("ucd_scripts");

pub const Codepoint = types.Codepoint;

/// Unicode Script values
pub const Script = ucd_scripts.Script;

/// Gets the Script for a code point
pub fn getScript(cp: Codepoint) Script {
    return ucd_scripts.getScript(cp);
}

/// Checks if a code point belongs to a specific script
pub fn isScript(cp: Codepoint, script: Script) bool {
    return ucd_scripts.isScript(cp, script);
}

/// Checks if a string contains only characters from the given script (plus Common/Inherited)
pub fn isScriptHomogeneous(text: []const u8, script: Script) bool {
    return ucd_scripts.isScriptHomogeneous(text, script);
}

/// Gets all scripts present in a string (excluding Common and Inherited)
pub fn detectScripts(allocator: std.mem.Allocator, text: []const u8) ![]Script {
    var scripts: std.AutoHashMap(Script, void) = .empty;
    defer scripts.deinit(allocator);

    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        const script = getScript(cp);
        if (script != .Common and script != .Inherited and script != .Unknown) {
            try scripts.put(allocator, script, {});
        }
    }

    var result = try allocator.alloc(Script, scripts.count());
    var i: usize = 0;
    var iter2 = scripts.keyIterator();
    while (iter2.next()) |key| {
        result[i] = key.*;
        i += 1;
    }
    return result;
}

/// Gets the primary script of a string (most common non-Common/Inherited script)
pub fn getPrimaryScript(text: []const u8) ?Script {
    var counts: [256]u32 = [_]u32{0} ** 256;

    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        const script = getScript(cp);
        if (script != .Common and script != .Inherited and script != .Unknown) {
            counts[@intFromEnum(script)] += 1;
        }
    }

    var max_count: u32 = 0;
    var primary: ?Script = null;
    for (counts, 0..) |count, i| {
        if (count > max_count) {
            max_count = count;
            primary = @enumFromInt(i);
        }
    }

    return primary;
}

/// Checks if a string is potentially confusable (mixed scripts that could be used for spoofing)
/// Returns true if the string contains characters from multiple distinct scripts
pub fn isMixedScript(text: []const u8) bool {
    var first_script: ?Script = null;

    var iter = std.unicode.Utf8Iterator{ .bytes = text, .i = 0 };
    while (iter.nextCodepoint()) |cp| {
        const script = getScript(cp);
        // Skip Common and Inherited - they can appear in any script
        if (script == .Common or script == .Inherited or script == .Unknown) {
            continue;
        }

        if (first_script) |first| {
            if (script != first) {
                return true;
            }
        } else {
            first_script = script;
        }
    }

    return false;
}

test "script detection - basic" {
    const testing = std.testing;

    // Latin
    try testing.expectEqual(Script.Latin, getScript('A'));
    try testing.expectEqual(Script.Latin, getScript('z'));

    // Cyrillic
    try testing.expectEqual(Script.Cyrillic, getScript(0x0410)); // А (Cyrillic A)

    // Han (CJK)
    try testing.expectEqual(Script.Han, getScript(0x4E00)); // 一 (one)

    // Common (numbers, punctuation)
    try testing.expectEqual(Script.Common, getScript('0'));
    try testing.expectEqual(Script.Common, getScript('.'));
}

test "script detection - homogeneous" {
    const testing = std.testing;

    try testing.expect(isScriptHomogeneous("Hello World", .Latin));
    try testing.expect(isScriptHomogeneous("Hello 123", .Latin)); // Numbers are Common
    try testing.expect(!isScriptHomogeneous("Hello Мир", .Latin)); // Mixed Latin + Cyrillic
}

test "script detection - mixed script" {
    const testing = std.testing;

    try testing.expect(!isMixedScript("Hello World")); // Pure Latin
    try testing.expect(!isMixedScript("123.456")); // Pure Common
    try testing.expect(isMixedScript("Hello Мир")); // Mixed Latin + Cyrillic
}

test "script detection - primary script" {
    const testing = std.testing;

    try testing.expectEqual(Script.Latin, getPrimaryScript("Hello World").?);
    try testing.expectEqual(Script.Cyrillic, getPrimaryScript("Привет мир").?);
    try testing.expectEqual(@as(?Script, null), getPrimaryScript("123.456")); // Only Common
}
