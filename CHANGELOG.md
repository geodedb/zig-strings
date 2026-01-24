# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-01-24

Initial public release - Feature Complete.

### Added
- Merge request template for contributions
- Issue templates for bug reports, features, and questions
- **Core String Types**
  - `String` - UTF-8 backed string with Small String Optimization (SSO)
  - `StringBuilder` - Efficient string concatenation
  - `StringPool` - String interning for memory efficiency

- **Unicode Support (Unicode 15.1)**
  - UTF-8, UTF-16, UTF-32 encoding/decoding
  - Unicode normalization (NFC, NFD, NFKC, NFKD) per UAX #15
  - Grapheme cluster segmentation per UAX #29
  - Word and sentence boundary detection per UAX #29
  - Case mapping and case folding
  - Unicode Collation Algorithm per UTS #10
  - Script detection per UAX #24
  - BiDi algorithm per UAX #9
  - Line breaking per UAX #14
  - Identifier syntax per UAX #31
  - Full Unicode Character Database (UCD) tables

- **Extended Unicode Categories**
  - Support for additional scripts and character categories

- **Legacy Encoding Support**
  - Windows code pages (CP1250-1258, CP437, CP850)
  - ISO-8859 family (1-16)
  - Chinese encodings: GB2312, GBK, GB18030
  - Japanese encodings: Shift_JIS, EUC-JP
  - Korean encodings: EUC-KR, CP949
  - Traditional Chinese: Big5, Big5-HKSCS

- **Advanced Features**
  - SIMD acceleration (AVX2/AVX-512) for performance
  - Regular expressions
  - Fuzzy matching (Levenshtein, Jaro-Winkler, etc.)
  - Phonetic algorithms (Soundex, Metaphone, Double Metaphone, NYSIIS)
  - Locale-specific formatting (20+ locales)
  - ICU compatibility layer

- **Advanced Data Structures**
  - Rope for large string manipulation
  - Memory-mapped strings
  - Lazy normalization

- **Go-style String Functions**
  - `cut`, `fields`, `trimPrefix`, `trimSuffix`, and more
  - Familiar API for Go developers

- **Security**
  - GitLab native Secret Detection
  - Advanced SAST and Dependency Scanning
  - SBOM generation

- **CI/CD**
  - Integration with devnw/ci-catalog components
  - Support for Zig 0.15.x
  - Code coverage support

### Fixed
- Comprehensive Unicode and regex improvements
- Zig 0.15 API compatibility issues
- Formatting issues across codebase

### Changed
- Updated CI catalog components to v1.7.1
- Licensed under Apache-2.0 for open source release

## [0.0.1] - 2025-12-30

Initial development release.

### Added
- Initial strings implementation with core functionality
- Basic UTF-8 string operations
- NFC Normalization support
- Full UCD tables integration
- Early Unicode implementation
- Basic feature set expansion

### Security
- Configured SAST in GitLab CI
- Configured Secret Detection in GitLab CI

[Unreleased]: https://gitlab.com/devnw/zig/strings/-/compare/v0.1.0...HEAD
[0.1.0]: https://gitlab.com/devnw/zig/strings/-/compare/v0.0.1...v0.1.0
[0.0.1]: https://gitlab.com/devnw/zig/strings/-/releases/v0.0.1
