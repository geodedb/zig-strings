# Gap Analysis

**Repository:** devnw/zig/strings
**Last updated:** 2026-03-25 (Wave 8 -- A4 closed)
**Analyzer:** Claude Opus 4.6 (automated gap determination)
**Branch:** main (commit: dad4272)
**Scope:** v1.0 readiness assessment

> This file contains ONLY open gaps. Resolved gaps are in [GAP_ANALYSIS_RESOLVED.md](GAP_ANALYSIS_RESOLVED.md).
> Satellite analysis files: [PERF_GAP_ANALYSIS.md](PERF_GAP_ANALYSIS.md), [QUALITY_GAP_ANALYSIS.md](QUALITY_GAP_ANALYSIS.md), [SECURITY_GAP_ANALYSIS.md](SECURITY_GAP_ANALYSIS.md).

---

## Gaps

### A1: Error type duplication across modules (Closed)
- **Issue:** [#39](https://gitlab.com/devnw/zig/strings/-/issues/39)
- **Category:** Code Quality
- **Severity:** Medium
- **Status:** Closed -- no further consolidation warranted. Remaining error sets are domain-specific.
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

### A4: Inconsistent parameter ordering across API (Closed)
- **Issue:** [#76](https://gitlab.com/devnw/zig/strings/-/issues/76)
- **Category:** Code Quality
- **Severity:** Low
- **Status:** Closed -- all 143 public allocator-accepting functions now follow consistent ordering.
- **Requirement source:** API consistency -- allocator-first vs allocator-last convention
- **Current state (evidence):**
  - Audited all 143 public allocator-accepting functions
  - 107 standalone/static functions: allocator-first (Zig stdlib convention) -- already correct
  - 36 methods: self, allocator, ...rest -- already idiomatic Zig
  - 1 outlier fixed: `ICUString.caseCompare(self, other, allocator)` reordered to `(self, allocator, other)`
  - Convention: standalone → allocator-first; methods → self, allocator, ...rest
  - PriorityScore: 24 (QUALITY_GAP_ANALYSIS.md)
- **Why this was a gap:** Inconsistent parameter ordering reduces API ergonomics.
- **Impact/Risk:** Minimal -- only 1 function signature changed (`caseCompare` had no external callers).
- **Fix applied:** Reordered `ICUString.caseCompare` parameter to `(self, allocator, other)`. All tests pass.
- **Acceptance criteria:**
  - All public allocator-accepting functions follow a consistent parameter ordering convention -- MET
  - Migration guide: N/A -- `caseCompare` had zero callers outside the module

---

## Gap Priority Matrix (Open Only)

| Severity | Count | Gap-IDs |
|----------|-------|---------|
| Critical | 0 | -- |
| High | 0 | -- |
| Medium | 0 | -- |
| Low | 0 | -- |

**Total open gaps: 0**
**Closed (Wave 8):** A4 (parameter ordering -- 1 outlier fixed: `ICUString.caseCompare`)
**Closed (Wave 7):** A1 (error type duplication -- domain-specific sets justified, no further action)

**Won't Do (moved to RESOLVED):** GAP-0002 (CI infra), GAP-0015 (UCD test vectors), GAP-0021 (fuzz infra), S6, S8, M2, M5, P1-4, Q14, Q25, Q26, P2-9, P2-16, S23, S24
**Closed (Wave 6):** P2-3 (streaming normalization -- O(1) memory), Q49 (6 files split below 800 lines)
**Closed (Wave 5):** GAP-0001 (NFC_QC/NFKC_QC trie tables), P1-6 (trie-based category/grapheme), P2-10 (block-indexed decomp/comp), P3-1 (subsumed by P2-10)
**Closed (Wave 4):** GAP-0033 (committed as 5c110b1), R4 (regex stack overflow -- MAX_RECURSION_DEPTH guard)
**Closed (satellite):** P2-13 (ASCII fast-path in getGraphemeBreak), P2-NEW-1 (SIMD isAllAscii in normalize), P2-NEW-2 (virama guard), P3-NEW-1 (reverse capacity), S22/AC-1 (phoneticMatch @panic), AC-2 (metaphone 'N' fix), AC-3 (doubleMetaphone doc), RE-3 (phonetic cross-tests), AC-4 (parallel sentinel doc)
**Closed (moved to RESOLVED):** GAP-0003-0014, GAP-0016-0020, GAP-0022-0032

---

## ID Registry

| Gap-ID Range | Analysis Date | Resolution Date | Notes |
|-------------|--------------|-----------------|-------|
| GAP-0001 through GAP-0022 | 2026-03-23 | 2026-03-24 | All closed (GAP-0001 Wave 5), 4 won't do |
| GAP-0023 through GAP-0030 | 2026-03-24 | 2026-03-24 | Phase 3: all closed |
| GAP-0031 through GAP-0033 | 2026-03-24 | 2026-03-24 | Wave 2 closed GAP-0012/0031, GAP-0018, GAP-0019; GAP-0033 committed (5c110b1) |
| Cross-file IDs | 2026-03-24 | 2026-03-25 | P1-6, P2-10, P3-1 closed (Wave 5); R4 closed (Wave 4); A1 closed (Wave 7); A4 closed (Wave 8) |
| Wave 4 closures | 2026-03-24 | 2026-03-24 | GAP-0033, R4, S22/AC-1, AC-2, AC-3, RE-3, AC-4, P2-NEW-1, P2-NEW-2, P3-NEW-1 |
| Wave 5 closures | 2026-03-24 | 2026-03-24 | GAP-0001 (Critical), P1-6, P2-10, P3-1 via UCD trie generation (commit dad4272) |
| Wave 6 closures | 2026-03-24 | 2026-03-24 | P2-3 (streaming normalization), Q49 (file splitting); A1 closed as Partial; A4 deferred; S6/S23/S24 Won't Do |
| Wave 8 closures | 2026-03-25 | 2026-03-25 | A4 (parameter ordering -- 1 outlier `ICUString.caseCompare` fixed) |
