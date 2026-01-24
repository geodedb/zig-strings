# Roadmap

This document outlines the development roadmap for the ZigStr library.

## Current Status: v0.1.0

### Phase 1: Core Implementation

- [x] Core types and constants
- [x] UTF-8 encoding/decoding
- [x] UTF-16 encoding/decoding
- [x] UTF-32 encoding/decoding
- [x] ASCII operations
- [x] Latin-1 operations
- [x] Code point operations
- [x] Basic iterators
- [x] **Small String Optimization (SSO)** - 23-byte inline storage
- [x] **Go-style string functions** - cut, fields, splitN, etc.

### Phase 2: Unicode Support

- [x] Unicode character categories (UAX #44)
- [x] Grapheme cluster boundaries (UAX #29)
- [x] Word boundaries (UAX #29)
- [x] Sentence boundaries (UAX #29)
- [x] Case mapping and folding
- [x] NFD normalization (decomposition)
- [x] NFKD normalization (compatibility decomposition)
- [x] NFC normalization (composition)
- [x] NFKC normalization
- [x] Basic collation (UTS #10)

### Phase 3: String Operations

- [x] Search operations (indexOf, contains, etc.)
- [x] Comparison operations
- [x] Manipulation (split, join, trim, replace)
- [x] String type with SSO
- [x] String16 type (UTF-16)
- [x] StringBuilder
- [x] Numeric parsing and formatting

### Phase 4: Utilities

- [x] Encoding detection
- [x] BOM handling
- [x] Transcoding between encodings
- [x] Basic SIMD acceleration
- [x] String interning (StringPool)
- [x] Symbol tables

---

## Planned Enhancements

### Phase 5: Full Unicode Compliance

**Milestone:** [Phase 2: Unicode Compliance](https://gitlab.com/devnw/zig/strings/-/milestones/2)

| Feature | Issue | Priority | Status |
|---------|-------|----------|--------|
| NFC/NFKC Composition | [#1](https://gitlab.com/devnw/zig/strings/-/issues/1) | Critical | **Done** |
| Full UCD Tables | [#2](https://gitlab.com/devnw/zig/strings/-/issues/2) | High | **Done** |
| Script Detection | [#3](https://gitlab.com/devnw/zig/strings/-/issues/3) | Medium | **Done** |
| BiDi Algorithm (UAX #9) | [#4](https://gitlab.com/devnw/zig/strings/-/issues/4) | Medium | **Done** |
| Line Breaking (UAX #14) | [#5](https://gitlab.com/devnw/zig/strings/-/issues/5) | Medium | **Done** |
| Identifier Syntax (UAX #31) | - | Low | **Done** |

### Phase 6: Performance Optimization

**Milestone:** [Phase 3: Performance](https://gitlab.com/devnw/zig/strings/-/milestones/3)

| Feature | Issue | Priority | Status |
|---------|-------|----------|--------|
| AVX2/AVX-512 SIMD | [#6](https://gitlab.com/devnw/zig/strings/-/issues/6) | Medium | **Done** |
| Rope Data Structure | [#7](https://gitlab.com/devnw/zig/strings/-/issues/7) | Low | **Done** |
| Benchmarking Suite | [#9](https://gitlab.com/devnw/zig/strings/-/issues/9) | Medium | **Done** |
| Memory-mapped Strings | - | Low | **Done** |
| Lazy Normalization | - | Low | **Done** |

### Phase 7: Extended Features

- [x] Regular expression support
- [x] Fuzzy matching algorithms
- [x] Phonetic algorithms (Soundex, Metaphone)
- [x] Locale-specific formatting
- [x] ICU compatibility layer

### Phase 8: Additional Encodings

**Issue:** [#8](https://gitlab.com/devnw/zig/strings/-/issues/8)

- [x] Windows code pages (CP1250-1258, CP437, CP850)
- [x] ISO-8859-* family (ISO-8859-1 through ISO-8859-16)
- [x] GB2312/GBK/GB18030
- [x] Shift_JIS
- [x] EUC-JP, EUC-KR
- [x] Big5 (including Big5-HKSCS)

---

## Version History

### v0.1.0 (Current)

Initial release with core functionality:
- UTF-8, UTF-16, UTF-32, ASCII, Latin-1 support
- Small String Optimization (SSO)
- Unicode character properties
- Text segmentation (grapheme, word, sentence)
- Full Unicode normalization (NFC, NFD, NFKC, NFKD)
- Case conversion and folding
- Basic collation
- String manipulation
- Go-style string functions
- Encoding detection and transcoding
- SIMD acceleration (AVX2/AVX-512)
- String interning
- Rope data structure for large strings
- Memory-mapped strings
- Lazy normalization
- Regular expressions
- Fuzzy matching (Levenshtein, Jaro-Winkler, etc.)
- Phonetic algorithms (Soundex, Metaphone, etc.)
- Locale-specific formatting (20+ locales)
- ICU compatibility layer
- Legacy encodings:
  - Windows code pages (CP1250-1258, CP437, CP850)
  - ISO-8859 family (1-16)
  - Chinese: GB2312, GBK, GB18030
  - Japanese: Shift_JIS, EUC-JP
  - Korean: EUC-KR, CP949
  - Traditional Chinese: Big5, Big5-HKSCS

---

## Milestones

| Milestone | Description | Status |
|-----------|-------------|--------|
| [Phase 1: Core Foundation](https://gitlab.com/devnw/zig/strings/-/milestones/1) | Core string types, SSO, encodings | Complete |
| [Phase 2: Unicode Compliance](https://gitlab.com/devnw/zig/strings/-/milestones/2) | Full normalization, collation | Complete |
| [Phase 3: Performance](https://gitlab.com/devnw/zig/strings/-/milestones/3) | SIMD, benchmarks, optimization | Complete |
| Phase 7: Extended Features | Regex, fuzzy, phonetic, locale, ICU | Complete |
| Phase 8: Legacy Encodings | Windows CP, ISO-8859, CJK encodings | Complete |
| [v1.0 Release](https://gitlab.com/devnw/zig/strings/-/milestones/4) | First stable release | Planned |

---

## Contributing

Contributions are welcome! Priority areas:

1. **Testing** - Add Unicode conformance test vectors
2. **Documentation** - Examples and tutorials
3. **Bug fixes** - Report and fix any issues
4. **Performance** - Profile and optimize critical paths
5. **Additional locales** - Expand locale support

See [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

---

## References

### Unicode Standards

- [Unicode Standard](https://unicode.org/standard/standard.html)
- [UAX #9: Unicode Bidirectional Algorithm](https://unicode.org/reports/tr9/)
- [UAX #14: Unicode Line Breaking Algorithm](https://unicode.org/reports/tr14/)
- [UAX #15: Unicode Normalization Forms](https://unicode.org/reports/tr15/)
- [UAX #29: Unicode Text Segmentation](https://unicode.org/reports/tr29/)
- [UAX #31: Unicode Identifier and Pattern Syntax](https://unicode.org/reports/tr31/)
- [UAX #44: Unicode Character Database](https://unicode.org/reports/tr44/)
- [UTS #10: Unicode Collation Algorithm](https://unicode.org/reports/tr10/)

### RFCs

- [RFC 3629: UTF-8](https://tools.ietf.org/html/rfc3629)
- [RFC 2781: UTF-16](https://tools.ietf.org/html/rfc2781)

### Zig Resources

- [Zig Language Reference](https://ziglang.org/documentation/master/)
- [Zig Standard Library](https://ziglang.org/documentation/master/std/)
