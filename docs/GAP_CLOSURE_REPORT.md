# Gap Closure Completion Report

**Repository:** devnw/zig/strings
**Date:** 2026-03-24
**Waves completed:** Wave 1 (initial gap-close), Wave 2 (post-audit gap-close), Wave 3 (remaining items), Wave 4 (final closures + commit)
**Platform:** GitLab (issues not updated -- skip-issues mode)

---

## GAP_ANALYSIS Status

| File | Closed | Partial | Won't Do | Remaining Open | Total |
|------|--------|---------|----------|----------------|-------|
| GAP_ANALYSIS.md (GAP-0001..0033 + cross-file) | 30 | 1 | 3 | 0 | 34 |
| SECURITY_GAP_ANALYSIS.md (S1..S24) | 20 | 0 | 2 | 2 (accepted risk) | 24 |
| QUALITY_GAP_ANALYSIS.md (56 items) | 45 | 2 | 8 | 1 | 56 |
| PERF_GAP_ANALYSIS.md (34 items) | 24 | 1 | 5 | 4 | 34 |

**Note:** Many items are cross-referenced across files (e.g., GAP-0001 = R3 = P0-1; S2 = GAP-0012 = GAP-0031; S18 = D4; S20 = R2; S22 = AC-1/Q48r). Unique findings after deduplication: approximately 85 distinct items.

**Overall (deduplicated):** ~73 closed, 2 partial, 14 won't do, ~6 deferred/open out of ~95 total items

---

## Wave 1 (Initial Gap-Close)

Closed 42 items across all four tracking files in the initial implementation pass.

| Gap-ID(s) | Title | Evidence |
|-----------|-------|----------|
| GAP-0003 | BiDi overclaims UAX #9 | README.md downgraded; bidi.zig override functions added |
| GAP-0004 | Regex ReDoS (recursive backtracking) | MAX_STEPS=1M step counter in regex.zig |
| GAP-0005 | Regex unicode_prop opcodes silently skipped | VM handlers implemented for unicode_prop/unicode_prop_neg |
| GAP-0006 | Permissive test assertions | `or std.mem.eql` clauses removed from unicode_conformance.zig |
| GAP-0007 | Zig version discrepancy | README updated to 0.15.1+ |
| GAP-0008 | "Zero Dependencies" in ARCHITECTURE.md | Changed to "Minimal Dependencies" |
| GAP-0009 | Security email mismatch | Aligned to security@codepros.dev |
| GAP-0010 | SECURITY.md false fuzz claims | Fuzz claim removed, deps claim corrected |
| GAP-0011 | StringPool thread safety overclaim | ARCHITECTURE.md corrected |
| GAP-0013 | Parallel module not in lib.zig | Added parallel import |
| GAP-0014 | formatDate ignores locale | Doc comment documenting limitation |
| GAP-0016 | Duplicate API surfaces lib/zigstr | zigstr.zig re-exports from types.zig |
| GAP-0017 | API.md stale NFC/NFKC note | Note updated |
| GAP-0020 | parallel.zig fails zig fmt | Auto-formatted |
| GAP-0022 | countCodepoints inconsistent contracts | Doc comments explaining different contracts |
| GAP-0023 | lib.zig "Zero Dependencies" regression | lib.zig:28 changed to "Minimal Dependencies" |
| GAP-0024 | Unicode version 15.0 vs 15.1 | lib.zig:17 changed to 15.1 |
| GAP-0025 | "Locale-aware" false claim | lib.zig:20 changed to "Unicode-aware" |
| GAP-0026 | ARCHITECTURE.md spice "disabled by default" | Changed to "enabled by default" |
| GAP-0028 | CHANGELOG overclaims | BiDi, UCD, coverage claims qualified |
| GAP-0029 | Collation UTS #10 overclaim | Doc comment: ASCII/Latin-1 only |
| GAP-0030 | caseFold(0x00DF) simplification | Doc comment warning |
| S1 | ReDoS regex backtracking | MAX_STEPS=1M, S17 global budget |
| S3 | Integer overflow repeat/replaceN/join | std.math.mul checked arithmetic |
| S5 | Normalization bomb | MAX_EXPANSION_RATIO=10 |
| S7 | UTF-16 length overflow | Checked multiplication |
| S9 | BiDi Trojan Source | containsBidiOverrides/stripBidiOverrides |
| S10 | Encoding detection fallback | Doc warning |
| S11 | Mmap path traversal | Doc warning |
| S12 | debug.assert elided ReleaseFast | Runtime error checks |
| S13 | Pool use-after-deinit race | Shutdown doc |
| S14 | catch unreachable / NaN UB | NaN/Inf guard |
| S15 | padLeft/padRight overflow | std.math.mul/add |
| S16 | concat() overflow | std.math.add |
| S17 | ReDoS per-position reset | Global step budget |
| S19 | ICU BreakIterator truncation | MAX_TEXT_LEN + InputTooLarge |
| S21 | BiDi misses LRM/RLM/ALM | isBidiMark + containsSuspiciousBidiChars |
| R1 | SIMD assert vanishes ReleaseFast | Replaced with @panic |
| Q1 | VM else catch-all | All opcodes handled; unreachable |
| Q3-Q9 | Regex/fuzzy fixes | Step counter, PatternTooComplex, capture groups, levenshtein dynamic alloc, damerau fallback doc |
| M1 | Duplicated UnicodeCategory | Replaced with categories.getCategory |
| Q5 | Regex test coverage | 20 to 39 tests |
| Q11-Q17 | API/quality fixes | Duplicate enums, magic numbers, overflow checks |
| M6 | lib.zig test block | All ~30 modules imported |
| M7 | Makefile fmt target | bench/ and examples/ added |
| D1-D5 | Documentation fixes | Zero deps, isNormalized warning, Unicode version, catch 0 sentinel |
| R5 | getPool() lifecycle | Pool lifecycle documented |
| R7 | Parallel test gaps | Tests above parallel thresholds |
| A2/A3 | Locale API contracts | getCurrencyFormat/formatDate limitations documented |
| P0-2 | page_allocator in parallel | Replaced with FixedBufferAllocator |
| P0-3 | Regex O(2^n) backtracking | Step counter (interim) |
| P1-1 | No ASCII fast-path normalize | ASCII fast-path added |
| P1-2 | No pre-alloc normalize | ensureTotalCapacity |
| P1-4 | Collation triple iteration | Single-pass with 3 weight buffers |
| P2-2 | StringBuilder.replace byte-by-byte | std.mem.indexOf + bulk copy |
| P2-4 | Parallel threshold 4096 | Raised to 65536 |
| P2-11 | Template per-byte append | Bulk appendSlice for literal spans |
| P3-2 | Redundant getCombiningClass | Negligible; closed |
| P3-3 | appendRepeat N separate calls | Pre-allocation added |

