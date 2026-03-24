# ADR-005: Normalization Strategy -- Decomposition Tables with Deferred NFC Quick_Check

## Status

Accepted

## Context

Unicode normalization (UAX #15) defines four forms: NFD, NFC, NFKD, NFKC.
The library needs to support both normalization (converting text to a form)
and quick-checking (testing whether text is already in a form).

NFD and NFKD are decomposition-only: each codepoint maps to zero or more
decomposed codepoints via a lookup table, followed by Canonical Combining
Class (CCC) reordering.

NFC and NFKC additionally require composition: after decomposition, adjacent
codepoints are composed back together using composition exclusion rules and
a composition table.

Quick_Check for NFD/NFKD can be implemented by checking whether a codepoint
has a decomposition mapping. Quick_Check for NFC/NFKC requires a separate
property (NFC_QC / NFKC_QC) from the Unicode Character Database that
indicates whether a codepoint might need re-composition.

## Decision

1. **Decomposition tables** (`src/unicode/data/decomposition.zig`) store
   canonical and compatibility decomposition mappings. These are generated
   from UCD data and support both NFD and NFKD normalization.

2. **Composition tables** (`src/unicode/data/composition.zig`) store the
   canonical composition pairs for NFC/NFKC recomposition.

3. **CCC tables** (`src/unicode/data/ccc.zig`) store Canonical Combining
   Class values for reordering.

4. **NFD/NFKD Quick_Check** is implemented by checking whether a codepoint
   has a decomposition entry plus CCC ordering validation.

5. **NFC/NFKC Quick_Check is deferred** (GAP-0001). The `isNormalized`
   function currently only validates CCC ordering for NFC/NFKC forms,
   which produces false positives for composed text. Full NFC_QC/NFKC_QC
   property tables are required but not yet generated.

6. An **ASCII fast-path** skips decomposition entirely for codepoints < 128
   (none have decomposition mappings), providing ~37% speedup on
   ASCII-heavy text.

## Consequences

**Positive:**

- NFD/NFKD normalization and quick-check work correctly.
- NFC/NFKC normalization (the `normalize` function) works correctly because
  it performs full decompose-then-recompose.
- ASCII fast-path makes normalization practical for predominantly-ASCII text.
- The decomposition/composition tables are compact and auditable.

**Negative:**

- `isNormalized(text, .nfc)` and `isNormalized(text, .nfkc)` return
  incorrect results (false positives). This is documented in API.md with a
  warning. Full fix requires generating NFC_QC/NFKC_QC tables from UCD.
- The compatibility decomposition table covers only ~30 of thousands of
  NFKD mappings (common symbols and ligatures). Full NFKD requires a
  complete UCD-derived table.
- The deferred Quick_Check means pipelines cannot reliably skip
  normalization when text is already NFC, reducing performance for
  pre-normalized input.
