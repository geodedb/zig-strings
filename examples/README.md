# ZigStr Examples

This directory contains practical examples demonstrating the features of the ZigStr Unicode string library.

## Examples Overview

| Example | Description |
|---------|-------------|
| `01_basic_strings.zig` | Core String type with SSO, basic operations, iteration |
| `02_string_builder.zig` | Efficient string construction with StringBuilder |
| `03_unicode_normalization.zig` | NFC, NFD, NFKC, NFKD normalization forms |
| `04_grapheme_clusters.zig` | User-perceived character handling (UAX #29) |
| `05_encoding_conversion.zig` | UTF-8/16/32 encoding and conversion |
| `06_string_pool.zig` | String interning for memory efficiency |
| `07_fuzzy_matching.zig` | Levenshtein, Jaro-Winkler, fuzzy search |
| `08_collation.zig` | Unicode Collation Algorithm (UTS #10) |
| `09_word_sentence.zig` | Word and sentence segmentation |
| `10_go_style.zig` | Go-style string functions |

## Using These Examples

These examples are **reference code** that demonstrates API usage patterns for the
strings library. They are not wired into the project build system and cannot be
compiled directly with `zig build`.

To use the code in your own project:

1. Add the strings library as a dependency in your project's `build.zig.zon`
2. Copy or adapt the relevant example code into your own source files
3. Import the library as `const strings = @import("strings");` (the module name
   depends on how you configure the dependency in your `build.zig`)

See the main project [README](../README.md) for instructions on adding the
strings library as a dependency.

## Example Descriptions

### 01 - Basic Strings

Learn the fundamentals of the String type:
- Creating strings with `String.fromSlice()`
- Small String Optimization (SSO) - strings <= 23 bytes stored inline
- Basic operations: len, contains, indexOf, startsWith
- Case conversion: toLower, toUpper, toTitle
- String manipulation: trim, replace, split
- Iteration over code points and grapheme clusters

### 02 - StringBuilder

Efficient string construction:
- Appending strings, bytes, and code points
- Formatted output with `appendFmt()`
- Insert, remove, and replace operations
- Converting to owned slice or String
- Using the Writer interface

### 03 - Unicode Normalization

Understanding Unicode normalization (UAX #15):
- NFC vs NFD: Composed vs Decomposed forms
- NFKC/NFKD: Compatibility normalization
- Why normalization matters for comparison
- Practical examples with accented characters

### 04 - Grapheme Clusters

User-perceived characters (UAX #29):
- What is a grapheme cluster?
- Counting graphemes vs code points vs bytes
- Iterating over grapheme clusters
- Handling combining marks and accents
- Indic scripts and conjuncts
- Safe string truncation

### 05 - Encoding Conversion

UTF-8/16/32 handling:
- UTF-8 validation and decoding
- Converting between encodings
- UTF-16 surrogate pairs
- Endianness (little-endian vs big-endian)
- Windows API interoperability

### 06 - String Pool

String interning for efficiency:
- Deduplicating strings with StringPool
- O(1) pointer comparison for interned strings
- Symbol tables for compilers and parsers
- Memory savings with many duplicate strings

### 07 - Fuzzy Matching

Approximate string matching:
- Levenshtein and Damerau-Levenshtein distance
- Jaro and Jaro-Winkler similarity
- Longest Common Subsequence/Substring
- Hamming distance and Cosine similarity
- Fuzzy search with ranking
- Practical: spell checking, data deduplication

### 08 - Collation

Unicode Collation Algorithm (UTS #10):
- Collation strength levels (primary, secondary, tertiary)
- Case-insensitive comparison
- Accent-insensitive comparison
- Sort keys for efficient sorting
- Practical: sorting names, dictionary lookup

### 09 - Word and Sentence Segmentation

Text segmentation (UAX #29):
- Word boundary detection
- Word break properties
- Handling various scripts
- Practical: word counting, text analysis

### 10 - Go-style Functions

Familiar APIs for Go developers:
- Contains, IndexOf, StartsWith, EndsWith
- Split, Join, Replace
- ToLower, ToUpper, Trim
- Count, IndexAny, IndexFunc
- Practical: path manipulation, URL parsing

## Key Concepts

### Small String Optimization (SSO)

Strings of 23 bytes or less are stored inline without heap allocation:

```zig
var small = try String.fromSlice(allocator, "Hello");
assert(small.isInline() == true);

var large = try String.fromSlice(allocator, "This is a much longer string...");
assert(large.isInline() == false);
```

### Graphemes vs Code Points vs Bytes

```zig
const text = "cafe\xCC\x81";  // cafe + combining acute = cafe

// Different counts!
text.len                    // 6 bytes
countCodepoints(text)       // 5 code points
countGraphemes(text)        // 4 graphemes (what users see)
```

### Normalization for Comparison

Always normalize before comparing user input:

```zig
const input1 = "cafe\xCC\x81";  // e + combining acute
const input2 = "caf\xC3\xA9";   // precomposed e

// Raw comparison fails
std.mem.eql(u8, input1, input2) == false

// After normalization
const n1 = try normalize(allocator, input1, .nfc);
const n2 = try normalize(allocator, input2, .nfc);
std.mem.eql(u8, n1, n2) == true
```

## License

Apache-2.0 - See the main project LICENSE file.