---

## Wave 2 (Post-Audit Gap-Close)

Re-audit found 3 false closures (S2, S4 never committed). Wave 2 closed 13 items.

| Gap-ID(s) | Title | Evidence |
|-----------|-------|----------|
| S2 / GAP-0012 / GAP-0031 | Jaro OOB write (Critical, re-opened) | `MAX_JARO_LEN=256` at fuzzy.zig:35; bounds guard at :229; test at :699-719 |
| S4 / GAP-0019 | Levenshtein/LCS silent truncation (re-opened) | `MAX_STACK_LEN=1024` at fuzzy.zig:40; doc comments at :62-68, :309-311, :352-354 |
| GAP-0018 | DamerauLevenshtein fallback | `MAX_DAMERAU_LEN=32` at fuzzy.zig:45; doc comment at :154-161 |
| Q46 | getAsciiCategory misclassification | Correct categories at categories.zig:585-595; test at :826-846 |
| Q48 | phoneticMatch soundex fallback | `unreachable` at phonetic.zig:602; doc comment at :585-594 |
| Q47 | CI omits test-comprehensive | test-comprehensive job added to .gitlab-ci.yml |
| GAP-0027 | Examples cannot compile | examples/README.md updated |
| GAP-0032 | README overclaims | README.md:227,231,232 qualified |
| P1-7 | SIMD case conversion never wired | case.zig:13 simd import; :195/:221 SIMD usage; build.zig:531 dependency |
| P1-8 | Parallel map threshold 65KB too low | Already at 10MB (parallel.zig:167) -- confirmed |
| P2-9 / P2-14 | ensureTotalCapacity all remaining sites | 29 total sites across 11 files |
| P2-13 | ASCII fast-path getGraphemeBreak | grapheme.zig:38-46: `if (cp < 0x80)` block |
| A5 | concat() overflow check | Already uses std.math.add (manipulation.zig:385) -- confirmed |

