# ADR-003: If-Chain Unicode Property Lookups Instead of Generated Tables

## Status

Accepted

## Context

Unicode character classification (`getCategory`, `getGraphemeBreak`,
`isLetter`, `isPunctuation`, etc.) requires mapping a 21-bit codepoint to
a property value. Two common implementation strategies exist:

1. **Generated lookup tables** (e.g., multi-stage trie or flat array):
   O(1) lookup, large binary size (100 KB+ for full UCD coverage), requires
   a code generation pipeline.

2. **If-chain / range checks**: O(log n) to O(n) depending on organisation,
   minimal binary size, straightforward to read and maintain.

The library currently uses option 2: `src/unicode/categories.zig` has a
561-line if-chain in `getCategory`, and grapheme/word/sentence modules use
similar range-check patterns.

## Decision

Keep the if-chain approach for the initial release (v1.0). The trade-off
favours simplicity and maintainability:

- No external code generation tooling is required.
- The if-chains are directly auditable against Unicode specification ranges.
- Binary size stays minimal (~50 KB for the entire library vs. 100 KB+ for
  full UCD tables alone).
- Performance is acceptable for the library's primary use cases (document
  processing, not real-time per-character classification at millions of
  codepoints/second).

Table-based `getCategory` / `getGraphemeBreak` is tracked as P1-6 for a
future performance phase when the code generation pipeline is available.

## Consequences

**Positive:**

- Zero build-time dependencies on UCD data files or generators.
- Easy to update for new Unicode versions: add or adjust range checks.
- Small binary footprint.

**Negative:**

- `getCategory` is 3-5x slower than a table lookup for BMP codepoints.
- Grapheme cluster iteration is ~2-3x slower than it would be with tables.
- The if-chain approach cannot scale to full UCD coverage (thousands of
  ranges for properties like `Script` or `Block`); the library uses
  generated data tables for those (in `src/unicode/data/`).
- NFC/NFKC Quick_Check (`isNormalized`) is blocked until NFC_QC tables are
  generated (see GAP-0001).
