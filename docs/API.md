# API Reference

Complete API documentation for the ZigStr library.

## Table of Contents

- [Core Types](#core-types)
- [Encoding Modules](#encoding-modules)
- [Unicode Modules](#unicode-modules)
- [String Operations](#string-operations)
- [Utility Functions](#utility-functions)

---

## Core Types

### String

UTF-8 backed string with Small String Optimization (SSO).

```zig
pub const String = struct {
    // Creation
    pub fn init(allocator: Allocator) String
    pub fn fromSlice(allocator: Allocator, slice: []const u8) !String
    pub fn fromUtf16(allocator: Allocator, utf16: []const u16, endian: Endian) !String
    pub fn deinit(self: *String) void

    // Properties
    pub fn len(self: *const String) usize
    pub fn bytes(self: *const String) []const u8
    pub fn isInline(self: *const String) bool
    pub fn isEmpty(self: *const String) bool

    // Modification
    pub fn append(self: *String, data: []const u8) !void
    pub fn appendCodepoint(self: *String, cp: Codepoint) !void
    pub fn clear(self: *String) void
    pub fn clone(self: *const String) !String

    // Transformations (return new String)
    pub fn trimmed(self: *const String) !String
    pub fn toUpper(self: *const String) !String
    pub fn toLower(self: *const String) !String
    pub fn replaced(self: *const String, old: []const u8, new: []const u8) !String

    // Search
    pub fn contains(self: *const String, needle: []const u8) bool
    pub fn startsWith(self: *const String, prefix: []const u8) bool
    pub fn endsWith(self: *const String, suffix: []const u8) bool
    pub fn indexOf(self: *const String, needle: []const u8) ?usize

    // Encoding conversion
    pub fn toUtf16(self: *const String, endian: Endian) ![]u16
};
```

**SSO Behavior:**
- Strings ≤23 bytes are stored inline (no heap allocation)
- Strings >23 bytes use heap allocation
- Use `isInline()` to check storage mode

### StringBuilder

Efficient string building with dynamic buffer.

```zig
pub const StringBuilder = struct {
    pub fn init(allocator: Allocator) StringBuilder
    pub fn deinit(self: *StringBuilder) void

    // Appending
    pub fn append(self: *StringBuilder, data: []const u8) !void
    pub fn appendByte(self: *StringBuilder, byte: u8) !void
    pub fn appendCodepoint(self: *StringBuilder, cp: Codepoint) !void
    pub fn appendFmt(self: *StringBuilder, comptime fmt: []const u8, args: anytype) !void

    // Access
    pub fn slice(self: *const StringBuilder) []const u8
    pub fn len(self: *const StringBuilder) usize

    // Modification
    pub fn clear(self: *StringBuilder) void
    pub fn replace(self: *StringBuilder, old: []const u8, new: []const u8) !void

    // Conversion
    pub fn toString(self: *const StringBuilder) !String
};
```

### StringPool

String interning for memory-efficient storage of repeated strings.

```zig
pub const StringPool = struct {
    pub fn init(allocator: Allocator) StringPool
    pub fn deinit(self: *StringPool) void

    pub fn intern(self: *StringPool, str: []const u8) ![]const u8
    pub fn contains(self: *const StringPool, str: []const u8) bool
    pub fn count(self: *const StringPool) usize
};
```

### SymbolTable

Symbol interning with numeric IDs.

```zig
pub const SymbolTable = struct {
    pub fn init(allocator: Allocator) SymbolTable
    pub fn deinit(self: *SymbolTable) void

    pub fn getOrPut(self: *SymbolTable, str: []const u8) !u32
    pub fn get(self: *const SymbolTable, str: []const u8) ?u32
    pub fn getName(self: *const SymbolTable, id: u32) ?[]const u8
    pub fn contains(self: *const SymbolTable, str: []const u8) bool
};
```

### String16

UTF-16 string type.

```zig
pub const String16 = struct {
    pub fn fromUtf8(allocator: Allocator, utf8: []const u8) !String16
    pub fn deinit(self: *String16) void

    pub fn toUtf8(self: *const String16) ![]u8
    pub fn len(self: *const String16) usize
    pub fn units(self: *const String16) []const u16
};
```

---

## Encoding Modules

### utf8

UTF-8 encoding utilities.

```zig
pub const utf8 = struct {
    // Validation
    pub fn isValid(bytes: []const u8) bool
    pub fn validate(bytes: []const u8) ValidationResult

    // Counting
    pub fn countCodepoints(bytes: []const u8) ?usize

    // Iteration
    pub fn iterator(bytes: []const u8) Iterator

    // Decoding
    pub fn decode(bytes: []const u8) ?DecodeResult
    pub fn decodeCodepoint(bytes: []const u8) ?Codepoint
};
```

### utf16

UTF-16 encoding utilities.

```zig
pub const utf16 = struct {
    pub fn encode(cp: Codepoint, buf: *[2]u16) []u16
    pub fn decode(units: []const u16) ?DecodeResult
    pub fn countCodeUnits(cp: Codepoint) u2
};
```

### utf32

UTF-32 encoding utilities.

```zig
pub const utf32 = struct {
    pub fn encode(cp: Codepoint) u32
    pub fn decode(unit: u32) ?Codepoint
    pub fn isValid(unit: u32) bool
};
```

### ascii

ASCII utilities.

```zig
pub const ascii = struct {
    pub fn isAscii(byte: u8) bool
    pub fn isAllAscii(bytes: []const u8) bool
    pub fn toLower(byte: u8) u8
    pub fn toUpper(byte: u8) u8
    pub fn isAlpha(byte: u8) bool
    pub fn isDigit(byte: u8) bool
    pub fn isAlphanumeric(byte: u8) bool
    pub fn isWhitespace(byte: u8) bool
};
```

### latin1

Latin-1 (ISO-8859-1) utilities.

```zig
pub const latin1 = struct {
    pub fn toUtf8(allocator: Allocator, bytes: []const u8) ![]u8
    pub fn fromUtf8(allocator: Allocator, utf8: []const u8) ![]u8
    pub fn isValid(byte: u8) bool  // Always true for Latin-1
};
```

---

## Unicode Modules

### grapheme

Grapheme cluster segmentation (UAX #29).

```zig
pub const grapheme = struct {
    pub fn count(bytes: []const u8) usize
    pub fn iterator(bytes: []const u8) Iterator

    pub const Iterator = struct {
        pub fn next(self: *Iterator) ?[]const u8
        pub fn reset(self: *Iterator) void
    };
};
```

### word

Word boundary detection (UAX #29).

```zig
pub const word = struct {
    pub fn iterator(bytes: []const u8) Iterator

    pub const Iterator = struct {
        pub fn next(self: *Iterator) ?[]const u8
    };
};
```

### sentence

Sentence boundary detection (UAX #29).

```zig
pub const sentence = struct {
    pub fn iterator(bytes: []const u8) Iterator

    pub const Iterator = struct {
        pub fn next(self: *Iterator) ?[]const u8
    };
};
```

### normalization

Unicode normalization (UAX #15).

```zig
pub const normalization = struct {
    pub const NormalizationForm = enum { nfc, nfd, nfkc, nfkd };

    pub fn normalize(allocator: Allocator, str: []const u8, form: NormalizationForm) ![]u8
    pub fn isNormalized(str: []const u8, form: NormalizationForm) bool
};
```

**Note:** NFD and NFKD are fully implemented. NFC and NFKC composition is in progress.

### case

Case mapping and folding.

```zig
pub const case = struct {
    pub fn toLowerString(allocator: Allocator, str: []const u8) ![]u8
    pub fn toUpperString(allocator: Allocator, str: []const u8) ![]u8
    pub fn toTitleString(allocator: Allocator, str: []const u8) ![]u8
    pub fn foldCase(allocator: Allocator, str: []const u8) ![]u8

    pub fn toLowerCodepoint(cp: Codepoint) Codepoint
    pub fn toUpperCodepoint(cp: Codepoint) Codepoint
};
```

### collation

Unicode Collation Algorithm (UTS #10).

```zig
pub const collation = struct {
    pub const Strength = enum { primary, secondary, tertiary, quaternary, identical };

    pub const Options = struct {
        strength: Strength = .tertiary,
    };

    pub fn compare(a: []const u8, b: []const u8, opts: Options) std.math.Order
    pub fn equals(a: []const u8, b: []const u8, opts: Options) bool
};
```

### categories

Unicode character categories (UAX #44).

```zig
pub const categories = struct {
    pub const Category = enum {
        Lu, Ll, Lt, Lm, Lo,  // Letter
        Mn, Mc, Me,          // Mark
        Nd, Nl, No,          // Number
        Pc, Pd, Ps, Pe, Pi, Pf, Po,  // Punctuation
        Sm, Sc, Sk, So,      // Symbol
        Zs, Zl, Zp,          // Separator
        Cc, Cf, Cs, Co, Cn,  // Other
    };

    pub fn getCategory(cp: Codepoint) Category
    pub fn isLetter(cp: Codepoint) bool
    pub fn isDigit(cp: Codepoint) bool
    pub fn isWhitespace(cp: Codepoint) bool
    pub fn isPunctuation(cp: Codepoint) bool
};
```

---

## String Operations

### search

String search operations.

```zig
pub const search = struct {
    pub fn indexOf(haystack: []const u8, needle: []const u8) ?usize
    pub fn lastIndexOf(haystack: []const u8, needle: []const u8) ?usize
    pub fn contains(haystack: []const u8, needle: []const u8) bool
    pub fn count(haystack: []const u8, needle: []const u8) usize

    pub fn indexByte(str: []const u8, byte: u8) ?usize
    pub fn lastIndexByte(str: []const u8, byte: u8) ?usize
    pub fn indexAny(str: []const u8, chars: []const u8) ?usize
    pub fn lastIndexAny(str: []const u8, chars: []const u8) ?usize
    pub fn indexFunc(str: []const u8, predicate: fn(Codepoint) bool) ?usize
    pub fn lastIndexFunc(str: []const u8, predicate: fn(Codepoint) bool) ?usize
};
```

### manipulation

String manipulation operations.

```zig
pub const manipulation = struct {
    // Go-style functions
    pub fn cut(str: []const u8, sep: []const u8) CutResult
    pub fn cutPrefix(str: []const u8, prefix: []const u8) ?[]const u8
    pub fn cutSuffix(str: []const u8, suffix: []const u8) ?[]const u8
    pub fn trimPrefix(str: []const u8, prefix: []const u8) []const u8
    pub fn trimSuffix(str: []const u8, suffix: []const u8) []const u8

    pub fn fields(allocator: Allocator, str: []const u8) !ArrayList([]const u8)
    pub fn fieldsFunc(allocator: Allocator, str: []const u8, f: fn(Codepoint) bool) !ArrayList([]const u8)

    pub fn splitN(allocator: Allocator, str: []const u8, sep: []const u8, n: usize) !ArrayList([]const u8)
    pub fn splitAfter(allocator: Allocator, str: []const u8, sep: []const u8) !ArrayList([]const u8)
    pub fn splitAfterN(allocator: Allocator, str: []const u8, sep: []const u8, n: usize) !ArrayList([]const u8)

    pub fn mapFunc(allocator: Allocator, f: fn(Codepoint) Codepoint, str: []const u8) ![]u8
    pub fn trimFunc(str: []const u8, f: fn(Codepoint) bool) []const u8
    pub fn toValidUtf8(allocator: Allocator, str: []const u8, replacement: []const u8) ![]u8

    pub fn containsAny(str: []const u8, chars: []const u8) bool
    pub fn containsFunc(str: []const u8, f: fn(Codepoint) bool) bool

    pub const CutResult = struct {
        before: []const u8,
        after: []const u8,
        found: bool,
    };
};
```

### comparison

String comparison operations.

```zig
pub const comparison = struct {
    pub fn equal(a: []const u8, b: []const u8) bool
    pub fn equalFold(a: []const u8, b: []const u8) bool  // Case-insensitive
    pub fn compare(a: []const u8, b: []const u8) std.math.Order
};
```

---

## Utility Functions

### detection

Encoding detection.

```zig
pub const detection = struct {
    pub const Encoding = enum { ascii, utf8, utf16le, utf16be, utf32le, utf32be, latin1, unknown };

    pub const DetectionResult = struct {
        encoding: Encoding,
        has_bom: bool,
        confidence: f32,
    };

    pub fn detect(bytes: []const u8) DetectionResult
};
```

### bom

Byte Order Mark handling.

```zig
pub const bom = struct {
    pub const BOM = enum { utf8, utf16le, utf16be, utf32le, utf32be, none };

    pub fn detect(bytes: []const u8) BOM
    pub fn skip(bytes: []const u8) []const u8
    pub fn getBytes(b: BOM) []const u8
};
```

### transcoding

Encoding conversion.

```zig
pub const transcoding = struct {
    pub fn utf8ToUtf16(allocator: Allocator, utf8: []const u8, endian: Endian) ![]u16
    pub fn utf16ToUtf8(allocator: Allocator, utf16: []const u16, endian: Endian) ![]u8
    pub fn utf8ToLatin1(allocator: Allocator, utf8: []const u8, opts: Latin1Options) ![]u8
    pub fn latin1ToUtf8(allocator: Allocator, latin1: []const u8) ![]u8
};
```

### simd

SIMD-accelerated operations.

```zig
pub const simd = struct {
    pub fn isAllAscii(bytes: []const u8) bool
    pub fn toLowerAscii(dest: []u8, src: []const u8) void
    pub fn toUpperAscii(dest: []u8, src: []const u8) void
    pub fn findByte(bytes: []const u8, needle: u8) ?usize
};
```

### formatting

String formatting utilities.

```zig
pub const formatting = struct {
    pub fn interpolate(allocator: Allocator, template: []const u8, args: []const []const u8) ![]u8
    pub fn interpolateNamed(allocator: Allocator, template: []const u8, values: []const NamedValue) ![]u8

    pub const NamedValue = struct {
        name: []const u8,
        value: []const u8,
    };
};
```

### numeric

Numeric parsing and formatting.

```zig
pub const numeric = struct {
    // Parsing
    pub fn parseInt(comptime T: type, str: []const u8) !T
    pub fn parseFloat(comptime T: type, str: []const u8) !T
    pub fn parseBool(str: []const u8) !bool

    // Formatting
    pub fn formatInt(allocator: Allocator, value: anytype, base: u8) ![]u8
    pub fn formatFloat(allocator: Allocator, value: anytype) ![]u8
    pub fn formatFloatPrecision(allocator: Allocator, value: anytype, precision: usize) ![]u8
    pub fn formatBool(value: bool) []const u8
};
```

---

## Convenience Re-exports

The main `strings` module re-exports common functions:

```zig
const strings = @import("strings");

// Direct access to common functions
strings.isValidUtf8(bytes)
strings.countGraphemes(bytes)
strings.countCodepoints(bytes)
strings.normalize(allocator, str, form)
strings.toLower(allocator, str)
strings.toUpper(allocator, str)
strings.toTitle(allocator, str)
strings.compare(a, b, strength)
strings.equals(a, b, strength)
strings.detectEncoding(bytes)

// Go-style functions
strings.cut(str, sep)
strings.cutPrefix(str, prefix)
strings.cutSuffix(str, suffix)
strings.trimPrefix(str, prefix)
strings.trimSuffix(str, suffix)
strings.fields(allocator, str)
strings.fieldsFunc(allocator, str, predicate)
strings.splitN(allocator, str, sep, n)
strings.indexByte(str, byte)
strings.lastIndexByte(str, byte)
strings.indexAny(str, chars)
strings.lastIndexAny(str, chars)
strings.indexFunc(str, predicate)
strings.lastIndexFunc(str, predicate)
```