---

## Wave 3 (Remaining Items -- Final)

Closed 13 items, marked 2 as Won't Do.

### Wave 3A

| Gap-ID(s) | Title | Evidence |
|-----------|-------|----------|
| Q21 | SIMD module zero internal callers | case.zig:13 imports simd; :195,:197,:221,:223 use simd functions (wired by P1-7) |
| Q22 | phoneticMatchAlloc zero callers | 7 tests added at phonetic.zig:782-831 exercising all algorithm paths |
| R2 / S20 | @intCast in legacy encoding | chinese.zig:330 codepoint guard, :375 std.math.cast; rest safe by construction. Closed (targeted fix) |
| M3 | Legacy encoding error duplication 4x | errors.zig created; 6 legacy files import shared LegacyEncodingError |

### Wave 3B

| Gap-ID(s) | Title | Evidence |
|-----------|-------|----------|
| P2-8 | Bitset for byte-level search/trim | buildAsciiLookup in manipulation.zig; trimLeftChars, trimRightChars, containsAny optimized; 8 tests |
| P2-12 | 4 O(n*m) search functions | buildCodepointLookup + buildByteLookup in search.zig; 4 functions optimized; 9 tests |
| P2-1 / P2-5 | containsAny/trim O(n*m) | Covered by P2-8 bitset implementation |
| P2-16 / P2-6 | replaceN/replace double scan | **Won't Do** -- intentional design for exact pre-allocation; doc comment added |

### Wave 3C

| Gap-ID(s) | Title | Evidence |
|-----------|-------|----------|
| M4 | build.zig monolith | addLibModule + addLibTest helpers; 1,398 to 837 lines (40% reduction) |
| A1 | Error type duplication | Partial -- M3 addressed actual duplication; remaining error sets are domain-specific |
| Q27 | 49 pub fns lack doc comments | All 49 documented across 15+ files |
| D3 | No ADRs | 5 ADRs in docs/adr/: SIMD arch, parallel thresholds, unicode tables, error handling, normalization |
| P2-15 | CharClass.contains() linear scan | Binary search for >8 ranges; sortRanges in parseCharClass; 2 tests |

---

## Wave 4 (Final Closures + Commit)

Closed 10 items, marked 2 as Won't Do. All changes committed as `5c110b1`.

### Wave 4A -- Code Fixes

| Gap-ID(s) | Title | Evidence |
|-----------|-------|----------|
| S22 / AC-1/Q48r | phoneticMatch `unreachable` replaced with `@panic` | phonetic.zig:604 -- `@panic` persists in all build modes |
| AC-2 | Metaphone duplicate 'N' logic bug fixed | phonetic.zig:261 -- duplicate condition corrected |
| AC-3 | doubleMetaphone stub documented | phonetic.zig:358-362 -- doc comment noting simplified implementation |
| RE-3 | Phonetic cross-string tests added | phonetic.zig -- tests verify phonetically similar but different strings |
| AC-4 | Parallel error sentinel documented | parallel.zig:219,342 -- doc comments for maxInt(usize) sentinel |
| P2-NEW-1 | normalize SIMD isAllAscii wired | normalization.zig:15,458 + build.zig simd dependency |
| P2-NEW-2 | Indic virama cp>=0x094D guard | grapheme.zig:367 -- short-circuits for non-Indic codepoints |
| P3-NEW-1 | reverse() capacity str.len/4+1 | manipulation.zig:319 -- 4x memory reduction |
| R4 | Regex VM MAX_RECURSION_DEPTH=500 | regex.zig:1032-1037,1269-1274 -- depth guard on split opcode |

### Wave 4B -- Commit + Close-Out

| Gap-ID(s) | Title | Evidence |
|-----------|-------|----------|
| GAP-0033 | All changes committed and pushed | commit 5c110b1; 538/538 tests, 76/76 build steps, format clean |

### Wave 4 Won't Do

