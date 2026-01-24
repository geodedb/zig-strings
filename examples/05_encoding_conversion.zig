// SPDX-License-Identifier: Apache-2.0
// UTF-8/16/32 Encoding Conversion Example
//
// This example demonstrates encoding detection and conversion between
// UTF-8, UTF-16, and UTF-32. Understanding encoding is essential for:
// - Reading/writing files from different systems
// - Interoperating with Windows APIs (often UTF-16)
// - Processing data from various sources
//
// Run with: zig build-exe 05_encoding_conversion.zig --deps strings && ./05_encoding_conversion

const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // =========================================================================
    // UTF-8 Basics
    // =========================================================================

    std.debug.print("=== UTF-8 Basics ===\n\n", .{});

    std.debug.print("UTF-8 is a variable-width encoding:\n", .{});
    std.debug.print("  - 1 byte: ASCII (U+0000 to U+007F)\n", .{});
    std.debug.print("  - 2 bytes: Latin, Greek, etc. (U+0080 to U+07FF)\n", .{});
    std.debug.print("  - 3 bytes: Most other BMP chars (U+0800 to U+FFFF)\n", .{});
    std.debug.print("  - 4 bytes: Supplementary planes (U+10000 to U+10FFFF)\n\n", .{});

    // Check sequence length by first byte
    const bytes = [_]u8{ 'A', 0xC3, 0xE4, 0xF0 };
    for (bytes) |byte| {
        if (strings.utf8.sequenceLength(byte)) |len| {
            std.debug.print("Byte 0x{X:0>2}: {}-byte sequence\n", .{ byte, len });
        } else {
            std.debug.print("Byte 0x{X:0>2}: invalid start byte\n", .{byte});
        }
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // UTF-8 Validation
    // =========================================================================

    std.debug.print("=== UTF-8 Validation ===\n\n", .{});

    const valid_utf8 = "Hello, \xE4\xB8\x96\xE7\x95\x8C!"; // Hello, 世界!
    const invalid_utf8 = "Hello\xFF\xFE"; // Invalid bytes

    std.debug.print("'{s}' is valid UTF-8: {}\n", .{ valid_utf8, strings.utf8.isValid(valid_utf8) });
    std.debug.print("Text with 0xFF 0xFE is valid UTF-8: {}\n\n", .{strings.utf8.isValid(invalid_utf8)});

    // Count code points
    std.debug.print("Code points in '{s}': {?}\n", .{ valid_utf8, strings.utf8.countCodepoints(valid_utf8) });
    std.debug.print("Code points in invalid UTF-8: {?}\n\n", .{strings.utf8.countCodepoints(invalid_utf8)});

    // =========================================================================
    // UTF-8 Decoding
    // =========================================================================

    std.debug.print("=== UTF-8 Decoding ===\n\n", .{});

    const text = "A\xC3\xA9\xE4\xB8\xAD\xF0\x9F\x98\x80"; // A e 中 emoji

    std.debug.print("Decoding '{s}':\n", .{text});
    var pos: usize = 0;
    while (pos < text.len) {
        const result = try strings.utf8.decode(text[pos..]);
        const end = pos + result.bytes_consumed;
        std.debug.print("  U+{X:0>4} ({s}) - {} byte(s)\n", .{
            result.value,
            text[pos..end],
            result.bytes_consumed,
        });
        pos = end;
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // UTF-8 Encoding
    // =========================================================================

    std.debug.print("=== UTF-8 Encoding ===\n\n", .{});

    const codepoints = [_]u21{ 'A', 0x00E9, 0x4E2D, 0x1F600 };
    var buf: [4]u8 = undefined;

    for (codepoints) |cp| {
        const len = try strings.utf8.encode(cp, &buf);
        std.debug.print("U+{X:0>4} encodes to {} byte(s): ", .{ cp, len });
        for (buf[0..len]) |byte| {
            std.debug.print("{X:0>2} ", .{byte});
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // UTF-8 Iterator
    // =========================================================================

    std.debug.print("=== UTF-8 Code Point Iterator ===\n\n", .{});

    const iter_text = "Hello!";
    std.debug.print("Iterating over '{s}':\n", .{iter_text});

    var iter = strings.utf8.iterator(iter_text);
    while (iter.next()) |cp| {
        std.debug.print("  U+{X:0>4}\n", .{cp});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // UTF-8 to UTF-16 Conversion
    // =========================================================================

    std.debug.print("=== UTF-8 to UTF-16 Conversion ===\n\n", .{});

    const utf8_text = "Hello, \xE4\xB8\x96\xE7\x95\x8C!"; // Hello, 世界!
    std.debug.print("UTF-8: {s}\n", .{utf8_text});

    // Calculate required buffer size
    if (strings.utf8.utf16Length(utf8_text)) |utf16_len| {
        std.debug.print("UTF-16 length: {} code units\n", .{utf16_len});

        // Convert to UTF-16
        var utf16_buf = try allocator.alloc(u16, utf16_len);
        defer allocator.free(utf16_buf);

        const written = try strings.utf8.toUtf16(utf8_text, utf16_buf);
        std.debug.print("UTF-16 code units: ", .{});
        for (utf16_buf[0..written]) |unit| {
            std.debug.print("{X:0>4} ", .{unit});
        }
        std.debug.print("\n\n", .{});
    }

    // =========================================================================
    // String.toUtf16() Method
    // =========================================================================

    std.debug.print("=== String.toUtf16() Method ===\n\n", .{});

    var str = try strings.String.fromSlice(allocator, "Hello\xF0\x9F\x98\x80"); // Hello + emoji
    defer str.deinit();

    std.debug.print("Original: {s}\n", .{str.bytes()});

    // Convert to UTF-16 (little-endian bytes)
    const utf16_bytes = try str.toUtf16(.little);
    defer allocator.free(utf16_bytes);

    std.debug.print("UTF-16LE bytes: ", .{});
    for (utf16_bytes) |byte| {
        std.debug.print("{X:0>2} ", .{byte});
    }
    std.debug.print("\n\n", .{});

    // =========================================================================
    // UTF-16 to UTF-8 Conversion
    // =========================================================================

    std.debug.print("=== UTF-16 to UTF-8 Conversion ===\n\n", .{});

    // UTF-16 code units: "ABC" + supplementary character
    const utf16_units = [_]u16{ 'A', 'B', 'C', 0xD83D, 0xDE00 }; // ABC + emoji (surrogate pair)

    std.debug.print("UTF-16 units: ", .{});
    for (utf16_units) |unit| {
        std.debug.print("{X:0>4} ", .{unit});
    }
    std.debug.print("\n", .{});

    // Calculate UTF-8 length
    if (strings.utf16.utf8Length(&utf16_units)) |utf8_len| {
        std.debug.print("UTF-8 length: {} bytes\n", .{utf8_len});

        // Convert to UTF-8
        var utf8_buf = try allocator.alloc(u8, utf8_len);
        defer allocator.free(utf8_buf);

        const written = try strings.utf16.toUtf8(&utf16_units, utf8_buf);
        std.debug.print("UTF-8 result: {s}\n\n", .{utf8_buf[0..written]});
    }

    // =========================================================================
    // String.fromUtf16() Method
    // =========================================================================

    std.debug.print("=== String.fromUtf16() Method ===\n\n", .{});

    // Create UTF-16LE bytes for "Hello"
    const hello_utf16 = [_]u8{ 'H', 0, 'e', 0, 'l', 0, 'l', 0, 'o', 0 };

    std.debug.print("UTF-16LE bytes: ", .{});
    for (hello_utf16) |byte| {
        std.debug.print("{X:0>2} ", .{byte});
    }
    std.debug.print("\n", .{});

    var from_utf16 = try strings.String.fromUtf16(allocator, &hello_utf16, .little);
    defer from_utf16.deinit();

    std.debug.print("Converted to UTF-8: {s}\n\n", .{from_utf16.bytes()});

    // =========================================================================
    // UTF-16 Surrogate Pairs
    // =========================================================================

    std.debug.print("=== UTF-16 Surrogate Pairs ===\n\n", .{});

    std.debug.print("Code points > U+FFFF require surrogate pairs in UTF-16:\n", .{});
    std.debug.print("  - High surrogate: U+D800 to U+DBFF\n", .{});
    std.debug.print("  - Low surrogate: U+DC00 to U+DFFF\n\n", .{});

    // Emoji U+1F600 as surrogate pair
    const emoji_cp: u21 = 0x1F600;
    var surrogate_buf: [2]u16 = undefined;
    const encoded = strings.codepoint.encodeUtf16(emoji_cp, &surrogate_buf);

    std.debug.print("U+{X:0>5} encodes as: ", .{emoji_cp});
    for (encoded) |unit| {
        if (strings.types.surrogate.isHighSurrogate(unit)) {
            std.debug.print("{X:0>4} (high) ", .{unit});
        } else if (strings.types.surrogate.isLowSurrogate(unit)) {
            std.debug.print("{X:0>4} (low) ", .{unit});
        } else {
            std.debug.print("{X:0>4} ", .{unit});
        }
    }
    std.debug.print("\n\n", .{});

    // Decode surrogate pair
    if (strings.codepoint.decodeSurrogatePair(encoded[0], encoded[1])) |decoded| {
        std.debug.print("Decoded back: U+{X:0>5}\n\n", .{decoded});
    }

    // =========================================================================
    // UTF-16 Validation
    // =========================================================================

    std.debug.print("=== UTF-16 Validation ===\n\n", .{});

    const valid_utf16 = [_]u16{ 'H', 'e', 'l', 'l', 'o', 0xD83D, 0xDE00 }; // Hello + emoji
    const lone_high = [_]u16{ 'H', 0xD83D }; // Lone high surrogate
    const lone_low = [_]u16{ 0xDE00, 'i' }; // Lone low surrogate

    std.debug.print("'Hello' + emoji is valid: {}\n", .{strings.utf16.isValid(&valid_utf16)});
    std.debug.print("Lone high surrogate is valid: {}\n", .{strings.utf16.isValid(&lone_high)});
    std.debug.print("Lone low surrogate is valid: {}\n\n", .{strings.utf16.isValid(&lone_low)});

    // =========================================================================
    // UTF-16 Iterator
    // =========================================================================

    std.debug.print("=== UTF-16 Iterator ===\n\n", .{});

    const utf16_input = [_]u16{ 'A', 0x4E2D, 0xD83D, 0xDE00 }; // A, 中, emoji
    std.debug.print("Iterating over UTF-16 array:\n", .{});

    var utf16_iter = strings.utf16.iterator(&utf16_input);
    while (utf16_iter.next()) |cp| {
        std.debug.print("  U+{X:0>5}\n", .{cp});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Endianness
    // =========================================================================

    std.debug.print("=== Endianness ===\n\n", .{});

    const value: u16 = 0x4142; // "AB" in a way

    var le_buf: [2]u8 = undefined;
    var be_buf: [2]u8 = undefined;

    strings.utf16.writeUnit(&le_buf, value, .little);
    strings.utf16.writeUnit(&be_buf, value, .big);

    std.debug.print("Value 0x{X:0>4}:\n", .{value});
    std.debug.print("  Little-endian: {X:0>2} {X:0>2}\n", .{ le_buf[0], le_buf[1] });
    std.debug.print("  Big-endian: {X:0>2} {X:0>2}\n\n", .{ be_buf[0], be_buf[1] });

    // Read back
    const read_le = strings.utf16.readUnit(&le_buf, .little);
    const read_be = strings.utf16.readUnit(&be_buf, .big);
    std.debug.print("Read back LE: 0x{X:0>4}\n", .{read_le.?});
    std.debug.print("Read back BE: 0x{X:0>4}\n\n", .{read_be.?});

    // =========================================================================
    // UTF-32 Conversion
    // =========================================================================

    std.debug.print("=== UTF-32 ===\n\n", .{});

    std.debug.print("UTF-32 uses exactly 4 bytes per code point.\n", .{});
    std.debug.print("It's the simplest encoding but uses the most space.\n\n", .{});

    // UTF-32 is essentially just the code point value as u32
    const utf32_cps = [_]u32{ 'H', 'i', 0x1F600 };
    std.debug.print("UTF-32: ", .{});
    for (utf32_cps) |cp| {
        std.debug.print("{X:0>8} ", .{cp});
    }
    std.debug.print("\n\n", .{});

    // =========================================================================
    // Practical: Windows API Interop
    // =========================================================================

    std.debug.print("=== Practical: Windows API Interop ===\n\n", .{});

    std.debug.print("Windows APIs typically use UTF-16LE (wchar_t).\n", .{});
    std.debug.print("To call Windows APIs from Zig:\n", .{});
    std.debug.print("  1. Convert UTF-8 strings to UTF-16LE\n", .{});
    std.debug.print("  2. Pass to Windows API\n", .{});
    std.debug.print("  3. Convert result back to UTF-8\n\n", .{});

    const path = "/home/user/file.txt";
    std.debug.print("Unix path: {s}\n", .{path});

    // Convert to UTF-16 for Windows
    if (strings.utf8.utf16Length(path)) |len| {
        var utf16_path = try allocator.alloc(u16, len + 1); // +1 for null terminator
        defer allocator.free(utf16_path);

        _ = try strings.utf8.toUtf16(path, utf16_path);
        utf16_path[len] = 0; // Null terminate

        std.debug.print("UTF-16 length: {} units (+ null terminator)\n\n", .{len});
    }

    std.debug.print("=== Example Complete ===\n", .{});
}
