# Gap Analysis

**Repository:** devnw/zig/strings
**Last updated:** 2026-03-30 (Wave 10 -- all parallelism gaps closed)
**Analyzer:** Claude Opus 4.6 (automated gap determination)
**Branch:** main
**Scope:** v1.0 readiness assessment

> This file contains ONLY open gaps. Resolved gaps are in [GAP_ANALYSIS_RESOLVED.md](GAP_ANALYSIS_RESOLVED.md).
> Satellite analysis files: [PERF_GAP_ANALYSIS.md](PERF_GAP_ANALYSIS.md), [QUALITY_GAP_ANALYSIS.md](QUALITY_GAP_ANALYSIS.md), [SECURITY_GAP_ANALYSIS.md](SECURITY_GAP_ANALYSIS.md).

---

## Gaps

_No open gaps._

---

## Gap Priority Matrix (Open Only)

| Severity | Count | Gap-IDs |
|----------|-------|---------|
| Critical | 0 | -- |
| High | 0 | -- |
| Medium | 0 | -- |
| Low | 0 | -- |

**Total open gaps: 0**
**Closed (Wave 10, 2026-03-30):** GAP-0038 (parallel module documented as opt-in with convenience re-exports and `strings.deinit()`), GAP-0039 (parallel normalization via `parallelNormalize` with ASCII-boundary chunking), GAP-0040 (parallel case conversion via `parallelCaseConvert` with UTF-8 boundary chunking), GAP-0041 (spice pinned to v0.1.0 tag), GAP-0042 (parallelMap threshold lowered from 10 MB to 64 KB), GAP-0043 (named `error_sentinel` constant and `isErrorSentinel` helper), GAP-0044 (library-level `strings.deinit()` calls `deinitPool()`)
**Opened (Wave 10, 2026-03-30):** GAP-0038 through GAP-0044 (7 gaps from parallelism review)
**Closed (Wave 9):** GAP-0035 (Unicode conformance test vectors -- 33 NormalizationTest.txt + 29 GraphemeBreakTest.txt vectors; also fixed recursive decomposition bug, spacing modifier compat decomps, and GB12/GB13 RI pairing), GAP-0036 (thread safety documentation -- doc comments added to all public parallel.zig functions, ARCHITECTURE.md expanded, README.md updated), GAP-0037 (cross-compilation CI jobs for macOS x86_64/aarch64 and Windows x86_64), RM-4 (duplicate build.zig imports), P-NEW-4 (SIMD countScalar), S25 (parallelCount boundary fix), P-NEW-3 (containsIgnoreCase ASCII fast-path), Q-CI1 (CI cache), Q-LOC1 (locale tests), A4 (parameter ordering), A1 (error type duplication)
**Won't Do (Wave 9):** S26 (CI component SHA pinning -- GitLab CI does not support SHA-based pinning; first-party control mitigates)
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
| GAP-0034 | 2026-03-25 | 2026-03-25 | Duplicate of S6 (Won't Do) -- not added |
| GAP-0035 through GAP-0037 | 2026-03-25 | 2026-03-25 | Phase 3 audit: GAP-0035 (conformance tests), GAP-0036 (thread safety docs), GAP-0037 (cross-platform CI) -- all Closed in Wave 9 |
| GAP-0038 through GAP-0044 | 2026-03-30 | 2026-03-30 | Wave 10: parallelism review -- 7 gaps opened and closed same wave |