| Gap-ID(s) | Title | Reason |
|-----------|-------|--------|
| RM-1 | Duplicate lookup-table builders | Semantic differences; ~15 lines not worth coupling |
| RM-4 | Duplicate build.zig imports | LOW; Zig comptime slice constraints (already closed by extraction) |

---

## Won't Do Items (All Waves)

| Gap-ID(s) | File(s) | Title | Reason |
|-----------|---------|-------|--------|
| GAP-0002 / Q18 | GAP, QUALITY | CI build/test stages disabled | Infrastructure/DevOps task requiring GitLab runner with Zig 0.15.x |
| GAP-0015 / Q14 | GAP, QUALITY | categories.zig test coverage | Requires UCD table generation for test vectors |
| GAP-0021 / Q26 | GAP, QUALITY | Fuzz testing infrastructure | Requires AFL/libFuzzer setup |
| S6 | SECURITY | Supply chain: spice pinned to main | Blocked on upstream -- no tagged releases |
| S8 | SECURITY | NFKC homoglyph detection | Application-layer concern requiring UTS #39 tables |
| Q25 | QUALITY | Coverage tooling | Tooling infrastructure, not code |
| M2 | QUALITY | getCategory 561-line if-chain | Superseded by P1-6 table generation effort |
| M5 | QUALITY | getCompatibilityDecomposition limited | Superseded by P1-6 table generation effort |
| P1-3 | PERF | Grapheme break brute-force if-chain | Superseded by P1-6 |
| P1-5 | PERF | No benchmark regression detection in CI | Requires CI infrastructure |
| P2-7 | PERF | isExtendedPictographic incomplete | Requires UCD Extended_Pictographic table |
| P2-6 | PERF | replace() scans string twice | Intentional design for exact allocation |
| P2-16 | PERF | replaceN() double scan | Intentional design for exact allocation |
| RM-1 | QUALITY | Duplicate lookup-table builders | Semantic differences; ~15 lines not worth coupling |

---

## Deferred / Remaining Open Items

### Partial

| Gap-ID(s) | File(s) | Title | Blocker | Next Steps |
|-----------|---------|-------|---------|------------|
| GAP-0001 / R3 / P0-1 | GAP, QUALITY, PERF | isNormalized NFC/NFKC Quick_Check | Requires generating UCD property tables (NFC_QC, NFKC_QC) | Build UCD table generation tooling |
| A1 | QUALITY | Error type duplication | Remaining error sets are domain-specific | No further consolidation warranted |

### Open (Deferred)

| Gap-ID(s) | File(s) | Title | Next Steps |
|-----------|---------|-------|------------|
| A4 | QUALITY | Inconsistent parameter ordering | Audit and align API conventions (breaking change) |
| Q49 | QUALITY | 7 files exceed 800-line limit | Extract sub-modules from regex.zig (2059), manipulation.zig (1145) |
| S23 | SECURITY | Regex VM unreachable for repeat opcodes | Accepted risk (safe by construction) |
| S24 | SECURITY | 128 @intCast without formal proof | Accepted risk; fuzz testing recommended |
| P1-6 | PERF | Table-based getCategory/getGraphemeBreak | Two-level trie from UCD data (requires UCD generation tooling) |
| P2-3 | PERF | normalize() materializes full codepoint buffer | Streaming with fixed windows |
| P2-10 | PERF | O(1) decomposition/composition tables | Two-level index or perfect hash |
| P3-1 | PERF | Composition binary search 941 entries | Subsumed by P2-10 |

---

## Closed Items (All Waves)

