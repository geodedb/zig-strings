# Usage Examples

Practical examples for using the ZigStr library.

## Table of Contents

- [Basic String Operations](#basic-string-operations)
- [Unicode Text Processing](#unicode-text-processing)
- [Encoding Conversion](#encoding-conversion)
- [Text Parsing](#text-parsing)
- [String Building](#string-building)
- [String Interning](#string-interning)
- [Performance Tips](#performance-tips)

---

## Basic String Operations

### Creating and Using Strings

```zig
const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a string - automatically uses SSO for small strings
    var str = try strings.String.fromSlice(allocator, "Hello, World!");
    defer str.deinit();

    // Check if using SSO (no heap allocation)
    if (str.isInline()) {
        std.debug.print("String is stored inline (SSO)\n", .{});
    }

    // Get string content
    std.debug.print("Content: {s}\n", .{str.bytes()});
    std.debug.print("Length: {} bytes\n", .{str.len()});
}
```

### Search Operations

```zig
var str = try strings.String.fromSlice(allocator, "Hello, World!");
defer str.deinit();

// Check if contains substring
if (str.contains("World")) {
    std.debug.print("Found 'World'\n", .{});
}

// Check prefix/suffix
if (str.startsWith("Hello")) {
    std.debug.print("Starts with 'Hello'\n", .{});
}

if (str.endsWith("!")) {
    std.debug.print("Ends with '!'\n", .{});
}

// Find index
if (str.indexOf("World")) |idx| {
    std.debug.print("'World' found at index {}\n", .{idx});
}
```

### String Transformations

```zig
var str = try strings.String.fromSlice(allocator, "  Hello, World!  ");
defer str.deinit();

// Trim whitespace (returns new string)
var trimmed = try str.trimmed();
defer trimmed.deinit();
std.debug.print("Trimmed: '{s}'\n", .{trimmed.bytes()});

// Case conversion
var upper = try str.toUpper();
defer upper.deinit();
std.debug.print("Upper: {s}\n", .{upper.bytes()});

var lower = try str.toLower();
defer lower.deinit();
std.debug.print("Lower: {s}\n", .{lower.bytes()});

// Replace
var replaced = try str.replaced("World", "Zig");
defer replaced.deinit();
std.debug.print("Replaced: {s}\n", .{replaced.bytes()});
```

---

## Unicode Text Processing

### Grapheme Clusters

User-perceived characters (grapheme clusters) can span multiple bytes:

```zig
const strings = @import("strings");

// Single grapheme, multiple bytes
const text = "e\xCC\x81"; // e + combining acute = é

// Count graphemes (user-perceived characters)
const grapheme_count = strings.grapheme.count(text);
std.debug.print("Graphemes: {}\n", .{grapheme_count}); // 1

// Count bytes
std.debug.print("Bytes: {}\n", .{text.len}); // 3

// Count codepoints
const cp_count = strings.countCodepoints(text);
std.debug.print("Codepoints: {?}\n", .{cp_count}); // 2

// Iterate over grapheme clusters
var iter = strings.grapheme.iterator("Hello, 世界!");
while (iter.next()) |cluster| {
    std.debug.print("Cluster: {s}\n", .{cluster});
}
```

### Word Iteration

```zig
var iter = strings.word.iterator("Hello, World! How are you?");

while (iter.next()) |word| {
    // Filter out punctuation/spaces
    var has_letter = false;
    for (word) |c| {
        if ((c >= 'A' and c <= 'Z') or (c >= 'a' and c <= 'z')) {
            has_letter = true;
            break;
        }
    }
    if (has_letter) {
        std.debug.print("Word: {s}\n", .{word});
    }
}
// Output: Hello, World, How, are, you
```

### Case Conversion with Unicode

```zig
// Convert Greek letters
const greek = "\xCE\x91\xCE\x92\xCE\x93"; // ΑΒΓ
const lower = try strings.toLower(allocator, greek);
defer allocator.free(lower);
std.debug.print("Lowercase: {s}\n", .{lower}); // αβγ

// German sharp s
const german = "stra\xC3\x9Fe"; // straße
const upper = try strings.toUpper(allocator, german);
defer allocator.free(upper);
std.debug.print("Uppercase: {s}\n", .{upper}); // STRASSE
```

### Unicode Collation

```zig
// Case-insensitive comparison
const opts = strings.collation.Options{ .strength = .primary };

if (strings.collation.equals("Hello", "HELLO", opts)) {
    std.debug.print("Strings are equal (case-insensitive)\n", .{});
}

// Sorting comparison
const order = strings.collation.compare("apple", "banana", opts);
switch (order) {
    .lt => std.debug.print("apple < banana\n", .{}),
    .gt => std.debug.print("apple > banana\n", .{}),
    .eq => std.debug.print("apple == banana\n", .{}),
}
```

### Normalization

```zig
// Decompose to NFD
const composed = "\xC3\xA9"; // é (precomposed)
const nfd = try strings.normalization.normalize(allocator, composed, .nfd);
defer allocator.free(nfd);
// nfd is now "e\xCC\x81" (e + combining acute)

// Check if normalized
if (strings.normalization.isNormalized(text, .nfd)) {
    std.debug.print("Already in NFD form\n", .{});
}
```

---

## Encoding Conversion

### UTF-8 to UTF-16

```zig
var str = try strings.String.fromSlice(allocator, "Hello, 世界!");
defer str.deinit();

// Convert to UTF-16 (little-endian)
const utf16 = try str.toUtf16(.little);
defer allocator.free(utf16);

std.debug.print("UTF-16 units: {}\n", .{utf16.len});

// Convert back to UTF-8
var back = try strings.String.fromUtf16(allocator, utf16, .little);
defer back.deinit();

std.debug.print("Round-trip: {s}\n", .{back.bytes()});
```

### Encoding Detection

```zig
// Detect encoding from BOM
const with_bom = "\xEF\xBB\xBFHello"; // UTF-8 BOM
const result = strings.detection.detect(with_bom);

std.debug.print("Encoding: {}\n", .{result.encoding}); // .utf8
std.debug.print("Has BOM: {}\n", .{result.has_bom}); // true

// Skip BOM if present
const content = strings.bom.skip(with_bom);
std.debug.print("Content: {s}\n", .{content}); // "Hello"
```

### Latin-1 Conversion

```zig
// UTF-8 to Latin-1 (for legacy systems)
const utf8 = "caf\xC3\xA9"; // café in UTF-8
const latin1 = try strings.transcoding.utf8ToLatin1(allocator, utf8, .{});
defer allocator.free(latin1);
// latin1[3] == 0xE9 (é in Latin-1)

// Latin-1 to UTF-8
const back = try strings.transcoding.latin1ToUtf8(allocator, latin1);
defer allocator.free(back);
```

---

## Text Parsing

### Go-style Cut Functions

```zig
// Cut at first separator
const result = strings.cut("user@example.com", "@");
if (result.found) {
    std.debug.print("User: {s}\n", .{result.before}); // user
    std.debug.print("Domain: {s}\n", .{result.after}); // example.com
}

// Remove prefix
if (strings.cutPrefix("hello.txt", "hello")) |suffix| {
    std.debug.print("Suffix: {s}\n", .{suffix}); // .txt
}

// Remove suffix
if (strings.cutSuffix("hello.txt", ".txt")) |prefix| {
    std.debug.print("Prefix: {s}\n", .{prefix}); // hello
}
```

### Splitting Strings

```zig
// Split on whitespace
var words = try strings.fields(allocator, "  hello   world  ");
defer words.deinit(allocator);

for (words.items) |word| {
    std.debug.print("Word: {s}\n", .{word});
}

// Split with limit
var parts = try strings.splitN(allocator, "a,b,c,d", ",", 2);
defer parts.deinit(allocator);
// parts.items = ["a", "b,c,d"]

// Split keeping delimiter
var segments = try strings.splitAfter(allocator, "a.b.c", ".");
defer segments.deinit(allocator);
// segments.items = ["a.", "b.", "c"]
```

### Line Processing

```zig
const text = "line1\nline2\r\nline3";
var iter = strings.iterator.lines(text);

while (iter.next()) |line| {
    std.debug.print("Line: {s}\n", .{line});
}
```

### Numeric Parsing

```zig
// Parse integers
const num = try strings.numeric.parseInt(i32, "12345");
std.debug.print("Number: {}\n", .{num});

// Parse floats
const f = try strings.numeric.parseFloat(f64, "3.14159");
std.debug.print("Float: {d}\n", .{f});

// Parse booleans
const b = try strings.numeric.parseBool("true");
std.debug.print("Bool: {}\n", .{b});

// Format numbers
const formatted = try strings.numeric.formatInt(allocator, 255, 16);
defer allocator.free(formatted);
std.debug.print("Hex: {s}\n", .{formatted}); // "ff"
```

---

## String Building

### StringBuilder for Concatenation

```zig
var builder = strings.StringBuilder.init(allocator);
defer builder.deinit();

// Build string incrementally
try builder.append("Hello");
try builder.appendByte(',');
try builder.appendByte(' ');
try builder.append("World");
try builder.appendCodepoint('!');

std.debug.print("Result: {s}\n", .{builder.slice()});

// In-place replacement
try builder.replace("World", "Zig");
std.debug.print("After replace: {s}\n", .{builder.slice()});

// Convert to String
var str = try builder.toString();
defer str.deinit();
```

### String Interpolation

```zig
// Positional interpolation
const result = try strings.formatting.interpolate(
    allocator,
    "Hello, {}! You have {} messages.",
    &[_][]const u8{ "Alice", "5" },
);
defer allocator.free(result);
std.debug.print("{s}\n", .{result});
// Output: Hello, Alice! You have 5 messages.

// Named interpolation
const named = try strings.formatting.interpolateNamed(
    allocator,
    "Welcome, {name}! Today is {day}.",
    &[_]strings.formatting.NamedValue{
        .{ .name = "name", .value = "Bob" },
        .{ .name = "day", .value = "Monday" },
    },
);
defer allocator.free(named);
std.debug.print("{s}\n", .{named});
// Output: Welcome, Bob! Today is Monday.
```

---

## String Interning

### StringPool for Deduplication

```zig
var pool = strings.StringPool.init(allocator);
defer pool.deinit();

// Intern strings
const s1 = try pool.intern("hello");
const s2 = try pool.intern("world");
const s3 = try pool.intern("hello"); // Returns same as s1

// Same pointer for identical strings
if (s1.ptr == s3.ptr) {
    std.debug.print("Strings are interned (same memory)\n", .{});
}

std.debug.print("Unique strings: {}\n", .{pool.count()}); // 2
```

### SymbolTable for Identifiers

```zig
var table = strings.SymbolTable.init(allocator);
defer table.deinit();

// Get or create symbol IDs
const id1 = try table.getOrPut("variable1");
const id2 = try table.getOrPut("variable2");
const id3 = try table.getOrPut("variable1"); // Returns same ID as id1

std.debug.print("ID1: {}, ID3: {}\n", .{id1, id3}); // Same

// Lookup by ID
if (table.getName(id1)) |name| {
    std.debug.print("Symbol {}: {s}\n", .{id1, name});
}

// Check existence
if (table.contains("variable1")) {
    std.debug.print("Symbol exists\n", .{});
}
```

---

## Performance Tips

### Use SSO for Short Strings

Strings ≤23 bytes use Small String Optimization (no heap allocation):

```zig
// These use SSO (fast, no heap)
var short = try strings.String.fromSlice(allocator, "hello");
var threshold = try strings.String.fromSlice(allocator, "12345678901234567890123"); // 23 bytes

// This uses heap allocation
var long = try strings.String.fromSlice(allocator, "123456789012345678901234"); // 24 bytes
```

### Use Slices When Possible

Many operations work directly on slices without allocation:

```zig
// No allocation - returns slice views
const prefix = strings.trimPrefix("hello.txt", "hello"); // ".txt"
const suffix = strings.trimSuffix("hello.txt", ".txt"); // "hello"

// Cut returns views into original string
const result = strings.cut("key=value", "=");
// result.before and result.after are views, not copies
```

### SIMD for Bulk Operations

Use SIMD functions for large data:

```zig
// Fast ASCII check
if (strings.simd.isAllAscii(large_buffer)) {
    // Use fast ASCII path
}

// SIMD case conversion
var dest: [1024]u8 = undefined;
strings.simd.toLowerAscii(dest[0..input.len], input);
```

### Reuse StringBuilder

Reuse builders instead of creating new ones:

```zig
var builder = strings.StringBuilder.init(allocator);
defer builder.deinit();

for (items) |item| {
    builder.clear(); // Reuse existing capacity
    try builder.append(prefix);
    try builder.append(item);
    processString(builder.slice());
}
```

### Use StringPool for Repeated Strings

When processing data with many repeated strings:

```zig
var pool = strings.StringPool.init(allocator);
defer pool.deinit();

for (records) |record| {
    // Intern frequently repeated values
    const category = try pool.intern(record.category);
    const status = try pool.intern(record.status);
    // Use interned strings...
}
```
