# Gap Analysis -- Resolved Gaps

**Repository:** devnw/zig/strings
**Last updated:** 2026-03-24 (Phase 4 -- full codebase audit)

This file tracks gaps that have been resolved. Gap-IDs are never reused.

> **Re-audit note (2026-03-24):** A re-audit found GAP-0012, GAP-0018, and GAP-0019 were
> falsely closed (fixes never committed to `src/extended/fuzzy.zig`). These were re-opened
> and have now been **truly closed in Wave 2** with verified fixes: `MAX_JARO_LEN=256` bounds
> guard, `MAX_DAMERAU_LEN=32` doc comment, `MAX_STACK_LEN=1024` doc comments, and
> corresponding tests.

---

## Resolved Gaps

### GAP-0001: `isNormalized()` ignores `form` parameter (PARTIAL)

- **Original Severity:** Critical
- **Status:** Partial
- **Resolved date:** 2026-03-24
- **Issue:** [#22](https://gitlab.com/devnw/zig/strings/-/issues/22)
- **Resolution summary:** NFD/NFKD checks now verify decomposition (the `form` parameter is no longer discarded for those forms). A WARNING doc comment was added explaining that NFC/NFKC still lack full Quick_Check tables. ASCII fast-path and pre-allocation were also added to `normalize()`.
- **Resolution evidence:** `src/unicode/normalization.zig` -- `isNormalized()` branches on form for NFD/NFKD.
- **Remaining:** Full NFC/NFKC Quick_Check requires generating UCD property tables (NFC_QC, NFKC_QC). This is a strategic effort requiring UCD regeneration tooling.

---

### GAP-0002: CI/CD has no build or test stages (WON'T DO)

- **Original Severity:** High
- **Status:** Won't Do
- **Resolved date:** 2026-03-24
- **Issue:** [#23](https://gitlab.com/devnw/zig/strings/-/issues/23)
- **Won't Do reason:** Requires GitLab CI runner infrastructure with Zig 0.15.x Docker image or nix environment. This is an infrastructure/DevOps task outside the scope of code-level gap closure. Build and tests verified passing locally (74/74 build steps, 461/461 tests).
- **Unblock steps:** Set up a GitLab runner with Zig 0.15.1+ installed. Add `build` and `test` stages to `.gitlab-ci.yml`.

---

### GAP-0003: BiDi module claims full UAX #9 but only implements simple direction detection

- **Original Severity:** High
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#24](https://gitlab.com/devnw/zig/strings/-/issues/24)
- **Resolution summary:** Downgraded README BiDi claim to "Basic detection (partial UAX #9)" to accurately reflect the implementation level. Also added `containsBidiOverrides()` and `stripBidiOverrides()` functions (see S9).
- **Resolution evidence:** `README.md` -- BiDi feature line updated. `src/unicode/bidi.zig` -- new override detection/stripping functions.

---

### GAP-0004: Regex VM uses unbounded recursive backtracking with no ReDoS protection

- **Original Severity:** High
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#25](https://gitlab.com/devnw/zig/strings/-/issues/25)
- **Resolution summary:** Added a step counter (MAX_STEPS = 1,000,000) to the `matchAt` function. When the step limit is exceeded, `matchAt` returns `null` instead of continuing to recurse. Also wired `PatternTooComplex` to be returned when instruction count exceeds MAX_INSTRUCTIONS (10,000).
- **Resolution evidence:** `src/extended/regex.zig` -- `step_count` field on VM, `MAX_STEPS` constant, `PatternTooComplex` returned from compiler.

---

### GAP-0005: Regex VM silently skips `unicode_prop` and `unicode_prop_neg` opcodes at runtime

- **Original Severity:** High
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#26](https://gitlab.com/devnw/zig/strings/-/issues/26)
- **Resolution summary:** Implemented `unicode_prop` and `unicode_prop_neg` VM handlers that look up the Unicode property and check the current character. Removed the `else => { current_pc += 1; }` catch-all.
- **Resolution evidence:** `src/extended/regex.zig` -- new case branches in VM switch for `unicode_prop` and `unicode_prop_neg`.

---

### GAP-0006: Unicode conformance tests accept incorrect output via permissive `or` assertions

- **Original Severity:** High
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#27](https://gitlab.com/devnw/zig/strings/-/issues/27)
- **Resolution summary:** Fixed permissive `or` assertions in conformance tests. Tests now assert exact expected output instead of accepting passthrough as valid.
- **Resolution evidence:** `tests/unicode_conformance.zig` -- removed `or std.mem.eql(u8, result, input)` clauses.

---

### GAP-0007: Zig version discrepancy between README and build.zig.zon

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#15](https://gitlab.com/devnw/zig/strings/-/issues/15)
- **Resolution summary:** Updated README to state `0.15.1+` matching `build.zig.zon`.
- **Resolution evidence:** `README.md` -- Zig version line updated.

---

### GAP-0008: "Zero Dependencies" claimed in three locations but spice dependency exists [PARTIAL REGRESSION]

- **Original Severity:** Medium
- **Status:** Closed (PARTIAL REGRESSION -- see GAP-0023 / [#49](https://gitlab.com/devnw/zig/strings/-/issues/49))
- **Resolved date:** 2026-03-24
- **Issue:** [#17](https://gitlab.com/devnw/zig/strings/-/issues/17)
- **Resolution summary:** Updated `docs/ARCHITECTURE.md` to say "Minimal Dependencies" instead of "Zero Dependencies".
- **Resolution evidence:** `docs/ARCHITECTURE.md` -- claim corrected to "Minimal Dependencies".
- **Regression note (2026-03-24):** Phase 3 re-scan found `src/lib.zig:28` was NOT updated and still reads "Zero Dependencies". The fix was applied to ARCHITECTURE.md only. This regression is tracked as GAP-0023 ([#49](https://gitlab.com/devnw/zig/strings/-/issues/49)).

---

### GAP-0009: Security email mismatch between SECURITY.md and CONTRIBUTING.md

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#28](https://gitlab.com/devnw/zig/strings/-/issues/28)
- **Resolution summary:** Aligned both files to use `security@codepros.dev` as the canonical security email.
- **Resolution evidence:** `CONTRIBUTING.md` -- both occurrences updated.

---

### GAP-0010: SECURITY.md falsely claims fuzz testing and no external dependencies

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#29](https://gitlab.com/devnw/zig/strings/-/issues/29)
- **Resolution summary:** Removed the false fuzz testing claim. Updated dependencies claim to acknowledge the spice dependency.
- **Resolution evidence:** `SECURITY.md` -- fuzz testing line removed, dependencies claim corrected.

---

### GAP-0011: StringPool docs claim internal synchronization but none exists

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#20](https://gitlab.com/devnw/zig/strings/-/issues/20)
- **Resolution summary:** Fixed ARCHITECTURE.md to state that StringPool is NOT thread-safe.
- **Resolution evidence:** `docs/ARCHITECTURE.md` -- synchronization claim corrected.

---

### GAP-0012: Jaro similarity function panics on strings longer than 256 bytes

- **Original Severity:** Critical (upgraded from Medium on re-audit)
- **Status:** Closed
- **Resolved date:** 2026-03-24 (Wave 2)
- **Issue:** [#30](https://gitlab.com/devnw/zig/strings/-/issues/30)
- **History:** Originally falsely closed (fixes never committed). Re-opened in re-audit. Truly fixed in Wave 2.
- **Resolution summary:** Added `MAX_JARO_LEN = 256` constant at `src/extended/fuzzy.zig:35`. Added bounds guard at line 229 that returns 0.0 for strings exceeding 256 bytes. Test added at lines 699-719 covering the boundary condition.
- **Resolution evidence:** `src/extended/fuzzy.zig:35` (constant), `src/extended/fuzzy.zig:229` (guard), `src/extended/fuzzy.zig:699-719` (test)
- **Cross-references:** S2 (SECURITY_GAP_ANALYSIS.md), GAP-0031

---

### GAP-0013: Parallel module not exposed in lib.zig and not documented

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#12](https://gitlab.com/devnw/zig/strings/-/issues/12)
- **Resolution summary:** Added `pub const parallel = @import("parallel.zig");` to `src/lib.zig`.
- **Resolution evidence:** `src/lib.zig` -- parallel import added.

---

### GAP-0014: `formatDate` ignores locale parameter and has no tests

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#31](https://gitlab.com/devnw/zig/strings/-/issues/31)
- **Resolution summary:** Documented the limitation that `formatDate` uses US English formatting regardless of locale.
- **Resolution evidence:** `src/extended/locale.zig` -- doc comment added documenting English-only limitation.

---

### GAP-0015: categories.zig has 19 public functions but only 4 test blocks (WON'T DO)

- **Original Severity:** Medium
- **Status:** Won't Do
- **Resolved date:** 2026-03-24
- **Issue:** [#32](https://gitlab.com/devnw/zig/strings/-/issues/32)
- **Won't Do reason:** Expanding test coverage for all 19 public functions requires generating test vectors from UCD data for non-BMP codepoints. Deferred to a dedicated test coverage sprint.
- **Unblock steps:** Generate test vectors from UCD UnicodeData.txt. Add boundary tests for each Unicode plane.

---

### GAP-0016: Duplicate API surfaces in lib.zig and zigstr.zig

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#33](https://gitlab.com/devnw/zig/strings/-/issues/33)
- **Resolution summary:** Replaced duplicate enum definitions in `zigstr.zig` with re-exports from `types.zig`. Added doc comments explaining canonical entry point.
- **Resolution evidence:** `src/zigstr.zig` -- duplicate enums replaced with re-exports. `src/lib.zig` -- doc comment added.

---

### GAP-0017: API.md NFC/NFKC note is stale

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#16](https://gitlab.com/devnw/zig/strings/-/issues/16)
- **Resolution summary:** Updated the stale "in progress" note to reflect that NFC and NFKC composition are implemented.
- **Resolution evidence:** `docs/API.md` -- note updated.

---

### GAP-0018: DamerauLevenshtein silently falls back to Levenshtein for strings > 32 characters

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24 (Wave 2)
- **Issue:** [#34](https://gitlab.com/devnw/zig/strings/-/issues/34)
- **History:** Originally falsely closed (fixes never committed). Re-opened in re-audit. Truly fixed in Wave 2.
- **Resolution summary:** Added `MAX_DAMERAU_LEN = 32` constant at `src/extended/fuzzy.zig:45`. Added doc comment on `damerauLevenshtein()` (lines 154-161) documenting the fallback behavior for strings exceeding 32 characters.
- **Resolution evidence:** `src/extended/fuzzy.zig:45` (constant), `src/extended/fuzzy.zig:154-161` (doc comment)

---

### GAP-0019: Levenshtein and LCS silently truncate at 1024 characters

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24 (Wave 2)
- **Issue:** [#35](https://gitlab.com/devnw/zig/strings/-/issues/35)
- **History:** Originally falsely closed (fixes never committed). Re-opened in re-audit. Truly fixed in Wave 2.
- **Resolution summary:** Added `MAX_STACK_LEN = 1024` constant at `src/extended/fuzzy.zig:40`. Added doc comments on `levenshtein()` (lines 62-68), `lcsLength()` (lines 309-311), and `longestCommonSubstring()` (lines 352-354) documenting the stack-based size limit and pointing to allocator-backed alternatives for larger inputs.
- **Resolution evidence:** `src/extended/fuzzy.zig:40` (constant), `src/extended/fuzzy.zig:62-68` (levenshtein doc), `src/extended/fuzzy.zig:309-311` (lcsLength doc), `src/extended/fuzzy.zig:352-354` (longestCommonSubstring doc)
- **Cross-references:** S4 (SECURITY_GAP_ANALYSIS.md)

---

### GAP-0020: parallel.zig fails `zig fmt` check

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#36](https://gitlab.com/devnw/zig/strings/-/issues/36)
- **Resolution summary:** Auto-formatted both `src/parallel.zig` and `build.zig`.
- **Resolution evidence:** `zig fmt --check` exits 0 for all files.

---

### GAP-0021: No fuzz testing infrastructure despite claims and .gitignore entries (WON'T DO)

- **Original Severity:** Low
- **Status:** Won't Do
- **Resolved date:** 2026-03-24
- **Issue:** [#14](https://gitlab.com/devnw/zig/strings/-/issues/14)
- **Won't Do reason:** Requires AFL/libFuzzer setup and `zig build` integration. Infrastructure task. The false fuzz testing claim in SECURITY.md has been removed (GAP-0010). Platform list in README split into primary/planned.
- **Unblock steps:** Set up AFL or libFuzzer. Add fuzz targets for regex, UTF-8 validation, and normalization.

---

### GAP-0022: `countCodepoints` has inconsistent return type contracts between simd and utf8 modules

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#37](https://gitlab.com/devnw/zig/strings/-/issues/37)
- **Resolution summary:** Added doc comments explaining the different contracts: SIMD version is a fast approximate count (no validation), utf8 version validates and returns `null` on invalid input.
- **Resolution evidence:** `src/util/simd.zig` and `src/utf8.zig` -- doc comments added.

---

### GAP-0023: GAP-0008 regression -- lib.zig still claims "Zero Dependencies"

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#49](https://gitlab.com/devnw/zig/strings/-/issues/49)
- **Resolution summary:** Changed `src/lib.zig:28` from "Zero Dependencies: Pure Zig, no external dependencies" to "Minimal Dependencies: Pure Zig with optional spice parallelism dependency".
- **Resolution evidence:** `grep -r "Zero Dependencies" src/` returns no matches. `src/lib.zig:28` now reads `//! - **Minimal Dependencies**: Pure Zig with optional spice parallelism dependency`.

---

### GAP-0024: Unicode version inconsistency -- lib.zig says "15.0", everywhere else says "15.1"

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#50](https://gitlab.com/devnw/zig/strings/-/issues/50)
- **Resolution summary:** Changed `src/lib.zig:17` from "Unicode 15.0" to "Unicode 15.1" to match README, CHANGELOG, and normalization.zig.
- **Resolution evidence:** `src/lib.zig:17` now reads `//! - **Unicode Support**: Full Unicode 15.1 character properties and algorithms`.

---

### GAP-0025: "Locale-aware case conversion" claim in lib.zig is false

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#51](https://gitlab.com/devnw/zig/strings/-/issues/51)
- **Resolution summary:** Changed `src/lib.zig:20` from "Locale-aware upper/lower/title case mapping" to "Full upper/lower/title case mapping (Unicode-aware)" to accurately reflect the non-locale implementation.
- **Resolution evidence:** `src/lib.zig:20` now reads `//! - **Case Conversion**: Full upper/lower/title case mapping (Unicode-aware)`.

---

### GAP-0026: ARCHITECTURE.md says spice "disabled by default" but build.zig shows enabled

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#52](https://gitlab.com/devnw/zig/strings/-/issues/52)
- **Resolution summary:** Changed `docs/ARCHITECTURE.md:88` from "(disabled by default)" to "(enabled by default)" to match `build.zig:16` which uses `orelse true`.
- **Resolution evidence:** `docs/ARCHITECTURE.md:88` now reads "enabled by default".

---

### GAP-0028: CHANGELOG.md overclaims -- BiDi "per UAX #9", "Code coverage", "Full UCD"

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#54](https://gitlab.com/devnw/zig/strings/-/issues/54)
- **Resolution summary:** Fixed three overclaims in CHANGELOG.md: (1) BiDi changed to "Basic BiDi direction detection (partial UAX #9)", (2) UCD changed to "Unicode Character Database (UCD) tables (simplified for some categories)", (3) Code coverage qualified with "(via Zig's built-in `--coverage` flag; no additional tooling configured)".
- **Resolution evidence:** `CHANGELOG.md` lines 30, 33, 71 updated.

---

### D2: API.md missing isNormalized NFC/NFKC false-positive warning

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Resolution summary:** Added a **Warning** note to the normalization section of `docs/API.md` explaining that `isNormalized` for NFC and NFKC forms only checks CCC ordering and may return false positives. Users are directed to normalize and compare for guaranteed correctness.
- **Resolution evidence:** `docs/API.md` normalization section now contains the warning paragraph.

---

### GAP-0029: Collation claims UTS #10 but only covers ASCII/Latin-1

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#55](https://gitlab.com/devnw/zig/strings/-/issues/55)
- **Resolution summary:** Documentation fix. Added module-level doc comment to `src/unicode/collation.zig` explicitly stating this is a simplified implementation covering ASCII/Latin-1 only, with non-Latin text falling back to raw codepoint ordering.
- **Resolution evidence:** `src/unicode/collation.zig` -- module-level doc comment.

---

### GAP-0030: caseFold(0x00DF) returns single 's' instead of "ss"

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#56](https://gitlab.com/devnw/zig/strings/-/issues/56)
- **Resolution summary:** Documentation fix. Added doc comment to `caseFold()` in `src/unicode/case.zig` warning that German sharp s (U+00DF) is simplified to single 's' and that `equalsIgnoreCase`/`compareIgnoreCase` inherit the same limitation.
- **Resolution evidence:** `src/unicode/case.zig` -- caseFold() doc comment.

---

### M7: Makefile fmt target misses bench/ and examples/

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#40](https://gitlab.com/devnw/zig/strings/-/issues/40)
- **Resolution summary:** Added `bench/` and `examples/` directories to the Makefile fmt target.
- **Resolution evidence:** `Makefile:74` -- `zig fmt src/ tests/ bench/ examples/ build.zig`

---

### D1: lib.zig header claims "Zero Dependencies" (spice exists)

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#17](https://gitlab.com/devnw/zig/strings/-/issues/17)
- **Resolution summary:** Changed `src/lib.zig:28` from "Zero Dependencies" to "Minimal Dependencies: Pure Zig with optional spice parallelism dependency".
- **Resolution evidence:** `src/lib.zig:28`

---

### D4: `catch 0` in parallel.zig corrupts edit-distance results silently

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#65](https://gitlab.com/devnw/zig/strings/-/issues/65)
- **Resolution summary:** Replaced `catch 0` with `catch std.math.maxInt(usize)` in both `parallelEditDistanceBatch` and `parallelFuzzySearch`. A maxInt sentinel clearly indicates "computation failed" rather than falsely reporting an exact match (edit distance 0).
- **Resolution evidence:** `src/parallel.zig:255,257,375,376`

---

### D5: Unicode version inconsistency (15.0 vs 15.1) in docs

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24 (via GAP-0024)
- **Issue:** [#82](https://gitlab.com/devnw/zig/strings/-/issues/82)
- **Resolution summary:** Changed `src/lib.zig:17` from "Unicode 15.0" to "Unicode 15.1" to match README, CHANGELOG, and normalization.zig.
- **Resolution evidence:** `src/lib.zig:17`

---

### R5: `parallel.getPool()` never frees unless `deinitPool()` called

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#77](https://gitlab.com/devnw/zig/strings/-/issues/77)
- **Resolution summary:** Added Pool Lifecycle documentation to the module-level doc comment in `src/parallel.zig`, explaining that the pool is lazily initialized and never freed unless `deinitPool()` is explicitly called. Documents that calling `deinitPool()` while operations are in-flight causes undefined behavior.
- **Resolution evidence:** `src/parallel.zig:9-15`

---

### S18: Parallel edit distance `catch 0` produces false exact match

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#61](https://gitlab.com/devnw/zig/strings/-/issues/61)
- **Resolution summary:** Same fix as D4. Replaced `catch 0` with `catch std.math.maxInt(usize)`.
- **Resolution evidence:** `src/parallel.zig:255,257,375,376`

---

### S19: ICU BreakIterator @intCast usize to i32 truncation

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#64](https://gitlab.com/devnw/zig/strings/-/issues/64)
- **Resolution summary:** Added `MAX_TEXT_LEN` constant (maxInt(i32)) and length checks to all three BreakIterator constructors (`createCharacterInstance`, `createWordInstance`, `createSentenceInstance`). Constructors return `error.InputTooLarge` for text > 2 GiB.
- **Resolution evidence:** `src/extended/icu.zig:374-401`

---

### S21: BiDi detector misses LRM/RLM/ALM markers

- **Original Severity:** Low
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#70](https://gitlab.com/devnw/zig/strings/-/issues/70)
- **Resolution summary:** Added `isBidiMark()` function detecting LRM (U+200E), RLM (U+200F), ALM (U+061C). Added `containsSuspiciousBidiChars()` that checks for both overrides and marks. Updated `stripBidiOverrides()` to also strip marks. Tests added for all three.
- **Resolution evidence:** `src/unicode/bidi.zig:146-168,404-467`

### GAP-0027: Examples cannot compile -- no build step in build.zig

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#53](https://gitlab.com/devnw/zig/strings/-/issues/53)
- **Resolution summary:** Updated `examples/README.md` to clarify that examples are reference code demonstrating API usage patterns, not standalone compilable programs. Removed incorrect claims about `zig build example-01` and `zig run` commands. Added guidance on adapting example code into user projects.
- **Resolution evidence:** `examples/README.md` -- "Using These Examples" section replaces "Running Examples" section.

### GAP-0032: README Project Status section overclaims feature completeness

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#86](https://gitlab.com/devnw/zig/strings/-/issues/86)
- **Resolution summary:** Qualified three overclaimed lines in README.md Project Status section: "Full Unicode Character Database tables" changed to "Unicode Character Database tables (simplified for some categories)"; "Unicode Collation Algorithm" changed to "Collation (ASCII/Latin-1)"; "BiDi" changed to "basic BiDi direction detection". Now matches qualifications in CHANGELOG.md and ARCHITECTURE.md.
- **Resolution evidence:** `README.md:227,231,232`

### Q47: CI omits test-comprehensive

- **Original Severity:** High (PriorityScore 76.8)
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Resolution summary:** Added `test-comprehensive` job to `.gitlab-ci.yml` following the same pattern as existing test jobs. The job runs `zig build test-comprehensive --summary all` in the `test` stage with the same `debian:bookworm-slim` image and zig installation anchor.
- **Resolution evidence:** `.gitlab-ci.yml` -- `test-comprehensive` job definition.

---

## Won't Do -- Satellite File Items (Phase 4)

The following items from satellite analysis files were marked Won't Do during the audit. They are tracked in their respective files and summarized here for completeness.

| ID | File | Summary | Won't Do Reason |
|----|------|---------|-----------------|
| S6 | SECURITY_GAP_ANALYSIS.md | Supply chain -- spice dependency pinned to main branch | Upstream dependency management decision |
| S8 | SECURITY_GAP_ANALYSIS.md | Identifier NFKC normalization gap -- homoglyph bypass | Requires full NFKC Quick_Check (same blocker as GAP-0001) |
| M2 | QUALITY_GAP_ANALYSIS.md | `getCategory` 561-line if-chain, no generated table | Superseded by P1-6 performance gap |
| M5 | QUALITY_GAP_ANALYSIS.md | `getCompatibilityDecomposition` covers ~30 of thousands of NFKD mappings | Requires full UCD table generation |
| P1-4 | PERF_GAP_ANALYSIS.md | No benchmark regression detection in CI | Requires CI infrastructure |
| Q14 | QUALITY_GAP_ANALYSIS.md | categories.zig: 19 pub fns, only 4 tests | Deferred to UCD test vector sprint (same as GAP-0015) |
| Q25 | QUALITY_GAP_ANALYSIS.md | No code coverage tooling | Requires CI infrastructure |
| Q26 | QUALITY_GAP_ANALYSIS.md | No fuzz testing infrastructure | Same as GAP-0021 |
| P2-9 | PERF_GAP_ANALYSIS.md | isExtendedPictographic incomplete ranges | Requires full UCD Extended_Pictographic table |
| P2-13 | PERF_GAP_ANALYSIS.md | ASCII fast-path in `getGraphemeBreak()` | Closed (implemented, not Won't Do) |
| P2-16 | PERF_GAP_ANALYSIS.md | `replaceN()` single-pass rewrite | Intentional double scan for exact pre-allocation |

---

## ID Registry

| Gap-ID Range | Analysis Date | Resolution Date | Notes |
|-------------|--------------|-----------------|-------|
| GAP-0001 through GAP-0022 | 2026-03-23 | 2026-03-24 | Initial gap analysis; 17 closed, 1 partial, 4 won't do |
| GAP-0023 through GAP-0030 | 2026-03-24 | 2026-03-24 | Phase 3: all closed |
| Wave 1-3 cross-file IDs | 2026-03-24 | 2026-03-24 | D1, D2, D4, D5, M7, R5, S18, S19, S21 closed |
| Re-audit | 2026-03-24 | 2026-03-24 | GAP-0012, GAP-0018, GAP-0019 false closures detected; re-opened; truly closed in Wave 2 |
| Wave 4 (docs/CI) | 2026-03-24 | 2026-03-24 | GAP-0027, GAP-0032, Q47 closed |
| Wave 2 (gap closure) | 2026-03-24 | 2026-03-24 | GAP-0012/0031 (Jaro OOB), GAP-0018 (Damerau doc), GAP-0019 (Levenshtein doc) truly closed |
| Phase 4 satellite Won't Do | 2026-03-24 | 2026-03-24 | S6, S8, M2, M5, P1-4, Q14, Q25, Q26, P2-9, P2-13, P2-16 |
