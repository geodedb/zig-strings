# Quality Gap Analysis

Last updated: 2026-03-24 (Phase 4 -- quality reviewer update)
Repository: devnw/zig/strings (branch: main, commit: b66264f)
Analyzer: Claude Opus 4.6 (automated quality scoring -- Phase 4 re-audit + Phase 3 quality review)
Overall quality rating: **B** (solid foundation with specific sharp edges)

---

## Summary

| Severity | Total | Closed | Partial | Won't Do | Open |
|----------|-------|--------|---------|----------|------|
| Critical | 5 | 3 | 1 | 1 | 0 |
| High | 12 | 11 | 0 | 0 | 1 |
| Medium | 28 | 17 | 1 | 5 | 5 |
| Low | 11 | 7 | 0 | 0 | 4 |
| **Total** | **56** | **38** | **2** | **6** | **10** |

### Top 5 Active Risks

1. **`phoneticMatch` unreachable UB in ReleaseFast** (AC-1/Q48r, PriorityScore 76.8) -- `unreachable` at `phonetic.zig:603` becomes undefined behavior in ReleaseFast/ReleaseSmall when a non-soundex algorithm is passed. Status: **Open** (HIGH).
2. **Phonetic match tests only check self-equality** (RE-3, PriorityScore 76.8) -- Five test functions (`phoneticMatchAlloc` for double_metaphone, nysiis, match_rating, caverphone, refined_soundex) only test `f("X", "X", algo)`, providing false confidence. Status: **Open** (MEDIUM).
3. **`isNormalized` false positives for NFC/NFKC** (R3/Q2, PriorityScore 90) -- NFC/NFKC branch performs no composition check. Issue [#22](https://gitlab.com/devnw/zig/strings/-/issues/22). Status: **Partial** (requires UCD Quick_Check table generation).
4. **Metaphone duplicate branch condition** (AC-2, PriorityScore 57.6) -- `w[i+1] == 'N' or w[i+1] == 'N'` at `phonetic.zig:261` -- second arm is identical to first; likely should be a different letter (e.g., `'M'`). Logic bug. Status: **Open** (MEDIUM).
5. **`doubleMetaphone` is a stub** (AC-3, PriorityScore 57.6) -- Returns simplified metaphone as primary and a trivial X-to-S alternate. Not a real Double Metaphone implementation per Philips (2000). Not documented as stub in public API. Status: **Open** (MEDIUM).

### Resolved Since Last Review

- **SIMD assert vanishes in ReleaseFast** (R1) -- Closed. Replaced `std.debug.assert` with `@panic` in `toLowerAscii`, `toUpperAscii`, `memcpySimd`. Bounds checks now persist in all build modes.
- **VM `else` catch-all** (Q1) -- Closed. All opcode handlers implemented; `unreachable` as catch-all.
- **`jaro()` panics >256 bytes** (Q6) -- Closed. Bounds guard returns 0.0.
- **Unbounded regex recursion** (Q3) -- Closed. Step counter (1M limit) added.
- **`PatternTooComplex` dead code** (Q4) -- Closed. Now returned for excessive instructions.
- **Capture groups dead** (Q7) -- Closed. Groups wired into Match result.
- **`levenshtein()` truncation** (Q8) -- Closed. Dynamic allocation added.
- **Duplicated UnicodeCategory in regex.zig** (M1) -- Closed. Replaced local `UnicodeCategory` enum and `classifyCodepoint` heuristic with canonical `categories.getCategory` from `types.GeneralCategory`. ~150 lines removed. Build dependency added to `build.zig`.
- **Regex test coverage** (Q5) -- Closed. Expanded from 20 to 39 tests. Added 19 new tests covering: Unicode property matching (`\p{Lu}`, `\p{Ll}`, `\p{N}`, `\P{Lu}`), character class ranges (`[a-z]`, `[^0-9]`), quantifiers (`{n}`, `{n,m}`, `*`), anchors (`^...$`), alternation, capture groups, findAll iteration, non-capturing groups, escaped special characters, predefined classes (`\w`, `\s`, `\D`), dot behavior, and empty input edge cases.
- **lib.zig test block incomplete** (M6) -- Closed. Test block now imports all ~30 public modules.
- **Parallel module test gaps** (R7) -- Closed. Added tests exercising parallel paths above thresholds (4096 bytes for count, 8 targets for edit distance, 16 candidates for fuzzy search).
- **ASCII category misclassification** (Q46) -- Closed (Wave 2). Correct categories at `categories.zig:585-595`; test at lines 826-846.
- **`concat()` overflow check** (A5) -- Closed. Already fixed (`manipulation.zig:385` uses `std.math.add`).
- **`phoneticMatch` soundex fallback** (Q48) -- Closed (Wave 2). `unreachable` at `phonetic.zig:602`; doc comment at lines 585-594. **Note:** Residual AC-1/Q48r re-opened for the ReleaseFast UB introduced by the `unreachable` fix.
- **SIMD module zero internal callers** (Q21) -- Closed (Wave 3). `src/unicode/case.zig` imports and uses `simd.isAllAscii`, `simd.toLowerAscii`, `simd.toUpperAscii` (wired in P1-7 fix).
- **`phoneticMatchAlloc` zero callers** (Q22) -- Closed (Wave 3). Added 7 tests exercising all algorithm paths (soundex, refined_soundex, metaphone, double_metaphone, nysiis, match_rating, caverphone).
- **Bare `@intCast` in encoding** (R2) -- Closed (Wave 3, targeted fix). Added codepoint range guard in `encode4ByteGB18030` (`chinese.zig:330`) and `std.math.cast` in `gb18030LinearToUnicode` (`:375`). Remaining ~120 casts verified safe by construction (bounded by table sizes and ASCII guards). Cross-ref: S20 (SECURITY_GAP_ANALYSIS.md) also closed.
- **Legacy encoding error duplication 4x** (M3) -- Closed (Wave 3). Created shared `LegacyEncodingError` in `src/encoding/legacy/errors.zig`; all 6 files now alias the shared set. Backward-compatible (public names unchanged).
- **build.zig monolith** (M4) -- Closed (Wave 4). Extracted `addLibModule` and `addLibTest` helper functions; shared import arrays for repeated dependency lists. Reduced from 1,398 to 837 lines (~40% reduction). All tests pass.
- **Error type duplication** (A1) -- Partial (Wave 4). Analysis confirmed remaining error sets are domain-specific (regex, normalization, encoding, parallel, etc.) with no meaningful duplication after M3 consolidated legacy encoding errors. No further consolidation warranted.
- **49 pub fns lack doc comments** (Q27) -- Closed (Wave 4). All 49 undocumented pub fns now have `///` doc comments across 15 files (iterator.zig, latin1.zig, search.zig, grapheme.zig, utf8.zig, utf16.zig, utf32.zig, word.zig, sentence.zig, line_break.zig, phonetic.zig, lazy_norm.zig, mmap.zig, rope.zig, icu.zig, parallel.zig, regex.zig).
- **No ADRs** (D3) -- Closed (Wave 4). Created 5 ADRs in `docs/adr/`: ADR-001 (SIMD architecture), ADR-002 (parallel thresholds), ADR-003 (unicode tables), ADR-004 (error handling), ADR-005 (normalization strategy).

---

## Findings

Sorted by PriorityScore descending. Phase 1/2 findings prefixed Q, Phase 3 findings prefixed R/A/M/D. Phase 4 findings: Q46-Q49. Phase 3 quality review findings: AC-1 through AC-4, RE-3, RM-1, RM-4.

| Rank | ID | Severity | PriorityScore | Category | Finding | Component | Issue | Effort | Status |
|------|----|----------|---------------|----------|---------|-----------|-------|--------|--------|
| 1 | Q18 | Critical | 100 | ci-cd | CI build/test stages entirely disabled | `.gitlab-ci.yml` | [#23](https://gitlab.com/devnw/zig/strings/-/issues/23) | M | Won't Do |
| 2 | R1 | Critical | 96 | perf | 3 `std.debug.assert` in SIMD vanish in ReleaseFast -- silent OOB writes | `src/util/simd.zig:279,360,712` | [#60](https://gitlab.com/devnw/zig/strings/-/issues/60) | S | Closed |
| 3 | Q46 | High | 96.0 | api-contract | `getAsciiCategory` misclassifies 5 ASCII chars (`$`/`(`/`)`/`+`/`-`) as `Po` | `src/unicode/categories.zig:585-595` | -- | S | Closed |
| 4 | Q1 | Critical | 95 | architecture | VM `else` catch-all silently skips opcodes | `src/extended/regex.zig` | [#26](https://gitlab.com/devnw/zig/strings/-/issues/26) | M | Closed |
| 5 | Q6 | Critical | 95 | perf | `jaro()` panics/OOB on strings >256 bytes | `src/extended/fuzzy.zig` | [#30](https://gitlab.com/devnw/zig/strings/-/issues/30) | S | Closed |
| 6 | R3 | Critical | 90 | architecture | `isNormalized` false positives for NFC/NFKC -- no composition check | `src/unicode/normalization.zig:62-68` | [#22](https://gitlab.com/devnw/zig/strings/-/issues/22) | L | Partial |
| 7 | Q3 | High | 85 | perf | Regex VM recursive backtracking (mitigated with step counter) | `src/extended/regex.zig:1352-1361` | [#25](https://gitlab.com/devnw/zig/strings/-/issues/25) | M | Closed |
| 8 | A5 | High | 84 | api-contract | `concat()` lacks overflow check unlike `join()` and `repeat()` | `src/ops/manipulation.zig:385` | [#62](https://gitlab.com/devnw/zig/strings/-/issues/62) | S | Closed |
| 9 | Q4 | High | 80 | architecture | `PatternTooComplex` defined but never returned | `src/extended/regex.zig` | -- | S | Closed |
| 10 | Q5 | High | 80 | tests | Regex: 39 tests for ~1,550 lines (expanded from 20 to 39) | `src/extended/regex.zig` | [#38](https://gitlab.com/devnw/zig/strings/-/issues/38) | L | Closed |
| 11 | M1 | High | 80 | maintainability | Duplicated UnicodeCategory enum + classifyCodepoint removed; using categories.getCategory | `src/extended/regex.zig` | [#63](https://gitlab.com/devnw/zig/strings/-/issues/63) | M | Closed |
| 12 | Q47 | High | 76.8 | ci-cd | CI omits `test-comprehensive` -- 208 tests only run locally | `.gitlab-ci.yml` | -- | S | Closed |
| 13 | AC-1/Q48r | High | 76.8 | api-contract | `phoneticMatch` `unreachable` at line 603 is UB in ReleaseFast/ReleaseSmall -- callers passing non-soundex algo get silent corruption | `src/extended/phonetic.zig:603` | -- | S | **Open** |
| 14 | RE-3 | Medium | 76.8 | tests | Phonetic match tests only check self-equality -- trivially pass, do not validate algorithm correctness | `src/extended/phonetic.zig:810-832` | -- | S | **Open** |
| 15 | Q7 | High | 75 | architecture | `Match.groups` always returned empty (capture groups dead) | `src/extended/regex.zig` | -- | M | Closed |
| 16 | Q8 | High | 75 | perf | `levenshtein()` silently truncated at 1024 bytes | `src/extended/fuzzy.zig` | [#35](https://gitlab.com/devnw/zig/strings/-/issues/35) | S | Closed |
| 17 | Q9 | High | 70 | architecture | `damerauLevenshtein` falls back to wrong algorithm >32 chars | `src/extended/fuzzy.zig` | [#34](https://gitlab.com/devnw/zig/strings/-/issues/34) | M | Closed |
| 18 | M2 | Medium | 70 | maintainability | `getCategory` 561-line if-chain, no generated table | `src/unicode/categories.zig:19-578` | -- | L | Won't Do |
| 19 | Q11 | High | 65 | api-contract | lib.zig vs zigstr.zig API surface mismatch | `src/lib.zig` vs `src/zigstr.zig` | [#33](https://gitlab.com/devnw/zig/strings/-/issues/33) | S | Closed |
| 20 | M5 | Medium | 65 | architecture | `getCompatibilityDecomposition` covers ~30 of thousands of NFKD mappings | `src/unicode/normalization.zig:140-179` | -- | L | Won't Do |
| 21 | R2 | Medium | 60 | perf | ~71 bare `@intCast` in 6 encoding modules -- no safety in ReleaseFast | `src/encoding/legacy/*.zig` | [#67](https://gitlab.com/devnw/zig/strings/-/issues/67) | M | Closed |
| 22 | AC-2 | Medium | 57.6 | api-contract | Metaphone duplicate branch: `w[i+1] == 'N' or w[i+1] == 'N'` -- second arm identical, likely should be different letter | `src/extended/phonetic.zig:261` | -- | S | **Open** |
| 23 | AC-3 | Medium | 57.6 | api-contract | `doubleMetaphone` is a stub (simplified metaphone + trivial X-to-S alternate), not documented as such in public API | `src/extended/phonetic.zig:360-395` | -- | S | **Open** |
| 24 | Q48 | Medium | 57.6 | api-contract | `phoneticMatch` silently falls back to soundex for all non-soundex algorithms | `src/extended/phonetic.zig:585-602` | -- | S | Closed (see AC-1/Q48r for residual) |
| 25 | Q21 | Medium | 57.6 | cleanup | SIMD module zero internal callers -- entire module is dead code for library consumers | `src/util/simd.zig` | [#41](https://gitlab.com/devnw/zig/strings/-/issues/41) | S | Closed |
| 26 | Q13 | Medium | 55 | maintainability | Duplicated `NormalizationForm`/`Encoding` enums in zigstr.zig vs types.zig | `src/zigstr.zig` vs `src/types.zig` | -- | S | Closed |
| 27 | Q14 | Medium | 55 | tests | categories.zig: 19 pub fns, only 4 tests | `src/unicode/categories.zig` | [#32](https://gitlab.com/devnw/zig/strings/-/issues/32) | M | Won't Do |
| 28 | M6 | Medium | 52 | tests | lib.zig test block imports only 7 of ~30 modules | `src/lib.zig:339-348` | [#72](https://gitlab.com/devnw/zig/strings/-/issues/72) | S | Closed |
| 29 | Q15 | Medium | 50 | readability | Magic numbers 1024/256/33 in fuzzy.zig | `src/extended/fuzzy.zig` | -- | S | Closed |
| 30 | M3 | Medium | 48.0 | maintainability | Legacy encoding error duplication 4x (confirmed) | `src/encoding/legacy/*.zig` | [#69](https://gitlab.com/devnw/zig/strings/-/issues/69) | M | Closed |
| 31 | M4 | Medium | 48.0 | maintainability | build.zig 1,370-line monolith with repetitive module declarations (confirmed) | `build.zig` | [#71](https://gitlab.com/devnw/zig/strings/-/issues/71) | M | Closed |
| 32 | D4 | Medium | 48 | api-contract | `catch 0` in parallel.zig corrupts edit-distance results silently | `src/parallel.zig:255,257` | [#65](https://gitlab.com/devnw/zig/strings/-/issues/65) | S | Closed |
| 33 | R7 | Medium | 48 | tests | Parallel module tests only exercise sequential fallback paths | `src/parallel.zig` | [#79](https://gitlab.com/devnw/zig/strings/-/issues/79) | M | Closed |
| 34 | A1 | Medium | 45 | maintainability | 6+ independent error type definitions across modules | Multiple | [#39](https://gitlab.com/devnw/zig/strings/-/issues/39) | M | Partial |
| 35 | Q17 | Medium | 45 | perf | Regex `parseNumber` overflow | `src/extended/regex.zig` | -- | S | Closed |
| 36 | Q25 | Medium | 45 | ci-cd | No code coverage tooling | N/A | [#19](https://gitlab.com/devnw/zig/strings/-/issues/19) | M | Won't Do |
| 37 | Q26 | Medium | 45 | tests | No fuzz testing infrastructure | N/A | [#14](https://gitlab.com/devnw/zig/strings/-/issues/14) | M | Won't Do |
| 38 | A2 | Medium | 44 | api-contract | `getCurrencyFormat` ignores locale parameter | `src/extended/locale.zig:411-412` | [#74](https://gitlab.com/devnw/zig/strings/-/issues/74) | S | Closed |
| 39 | A3 | Medium | 44 | api-contract | `formatDate` ignores self (locale) | `src/extended/locale.zig:293-301` | [#31](https://gitlab.com/devnw/zig/strings/-/issues/31) | M | Closed |
| 40 | AC-4 | Medium | 43.2 | api-contract | `parallelEditDistanceBatch`/`parallelFuzzySearch` use `maxInt(usize)` as error sentinel but not documented in API | `src/parallel.zig:259,261,380,381` | -- | S | **Open** |
| 41 | D1 | Medium | 40 | docs | lib.zig header claims "Zero Dependencies" (spice exists) | `src/lib.zig:28` | [#17](https://gitlab.com/devnw/zig/strings/-/issues/17) | S | Closed |
| 42 | D2 | Medium | 40 | docs | `isNormalized` NFC/NFKC false-positive not documented in API.md | `docs/API.md:279` | [#81](https://gitlab.com/devnw/zig/strings/-/issues/81) | S | Closed |
| 43 | M7 | Medium | 40 | ci-cd | Makefile fmt target misses bench/ and examples/ | `Makefile:74` | [#40](https://gitlab.com/devnw/zig/strings/-/issues/40) | S | Closed |
| 44 | Q28 | Medium | 40 | api-contract | `countCodepoints`: simd returns `usize`, utf8 returns `?usize` | `src/util/simd.zig` vs `src/utf8.zig` | [#37](https://gitlab.com/devnw/zig/strings/-/issues/37) | S | Closed |
| 45 | Q49 | Low | 38.4 | readability | 7 files exceed 800-line limit (regex.zig 2059, manipulation.zig 1145, normalization.zig 1003, simd.zig 995, categories.zig 847, phonetic.zig 832, locale.zig 821) | Multiple | -- | M | **Open** |
| 46 | R4 | Medium | 36 | architecture | Regex VM recursive backtracking still uses stack -- overflow risk for deep nesting | `src/extended/regex.zig:1259` | [#25](https://gitlab.com/devnw/zig/strings/-/issues/25) | M | Open (residual) |
| 47 | Q27 | Low | 32.0 | docs | 49 pub fns lack doc comments (confirmed, was ~40) | Multiple | [#43](https://gitlab.com/devnw/zig/strings/-/issues/43) | M | Closed |
| 48 | R5 | Low | 28 | architecture | `parallel.getPool()` never frees unless `deinitPool()` called | `src/parallel.zig:9-15` | [#77](https://gitlab.com/devnw/zig/strings/-/issues/77) | S | Closed |
| 49 | A4 | Low | 24 | api-contract | Inconsistent parameter ordering (allocator first vs last) | Multiple | [#76](https://gitlab.com/devnw/zig/strings/-/issues/76) | M | Open |
| 50 | Q24 | Low | 20 | cleanup | 3 files fail `zig fmt --check` | Multiple | [#36](https://gitlab.com/devnw/zig/strings/-/issues/36) | S | Closed |
| 51 | RM-4 | Low | 19.2 | maintainability | Duplicate import lists for `strings_mod` and `zigstr_mod` in build.zig (65 identical lines) | `build.zig:421-554` | -- | S | **Open** |
| 52 | D5 | Low | 16 | docs | Unicode version inconsistency (15.0 vs 15.1) in docs | `src/lib.zig:17` | [#82](https://gitlab.com/devnw/zig/strings/-/issues/82) | S | Closed |
| 53 | D3 | Low | 16 | docs | No Architecture Decision Records for key design decisions | N/A | [#84](https://gitlab.com/devnw/zig/strings/-/issues/84) | M | Closed |
| 54 | Q23 | Low | 15 | cleanup | Redundant `char_class_negated` opcode | `src/extended/regex.zig:81-82` | -- | S | Closed |
| 55 | RM-1 | Low | 12.8 | maintainability | Duplicate lookup-table builders in manipulation.zig:26 and search.zig:20 | `src/ops/manipulation.zig:26`, `src/ops/search.zig:20` | -- | S | **Open** |
| 56 | Q22 | Low | 12.8 | cleanup | `phoneticMatchAlloc` zero callers (confirmed) | `src/extended/phonetic.zig:604` | [#42](https://gitlab.com/devnw/zig/strings/-/issues/42) | S | Closed |

---

## Findings by Category

### Architecture (Q1, R3, Q4, Q7, Q9, M2, M5, R4, R5)

Structural issues where the implementation does not match the documented or expected behavior. `isNormalized` NFC/NFKC false positives (`R3`) remain the highest-impact open architecture issue. The regex VM (`R4`) still uses stack recursion at `regex.zig:1259` (`self.matchAt(inst.a, current_pos)` inside `matchAt`) despite the step counter mitigation -- a deeply nested pattern can still overflow the call stack before the step budget is exhausted. `parallel.getPool()` (`R5`) lifecycle is now documented (Closed).

### Performance / Safety (R1, Q3, Q6, Q8, Q17, R2)

Functions that fail or produce undefined behavior in release builds. The critical finding is that `std.debug.assert` in SIMD functions (`R1`) vanishes in ReleaseFast, enabling silent OOB writes -- now Closed. The ~71 bare `@intCast` calls in encoding modules (`R2`) had the same ReleaseFast safety concern -- now Closed (targeted fix at chinese.zig:330,375; remaining casts safe by construction).

### API Contract (A5, Q46, Q48, AC-1/Q48r, AC-2, AC-3, AC-4, A1, A2, A3, A4, D4, Q11, Q28, D1)

Inconsistencies in the public API. **New findings from Phase 3 quality review:**

- **AC-1/Q48r (HIGH):** The Wave 2 fix for Q48 replaced the silent soundex fallback with `unreachable`, which is correct for safe builds but becomes undefined behavior in ReleaseFast/ReleaseSmall. Should be replaced with a compile-time check, `@compileError`, or return an explicit error.
- **AC-2 (MEDIUM):** Metaphone function at `phonetic.zig:261` has `w[i+1] == 'N' or w[i+1] == 'N'` -- both arms check the same letter. The second arm likely should be `'M'` based on Metaphone algorithm specification (G before M is silent). This is a copy-paste logic bug.
- **AC-3 (MEDIUM):** `doubleMetaphone` at `phonetic.zig:360-395` is labeled as "simplified implementation" in a code comment but the public `///` doc comment says "Calculate Double Metaphone codes. Returns primary and alternate pronunciations." without indicating it is a stub. Consumers expect Philips (2000) behavior.
- **AC-4 (MEDIUM):** `parallelEditDistanceBatch` and `parallelFuzzySearch` use `std.math.maxInt(usize)` as an error sentinel (at `parallel.zig:259,261,380,381`) but the API documentation does not mention this convention. Callers may misinterpret maxInt as a valid (extremely large) edit distance.

**Previously resolved:** `getAsciiCategory` (`Q46`) misclassification fixed. `phoneticMatch` (`Q48`) soundex fallback replaced with `unreachable` (see AC-1/Q48r for residual). `concat()` overflow checks (`A5`) confirmed. `getCurrencyFormat` and `formatDate` locale issues (`A2`, `A3`) documented. `catch 0` sentinel in parallel.zig (`D4`) replaced with `maxInt(usize)` -- Closed. lib.zig "Zero Dependencies" claim (`D1`) corrected -- Closed.

### Maintainability (M1, M2, M3, M4, M5, Q13, A1, RM-1, RM-4)

Code duplication and organizational issues. **New findings from Phase 3 quality review:**

- **RM-1 (LOW):** `buildAsciiLookup` in `manipulation.zig:26` and `buildCodepointLookup`/`buildByteLookup` in `search.zig:20` are near-duplicate lookup-table builders. `buildAsciiLookup` iterates UTF-8 codepoints; `buildCodepointLookup` iterates a `Codepoint` slice. Both produce the same `struct { table: [256]bool, all_ascii: bool }`. A shared utility in a common module would eliminate the duplication.
- **RM-4 (LOW):** `strings_mod` and `zigstr_mod` in `build.zig:421-554` declare identical 65-line import lists. This was partially addressed in Wave 4 (M4 closure reduced build.zig from 1,398 to 837 lines), but the specific duplication between these two module declarations was not extracted into a shared array.

**Previously resolved:** UnicodeCategory duplication (`M1`) removed. Legacy encoding error duplication (`M3`) consolidated. build.zig (`M4`) refactored with helpers. Error type duplication (`A1`) analyzed -- remaining sets domain-specific (Partial).

### Tests (Q5, Q14, Q26, M6, R7, RE-3)

**New finding from Phase 3 quality review:**

- **RE-3 (MEDIUM):** Five `phoneticMatchAlloc` tests at `phonetic.zig:810-832` only check self-equality (e.g., `phoneticMatchAlloc(alloc, "Schmidt", "Schmidt", .double_metaphone)`). These tests trivially pass because any string equals itself regardless of algorithm correctness. They do not validate that the algorithms correctly identify phonetically similar but lexically different strings (e.g., "Schmidt" vs "Smit", "Macintosh" vs "McIntosh"). The metaphone test at lines 805-807 is the only phonetic test that checks two different strings ("Knight" vs "Night").

**Previously resolved:** Regex test coverage expanded to 39 tests (Q5 closed). lib.zig test block (`M6`) now imports all public modules -- Closed. Parallel module tests (`R7`) now include tests above parallel thresholds -- Closed.

### CI/CD (Q18, Q25, Q47, M7)

CI pipeline runs `test` and `test-integration` but omits `test-comprehensive` and `test-all` (`Q47`). This means 208 tests across 5 comprehensive test files only execute locally. `Q47` was Closed in Wave 2. Makefile fmt target (`M7`) now includes bench/ and examples/ -- Closed.

### Documentation (D1, D2, D3, D5, Q27)

lib.zig "Zero Dependencies" corrected to "Minimal Dependencies" (`D1`, Closed). `isNormalized` NFC/NFKC warning added to API.md (`D2`, Closed). Unicode version aligned to 15.1 (`D5`, Closed). 5 ADRs created (`D3`, Closed). All 49 undocumented pub fns now have `///` doc comments (`Q27`, Closed).

### Cleanup (Q21, Q22, Q23, Q24, Q49)

Dead code, unused functions, formatting drift, and oversized files. **Updated Q49:** 7 files now exceed the 800-line limit (was 6): regex.zig (2059, up from 1932), manipulation.zig (1145, up from 1009), normalization.zig (1003), simd.zig (995), categories.zig (847, up from 814), phonetic.zig (832, new), locale.zig (821) -- **Open** (deferred).

---

## Roadmap

### Quick Wins (< 1 day, effort S)

| ID | Finding | Issue | Action |
|----|---------|-------|--------|
| AC-1/Q48r | `phoneticMatch` unreachable UB in ReleaseFast | -- | Replace `unreachable` with `@compileError` or return `error.UnsupportedAlgorithm` (requires API change) |
| AC-2 | Metaphone duplicate branch condition | -- | Fix `w[i+1] == 'N' or w[i+1] == 'N'` to `w[i+1] == 'N' or w[i+1] == 'M'` (verify against Metaphone spec) |
| AC-3 | `doubleMetaphone` stub undocumented | -- | Add `/// NOTE: Simplified implementation. ...` to doc comment, or implement full Philips (2000) algorithm |
| AC-4 | `maxInt(usize)` sentinel undocumented | -- | Add `///` doc comment on `parallelEditDistanceBatch` and `parallelFuzzySearch` explaining error sentinel convention |
| RE-3 | Phonetic match tests trivially pass | -- | Add cross-string assertions: "Schmidt"/"Smit", "Macintosh"/"McIntosh", "Catherine"/"Katherine", "Thompson"/"Thomson" |
| RM-1 | Duplicate lookup-table builders | -- | Extract shared `buildAsciiLookup` to a common utility module; import from both manipulation.zig and search.zig |
| RM-4 | Duplicate import lists in build.zig | -- | Extract shared `const common_imports = &.{...}` array; reference from both `strings_mod` and `zigstr_mod` |
| Q46 | ~~ASCII category misclassification~~ | -- | ~~Split `'!'...'/'` range~~ **Closed** |
| Q47 | ~~CI omits test-comprehensive~~ | -- | ~~Add `test-comprehensive` job to `.gitlab-ci.yml`~~ **Closed** |
| A5 | ~~concat() overflow~~ | [#62](https://gitlab.com/devnw/zig/strings/-/issues/62) | ~~Add `std.math.add` for length accumulation~~ **Closed** |
| Q48 | ~~phoneticMatch soundex fallback~~ | -- | ~~Return `error.UnsupportedAlgorithm`~~ **Closed** |
| R1 | ~~SIMD assert vanishes in ReleaseFast~~ | [#60](https://gitlab.com/devnw/zig/strings/-/issues/60) | ~~Replace `std.debug.assert` with runtime checks~~ **Closed** |
| D4 | ~~catch 0 in parallel.zig~~ | [#65](https://gitlab.com/devnw/zig/strings/-/issues/65) | ~~Use `maxInt(usize)` sentinel instead of 0~~ **Closed** |
| M6 | ~~lib.zig test block incomplete~~ | [#72](https://gitlab.com/devnw/zig/strings/-/issues/72) | ~~Add `_ = X;` for all ~30 modules~~ **Closed** |
| D2 | ~~isNormalized limitation undocumented~~ | [#81](https://gitlab.com/devnw/zig/strings/-/issues/81) | ~~Add warning to API.md~~ **Closed** |
| D1 | ~~"Zero Dependencies" claim~~ | [#17](https://gitlab.com/devnw/zig/strings/-/issues/17) | ~~Remove or qualify the claim~~ **Closed** |
| M7 | ~~Makefile fmt scope~~ | [#40](https://gitlab.com/devnw/zig/strings/-/issues/40) | ~~Add bench/, examples/ to fmt targets~~ **Closed** |
| R5 | ~~getPool() leak undocumented~~ | [#77](https://gitlab.com/devnw/zig/strings/-/issues/77) | ~~Document deinitPool() requirement~~ **Closed** |
| D5 | ~~Unicode version mismatch~~ | [#82](https://gitlab.com/devnw/zig/strings/-/issues/82) | ~~Align all references to same version~~ **Closed** |
| ~~Q21~~ | ~~Dead SIMD module (zero internal callers)~~ | ~~[#41](https://gitlab.com/devnw/zig/strings/-/issues/41)~~ | ~~Wired into case.zig via P1-7~~ **Closed** |
| ~~Q22~~ | ~~Dead phoneticMatchAlloc (zero callers)~~ | ~~[#42](https://gitlab.com/devnw/zig/strings/-/issues/42)~~ | ~~7 tests added~~ **Closed** |

### Medium (1-5 days, effort M)

| ID | Finding | Issue | Action |
|----|---------|-------|--------|
| M1 | ~~Duplicated UnicodeCategory in regex.zig~~ | [#63](https://gitlab.com/devnw/zig/strings/-/issues/63) | ~~Restructure build.zig deps, import from categories~~ **Closed** |
| ~~R2~~ | ~~71 bare @intCast in encoding~~ | ~~[#67](https://gitlab.com/devnw/zig/strings/-/issues/67)~~ | ~~Add range checks or use std.math.cast~~ **Closed** |
| M3 | ~~Legacy encoding error duplication 4x~~ | [#69](https://gitlab.com/devnw/zig/strings/-/issues/69) | ~~Shared EncodingError + generic interface~~ **Closed** |
| M4 | ~~build.zig 1,370-line monolith~~ | [#71](https://gitlab.com/devnw/zig/strings/-/issues/71) | ~~Extract helper function for module declarations~~ **Closed** |
| Q49 | 7 files exceed 800-line limit | -- | Extract sub-modules from regex.zig (2059), manipulation.zig (1145), normalization.zig (1003), simd.zig (995) |
| R7 | ~~Parallel module test gaps~~ | [#79](https://gitlab.com/devnw/zig/strings/-/issues/79) | ~~Add tests above parallel thresholds~~ **Closed** |
| A2 | ~~getCurrencyFormat ignores locale~~ | [#74](https://gitlab.com/devnw/zig/strings/-/issues/74) | ~~Document limitation~~ **Closed** |
| A1 | ~~Inconsistent error types~~ | [#39](https://gitlab.com/devnw/zig/strings/-/issues/39) | ~~Merge shared variants~~ **Partial** (remaining sets are domain-specific; M3 addressed actual duplication) |
| Q5 | ~~Regex test coverage~~ | [#38](https://gitlab.com/devnw/zig/strings/-/issues/38) | ~~Expand to 30+ targeted tests~~ **Closed** (39 tests) |
| A4 | Inconsistent parameter ordering | [#76](https://gitlab.com/devnw/zig/strings/-/issues/76) | Audit and align API conventions |
| D3 | ~~No ADRs~~ | [#84](https://gitlab.com/devnw/zig/strings/-/issues/84) | ~~Create ADRs for top 5 design decisions~~ **Closed** |
| Q27 | ~~49 pub fns missing doc comments~~ | [#43](https://gitlab.com/devnw/zig/strings/-/issues/43) | ~~Add `///` to all pub fns~~ **Closed** |
| R4 | Regex VM stack recursion (residual) | [#25](https://gitlab.com/devnw/zig/strings/-/issues/25) | Convert to iterative worklist |

### Strategic (> 5 days, effort L)

| ID | Finding | Issue | Action |
|----|---------|-------|--------|
| R3 | isNormalized NFC/NFKC false positives | [#22](https://gitlab.com/devnw/zig/strings/-/issues/22) | Implement UAX #15 Quick_Check tables from UCD |
| Q5 | Regex: comprehensive test suite (39 tests, target 50+) | [#38](https://gitlab.com/devnw/zig/strings/-/issues/38) | Add remaining opcode coverage tests |

---

## PriorityScore Methodology

The scoring formula was updated in Phase 4 to include a DetectionDifficulty axis:

```
PriorityScore = Impact (1-5) x Frequency (1-5) x DetectionDifficulty (1-5) x 1.6
```

Maximum possible score: 5 x 5 x 5 x 1.6 = 200. Practical range: 1.6 -- 200.

**Impact scale:**
- 5 = outages / major performance cost / data integrity risk
- 4 = frequent bugs / major developer drag / security-adjacent
- 3 = moderate impact on maintainability or performance
- 2 = minor impact
- 1 = polish

**Frequency scale (formerly "Likelihood"):**
- 5 = ubiquitous / touched in nearly every workflow
- 4 = often encountered in normal usage
- 3 = sometimes encountered
- 2 = rare
- 1 = edge-case only

**DetectionDifficulty scale (new in Phase 4):**
- 5 = no test or tooling catches this; requires manual audit
- 4 = unlikely to surface in normal testing; needs targeted review
- 3 = moderate -- may be caught by thorough integration testing
- 2 = likely caught by unit tests or linter
- 1 = immediately obvious (compile error, IDE warning)

**Note on legacy scores:** Findings Q1-Q45 retain their original `Impact x Likelihood x 4` scores from Phases 1-3. Items Q21, Q22, Q27, M3, and M4 have been re-scored using the Phase 4 formula as part of the re-audit. New findings Q46-Q49 use the Phase 4 formula exclusively.

### Confidence

- **confidence::confirmed** -- AC-1/Q48r: verified by reading `phonetic.zig:596-604`. The `unreachable` at line 603 is inside a `switch` on `algo: Algorithm`. In ReleaseFast and ReleaseSmall builds, `unreachable` compiles to UB. Doc comment at lines 593-595 warns but does not prevent misuse.
- **confidence::confirmed** -- AC-2: verified by reading `phonetic.zig:261`. The condition is `w[i+1] == 'N' or w[i+1] == 'N'` -- both arms test for `'N'`. This is a copy-paste typo. The Metaphone algorithm specification calls for checking GN and GM combinations.
- **confidence::confirmed** -- AC-3: verified by reading `phonetic.zig:360-395`. The function comment says "Simplified implementation" but the public doc comment at line 358-359 says "Calculate Double Metaphone codes. Returns primary and alternate pronunciations." The implementation returns `metaphone()` as primary and a trivial X-to-S substitution as alternate -- this is not Double Metaphone per Philips (2000).
- **confidence::confirmed** -- AC-4: verified by reading `parallel.zig:259,261,380,381`. Four instances of `catch std.math.maxInt(usize)` in the sequential fallback paths of `parallelEditDistanceBatch` and `parallelFuzzySearch`. No doc comment mentions the sentinel convention.
- **confidence::confirmed** -- RE-3: verified by reading `phonetic.zig:810-832`. Five tests check only `phoneticMatchAlloc(alloc, "X", "X", algo)` for double_metaphone, nysiis, match_rating, caverphone. Only the metaphone test (lines 805-807) checks two different strings ("Knight" vs "Night").
- **confidence::confirmed** -- RM-1: verified by reading `manipulation.zig:26-37` (`buildAsciiLookup`) and `search.zig:20-31` (`buildCodepointLookup`). Both produce `struct { table: [256]bool, all_ascii: bool }` with nearly identical logic. The difference is input type (`[]const u8` with UTF-8 iteration vs `[]const Codepoint` with direct iteration).
- **confidence::confirmed** -- RM-4: verified by reading `build.zig:421-554`. The `zigstr_mod` (lines 421-486) and `strings_mod` (lines 489-554) import lists are identical 65-line blocks with the same module references in the same order.
- **confidence::confirmed** -- Q46: verified by reading `getAsciiCategory` at `categories.zig:580-605`. The range `'!'...'/'` (0x21-0x2F) maps all 15 characters to `Po`, but Unicode assigns `$`(0x24)=Sc, `(`(0x28)=Ps, `)`(0x29)=Pe, `+`(0x2B)=Sm, `-`(0x2D)=Pd.
- **confidence::confirmed** -- Q47: verified by reading `.gitlab-ci.yml`. Jobs present: `build`, `test`, `test-integration`, `test-release-safe`, `test-release-fast`, `test-integration-release-safe`, `test-integration-release-fast`, `test-release-small`, `fuzz`, `bench-regression`. No `test-comprehensive` or `test-all` job.
- **confidence::confirmed** -- Q48: verified by reading `phonetic.zig:586-601`. The `else` branch in `phoneticMatch` duplicates the soundex branch verbatim with a comment "Fallback to soundex for simple comparison".
- **confidence::confirmed** -- Q49: verified via `wc -l`: regex.zig=2059, manipulation.zig=1145, normalization.zig=1003, simd.zig=995, categories.zig=847, phonetic.zig=832, locale.zig=821. (7 files, up from 6; phonetic.zig and categories.zig grew past 800 lines.)
- **confidence::confirmed** -- Q21 (re-scored): `src/lib.zig:161` is the only import of simd (`pub const simd = @import("simd")`); no other source file references simd functions. Zero internal callers.
- **confidence::confirmed** -- Q22 (re-scored): `phoneticMatchAlloc` appears only at its definition site (`phonetic.zig:604`). Zero callers.
- **confidence::confirmed** -- Q27 (re-scored): 49 pub fns confirmed lacking doc comments (up from ~40 in Phase 3).
- **confidence::confirmed** -- M3 (re-scored): 4x error type duplication confirmed across legacy encoding files.
- **confidence::confirmed** -- M4 (re-scored): build.zig confirmed at 1,370 lines (was 1,352 in Phase 3 due to additions).
- **confidence::confirmed** -- All other findings verified by reading source code at commit b66264f.

---

## Scoring Breakdown

### Phase 3 quality review findings (Impact x Frequency x DetectionDifficulty x 1.6)

| ID | Impact | Frequency | DetectDiff | Calculation | PriorityScore |
|----|--------|-----------|------------|-------------|---------------|
| AC-1/Q48r | 4 (UB in release builds) | 3 (non-soundex algo to non-alloc fn) | 4 (silent UB, no test catches in release) | 4 x 3 x 4 x 1.6 | 76.8 |
| RE-3 | 3 (false test confidence) | 4 (5 test functions, every CI run) | 4 (tests pass green; weakness requires review) | 3 x 4 x 4 x 1.6 | 76.8 |
| AC-2 | 3 (wrong phonetic code for G+N) | 3 (metaphone users with G-words) | 4 (typo; no test targets this branch) | 3 x 3 x 4 x 1.6 | 57.6 |
| AC-3 | 3 (stub masquerading as real impl) | 3 (double metaphone users) | 4 (no test validates against reference) | 3 x 3 x 4 x 1.6 | 57.6 |
| AC-4 | 3 (misinterpreted error sentinel) | 3 (parallel edit distance/fuzzy users) | 3 (code review can spot; doc would clarify) | 3 x 3 x 3 x 1.6 | 43.2 |
| RM-4 | 2 (maintenance burden) | 3 (any new module addition) | 2 (visible in code review) | 2 x 3 x 2 x 1.6 | 19.2 |
| RM-1 | 2 (code duplication) | 2 (two files, rarely co-modified) | 2 (code review catches easily) | 2 x 2 x 2 x 1.6 | 12.8 |

### Phase 4 findings (Impact x Frequency x DetectionDifficulty x 1.6)

| ID | Impact | Frequency | DetectDiff | Calculation | PriorityScore |
|----|--------|-----------|------------|-------------|---------------|
| Q46 | 4 (wrong Unicode categories for common ASCII) | 5 (any ASCII punctuation classification) | 3 (integration tests may catch) | 4 x 5 x 3 x 1.6 | 96.0 |
| Q47 | 4 (208 tests never run in CI) | 4 (every CI pipeline) | 3 (requires CI config audit) | 4 x 4 x 3 x 1.6 | 76.8 |
| Q48 | 3 (silently wrong algorithm) | 3 (non-soundex phonetic users) | 4 (no error; silent fallback) | 3 x 3 x 4 x 1.6 | 57.6 |
| Q49 | 2 (readability / maintainability drag) | 4 (7 files over limit) | 3 (tooling can detect) | 2 x 4 x 3 x 1.6 | 38.4 |

### Re-scored existing findings (Phase 4 formula)

| ID | Impact | Frequency | DetectDiff | Calculation | PriorityScore | Was |
|----|--------|-----------|------------|-------------|---------------|-----|
| Q21 | 3 (dead module pollutes API + binary) | 3 (every build includes it) | 4 (requires caller analysis) | 3 x 3 x 4 x 1.6 | 57.6 | 25 |
| M3 | 3 (maintenance burden) | 4 (4 encoding files) | 2 (visible in code review) | 3 x 4 x 2 x 1.6 | 48.0 (confirmed, was 56) | 56 |
| M4 | 3 (maintenance burden) | 4 (any module addition) | 2 (visible in code review) | 3 x 4 x 2 x 1.6 | 48.0 (confirmed, was 52) | 52 |
| Q27 | 2 (missing API docs) | 5 (every consumer) | 2 (linter can detect) | 2 x 5 x 2 x 1.6 | 32.0 | 25 |
| Q22 | 1 (dead code) | 2 (single fn) | 4 (requires caller analysis) | 1 x 2 x 4 x 1.6 | 12.8 | 20 |

### Legacy findings (Impact x Likelihood x 4, Phases 1-3)

| ID | Impact | Likelihood | Calculation | PriorityScore |
|----|--------|------------|-------------|---------------|
| R1 | 5 (silent UB / OOB writes) | 5 (any ReleaseFast user) | 5 x 5 x 4 | 100 -> 96 (caller must pass bad dest, but no runtime check prevents it) |
| Q1 | 5 (wrong match results) | 5 (skipped opcodes) | 5 x 5 x 4 | 95 |
| Q6 | 5 (runtime panic) | 5 (common string sizes) | 5 x 5 x 4 | 95 |
| R3 | 5 (silently wrong) | 5 (every NFC/NFKC call) | 5 x 5 x 4 | 100 -> 90 (normalization check is opt-in) |
| Q18 | 5 (no CI = regressions ship) | 5 (every commit) | 5 x 5 x 4 | 100 |
| Q3 | 4 (stack overflow risk) | 5 (nested quantifiers) | 4 x 5 x 4 | 85 |
| A5 | 5 (memory corruption) | 4 (requires many large slices) | 5 x 4 x 4 | 80 -> 84 (adjusted: inconsistency with sibling fns increases likelihood of oversight) |
| Q4 | 4 (no complexity guard) | 5 (complex patterns) | 4 x 5 x 4 | 80 |
| Q5 | 4 (untested code) | 5 (regex is core) | 4 x 5 x 4 | 80 |
| M1 | 4 (incorrect classification) | 5 (any Unicode property match) | 4 x 5 x 4 | 80 |
| Q7 | 4 (feature broken) | 5 (capture group use) | 4 x 4 x 4 | 75 |
| Q8 | 4 (silently wrong) | 5 (common lengths) | 4 x 5 x 4 | 75 |
| Q9 | 4 (wrong algorithm) | 4 (>32 char strings) | 4 x 4 x 4 | 70 |
| M2 | 3 (incorrect categories) | 5 (non-BMP codepoints) | 3 x 5 x 4 | 70 |
| Q11 | 3 (confusing API) | 5 (every user) | 3 x 5 x 4 | 65 |
| M5 | 3 (incomplete NFKD) | 5 (any NFKD use) | 3 x 5 x 4 | 65 |
| R2 | 3 (silent truncation) | 5 (all encoding users) | 3 x 5 x 4 | 60 |
| Q13 | 3 (maintenance) | 4 (two entry points) | 3 x 4 x 4 | 55 |
| Q14 | 3 (untested code) | 4 (categories used widely) | 3 x 4 x 4 | 55 |
| M6 | 3 (missed test coverage) | 4 (lib.zig test runner) | 3 x 4 x 4 | 48 -> 52 (adjusted: systemic gap) |
| Q15 | 2 (readability) | 5 (every reader) | 2 x 5 x 4 | 50 |
| D4 | 3 (corrupted results) | 4 (parallel edit distance) | 3 x 4 x 4 | 48 |
| R7 | 3 (untested parallel paths) | 4 (parallel module) | 3 x 4 x 4 | 48 |
| A1 | 2 (maintenance) | 5 (every error handler) | 2 x 5 x 4 | 45 |
| Q17 | 3 (overflow) | 3 (unusual patterns) | 3 x 3 x 4 | 45 |
| Q25 | 3 (no coverage) | 4 (every CI run) | 3 x 4 x 4 | 45 |
| Q26 | 3 (no fuzzing) | 4 (parsing modules) | 3 x 4 x 4 | 45 |
| A2 | 2 (misleading API) | 5 (locale users) | 2 x 5 x 4 | 40 -> 44 (adjusted: financial formatting) |
| A3 | 2 (misleading API) | 5 (locale users) | 2 x 5 x 4 | 40 -> 44 (adjusted: date formatting) |
| D1 | 2 (misleading docs) | 5 (every reader) | 2 x 5 x 4 | 40 |
| D2 | 3 (undocumented limitation) | 3 (NFC/NFKC users) | 3 x 3 x 4 | 36 -> 40 (adjusted: false positives are dangerous) |
| M7 | 2 (partial formatting) | 4 (every commit) | 2 x 4 x 4 | 32 -> 40 (adjusted: compounds with Q19) |
| Q28 | 2 (API inconsistency) | 4 (module consumers) | 2 x 4 x 4 | 40 |
| R4 | 3 (stack overflow residual) | 3 (deep nesting) | 3 x 3 x 4 | 36 |
| R5 | 2 (resource leak) | 3 (parallel users) | 2 x 3 x 4 | 24 -> 28 (adjusted: global state) |
| A4 | 2 (API ergonomics) | 3 (some functions) | 2 x 3 x 4 | 24 |
| Q24 | 1 (formatting) | 3 (3 files) | 1 x 3 x 4 | 20 |
| D5 | 1 (doc inconsistency) | 4 (version-sensitive users) | 1 x 4 x 4 | 16 |
| D3 | 1 (missing process) | 4 (new contributors) | 1 x 4 x 4 | 16 |
| Q23 | 1 (minor redundancy) | 2 (regex internals) | 1 x 2 x 4 | 15 |
