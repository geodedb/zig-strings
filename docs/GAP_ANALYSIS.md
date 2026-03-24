# Gap Analysis

**Repository:** devnw/zig/strings
**Last updated:** 2026-03-24 (Phase 4 -- full codebase audit)
**Analyzer:** Claude Opus 4.6 (automated gap determination)
**Branch:** main (commit: c8b770d)
**Scope:** v1.0 readiness assessment

> This file contains ONLY open gaps. Resolved gaps are in [GAP_ANALYSIS_RESOLVED.md](GAP_ANALYSIS_RESOLVED.md).
> Satellite analysis files: [PERF_GAP_ANALYSIS.md](PERF_GAP_ANALYSIS.md), [QUALITY_GAP_ANALYSIS.md](QUALITY_GAP_ANALYSIS.md), [SECURITY_GAP_ANALYSIS.md](SECURITY_GAP_ANALYSIS.md).

---

## Gaps

### GAP-0001: `isNormalized()` NFC/NFKC branch is empty -- returns incorrect results for composed forms
- **Issue:** [#22](https://gitlab.com/devnw/zig/strings/-/issues/22)
- **Category:** Bug
- **Severity:** Critical
- **Requirement source:** UAX #15 Section 9: Quick_Check property lookups (NFC_QC, NFD_QC, NFKC_QC, NFKD_QC)
- **Current state (evidence):**
  - `src/unicode/normalization.zig:62-68` -- The NFC/NFKC branch of the `switch (form)` statement is an empty block with only a comment: "the partial check only validates CCC ordering."
  - NFD/NFKD branches (lines 69-90) correctly check decomposition tables and Hangul syllables.
  - NFD/NFKD fix verified in Wave 1; NFC/NFKC remains unimplemented. Requires UCD property table generation.
- **Why this is a gap:** `isNormalized("caf\xC3\xA9", .nfc)` returns `true` even though the precomposed character has no special NFC validation. Any composed string passes trivially. The function remains broken for NFC/NFKC.
- **Impact/Risk:** Data corruption in any pipeline that uses `isNormalized()` as a guard before processing. Unicode conformance failure.
- **Recommended fix:** Implement proper Quick_Check property lookups per UAX #15 Section 9. Requires generating UCD property tables (NFC_QC, NFKC_QC).
- **Acceptance criteria:**
  - `isNormalized("\xC3\xA9", .nfd)` returns `false`
  - `isNormalized("e\xCC\x81", .nfc)` returns `false`
  - Tests cover all four forms with known normalized/unnormalized inputs

### GAP-0033: Gap-closure changes remain uncommitted in working tree
- **Issue:** [#87](https://gitlab.com/devnw/zig/strings/-/issues/87)
- **Category:** Code Quality
- **Severity:** High
- **Status:** Pending commit
- **Requirement source:** All gap closures from GAP-0003 through GAP-0030, plus Wave 2 closures (GAP-0012, GAP-0018, GAP-0019, GAP-0027, GAP-0032, and associated security/quality/perf items), plus Wave 3 closures (Q21, Q22, R2/S20, M3, P2-8, P2-12, M4, A1, Q27, D3, P2-15)
- **Current state (evidence):**
  - All code changes are complete and verified (536/536 tests pass, 76/76 build steps)
  - `git diff --stat HEAD` shows 43 files changed, +1,792/-1,235 lines
  - HEAD is `c8b770d` (spice dependency hash fix) -- no gap-closure commit exists yet
  - Wave 3 additions: 19 new tests across manipulation.zig, search.zig, phonetic.zig, regex.zig
- **Why this is a gap:** All gap-closure work exists only in the working tree until committed. The fixes are invisible to CI, other contributors, and the GitLab issue tracker.
- **Impact/Risk:** High -- all gap-closure work is at risk of loss until committed.
- **Recommended fix:** Stage and commit all gap-closure changes. Push to the remote.
- **Acceptance criteria:**
  - All modified and new files committed to `main` (or a feature branch)
  - `git status` shows a clean working tree
  - CI can run tests against the committed changes

### R4: Regex VM recursive backtracking -- stack overflow risk for deep nesting
- **Issue:** [#25](https://gitlab.com/devnw/zig/strings/-/issues/25) (shares issue with GAP-0004, which closed the ReDoS aspect)
- **Category:** Bug
- **Severity:** Medium
- **Requirement source:** Regex engine safety -- deep alternation/group nesting causes native stack overflow
- **Current state (evidence):**
  - `src/extended/regex.zig:1352-1361` -- `matchAt()` uses Zig function recursion for backtracking alternatives
  - GAP-0004 added a step counter (MAX_STEPS = 1,000,000) which mitigates CPU-time DoS but does NOT prevent stack overflow from deep recursion
  - PriorityScore: 36 (QUALITY_GAP_ANALYSIS.md)
- **Why this is a gap:** A pattern with deep alternation nesting (e.g., `(a|b(c|d(e|f(...))))`) matched against long input can overflow the native stack before the step counter triggers.
- **Impact/Risk:** Process crash (stack overflow) on adversarial or deeply nested regex patterns.
- **Recommended fix:** Convert `matchAt()` from recursive to iterative using an explicit worklist/stack with a bounded depth limit.
- **Acceptance criteria:**
  - `matchAt()` uses an explicit stack with configurable depth limit
  - Deeply nested patterns return an error instead of crashing

### A1: Error type duplication across modules (Partial)
- **Issue:** [#39](https://gitlab.com/devnw/zig/strings/-/issues/39)
- **Category:** Code Quality
- **Severity:** Medium
- **Status:** Partial -- no further consolidation warranted
- **Requirement source:** API consistency and maintainability
- **Current state (evidence):**
  - 6+ independent error type definitions across modules (regex, normalization, encoding, parallel, etc.)
  - Wave 3 closure of M3 consolidated legacy encoding errors into shared `LegacyEncodingError`
  - Remaining error sets are domain-specific with no meaningful overlap
  - PriorityScore: 45 (QUALITY_GAP_ANALYSIS.md)
- **Why this is a gap:** Multiple similar-but-distinct error types reduce API ergonomics, though the remaining duplication is justified by domain separation.
- **Impact/Risk:** Low -- remaining error sets are appropriately domain-specific.
- **Recommended fix:** No further action recommended. Remaining error sets serve distinct domains.
- **Acceptance criteria:**
  - No new error type duplication introduced in future work

### P1-6: Table-based `getCategory()` / `getGraphemeBreak()` lookup
- **Issue:** [#68](https://gitlab.com/devnw/zig/strings/-/issues/68)
- **Category:** Performance
- **Severity:** High
- **PerfScore:** 80
- **Requirement source:** Hottest per-codepoint functions; called in grapheme iteration, normalization, case mapping
- **Current state (evidence):**
  - `src/unicode/categories.zig:19-32` -- 100+ sequential if-chain range comparisons
  - `src/unicode/grapheme.zig:37-83` -- 80+ if-checks plus `isIndicSpacingMark` (~40 more)
  - Grapheme count benchmark: 242,823 ns/op (16 MB/s)
  - NFC normalize benchmark: 82,641 ns/op (35 MB/s)
- **Why this is a gap:** Sequential if-chain is O(n) per codepoint where n is number of Unicode ranges. Standard Unicode implementations use two-level tries for O(1) lookup.
- **Impact/Risk:** 3-5x throughput improvement expected for grapheme operations, 2-3x for NFC normalization.
- **Recommended fix:** Generate two-level trie (stage1 + stage2 arrays) from UCD data files (`UnicodeData.txt`, `GraphemeBreakProperty.txt`). BMP: direct array lookup (64KB). Supplementary: block-based trie.
- **Acceptance criteria:**
  - `getCategory()` and `getGraphemeBreak()` use generated lookup tables
  - Grapheme count benchmark < 80,000 ns/op
  - All existing tests pass unchanged

### P2-10: O(1) decomposition/composition tables
- **Issue:** [#80](https://gitlab.com/devnw/zig/strings/-/issues/80)
- **Category:** Performance
- **Severity:** Medium
- **PerfScore:** 44
- **Requirement source:** Normalization hot path -- per-codepoint decomposition/composition lookup
- **Current state (evidence):**
  - `src/unicode/data/decomposition.zig:2087-2095` -- `getDecomposition()` calls `binarySearchDecomp1` + `binarySearchDecomp2`
  - `src/unicode/data/composition.zig:965-979` -- binary search on 941-entry flat array
- **Why this is a gap:** Binary search is O(log n) per lookup; O(1) table would improve NFC normalization by 10-25%.
- **Impact/Risk:** 10-25% NFC improvement (current: 82,641 ns/op).
- **Recommended fix:** Two-level index: group by high bits, binary search within blocks. Or comptime perfect hash.
- **Acceptance criteria:**
  - Decomposition and composition lookups use indexed or hashed tables
  - NFC benchmark shows measurable improvement
  - NormalizationTest.txt conformance maintained

### P2-3: `normalize()` materializes full codepoint buffer
- **Issue:** [#45](https://gitlab.com/devnw/zig/strings/-/issues/45)
- **Category:** Performance
- **Severity:** Medium
- **PerfScore:** 35
- **Requirement source:** Memory efficiency in normalization pipeline
- **Current state (evidence):**
  - `src/unicode/normalization.zig:422-442` -- decomposes entire input into ArrayList before sorting/composing
  - O(n) extra memory proportional to input length
- **Why this is a gap:** For large inputs, materializing all codepoints wastes memory. CCC sequences are typically 2-4 elements; a streaming approach with fixed windows would be O(1) memory.
- **Impact/Risk:** Memory pressure for large normalization inputs. 20-40% NFC improvement with O(1) memory possible.
- **Recommended fix:** Streaming normalization with fixed-size windows over CCC sequences.
- **Acceptance criteria:**
  - `normalize()` uses bounded memory independent of input length
  - NormalizationTest.txt conformance maintained

### A4: Inconsistent parameter ordering across API
- **Issue:** [#76](https://gitlab.com/devnw/zig/strings/-/issues/76)
- **Category:** Code Quality
- **Severity:** Low
- **Requirement source:** API consistency -- allocator-first vs allocator-last convention
- **Current state (evidence):**
  - Some functions take allocator as first parameter, others as last
  - PriorityScore: 24 (QUALITY_GAP_ANALYSIS.md)
- **Why this is a gap:** Inconsistent parameter ordering reduces API ergonomics and increases cognitive load for users.
- **Impact/Risk:** Low -- cosmetic API inconsistency. Breaking change to fix.
- **Recommended fix:** Audit all public functions and align to allocator-first convention (Zig standard library convention). This is a breaking API change.
- **Acceptance criteria:**
  - All public allocator-accepting functions follow a consistent parameter ordering convention
  - Migration guide provided for breaking changes

### Q49: 6 files exceed 800-line limit
- **Issue:** Not yet filed
- **Category:** Code Quality
- **Severity:** Low
- **Requirement source:** Coding style guideline -- files should be under 800 lines
- **Current state (evidence):**
  - `src/extended/regex.zig`: 2,059 lines
  - `src/ops/manipulation.zig`: 1,145 lines
  - `src/unicode/normalization.zig`: 1,003 lines
  - `src/util/simd.zig`: 995 lines
  - `src/extended/locale.zig`: 821 lines
  - `src/unicode/categories.zig`: 814 lines
- **Why this is a gap:** Large files reduce readability and increase merge conflict risk. regex.zig at 2,059 lines is the most significant outlier.
- **Impact/Risk:** Low -- maintainability drag; no functional impact.
- **Recommended fix:** Extract sub-modules from the largest files. regex.zig could split compiler/VM/parser. manipulation.zig could separate string operations by category.
- **Acceptance criteria:**
  - No source file exceeds 800 lines (or documented exceptions for generated code)

### P3-1: Composition binary search on 941-entry flat array
- **Issue:** Subsumed by P2-10 ([#80](https://gitlab.com/devnw/zig/strings/-/issues/80))
- **Category:** Performance
- **Severity:** Low
- **PerfScore:** 15
- **Requirement source:** Normalization composition lookup efficiency
- **Current state (evidence):**
  - `src/unicode/data/composition.zig:965-979` -- binary search on 941-entry array (~10 comparisons per lookup)
- **Why this is a gap:** Minor optimization opportunity within the composition step. Subsumed by P2-10 which addresses both decomposition and composition tables.
- **Impact/Risk:** Marginal. Fixing P2-10 resolves this automatically.
- **Recommended fix:** Addressed as part of P2-10 (two-level index or perfect hash).
- **Acceptance criteria:**
  - Resolved when P2-10 is closed

---

## Gap Priority Matrix (Open Only)

| Severity | Count | Gap-IDs |
|----------|-------|---------|
| Critical | 1 | GAP-0001 (isNormalized NFC/NFKC -- requires UCD Quick_Check tables) |
| High | 2 | GAP-0033 (uncommitted changes -- 43 files, +1,792/-1,235), P1-6 (table-based category/grapheme lookup, PerfScore 80) |
| Medium | 4 | R4 (regex stack overflow), A1 (error type duplication -- partial, no action needed), P2-10 (O(1) decomposition tables, PerfScore 44), P2-3 (streaming normalization, PerfScore 35) |
| Low | 3 | A4 (parameter ordering), Q49 (6 files over 800-line limit), P3-1 (composition binary search, subsumed by P2-10) |

**Total open gaps: 10**

**Won't Do (moved to RESOLVED):** GAP-0002 (CI infra), GAP-0015 (UCD test vectors), GAP-0021 (fuzz infra), S6, S8, M2, M5, P1-4, Q14, Q25, Q26, P2-9, P2-16
**Closed (satellite):** P2-13 (ASCII fast-path in getGraphemeBreak -- implemented)
**Closed (moved to RESOLVED):** GAP-0003-0014, GAP-0016-0020, GAP-0022-0032

---

## ID Registry

| Gap-ID Range | Analysis Date | Resolution Date | Notes |
|-------------|--------------|-----------------|-------|
| GAP-0001 through GAP-0022 | 2026-03-23 | 2026-03-24 | Initial gap analysis; 17 closed, 1 partial (GAP-0001), 4 won't do |
| GAP-0023 through GAP-0030 | 2026-03-24 | 2026-03-24 | Phase 3: all closed |
| GAP-0031 through GAP-0033 | 2026-03-24 | -- | Re-audit: 3 false closures re-opened; Wave 2 closed GAP-0012/0031, GAP-0018, GAP-0019; GAP-0033 pending commit |
| Cross-file IDs (R4, A1, A4, Q49, P1-6, P2-10, P2-3, P3-1) | 2026-03-24 | -- | Satellite analysis findings; tracked in PERF/QUALITY gap analysis files |
