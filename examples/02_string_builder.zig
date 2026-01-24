// SPDX-License-Identifier: Apache-2.0
// StringBuilder Example
//
// This example demonstrates efficient string construction using StringBuilder,
// which is optimized for building strings through multiple append operations.
//
// Run with: zig build-exe 02_string_builder.zig --deps strings && ./02_string_builder

const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // =========================================================================
    // Basic StringBuilder Usage
    // =========================================================================

    std.debug.print("=== Basic StringBuilder Usage ===\n\n", .{});

    var builder = strings.StringBuilder.init(allocator);
    defer builder.deinit();

    // Append strings
    try builder.append("Hello");
    try builder.append(", ");
    try builder.append("World!");

    std.debug.print("Built string: {s}\n", .{builder.slice()});
    std.debug.print("Length: {}\n", .{builder.len()});
    std.debug.print("Capacity: {}\n\n", .{builder.capacity()});

    // =========================================================================
    // Various Append Methods
    // =========================================================================

    std.debug.print("=== Append Methods ===\n\n", .{});

    var b = strings.StringBuilder.init(allocator);
    defer b.deinit();

    // Append a single byte
    try b.appendByte('H');
    try b.appendByte('i');
    std.debug.print("After appendByte: {s}\n", .{b.slice()});

    // Append a code point (Unicode character)
    try b.appendCodepoint(' ');
    try b.appendCodepoint(0x4E16); // Chinese character
    try b.appendCodepoint(0x754C); // Another Chinese character
    std.debug.print("After appendCodepoint: {s}\n", .{b.slice()});

    // Append a string repeated N times
    try b.append(" ");
    try b.appendRepeat("-", 10);
    std.debug.print("After appendRepeat: {s}\n", .{b.slice()});

    // Append with formatting
    try b.append(" ");
    try b.appendFmt("Value: {d}, Name: {s}", .{ 42, "test" });
    std.debug.print("After appendFmt: {s}\n", .{b.slice()});

    // Append a line (string + newline)
    b.clear();
    try b.appendLine("First line");
    try b.appendLine("Second line");
    try b.append("Third line (no newline)");
    std.debug.print("\nWith lines:\n{s}\n\n", .{b.slice()});

    // Append integers and floats
    b.clear();
    try b.append("Int: ");
    try b.appendInt(@as(i32, 12345));
    try b.append(", Float: ");
    try b.appendFloat(@as(f64, 3.14159));
    std.debug.print("Numbers: {s}\n\n", .{b.slice()});

    // =========================================================================
    // Building with Multiple Code Points
    // =========================================================================

    std.debug.print("=== Building Unicode Strings ===\n\n", .{});

    var unicode_builder = strings.StringBuilder.init(allocator);
    defer unicode_builder.deinit();

    // Append multiple code points at once
    const codepoints = [_]strings.Codepoint{ 'H', 'e', 'l', 'l', 'o', ' ', 0x1F600 };
    try unicode_builder.appendCodepoints(&codepoints);
    std.debug.print("Unicode string: {s}\n\n", .{unicode_builder.slice()});

    // =========================================================================
    // Insert and Remove
    // =========================================================================

    std.debug.print("=== Insert and Remove ===\n\n", .{});

    var edit_builder = strings.StringBuilder.init(allocator);
    defer edit_builder.deinit();

    try edit_builder.append("Hello World!");
    std.debug.print("Original: {s}\n", .{edit_builder.slice()});

    // Insert at position
    try edit_builder.insert(6, "Beautiful ");
    std.debug.print("After insert: {s}\n", .{edit_builder.slice()});

    // Remove range [start, end)
    edit_builder.remove(6, 16);
    std.debug.print("After remove: {s}\n\n", .{edit_builder.slice()});

    // =========================================================================
    // Replace
    // =========================================================================

    std.debug.print("=== Replace ===\n\n", .{});

    var replace_builder = strings.StringBuilder.init(allocator);
    defer replace_builder.deinit();

    try replace_builder.append("The cat sat on the mat. The cat was happy.");
    std.debug.print("Original: {s}\n", .{replace_builder.slice()});

    try replace_builder.replace("cat", "dog");
    std.debug.print("After replace: {s}\n\n", .{replace_builder.slice()});

    // =========================================================================
    // Get/Set Individual Bytes
    // =========================================================================

    std.debug.print("=== Get/Set Bytes ===\n\n", .{});

    var byte_builder = strings.StringBuilder.init(allocator);
    defer byte_builder.deinit();

    try byte_builder.append("Hello");
    std.debug.print("Original: {s}\n", .{byte_builder.slice()});

    // Get byte at position
    if (byte_builder.get(0)) |byte| {
        std.debug.print("Byte at 0: '{c}' (0x{x})\n", .{ byte, byte });
    }

    // Set byte at position
    byte_builder.set(0, 'J');
    std.debug.print("After set(0, 'J'): {s}\n\n", .{byte_builder.slice()});

    // =========================================================================
    // Converting to Owned Slice/String
    // =========================================================================

    std.debug.print("=== Converting to Owned Slice/String ===\n\n", .{});

    // Get owned slice (caller owns the memory)
    var slice_builder = strings.StringBuilder.init(allocator);
    try slice_builder.append("Owned slice");
    const owned_slice = try slice_builder.toOwnedSlice();
    defer allocator.free(owned_slice);
    std.debug.print("Owned slice: {s}\n", .{owned_slice});
    std.debug.print("Builder is now empty: {}\n\n", .{slice_builder.isEmpty()});

    // Convert to String type
    var string_builder = strings.StringBuilder.init(allocator);
    defer string_builder.deinit();
    try string_builder.append("String type");

    var str = try string_builder.toString();
    defer str.deinit();
    std.debug.print("As String: {s}\n", .{str.bytes()});
    std.debug.print("String is inline: {}\n\n", .{str.isInline()});

    // =========================================================================
    // Using Writer Interface
    // =========================================================================

    std.debug.print("=== Writer Interface ===\n\n", .{});

    var writer_builder = strings.StringBuilder.init(allocator);
    defer writer_builder.deinit();

    // Get a std.io.Writer compatible writer
    var writer = writer_builder.writer();

    // Use standard formatting with the writer
    try writer.print("Formatted: {d} + {d} = {d}\n", .{ 2, 2, 4 });
    try writer.writeAll("Additional text\n");

    std.debug.print("Using writer:\n{s}\n", .{writer_builder.slice()});

    // =========================================================================
    // Pre-allocated Capacity
    // =========================================================================

    std.debug.print("=== Pre-allocated Capacity ===\n\n", .{});

    // Create with initial capacity to avoid reallocations
    var preallocated = try strings.StringBuilder.initCapacity(allocator, 1024);
    defer preallocated.deinit();

    std.debug.print("Initial capacity: {}\n", .{preallocated.capacity()});

    // Append without reallocating (up to 1024 bytes)
    try preallocated.append("This won't cause reallocation");
    std.debug.print("After append - capacity unchanged: {}\n\n", .{preallocated.capacity()});

    // Ensure capacity for additional content
    try preallocated.ensureCapacity(100);
    std.debug.print("After ensureCapacity(100): {}\n\n", .{preallocated.capacity()});

    // =========================================================================
    // Clear vs Reset
    // =========================================================================

    std.debug.print("=== Clear vs Reset ===\n\n", .{});

    var clear_builder = strings.StringBuilder.init(allocator);
    defer clear_builder.deinit();

    try clear_builder.append("Some content here that needs a fair bit of capacity");
    std.debug.print("Before clear - len: {}, capacity: {}\n", .{ clear_builder.len(), clear_builder.capacity() });

    // Clear retains capacity (fast)
    clear_builder.clear();
    std.debug.print("After clear - len: {}, capacity: {}\n", .{ clear_builder.len(), clear_builder.capacity() });

    try clear_builder.append("More content");

    // Reset frees all memory (returns capacity to 0)
    clear_builder.reset();
    std.debug.print("After reset - len: {}, capacity: {}\n\n", .{ clear_builder.len(), clear_builder.capacity() });

    // =========================================================================
    // Practical Example: Building HTML
    // =========================================================================

    std.debug.print("=== Practical Example: Building HTML ===\n\n", .{});

    const items = [_][]const u8{ "Apple", "Banana", "Cherry" };

    var html = strings.StringBuilder.init(allocator);
    defer html.deinit();

    try html.appendLine("<ul>");
    for (items) |item| {
        try html.appendFmt("  <li>{s}</li>\n", .{item});
    }
    try html.append("</ul>");

    std.debug.print("Generated HTML:\n{s}\n\n", .{html.slice()});

    // =========================================================================
    // Practical Example: Building JSON
    // =========================================================================

    std.debug.print("=== Practical Example: Building JSON ===\n\n", .{});

    var json = strings.StringBuilder.init(allocator);
    defer json.deinit();

    try json.appendLine("{");
    try json.appendLine("  \"name\": \"John Doe\",");
    try json.appendFmt("  \"age\": {d},\n", .{@as(u32, 30)});
    try json.appendLine("  \"languages\": [\"Zig\", \"Rust\", \"Go\"]");
    try json.append("}");

    std.debug.print("Generated JSON:\n{s}\n\n", .{json.slice()});

    std.debug.print("=== Example Complete ===\n", .{});
}
