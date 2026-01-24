# ZigStr - Unicode String Library for Zig

A comprehensive Unicode string manipulation library for Zig with full UTF-8/UTF-16/UTF-32 support, Small String Optimization (SSO), and Unicode 15.1 compliance.

## Status

| Aspect | Info |
|--------|------|
| API Stability | Beta |
| Zig Version | 0.14.0+ |
| Platforms | Linux, macOS, Windows |

## Features

- **UTF-8 Internal Storage** - Efficient storage like Go and Rust
- **Small String Optimization (SSO)** - Strings ≤23 bytes stored inline without heap allocation
- **Full Unicode Support**
  - UTF-8, UTF-16, UTF-32 encoding/decoding
  - Unicode normalization (NFC, NFD, NFKC, NFKD)
  - Grapheme cluster segmentation (UAX #29)
  - Word and sentence boundaries (UAX #29)
  - Case mapping and folding
  - Unicode Collation Algorithm (UTS #10)
  - Script detection (UAX #24)
  - BiDi algorithm (UAX #9)
  - Line breaking (UAX #14)
  - Identifier syntax (UAX #31)
- **Go-style String Functions** - Familiar API for Go developers
- **SIMD Acceleration** - AVX2/AVX-512 hardware acceleration
- **String Interning** - Memory-efficient string deduplication
- **Advanced Data Structures**
  - Rope for large string manipulation
  - Memory-mapped strings
  - Lazy normalization
- **Extended Features**
  - Regular expressions
  - Fuzzy matching (Levenshtein, Jaro-Winkler, etc.)
  - Phonetic algorithms (Soundex, Metaphone, Double Metaphone, NYSIIS)
  - Locale-specific formatting (20+ locales)
  - ICU compatibility layer
- **Legacy Encoding Support**
  - Windows code pages (CP1250-1258, CP437, CP850)
  - ISO-8859 family (1-16)
  - Chinese: GB2312, GBK, GB18030
  - Japanese: Shift_JIS, EUC-JP
  - Korean: EUC-KR, CP949
  - Traditional Chinese: Big5, Big5-HKSCS

## Installation

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .strings = .{
        .url = "https://gitlab.com/devnw/zig/strings/-/archive/main/strings-main.tar.gz",
        // Add the hash after first build attempt
    },
},
```

Then in your `build.zig`:

```zig
const strings = b.dependency("strings", .{
    .target = target,
    .optimize = optimize,
});
exe.root_module.addImport("strings", strings.module("strings"));
```

## Quick Start

```zig
const std = @import("std");
const strings = @import("strings");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Create a string (uses SSO for small strings)
    var str = try strings.String.fromSlice(allocator, "Hello, World!");
    defer str.deinit();

    // String operations
    std.debug.print("Length: {}\n", .{str.len()});
    std.debug.print("Is inline (SSO): {}\n", .{str.isInline()});

    // Search
    if (str.contains("World")) {
        std.debug.print("Found 'World'!\n", .{});
    }

    // Case conversion
    var upper = try str.toUpper();
    defer upper.deinit();
    std.debug.print("Upper: {s}\n", .{upper.bytes()});

    // UTF-16 conversion
    const utf16 = try str.toUtf16(.little);
    defer allocator.free(utf16);
}
```

## Core Types

### String
UTF-8 backed string with SSO:
```zig
var str = try strings.String.fromSlice(allocator, "Hello");
defer str.deinit();

// SSO: strings ≤23 bytes are stored inline
try std.testing.expect(str.isInline());
```

### StringBuilder
Efficient string concatenation:
```zig
var builder = strings.StringBuilder.init(allocator);
defer builder.deinit();

try builder.append("Hello");
try builder.appendByte(' ');
try builder.append("World");

const result = builder.slice(); // "Hello World"
```

### StringPool
String interning for memory efficiency:
```zig
var pool = strings.StringPool.init(allocator);
defer pool.deinit();

const s1 = try pool.intern("hello");
const s2 = try pool.intern("hello");
// s1.ptr == s2.ptr (same memory)
```

## Unicode Operations

### Grapheme Clusters
```zig
// Count user-perceived characters
const text = "e\xCC\x81"; // e + combining acute = é
const count = strings.grapheme.count(text);
// count == 1 (one grapheme cluster)
```

### Case Conversion
```zig
const upper = try strings.toUpper(allocator, "hello");
defer allocator.free(upper);
// upper == "HELLO"

const lower = try strings.toLower(allocator, "WORLD");
defer allocator.free(lower);
// lower == "world"
```

### Collation
```zig
// Case-insensitive comparison
const eq = strings.collation.equals("Hello", "HELLO", .{ .strength = .primary });
// eq == true
```

### Encoding Detection
```zig
const result = strings.detection.detect("\xEF\xBB\xBFHello");
// result.encoding == .utf8
// result.has_bom == true
```

## Go-style Functions

For developers familiar with Go's `strings` package:

```zig
// Cut - split at first separator
const result = strings.cut("hello,world", ",");
// result.before == "hello", result.after == "world"

// Fields - split on whitespace
var fields = strings.fields(allocator, "  hello   world  ");
defer fields.deinit();
// fields.items == ["hello", "world"]

// TrimPrefix/TrimSuffix
const trimmed = strings.trimPrefix("hello.txt", "hello");
// trimmed == ".txt"
```

## Building

```bash
# Build library
zig build

# Run all tests
zig build test

# Run specific test suite
zig build test-string
zig build test-unicode
zig build test-acceptance
```

## Documentation

- [API Reference](docs/API.md)
- [Usage Examples](docs/USAGE.md)
- [Architecture](docs/ARCHITECTURE.md)
- [Roadmap](docs/ROADMAP.md)

## Project Status

**v0.1.0** - Feature Complete

All planned features have been implemented:

- UTF-8, UTF-16, UTF-32, ASCII, Latin-1 encoding/decoding
- Small String Optimization (SSO)
- Full Unicode Character Database tables
- Text segmentation (grapheme, word, sentence)
- Unicode normalization (NFC, NFD, NFKC, NFKD)
- Case conversion and folding
- Unicode Collation Algorithm
- Script detection, BiDi, line breaking, identifier syntax
- SIMD acceleration (AVX2/AVX-512)
- String interning, rope data structure, memory-mapped strings
- Regular expressions, fuzzy matching, phonetic algorithms
- Locale-specific formatting, ICU compatibility layer
- Legacy encodings (Windows CP, ISO-8859, CJK)

See [ROADMAP.md](docs/ROADMAP.md) for full details.

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Priority areas:
1. **Testing** - Add Unicode conformance test vectors
2. **Documentation** - Examples and tutorials
3. **Bug fixes** - Report and fix any issues
4. **Performance** - Profile and optimize critical paths
5. **Additional locales** - Expand locale support

## License

Apache-2.0 License - See [LICENSE](LICENSE) for details.

## References

- [Unicode Standard](https://unicode.org/standard/standard.html)
- [UAX #15: Normalization Forms](https://unicode.org/reports/tr15/)
- [UAX #29: Text Segmentation](https://unicode.org/reports/tr29/)
- [UTS #10: Collation Algorithm](https://unicode.org/reports/tr10/)
- [Zig Language](https://ziglang.org/)