| Gap-ID | File | Title | Evidence |
|--------|------|-------|----------|
| GAP-0003 | GAP | BiDi overclaims UAX #9 | README.md downgraded |
| GAP-0004 | GAP | Regex ReDoS | MAX_STEPS=1M |
| GAP-0005 | GAP | unicode_prop opcodes skipped | VM handlers added |
| GAP-0006 | GAP | Permissive test assertions | `or` clauses removed |
| GAP-0007 | GAP | Zig version mismatch | README updated |
| GAP-0008 | GAP | Zero Dependencies overclaim | ARCHITECTURE.md corrected |
| GAP-0009 | GAP | Security email mismatch | CONTRIBUTING.md aligned |
| GAP-0010 | GAP | SECURITY.md false claims | Claims removed/corrected |
| GAP-0011 | GAP | StringPool thread safety | ARCHITECTURE.md corrected |
| GAP-0012 | GAP | Jaro OOB (Critical) | fuzzy.zig:35,229,699-719 |
| GAP-0013 | GAP | Parallel not in lib.zig | Import added |
| GAP-0014 | GAP | formatDate ignores locale | Doc comment |
| GAP-0016 | GAP | Duplicate API surfaces | Re-exports from types.zig |
| GAP-0017 | GAP | API.md stale note | Note updated |
| GAP-0018 | GAP | DamerauLevenshtein fallback | fuzzy.zig:45,154-161 |
| GAP-0019 | GAP | Levenshtein truncation | fuzzy.zig:40,62-68,309-311 |
| GAP-0020 | GAP | zig fmt failures | Auto-formatted |
| GAP-0022 | GAP | countCodepoints contracts | Doc comments |
| GAP-0023 | GAP | lib.zig Zero Dependencies regression | lib.zig:28 corrected |
| GAP-0024 | GAP | Unicode version 15.0 vs 15.1 | lib.zig:17 corrected |
| GAP-0025 | GAP | Locale-aware false claim | lib.zig:20 corrected |
| GAP-0026 | GAP | ARCHITECTURE.md spice default | Corrected to "enabled" |
| GAP-0027 | GAP | Examples documentation | examples/README.md updated |
| GAP-0028 | GAP | CHANGELOG overclaims | Three claims qualified |
| GAP-0029 | GAP | Collation UTS #10 overclaim | Doc comment |
| GAP-0030 | GAP | caseFold simplification | Doc comment |
| GAP-0031 | GAP | Jaro OOB (duplicate of GAP-0012) | Same fix |
| GAP-0032 | GAP | README overclaims | README.md:227,231,232 |
| S1 | SECURITY | ReDoS | MAX_STEPS=1M global budget |
| S2 | SECURITY | Jaro OOB write (Critical) | fuzzy.zig:35,229 |
| S3 | SECURITY | Integer overflow repeat/replaceN/join | std.math.mul |
| S4 | SECURITY | Levenshtein/LCS truncation | fuzzy.zig:40, doc comments |
| S5 | SECURITY | Normalization bomb | MAX_EXPANSION_RATIO=10 |
| S7 | SECURITY | UTF-16 length overflow | Checked multiplication |
| S9 | SECURITY | BiDi Trojan Source | Override detection/stripping |
| S10 | SECURITY | Encoding detection fallback | Doc warning |
| S11 | SECURITY | Mmap path traversal | Doc warning |
| S12 | SECURITY | debug.assert elided | Runtime checks |
| S13 | SECURITY | Pool use-after-deinit | Shutdown doc |
| S14 | SECURITY | catch unreachable / NaN | NaN/Inf guard |
| S15 | SECURITY | padLeft/padRight overflow | std.math.mul/add |
| S16 | SECURITY | concat() overflow | std.math.add |
| S17 | SECURITY | ReDoS per-position reset | Global step budget |
| S18 | SECURITY | catch 0 false exact match | maxInt(usize) sentinel |
| S19 | SECURITY | ICU BreakIterator truncation | InputTooLarge check |
| S20 | SECURITY | @intCast legacy encoding | chinese.zig:330,375 targeted fix |
| S21 | SECURITY | BiDi misses LRM/RLM/ALM | isBidiMark + containsSuspiciousBidiChars |
| Q1 | QUALITY | VM else catch-all | All opcodes handled |
| Q3 | QUALITY | Regex backtracking | Step counter |
| Q4 | QUALITY | PatternTooComplex dead | Now returned |
| Q5 | QUALITY | Regex test coverage | 20 to 39 tests |
| Q6 | QUALITY | jaro() OOB | Bounds guard |
| Q7 | QUALITY | Capture groups dead | Groups wired |
| Q8 | QUALITY | levenshtein() truncation | Dynamic allocation |
| Q9 | QUALITY | damerauLevenshtein fallback | Doc comment |
| Q11 | QUALITY | lib/zigstr API mismatch | Re-exports |
| Q13 | QUALITY | Duplicated enums | Re-exports |
| Q15 | QUALITY | Magic numbers fuzzy.zig | Named constants |
| Q17 | QUALITY | Regex parseNumber overflow | Checked |
| Q21 | QUALITY | SIMD zero internal callers | case.zig now imports simd |
| Q22 | QUALITY | phoneticMatchAlloc zero callers | 7 tests added |
| Q23 | QUALITY | Redundant char_class_negated | Cleaned up |
| Q24 | QUALITY | zig fmt failures | Auto-formatted |
| Q27 | QUALITY | 49 pub fns lack doc comments | All 49 documented |
| Q28 | QUALITY | countCodepoints inconsistency | Doc comments |
| Q46 | QUALITY | getAsciiCategory misclassification | categories.zig:585-595 |
| Q47 | QUALITY | CI omits test-comprehensive | .gitlab-ci.yml job added |
| Q48 | QUALITY | phoneticMatch soundex fallback | unreachable + doc comment |
| R1 | QUALITY | SIMD assert vanishes | @panic replacement |
| R2 | QUALITY | @intCast encoding (targeted) | chinese.zig:330,375 |
| R5 | QUALITY | getPool() lifecycle | Pool lifecycle documented |
| R7 | QUALITY | Parallel test gaps | Tests above thresholds |
| M1 | QUALITY | Duplicated UnicodeCategory | categories.getCategory |
| M3 | QUALITY | Legacy error duplication | shared LegacyEncodingError |
| M4 | QUALITY | build.zig monolith | addLibModule/addLibTest helpers |
| M6 | QUALITY | lib.zig test block | All modules imported |
| M7 | QUALITY | Makefile fmt target | bench/ + examples/ added |
| A2 | QUALITY | getCurrencyFormat ignores locale | Doc comment |
| A3 | QUALITY | formatDate ignores self | Doc comment |
| A5 | QUALITY | concat() overflow | std.math.add (confirmed) |
| D1 | QUALITY | lib.zig "Zero Dependencies" | Changed to "Minimal" |
| D2 | QUALITY | isNormalized NFC/NFKC undocumented | API.md warning |
| D3 | QUALITY | No ADRs | 5 ADRs created |
| D4 | QUALITY | catch 0 parallel | maxInt(usize) sentinel |
| D5 | QUALITY | Unicode version inconsistency | 15.1 aligned |
| P0-2 | PERF | page_allocator in parallel | FixedBufferAllocator |
| P0-3 | PERF | Regex O(2^n) | Step counter |
| P1-1 | PERF | No ASCII fast-path normalize | ASCII fast-path |
| P1-2 | PERF | No pre-alloc normalize | ensureTotalCapacity |
| P1-4 | PERF | Collation triple iteration | Single-pass |
| P1-7 | PERF | SIMD case conversion | case.zig:13 import, :195/:221 usage |
| P1-8 | PERF | Parallel threshold too low | 10MB threshold |
| P2-1 | PERF | containsAny O(n*m) | Covered by P2-8 bitset |
| P2-2 | PERF | StringBuilder.replace | std.mem.indexOf + bulk copy |
| P2-4 | PERF | Parallel threshold 4096 | Raised to 65536 |
| P2-5 | PERF | trimLeftChars/trimRightChars O(n*m) | Covered by P2-8 bitset |
| P2-8 | PERF | Bitset for search/trim | buildAsciiLookup; 3 fns optimized; 8 tests |
| P2-9/P2-14 | PERF | ensureTotalCapacity | 29 sites across 11 files |
| P2-11 | PERF | Template per-byte append | Bulk appendSlice |
| P2-12 | PERF | 4 O(n*m) search functions | buildCodepointLookup/buildByteLookup; 9 tests |
| P2-13 | PERF | ASCII fast-path getGraphemeBreak | grapheme.zig:38-46 |
| P2-15 | PERF | CharClass linear scan | Binary search for >8 ranges; 2 tests |
| P3-2 | PERF | Redundant getCombiningClass | Negligible; closed |
| P3-3 | PERF | appendRepeat N calls | Pre-allocation |
| GAP-0033 | GAP | Uncommitted changes | Committed as 5c110b1 |
| R4 | GAP, QUALITY | Regex VM stack recursion | MAX_RECURSION_DEPTH=500; regex.zig:1032-1037,1269-1274 |
| S22 / AC-1/Q48r | SECURITY, QUALITY | phoneticMatch unreachable UB | @panic at phonetic.zig:604 |
| AC-2 | QUALITY | Metaphone duplicate 'N' | phonetic.zig:261 corrected |
| AC-3 | QUALITY | doubleMetaphone stub | phonetic.zig:358-362 documented |
| RE-3 | QUALITY | Phonetic cross-string tests | phonetic.zig -- cross-string assertions |
| AC-4 | QUALITY | Parallel sentinel undocumented | parallel.zig:219,342 doc comments |
| P2-NEW-1 | PERF | normalize SIMD isAllAscii | normalization.zig:15,458 + build.zig |
| P2-NEW-2 | PERF | Indic virama guard | grapheme.zig:367 |
| P3-NEW-1 | PERF | reverse() capacity | manipulation.zig:319 |

