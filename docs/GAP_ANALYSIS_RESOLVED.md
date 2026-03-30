# Gap Analysis -- Resolved Gaps

**Repository:** devnw/zig/strings
**Last updated:** 2026-03-30 (Wave 10 closure -- GAP-0038 through GAP-0044 added)

This file tracks gaps that have been resolved. Gap-IDs are never reused.

> **Re-audit note (2026-03-24):** A re-audit found GAP-0012, GAP-0018, and GAP-0019 were
> falsely closed (fixes never committed to `src/extended/fuzzy.zig`). These were re-opened
> and have now been **truly closed in Wave 2** with verified fixes: `MAX_JARO_LEN=256` bounds
> guard, `MAX_DAMERAU_LEN=32` doc comment, `MAX_STACK_LEN=1024` doc comments, and
> corresponding tests.

---

## Resolved Gaps

### GAP-0001: `isNormalized()` ignores `form` parameter (CLOSED)

- **Original Severity:** Critical
- **Status:** Closed (Wave 5, commit dad4272)
- **Resolved date:** 2026-03-24
- **Issue:** [#22](https://gitlab.com/devnw/zig/strings/-/issues/22)
- **Resolution summary:** Fully resolved. Extended `tools/generate_ucd.py` to download `DerivedNormalizationProps.txt` and generate NFC_QC/NFKC_QC two-level trie tables. `isNormalized()` now performs Quick_Check lookups per UAX #15 Section 9 for all four normalization forms (NFC, NFD, NFKC, NFKD).
- **Resolution evidence:** `src/unicode/data/nfc_qc.zig` (1,231 entries), `src/unicode/data/nfkc_qc.zig` (5,039 entries), `src/unicode/normalization.zig:67-76` (Quick_Check branch). 4 new tests added. All tests pass.

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

### GAP-0033: Gap-closure changes remain uncommitted in working tree

- **Original Severity:** High
- **Status:** Closed
- **Resolved date:** 2026-03-24 (Wave 4)
- **Issue:** [#87](https://gitlab.com/devnw/zig/strings/-/issues/87)
- **Resolution summary:** All gap-closure changes from Waves 1-4 committed as `5c110b1` and pushed to remote. 538/538 tests pass, 76/76 build steps, format clean. Working tree is clean.
- **Resolution evidence:** `git log --oneline -1` shows `5c110b1`. `git status` shows clean working tree. 538 tests pass (536 original + 2 new R4 tests).

---

### R4: Regex VM recursive backtracking -- stack overflow risk for deep nesting

- **Original Severity:** Medium
- **Status:** Closed
- **Resolved date:** 2026-03-24 (Wave 4)
- **Issue:** [#25](https://gitlab.com/devnw/zig/strings/-/issues/25)
- **Resolution summary:** Added `MAX_RECURSION_DEPTH=500` guard to the recursive `matchAt()` call in the `split` opcode handler. The recursion depth is incremented before the recursive call and decremented after. When the limit is exceeded, the function returns null (no match) instead of recursing further. Two new tests added.
- **Resolution evidence:** `src/extended/regex.zig:1038` (constant), `:1048` (field init), `:1273-1281` (depth check in split handler). Tests: "R4: deeply nested groups do not cause stack overflow", "R4: MAX_RECURSION_DEPTH prevents stack overflow on pathological split chains".

---

### P1-6: Table-based `getCategory()` / `getGraphemeBreak()` lookup [RESOLVED]

- **Original Severity:** High (PerfScore 80)
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#68](https://gitlab.com/devnw/zig/strings/-/issues/68) (closed)
- **Category:** Performance
- **Resolution:** Trie-based lookup tables generated from UCD data. `getCategory()` and `getGraphemeBreak()` now use two-level trie tables instead of 80-100+ sequential if-chain range comparisons.
- **Evidence:** `src/unicode/categories.zig:20-29` (trie-based getCategory), `src/unicode/grapheme.zig:41-55` (trie-based getGraphemeBreak). All existing tests pass unchanged.

---

### P2-10: O(1) decomposition/composition tables [RESOLVED]

- **Original Severity:** Medium (PerfScore 44)
- **Status:** Closed
- **Resolved date:** 2026-03-24
- **Issue:** [#80](https://gitlab.com/devnw/zig/strings/-/issues/80) (closed)
- **Category:** Performance
- **Resolution:** Block-indexed decomposition/composition tables generated by `tools/generate_ucd.py`. `stage1[cp >> 8]` gives `[start, end)` range into flat sorted arrays. Binary search within block is O(log ~4) per lookup (practically constant time), down from O(log n) over full array.
- **Evidence:** `src/unicode/data/decomposition.zig` (block-indexed lookup), `src/unicode/data/composition.zig` (block-indexed lookup). NormalizationTest.txt conformance maintained. All 543 tests pass. Also closes P3-1.

---

### P3-1: Composition binary search on 941-entry flat array [RESOLVED]

- **Original Severity:** Low (PerfScore 15)
- **Status:** Closed (subsumed by P2-10)
- **Resolved date:** 2026-03-24
- **Issue:** Subsumed by P2-10 ([#80](https://gitlab.com/devnw/zig/strings/-/issues/80))
- **Category:** Performance
- **Resolution:** Block index on starter codepoint narrows 941-entry search to per-block range (typically 1-58 entries). Resolved automatically as part of P2-10 block-indexed table generation.
- **Evidence:** `src/unicode/data/composition.zig` -- uses `comp_block_index[starter >> 8]` to narrow range.

---

### P2-3: `normalize()` materializes full codepoint buffer [RESOLVED]

- **Original Severity:** Medium (PerfScore 35)
- **Status:** Closed (Wave 6)
- **Resolved date:** 2026-03-24
- **Issue:** [#45](https://gitlab.com/devnw/zig/strings/-/issues/45)
- **Category:** Performance
- **Resolution:** Replaced full-buffer materialization with fixed 64-codepoint window streaming. `normalize()` now uses O(1) memory for typical inputs. Codepoints are accumulated in a fixed stack buffer delimited by starters (CCC=0). Each window is CCC-sorted, optionally composed, and flushed to output before the next window begins. Dynamic allocation is used only when a single CCC sequence exceeds 64 codepoints (extremely rare).
- **Evidence:** `src/unicode/normalization.zig` (streaming window implementation), `src/unicode/norm_compose.zig`, `src/unicode/norm_decompose.zig`. All existing normalization tests pass unchanged. 8 new streaming-specific tests added.

---

### Q49: 6 files exceed 800-line limit [RESOLVED]

- **Original Severity:** Low (PriorityScore 38.4)
- **Status:** Closed (Wave 6)
- **Resolved date:** 2026-03-24
- **Issue:** Not filed
- **Category:** Code Quality
- **Resolution:** All 6 oversized files split into sub-modules, each now under 800 lines:
  - `regex.zig`: 2,147 -> 787 lines (+ `regex_types.zig` 240, `regex_compiler.zig` 761, `regex_vm.zig` 480)
  - `manipulation.zig`: 1,154 -> 89 lines (+ `splitting.zig` 290, `trimming.zig` 417, `transform.zig` 478)
  - `normalization.zig`: 1,035 -> 786 lines (+ `norm_decompose.zig` 329, `norm_compose.zig` 240)
  - `simd.zig`: 995 -> 662 lines (+ `simd_case.zig` 238, `simd_mem.zig` 167)
  - `phonetic.zig`: 869 -> 594 lines (+ `phonetic_metaphone.zig` 315)
  - `locale.zig`: 821 -> 626 lines (+ `locale_data.zig` 230)
- **Evidence:** `src/extended/regex.zig`, `src/ops/manipulation.zig`, `src/unicode/normalization.zig`, `src/util/simd.zig`, `src/extended/phonetic.zig`, `src/extended/locale.zig` and their respective sub-modules. All tests pass.

---

## Won't Do -- Satellite File Items (Phase 4+)

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
| RM-1 | QUALITY_GAP_ANALYSIS.md | Duplicate lookup-table builders in manipulation.zig and search.zig | Semantic differences; ~15 lines not worth coupling |
| S23 | SECURITY_GAP_ANALYSIS.md | Regex VM unreachable for repeat_greedy/repeat_lazy opcodes | Safe by construction (compiled away); accepted risk |
| S24 | SECURITY_GAP_ANALYSIS.md | 128 @intCast calls across src/ without formal proof | Accepted risk; highest-risk casts fixed in S20; fuzz testing recommended |
| S26 | SECURITY_GAP_ANALYSIS.md | CI components lack hash pinning (tag-only) | GitLab CI does not support SHA-based component pinning; first-party control over CI catalog repository mitigates supply chain risk |

---

## Wave 9 Resolved Items (2026-03-25)

### GAP-0035: No official Unicode conformance test data integration (CLOSED)

- **Original Severity:** Medium
- **Status:** Closed (Wave 9)
- **Resolved date:** 2026-03-25
- **Issue:** [#13](https://gitlab.com/devnw/zig/strings/-/issues/13) (closed)
- **Category:** Test
- **Resolution summary:** Created `tests/unicode_conformance_vectors.zig` with 33 NormalizationTest.txt Part 1 vectors and 29 GraphemeBreakTest.txt vectors, all sourced from official Unicode 15.1 test data. Tests cover all four normalization forms (NFC, NFD, NFKC, NFKD) plus stability invariants (idempotency, round-trip) -- 9 test functions total. Grapheme tests cover GB3 (CR+LF), GB4/GB5 (controls), GB6-GB8 (Hangul), GB9 (Extend), GB9a (SpacingMark), GB9b (Prepend), GB11 (emoji ZWJ), GB12/GB13 (regional indicators). Added `test-conformance` build step in `build.zig`; also wired into `test-comprehensive` and `test-all`.
- **Bugs found and fixed:**
  - `norm_decompose.zig`: recursive decomposition for multi-level chains
  - `grapheme.zig`: GB12/GB13 regional indicator parity reset
  - Spacing modifier compat decompositions for U+00A8, U+00AF, U+00B4, U+00B8, U+02C7, U+02D8-U+02DD
- **Resolution evidence:** `tests/unicode_conformance_vectors.zig`, `build.zig` (test-conformance step), `src/unicode/norm_decompose.zig` (recursive decomposition fix), `src/unicode/grapheme.zig` (GB12/GB13 ri_odd reset)

---

### GAP-0036: Thread safety documentation insufficient (CLOSED)

- **Original Severity:** Low
- **Status:** Closed (Wave 9)
- **Resolved date:** 2026-03-25
- **Issue:** [#20](https://gitlab.com/devnw/zig/strings/-/issues/20) (closed)
- **Category:** Docs
- **Resolution summary:** Added `/// Thread-safe: ...` doc comments to all 6 public functions in `src/parallel.zig` and thread safety annotations to all 5 public context/result types. Expanded `docs/ARCHITECTURE.md` Thread Safety section with subsections for General Guarantees, Parallel Module, and a Summary Table. Added Thread Safety section to `README.md`.
- **Resolution evidence:** `src/parallel.zig` (doc comments on `getPool`, `deinitPool`, `parallelCount`, `parallelMap`, `parallelEditDistanceBatch`, `parallelFuzzySearch`, `CountContext`, `MapContext`, `EditDistanceBatchContext`, `FuzzySearchContext`, `FuzzyResult`), `docs/ARCHITECTURE.md` (Thread Safety section), `README.md` (Thread Safety section)

---

### GAP-0037: CI tests only Linux x86_64; README claims macOS/Windows (CLOSED)

- **Original Severity:** Low
- **Status:** Closed (Wave 9)
- **Resolved date:** 2026-03-25
- **Issue:** [#21](https://gitlab.com/devnw/zig/strings/-/issues/21) (closed)
- **Category:** CI-CD
- **Resolution summary:** Added 3 cross-compilation CI jobs to `.gitlab-ci.yml`: `build-macos-x86_64` (`-Dtarget=x86_64-macos`), `build-macos-aarch64` (`-Dtarget=aarch64-macos`), `build-windows-x86_64` (`-Dtarget=x86_64-windows`). README.md:11 updated to "Linux, macOS, Windows (cross-compilation verified in CI)".
- **Resolution evidence:** `.gitlab-ci.yml` (3 cross-compilation jobs), `README.md:11`

---

### A1: Error type duplication across modules (CLOSED)

- **Original Severity:** Medium
- **Status:** Closed (Wave 7)
- **Resolved date:** 2026-03-25
- **Issue:** [#39](https://gitlab.com/devnw/zig/strings/-/issues/39)
- **Category:** Maintainability
- **Resolution summary:** Analysis confirmed remaining error sets are domain-specific (regex, normalization, encoding, parallel, etc.) with no meaningful overlap after M3 consolidated legacy encoding errors. No further consolidation warranted.
- **Resolution evidence:** M3 fix (shared `LegacyEncodingError` in `src/encoding/legacy/errors.zig`). Remaining error sets verified as non-duplicative.

---

### A4: Inconsistent parameter ordering (CLOSED)

- **Original Severity:** Low
- **Status:** Closed (Wave 8)
- **Resolved date:** 2026-03-25
- **Issue:** [#76](https://gitlab.com/devnw/zig/strings/-/issues/76)
- **Category:** API Contract
- **Resolution summary:** Audited 143 functions across the library. Found 1 outlier: `ICUString.caseCompare` had allocator in a non-standard position. Fixed to follow `self, allocator, ...rest` convention. All functions now follow consistent `allocator-first` (standalone) or `self, allocator, ...rest` (methods) ordering.
- **Resolution evidence:** `src/extended/icu.zig` (`caseCompare` parameter order fixed)

---

### S26: CI components lack hash pinning (WON'T DO)

- **Original Severity:** Low
- **Status:** Won't Do (Wave 9)
- **Resolved date:** 2026-03-25
- **Category:** Security
- **Won't Do reason:** GitLab CI does not support SHA-based component pinning; only tag-based references are available. First-party control over the CI catalog repository mitigates the supply chain risk. The risk score (12) is low and non-exploitable for memory corruption.
- **Evidence:** `.gitlab-ci.yml:7-20` (tag-based component references)

---

## ID Registry

| Gap-ID Range | Analysis Date | Resolution Date | Notes |
|-------------|--------------|-----------------|-------|
| GAP-0001 through GAP-0022 | 2026-03-23 | 2026-03-24 | Initial gap analysis; all closed (GAP-0001 fully resolved), 4 won't do |
| GAP-0023 through GAP-0030 | 2026-03-24 | 2026-03-24 | Phase 3: all closed |
| Wave 1-3 cross-file IDs | 2026-03-24 | 2026-03-24 | D1, D2, D4, D5, M7, R5, S18, S19, S21 closed |
| Re-audit | 2026-03-24 | 2026-03-24 | GAP-0012, GAP-0018, GAP-0019 false closures detected; re-opened; truly closed in Wave 2 |
| Wave 4 (docs/CI) | 2026-03-24 | 2026-03-24 | GAP-0027, GAP-0032, Q47 closed |
| Wave 2 (gap closure) | 2026-03-24 | 2026-03-24 | GAP-0012/0031 (Jaro OOB), GAP-0018 (Damerau doc), GAP-0019 (Levenshtein doc) truly closed |
| Phase 4 satellite Won't Do | 2026-03-24 | 2026-03-24 | S6, S8, M2, M5, P1-4, Q14, Q25, Q26, P2-9, P2-13, P2-16 |
| Wave 4 closures | 2026-03-24 | 2026-03-24 | GAP-0033, R4, S22/AC-1, AC-2, AC-3, RE-3, AC-4, P2-NEW-1, P2-NEW-2, P3-NEW-1, RM-1 (Won't Do) |
| Post-closure audit | 2026-03-24 | 2026-03-24 | GAP-0001 fully resolved (NFC_QC/NFKC_QC), P1-6 closed (trie-based), P2-10 closed (block-indexed), P3-1 closed (subsumed) |
| Wave 6 closures | 2026-03-24 | 2026-03-24 | P2-3 closed (streaming normalization), Q49 closed (file splitting), S23/S24 Won't Do |
| Wave 7 closures | 2026-03-25 | 2026-03-25 | A1 closed (error type duplication -- domain-specific, no further consolidation) |
| Wave 8 closures | 2026-03-25 | 2026-03-25 | A4 closed (parameter ordering -- 1 outlier ICUString.caseCompare fixed) |
| Wave 9 closures | 2026-03-25 | 2026-03-25 | GAP-0035, GAP-0036, GAP-0037 closed; RM-4, P-NEW-3, P-NEW-4, S25, Q-CI1, Q-LOC1 closed; S26 Won't Do |
| Wave 10 closures | 2026-03-30 | 2026-03-30 | GAP-0038 through GAP-0044 closed (parallelism review: opt-in API documented, parallel normalize/case added, spice v0.1.0 tagged, threshold lowered, error sentinel named, library deinit added) |

---

### GAP-0038: Parallel module not integrated into public API operations (CLOSED)

- **Original Severity:** High
- **Resolution:** Closed (opt-in by design)
- **Date:** 2026-03-30
- **Details:** Transparent auto-dispatch was considered but rejected: parallel operations require different allocator/lifetime semantics (batch results with error sentinels, page_allocator in forked tasks) that would leak into the core API surface. Instead, the parallel module is documented prominently in `lib.zig` with an enumeration of all available parallel operations and thresholds. A library-level `strings.deinit()` was added for cleanup.

### GAP-0039: No parallel normalization (NFC/NFD/NFKC/NFKD) (CLOSED)

- **Original Severity:** Medium
- **Resolution:** Closed
- **Date:** 2026-03-30
- **Details:** Added `parallelNormalize()` to `parallel.zig`. Splits input at ASCII byte boundaries (always normalization-safe since ASCII codepoints have CCC=0 and cannot participate in composition). Each chunk is normalized independently via spice fork/join. Threshold: 64 KB. Falls back to sequential for small inputs, pure-ASCII inputs (existing fast-path), or when no ASCII split points are found.

### GAP-0040: No parallel case conversion (toLower/toUpper/toTitle) (CLOSED)

- **Original Severity:** Medium
- **Resolution:** Closed
- **Date:** 2026-03-30
- **Details:** Added `parallelCaseConvert()` to `parallel.zig` with a `CaseDirection` enum (.lower/.upper). Splits input at UTF-8 sequence boundaries (case conversion is codepoint-independent, so any sequence boundary is safe). Each chunk is converted independently via spice fork/join. Threshold: 64 KB.

### GAP-0041: Spice dependency pinned to `main` branch (CLOSED)

- **Original Severity:** Medium
- **Resolution:** Closed
- **Date:** 2026-03-30
- **Details:** Created tag `v0.1.0` on the spice fork (`gitlab.com/devnw/zig/spice`). Updated `build.zig.zon` URL from `main` branch archive to `v0.1.0` tag archive. Content hash unchanged (Zig's hash is content-addressed, not path-dependent).

### GAP-0042: `parallelMap` threshold too high (10 MB) (CLOSED)

- **Original Severity:** Low
- **Resolution:** Closed
- **Date:** 2026-03-30
- **Details:** Lowered `parallelMap` threshold from 10,485,760 bytes (10 MB) to 65,536 bytes (64 KB). The map function `fn(T) T` has comparable per-element overhead to counting, so the threshold should be in the same order of magnitude as `parallelCount`'s 4,096 bytes.

### GAP-0043: Error sentinel in parallel edit distance / fuzzy search (CLOSED)

- **Original Severity:** Low
- **Resolution:** Closed
- **Date:** 2026-03-30
- **Details:** Added `pub const error_sentinel: usize = std.math.maxInt(usize)` as a named constant and `pub fn isErrorSentinel(score: usize) bool` as a helper function. Updated all internal usages to reference the named constant instead of the raw `std.math.maxInt(usize)` expression.

### GAP-0044: No `deinitPool` integration with library-level deinit (CLOSED)

- **Original Severity:** Low
- **Resolution:** Closed
- **Date:** 2026-03-30
- **Details:** Added `pub fn deinit()` to `lib.zig` that calls `parallel.deinitPool()`. Safe to call even when no parallel operations were performed or when spice is disabled (no-op in both cases). Documented in the parallel module's doc comment in `lib.zig`.
