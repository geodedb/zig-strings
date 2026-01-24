// SPDX-License-Identifier: Apache-2.0
// String Interning Pool Example
//
// This example demonstrates string interning for memory efficiency.
// String interning stores only one copy of each unique string, which:
// - Reduces memory usage when many duplicates exist
// - Enables O(1) equality comparison by pointer
// - Is useful for identifiers, keywords, and symbols
//
// Run with: zig build-exe 06_string_pool.zig --deps strings && ./06_string_pool

const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // =========================================================================
    // Basic String Pool Usage
    // =========================================================================

    std.debug.print("=== Basic String Pool Usage ===\n\n", .{});

    var pool = strings.StringPool.init(allocator);
    defer pool.deinit();

    // Intern some strings
    const hello1 = try pool.intern("hello");
    const world = try pool.intern("world");
    const hello2 = try pool.intern("hello"); // Returns same pointer

    std.debug.print("Interned 'hello' twice and 'world' once\n", .{});
    std.debug.print("hello1 ptr: {*}\n", .{hello1.ptr});
    std.debug.print("hello2 ptr: {*}\n", .{hello2.ptr});
    std.debug.print("world ptr: {*}\n\n", .{world.ptr});

    // Same strings have same pointer
    std.debug.print("hello1.ptr == hello2.ptr: {}\n", .{hello1.ptr == hello2.ptr});
    std.debug.print("hello1.ptr == world.ptr: {}\n", .{hello1.ptr == world.ptr});
    std.debug.print("Unique strings in pool: {}\n\n", .{pool.count()});

    // =========================================================================
    // Memory Efficiency
    // =========================================================================

    std.debug.print("=== Memory Efficiency ===\n\n", .{});

    var efficiency_pool = strings.StringPool.init(allocator);
    defer efficiency_pool.deinit();

    // Simulate many duplicate strings (like parsing keywords)
    const keywords = [_][]const u8{
        "function", "if", "else", "while", "for", "return",
        "function", "if", "if", "return", "else", "function",
        "while", "for", "return", "if", "else", "function",
    };

    std.debug.print("Interning {} string instances...\n", .{keywords.len});

    for (keywords) |kw| {
        _ = try efficiency_pool.intern(kw);
    }

    std.debug.print("Unique strings stored: {}\n", .{efficiency_pool.count()});
    std.debug.print("Memory saved: {} string copies avoided\n\n", .{keywords.len - efficiency_pool.count()});

    // =========================================================================
    // Fast Comparison
    // =========================================================================

    std.debug.print("=== Fast Pointer Comparison ===\n\n", .{});

    var cmp_pool = strings.StringPool.init(allocator);
    defer cmp_pool.deinit();

    const str_a = try cmp_pool.intern("identifier_name");
    const str_b = try cmp_pool.intern("identifier_name");
    const str_c = try cmp_pool.intern("different_name");

    // Pointer comparison is O(1), no need to compare bytes
    std.debug.print("Pointer comparison (O(1)):\n", .{});
    std.debug.print("  str_a == str_b: {}\n", .{str_a.ptr == str_b.ptr});
    std.debug.print("  str_a == str_c: {}\n\n", .{str_a.ptr == str_c.ptr});

    // Can still use for string content
    std.debug.print("String content: {s}\n\n", .{str_a});

    // =========================================================================
    // Check Existence
    // =========================================================================

    std.debug.print("=== Check Existence ===\n\n", .{});

    var check_pool = strings.StringPool.init(allocator);
    defer check_pool.deinit();

    _ = try check_pool.intern("exists");

    std.debug.print("Pool contains 'exists': {}\n", .{check_pool.contains("exists")});
    std.debug.print("Pool contains 'missing': {}\n\n", .{check_pool.contains("missing")});

    // Get returns the interned version if it exists
    if (check_pool.get("exists")) |interned| {
        std.debug.print("Retrieved: {s}\n", .{interned});
    }
    if (check_pool.get("missing")) |_| {
        std.debug.print("Should not reach here\n", .{});
    } else {
        std.debug.print("'missing' not in pool\n\n", .{});
    }

    // =========================================================================
    // Iterating Over Interned Strings
    // =========================================================================

    std.debug.print("=== Iterating Over Pool ===\n\n", .{});

    var iter_pool = strings.StringPool.init(allocator);
    defer iter_pool.deinit();

    _ = try iter_pool.intern("apple");
    _ = try iter_pool.intern("banana");
    _ = try iter_pool.intern("cherry");

    std.debug.print("All interned strings:\n", .{});
    for (iter_pool.iterator()) |s| {
        std.debug.print("  - {s}\n", .{s});
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Symbol Table
    // =========================================================================

    std.debug.print("=== Symbol Table ===\n\n", .{});

    std.debug.print("SymbolTable assigns unique IDs to interned strings.\n", .{});
    std.debug.print("Useful for compilers, interpreters, and parsers.\n\n", .{});

    var symbols = strings.SymbolTable.init(allocator);
    defer symbols.deinit();

    // Get or create symbol IDs
    const id_foo = try symbols.getOrPut("foo");
    const id_bar = try symbols.getOrPut("bar");
    const id_baz = try symbols.getOrPut("baz");
    const id_foo2 = try symbols.getOrPut("foo"); // Same as id_foo

    std.debug.print("Symbol IDs:\n", .{});
    std.debug.print("  foo: {}\n", .{id_foo});
    std.debug.print("  bar: {}\n", .{id_bar});
    std.debug.print("  baz: {}\n", .{id_baz});
    std.debug.print("  foo (again): {}\n\n", .{id_foo2});

    std.debug.print("id_foo == id_foo2: {}\n", .{id_foo == id_foo2});
    std.debug.print("Total symbols: {}\n\n", .{symbols.count()});

    // Check if symbol exists
    std.debug.print("Contains 'foo': {}\n", .{symbols.contains("foo")});
    std.debug.print("Contains 'missing': {}\n", .{symbols.contains("missing")});

    // Get symbol ID (returns null if not exists)
    if (symbols.get("bar")) |id| {
        std.debug.print("ID for 'bar': {}\n\n", .{id});
    }

    // =========================================================================
    // Practical Example: Lexer Keywords
    // =========================================================================

    std.debug.print("=== Practical: Lexer Keywords ===\n\n", .{});

    var keyword_pool = strings.StringPool.init(allocator);
    defer keyword_pool.deinit();

    // Pre-intern all language keywords
    const lang_keywords = [_][]const u8{
        "fn", "const", "var", "if", "else", "while", "for",
        "return", "break", "continue", "pub", "struct", "enum",
    };

    std.debug.print("Pre-interning {} keywords...\n", .{lang_keywords.len});
    for (lang_keywords) |kw| {
        _ = try keyword_pool.intern(kw);
    }

    // Simulated lexer: check if identifier is a keyword
    const tokens = [_][]const u8{ "fn", "main", "if", "x", "return" };

    std.debug.print("\nToken classification:\n", .{});
    for (tokens) |token| {
        const is_keyword = keyword_pool.contains(token);
        std.debug.print("  '{s}': {s}\n", .{
            token,
            if (is_keyword) "KEYWORD" else "IDENTIFIER",
        });
    }
    std.debug.print("\n", .{});

    // =========================================================================
    // Practical Example: Compiler Symbol Table
    // =========================================================================

    std.debug.print("=== Practical: Compiler Symbol Table ===\n\n", .{});

    var compiler_symbols = strings.SymbolTable.init(allocator);
    defer compiler_symbols.deinit();

    // Simulated variable declarations
    const Variable = struct {
        name_id: usize,
        type_id: usize,
        scope_depth: usize,
    };

    var variables: [10]Variable = undefined;
    var var_count: usize = 0;

    // Declare some variables
    const decls = [_]struct { name: []const u8, type_name: []const u8, depth: usize }{
        .{ .name = "x", .type_name = "i32", .depth = 0 },
        .{ .name = "y", .type_name = "i32", .depth = 0 },
        .{ .name = "name", .type_name = "string", .depth = 1 },
        .{ .name = "x", .type_name = "f64", .depth = 1 }, // Shadow x
    };

    for (decls) |decl| {
        variables[var_count] = .{
            .name_id = try compiler_symbols.getOrPut(decl.name),
            .type_id = try compiler_symbols.getOrPut(decl.type_name),
            .scope_depth = decl.depth,
        };
        var_count += 1;
    }

    std.debug.print("Variables (using symbol IDs):\n", .{});
    for (variables[0..var_count]) |v| {
        std.debug.print("  name_id={}, type_id={}, depth={}\n", .{
            v.name_id,
            v.type_id,
            v.scope_depth,
        });
    }
    std.debug.print("\nTotal unique symbols: {}\n\n", .{compiler_symbols.count()});

    // =========================================================================
    // Clearing the Pool
    // =========================================================================

    std.debug.print("=== Clearing the Pool ===\n\n", .{});

    var clearable_pool = strings.StringPool.init(allocator);
    defer clearable_pool.deinit();

    _ = try clearable_pool.intern("one");
    _ = try clearable_pool.intern("two");
    _ = try clearable_pool.intern("three");

    std.debug.print("Before clear: {} strings\n", .{clearable_pool.count()});

    clearable_pool.clear();

    std.debug.print("After clear: {} strings\n\n", .{clearable_pool.count()});

    // Can add new strings after clear
    _ = try clearable_pool.intern("new");
    std.debug.print("After adding 'new': {} strings\n\n", .{clearable_pool.count()});

    std.debug.print("=== Example Complete ===\n", .{});
}