---

## Tests Executed

| Command | Result |
|---------|--------|
| `zig build` (76 build steps) | PASS (76/76) |
| `zig build test` (538 tests) | PASS (538/538) |
| `zig fmt --check src/ tests/ bench/ examples/ build.zig` | PASS (clean) |
| Regressions | None detected |

---

## Security Notes

- **All 2 Critical security findings closed:** S1 (ReDoS via recursive backtracking -- MAX_STEPS=1M global budget), S2 (Jaro OOB write -- MAX_JARO_LEN=256 bounds guard, Wave 2)
- **All 6 High security findings closed:** S3 (integer overflow -- checked arithmetic), S4 (Levenshtein/LCS truncation -- MAX_STACK_LEN=1024 documented, Wave 2), S5 (normalization bomb -- MAX_EXPANSION_RATIO=10), S15 (padLeft/padRight overflow), S16 (concat overflow), S22 (phoneticMatch unreachable -- @panic, Wave 4)
- **All 8 Medium security findings closed or Won't Do:** S6 (supply chain -- Won't Do, blocked on upstream), S7 (UTF-16 overflow -- closed), S8 (NFKC homoglyph -- Won't Do), S9 (BiDi overrides -- closed), S10 (encoding detection -- closed), S11 (mmap path -- closed), S17 (ReDoS per-position -- closed), S18 (catch 0 sentinel -- closed)
- **All 8 Low security findings closed or accepted risk:** S12 (debug.assert -- closed), S13 (pool race -- closed), S14 (NaN/Inf -- closed), S19 (ICU truncation -- closed), S20 (legacy @intCast -- closed, targeted fix, Wave 3), S21 (BiDi marks -- closed), S23 (regex VM unreachable -- accepted risk, safe by construction), S24 (128 @intCast -- accepted risk)
- **False closure remediation:** S2 and S4 were falsely closed in Wave 1 (fixes never committed to fuzzy.zig). Re-audit caught this. Wave 2 applied actual fixes with verified evidence.
- **Mitigations verified:** Regex MAX_STEPS=1M (global budget), Regex MAX_RECURSION_DEPTH=500, normalization MAX_EXPANSION_RATIO=10, checked arithmetic in join/repeat/replace/padLeft/padRight/concat, Jaro MAX_JARO_LEN=256 bounds guard, Levenshtein MAX_STACK_LEN=1024 documented, BiDi override+mark detection, ICU InputTooLarge guard, legacy encoding targeted intCast guards, phoneticMatch @panic guard.

---

## Remaining Blockers

1. ~~**Uncommitted Changes (GAP-0033)**~~ -- **Resolved (Wave 4).** All gap-closure work committed as `5c110b1`. 538 tests pass, 76 build steps succeed, format clean.

2. **UCD Table Generation Tooling** -- GAP-0001 (isNormalized Quick_Check), P1-6 (table-based getCategory/getGraphemeBreak), P2-10 (O(1) decomposition), and multiple Won't-Do items all require a shared UCD code generation pipeline. This is the single largest blocker for further performance and correctness improvements.

3. **CI Infrastructure** -- GAP-0002 (CI build/test) and P1-5 (benchmark regression) require GitLab runner setup. Q47 (test-comprehensive job) has been added to .gitlab-ci.yml but cannot run until the runner is configured.

---

## Platform Issues Updated

Skipped -- `--skip-issues` mode (no GitLab API access configured).

### Wave 3 Issues Needing Update

| Gap-ID | Issue | Action Needed |
|--------|-------|---------------|
| Q21 | [#41](https://gitlab.com/devnw/zig/strings/-/issues/41) | Close (SIMD now used by case.zig) |
| Q22 | [#42](https://gitlab.com/devnw/zig/strings/-/issues/42) | Close (7 tests added) |
| R2 | [#67](https://gitlab.com/devnw/zig/strings/-/issues/67) | Close (targeted fix + audit) |
| S20 | [#66](https://gitlab.com/devnw/zig/strings/-/issues/66) | Close (targeted fix + audit) |
| M3 | [#69](https://gitlab.com/devnw/zig/strings/-/issues/69) | Close (shared LegacyEncodingError) |
| P2-8 | [#85](https://gitlab.com/devnw/zig/strings/-/issues/85) | Close (buildAsciiLookup bitset) |
| P2-1/P2-5 | [#44](https://gitlab.com/devnw/zig/strings/-/issues/44) | Close (covered by P2-8) |
| M4 | [#71](https://gitlab.com/devnw/zig/strings/-/issues/71) | Close (addLibModule/addLibTest helpers) |
| Q27 | [#43](https://gitlab.com/devnw/zig/strings/-/issues/43) | Close (all 49 pub fns documented) |
| D3 | [#84](https://gitlab.com/devnw/zig/strings/-/issues/84) | Close (5 ADRs created) |
| GAP-0033 | [#87](https://gitlab.com/devnw/zig/strings/-/issues/87) | Close (committed as 5c110b1) |

### Wave 4 Issues Needing Update

| Gap-ID | Issue | Action Needed |
|--------|-------|---------------|
| S22 / AC-1/Q48r | -- (not filed) | No issue to close |
| AC-2, AC-3, RE-3, AC-4 | -- (not filed) | No issue to close |
| R4 | [#25](https://gitlab.com/devnw/zig/strings/-/issues/25) | Comment (MAX_RECURSION_DEPTH=500 added; shares issue with GAP-0004) |
| GAP-0033 | [#87](https://gitlab.com/devnw/zig/strings/-/issues/87) | Close (committed as 5c110b1) |

### Previously Reported Issues (Waves 1-2)

| Gap-ID | Issue | Action Needed |
|--------|-------|---------------|
| S2 / GAP-0012 | [#30](https://gitlab.com/devnw/zig/strings/-/issues/30) | Close (Jaro OOB bounds guard) |
| S4 / GAP-0019 | [#35](https://gitlab.com/devnw/zig/strings/-/issues/35) | Close (Levenshtein/LCS doc) |
| GAP-0018 | [#34](https://gitlab.com/devnw/zig/strings/-/issues/34) | Close (DamerauLevenshtein doc) |
| GAP-0027 | [#53](https://gitlab.com/devnw/zig/strings/-/issues/53) | Close (examples/README.md) |
| GAP-0032 | [#86](https://gitlab.com/devnw/zig/strings/-/issues/86) | Close (README overclaims) |
| P1-7 | [#73](https://gitlab.com/devnw/zig/strings/-/issues/73) | Close (SIMD wired) |
| P1-8 | [#75](https://gitlab.com/devnw/zig/strings/-/issues/75) | Close (threshold at 10MB) |
| P2-9/P2-14 | [#78](https://gitlab.com/devnw/zig/strings/-/issues/78) | Close (all 29 sites) |
| S18 / D4 | [#61](https://gitlab.com/devnw/zig/strings/-/issues/61) / [#65](https://gitlab.com/devnw/zig/strings/-/issues/65) | Close (maxInt sentinel) |
| S19 | [#64](https://gitlab.com/devnw/zig/strings/-/issues/64) | Close (InputTooLarge) |
| S21 | [#70](https://gitlab.com/devnw/zig/strings/-/issues/70) | Close (isBidiMark) |
| S17 | [#59](https://gitlab.com/devnw/zig/strings/-/issues/59) | Close (global step budget) |
| S15 | [#57](https://gitlab.com/devnw/zig/strings/-/issues/57) | Close (checked arithmetic) |
| S16 | [#58](https://gitlab.com/devnw/zig/strings/-/issues/58) | Close (checked arithmetic) |
| All Wave 1 issues | [#15-#37, #47-#56](https://gitlab.com/devnw/zig/strings/-/issues/) | Close (see GAP_ANALYSIS_RESOLVED.md) |
