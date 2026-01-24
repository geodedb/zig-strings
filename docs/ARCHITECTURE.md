# Architecture

This document describes the architecture and design decisions of the Strings library.

## Overview

The Strings library is organized into a layered architecture with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                     High-Level API                           │
│              (String, String16, StringBuilder)               │
├─────────────────────────────────────────────────────────────┤
│                    Operations Layer                          │
│           (search, comparison, manipulation)                 │
├─────────────────────────────────────────────────────────────┤
│                    Unicode Layer                             │
│  (categories, normalization, grapheme, word, sentence, case) │
├─────────────────────────────────────────────────────────────┤
│                    Encoding Layer                            │
│         (utf8, utf16, utf32, ascii, latin1, bom)            │
├─────────────────────────────────────────────────────────────┤
│                    Core Types Layer                          │
│              (types, codepoint, iterator)                    │
└─────────────────────────────────────────────────────────────┘
```

## Module Organization

### Core Types (`src/types.zig`, `src/codepoint.zig`)

Foundation types used throughout the library:

- `Codepoint` - Unicode code point type (u21)
- `Encoding` - Supported text encodings
- `GeneralCategory` - Unicode general categories
- `NormalizationForm` - Unicode normalization forms
- `StringError` - Error types for string operations

### Encoding Modules (`src/utf8.zig`, `src/utf16.zig`, etc.)

Each encoding module provides:

- Encoding and decoding functions
- Validation
- Iteration
- Conversion to other encodings

### Unicode Modules (`src/unicode/`)

Unicode algorithms and data:

- **categories.zig** - Character classification (UAX #44)
- **normalization.zig** - Normalization forms (UAX #15)
- **grapheme.zig** - Grapheme cluster boundaries (UAX #29)
- **word.zig** - Word boundaries (UAX #29)
- **sentence.zig** - Sentence boundaries (UAX #29)
- **case.zig** - Case mapping and folding
- **collation.zig** - Unicode Collation Algorithm (UTS #10)

### Operations Modules (`src/ops/`)

Common string operations:

- **search.zig** - Finding substrings, patterns
- **comparison.zig** - String comparison with options
- **manipulation.zig** - Split, join, trim, replace, etc.

### String Types (`src/string.zig`, `src/string16.zig`, `src/builder.zig`)

High-level managed string types:

- **String** - UTF-8 backed string with allocator
- **String16** - UTF-16 backed string
- **StringBuilder** - Efficient string construction

### Utilities (`src/util/`)

Performance and convenience utilities:

- **simd.zig** - SIMD-accelerated operations
- **pool.zig** - String interning

## Design Principles

### 1. Pure Zig, Zero Dependencies

The library is implemented entirely in Zig with no external dependencies. All Unicode data and algorithms are self-contained.

### 2. UTF-8 First

UTF-8 is the primary encoding. All high-level APIs work with UTF-8, with UTF-16 provided for interoperability.

### 3. Explicit Memory Management

All allocating functions require an allocator parameter. No hidden allocations.

### 4. Unicode Correctness

Operations are Unicode-aware by default:
- String length counts grapheme clusters, not bytes
- Case conversion handles special mappings
- Comparison supports normalization

### 5. Safety with Performance

- Safe by default (bounds checking, valid encoding enforcement)
- Optional unsafe variants where needed
- SIMD acceleration where available

## Encoding Support

| Encoding   | Read | Write | Validate | Iterate |
|------------|------|-------|----------|---------|
| UTF-8      | ✓    | ✓     | ✓        | ✓       |
| UTF-16 LE  | ✓    | ✓     | ✓        | ✓       |
| UTF-16 BE  | ✓    | ✓     | ✓        | ✓       |
| UTF-32 LE  | ✓    | ✓     | ✓        | ✓       |
| UTF-32 BE  | ✓    | ✓     | ✓        | ✓       |
| ASCII      | ✓    | ✓     | ✓        | ✓       |
| Latin-1    | ✓    | ✓     | ✓        | ✓       |

## Unicode Standard Support

The library implements key Unicode algorithms:

- **UAX #15** - Unicode Normalization Forms
- **UAX #29** - Text Segmentation (Grapheme, Word, Sentence)
- **UAX #44** - Unicode Character Database
- **UTS #10** - Unicode Collation Algorithm

## Thread Safety

- All functions are thread-safe when operating on different data
- String types are not internally synchronized
- StringPool uses internal synchronization

## Platform Support

The library supports all platforms supported by Zig:

- Linux (x86_64, aarch64, arm, riscv64, etc.)
- macOS (x86_64, aarch64)
- Windows (x86_64, aarch64)
- FreeBSD, NetBSD, OpenBSD
- WebAssembly

SIMD acceleration is available on:
- x86_64 (SSE2+)
- aarch64 (NEON)

## File Structure

```
strings/
├── build.zig           # Build configuration
├── build.zig.zon       # Package manifest
├── src/
│   ├── lib.zig         # Main public API
│   ├── types.zig       # Core types
│   ├── codepoint.zig   # Code point operations
│   ├── utf8.zig        # UTF-8 encoding
│   ├── utf16.zig       # UTF-16 encoding
│   ├── utf32.zig       # UTF-32 encoding
│   ├── ascii.zig       # ASCII operations
│   ├── latin1.zig      # Latin-1 operations
│   ├── iterator.zig    # String iterators
│   ├── string.zig      # String type
│   ├── string16.zig    # String16 type
│   ├── builder.zig     # StringBuilder
│   ├── unicode/        # Unicode modules
│   ├── encoding/       # Encoding utilities
│   ├── ops/            # String operations
│   ├── conversion/     # Type conversion
│   └── util/           # Utilities
├── tests/
│   ├── vectors.zig     # Test vectors
│   └── acceptance.zig  # Acceptance tests
└── docs/
    ├── ARCHITECTURE.md # This file
    └── ROADMAP.md      # Development roadmap
```
