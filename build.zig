// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // ============================================================
    // Build Options
    // ============================================================

    const feature_simd = b.option(bool, "simd", "Enable SIMD-accelerated operations (default: true)") orelse true;
    const feature_unicode_data = b.option(bool, "unicode-data", "Include full Unicode data tables (default: true)") orelse true;
    const enable_spice = b.option(bool, "spice", "Enable spice-based parallelism") orelse true;

    // Build options module
    const build_options = b.addOptions();
    build_options.addOption(bool, "enable_spice", enable_spice);
    build_options.addOption(bool, "enable_simd", feature_simd);
    build_options.addOption(bool, "enable_unicode_data", feature_unicode_data);

    // Get spice dependency if enabled
    const spice_mod: ?*std.Build.Module = if (enable_spice) blk: {
        const spice_dep = b.dependency("spice", .{
            .target = target,
            .optimize = optimize,
        });
        break :blk spice_dep.module("spice");
    } else null;

    // ============================================================
    // Core Type Modules
    // ============================================================

    // types.zig - Core type definitions, encoding enums, constants
    const types_mod = b.addModule("types", .{
        .root_source_file = b.path("src/types.zig"),
        .target = target,
        .optimize = optimize,
    });

    // codepoint.zig - Unicode code point operations
    const codepoint_mod = b.addModule("codepoint", .{
        .root_source_file = b.path("src/codepoint.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // ============================================================
    // Encoding Modules - UTF-8, UTF-16, UTF-32, ASCII, Latin-1
    // ============================================================

    // utf8.zig - UTF-8 encoding/decoding (RFC 3629)
    const utf8_mod = b.addModule("utf8", .{
        .root_source_file = b.path("src/utf8.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
        },
    });

    // utf16.zig - UTF-16 encoding/decoding (RFC 2781)
    const utf16_mod = b.addModule("utf16", .{
        .root_source_file = b.path("src/utf16.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
        },
    });

    // utf32.zig - UTF-32 encoding/decoding
    const utf32_mod = b.addModule("utf32", .{
        .root_source_file = b.path("src/utf32.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
        },
    });

    // ascii.zig - ASCII operations
    const ascii_mod = b.addModule("ascii", .{
        .root_source_file = b.path("src/ascii.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // latin1.zig - Latin-1/ISO-8859-1 operations
    const latin1_mod = b.addModule("latin1", .{
        .root_source_file = b.path("src/latin1.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
        },
    });

    // ============================================================
    // Unicode Modules - Categories, Normalization, Boundaries
    // ============================================================

    // unicode/categories.zig - Unicode character categories (UAX #44)
    const categories_mod = b.addModule("categories", .{
        .root_source_file = b.path("src/unicode/categories.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
        },
    });

    // ============================================================
    // Unicode Data Modules - Generated from UCD
    // ============================================================

    // unicode/data/ccc.zig - Canonical Combining Class table
    const ucd_ccc_mod = b.addModule("ucd_ccc", .{
        .root_source_file = b.path("src/unicode/data/ccc.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // unicode/data/decomposition.zig - Decomposition mappings
    const ucd_decomp_mod = b.addModule("ucd_decomposition", .{
        .root_source_file = b.path("src/unicode/data/decomposition.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // unicode/data/composition.zig - Composition mappings
    const ucd_comp_mod = b.addModule("ucd_composition", .{
        .root_source_file = b.path("src/unicode/data/composition.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // unicode/data/scripts.zig - Script detection (UAX #24)
    const ucd_scripts_mod = b.addModule("ucd_scripts", .{
        .root_source_file = b.path("src/unicode/data/scripts.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // unicode/data/line_break.zig - Line breaking (UAX #14)
    const ucd_line_break_mod = b.addModule("ucd_line_break", .{
        .root_source_file = b.path("src/unicode/data/line_break.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // unicode/data/bidi.zig - Bidirectional properties (UAX #9)
    const ucd_bidi_mod = b.addModule("ucd_bidi", .{
        .root_source_file = b.path("src/unicode/data/bidi.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // unicode/data/identifier.zig - Identifier syntax (UAX #31)
    const ucd_identifier_mod = b.addModule("ucd_identifier", .{
        .root_source_file = b.path("src/unicode/data/identifier.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // unicode/normalization.zig - Unicode normalization (UAX #15)
    const normalization_mod = b.addModule("normalization", .{
        .root_source_file = b.path("src/unicode/normalization.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "categories", .module = categories_mod },
            .{ .name = "ucd_ccc", .module = ucd_ccc_mod },
            .{ .name = "ucd_decomposition", .module = ucd_decomp_mod },
            .{ .name = "ucd_composition", .module = ucd_comp_mod },
        },
    });

    // unicode/grapheme.zig - Grapheme cluster boundaries (UAX #29)
    const grapheme_mod = b.addModule("grapheme", .{
        .root_source_file = b.path("src/unicode/grapheme.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "categories", .module = categories_mod },
        },
    });

    // unicode/word.zig - Word boundaries (UAX #29)
    const word_mod = b.addModule("word", .{
        .root_source_file = b.path("src/unicode/word.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "categories", .module = categories_mod },
        },
    });

    // unicode/sentence.zig - Sentence boundaries (UAX #29)
    const sentence_mod = b.addModule("sentence", .{
        .root_source_file = b.path("src/unicode/sentence.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "categories", .module = categories_mod },
        },
    });

    // unicode/case.zig - Case mapping and folding (UAX #29, SpecialCasing.txt)
    const case_mod = b.addModule("case", .{
        .root_source_file = b.path("src/unicode/case.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "categories", .module = categories_mod },
        },
    });

    // unicode/collation.zig - Unicode collation (UTS #10)
    const collation_mod = b.addModule("collation", .{
        .root_source_file = b.path("src/unicode/collation.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "categories", .module = categories_mod },
            .{ .name = "normalization", .module = normalization_mod },
        },
    });

    // unicode/scripts.zig - Script detection (UAX #24)
    const scripts_mod = b.addModule("scripts", .{
        .root_source_file = b.path("src/unicode/scripts.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "ucd_scripts", .module = ucd_scripts_mod },
        },
    });

    // unicode/line_break.zig - Line breaking (UAX #14)
    const line_break_mod = b.addModule("line_break", .{
        .root_source_file = b.path("src/unicode/line_break.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "ucd_line_break", .module = ucd_line_break_mod },
        },
    });

    // unicode/bidi.zig - Bidirectional algorithm (UAX #9)
    const bidi_mod = b.addModule("bidi", .{
        .root_source_file = b.path("src/unicode/bidi.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "ucd_bidi", .module = ucd_bidi_mod },
        },
    });

    // unicode/identifier.zig - Identifier syntax (UAX #31)
    const identifier_mod = b.addModule("identifier", .{
        .root_source_file = b.path("src/unicode/identifier.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "ucd_identifier", .module = ucd_identifier_mod },
        },
    });

    // ============================================================
    // Encoding Detection and Conversion
    // ============================================================

    // encoding/detection.zig - Encoding detection
    const detection_mod = b.addModule("detection", .{
        .root_source_file = b.path("src/encoding/detection.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "utf16", .module = utf16_mod },
            .{ .name = "ascii", .module = ascii_mod },
        },
    });

    // encoding/bom.zig - Byte Order Mark handling
    const bom_mod = b.addModule("bom", .{
        .root_source_file = b.path("src/encoding/bom.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // encoding/transcoding.zig - Encoding transcoding
    const transcoding_mod = b.addModule("transcoding", .{
        .root_source_file = b.path("src/encoding/transcoding.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "utf16", .module = utf16_mod },
            .{ .name = "utf32", .module = utf32_mod },
            .{ .name = "ascii", .module = ascii_mod },
            .{ .name = "latin1", .module = latin1_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
        },
    });

    // ============================================================
    // Iterator Modules
    // ============================================================

    // iterator.zig - Various string iterators
    const iterator_mod = b.addModule("iterator", .{
        .root_source_file = b.path("src/iterator.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "utf16", .module = utf16_mod },
            .{ .name = "grapheme", .module = grapheme_mod },
            .{ .name = "word", .module = word_mod },
            .{ .name = "sentence", .module = sentence_mod },
        },
    });

    // ============================================================
    // Core String Operations
    // ============================================================

    // ops/search.zig - Search operations (find, contains, indexOf, etc.)
    const search_mod = b.addModule("search", .{
        .root_source_file = b.path("src/ops/search.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "iterator", .module = iterator_mod },
        },
    });

    // ops/comparison.zig - Comparison operations
    const comparison_mod = b.addModule("comparison", .{
        .root_source_file = b.path("src/ops/comparison.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "case", .module = case_mod },
            .{ .name = "normalization", .module = normalization_mod },
            .{ .name = "collation", .module = collation_mod },
        },
    });

    // ops/manipulation.zig - String manipulation (split, join, trim, etc.)
    const manipulation_mod = b.addModule("manipulation", .{
        .root_source_file = b.path("src/ops/manipulation.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "iterator", .module = iterator_mod },
            .{ .name = "grapheme", .module = grapheme_mod },
            .{ .name = "categories", .module = categories_mod },
        },
    });

    // ============================================================
    // Conversion Modules
    // ============================================================

    // conversion/numeric.zig - Numeric parsing and formatting
    const numeric_mod = b.addModule("numeric", .{
        .root_source_file = b.path("src/conversion/numeric.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "ascii", .module = ascii_mod },
        },
    });

    // conversion/formatting.zig - String formatting
    const formatting_mod = b.addModule("formatting", .{
        .root_source_file = b.path("src/conversion/formatting.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "numeric", .module = numeric_mod },
        },
    });

    // ============================================================
    // High-Level String Types
    // ============================================================

    // string.zig - Main UTF-8 backed string type
    const string_mod = b.addModule("string", .{
        .root_source_file = b.path("src/string.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "utf16", .module = utf16_mod },
            .{ .name = "iterator", .module = iterator_mod },
            .{ .name = "search", .module = search_mod },
            .{ .name = "comparison", .module = comparison_mod },
            .{ .name = "manipulation", .module = manipulation_mod },
            .{ .name = "case", .module = case_mod },
            .{ .name = "grapheme", .module = grapheme_mod },
            .{ .name = "normalization", .module = normalization_mod },
        },
    });

    // string16.zig - UTF-16 backed string type
    const string16_mod = b.addModule("string16", .{
        .root_source_file = b.path("src/string16.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "utf16", .module = utf16_mod },
            .{ .name = "iterator", .module = iterator_mod },
            .{ .name = "search", .module = search_mod },
            .{ .name = "comparison", .module = comparison_mod },
            .{ .name = "manipulation", .module = manipulation_mod },
            .{ .name = "case", .module = case_mod },
            .{ .name = "grapheme", .module = grapheme_mod },
            .{ .name = "normalization", .module = normalization_mod },
            .{ .name = "transcoding", .module = transcoding_mod },
        },
    });

    // builder.zig - String builder for efficient concatenation
    const builder_mod = b.addModule("builder", .{
        .root_source_file = b.path("src/builder.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "string", .module = string_mod },
        },
    });

    // ============================================================
    // Utility Modules
    // ============================================================

    // util/simd.zig - SIMD-accelerated operations
    const simd_mod = b.addModule("simd", .{
        .root_source_file = b.path("src/util/simd.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // util/pool.zig - String interning pool
    const pool_mod = b.addModule("pool", .{
        .root_source_file = b.path("src/util/pool.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "string", .module = string_mod },
        },
    });

    // util/rope.zig - Rope data structure for large strings
    const rope_mod = b.addModule("rope", .{
        .root_source_file = b.path("src/util/rope.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // util/mmap.zig - Memory-mapped string support
    const mmap_mod = b.addModule("mmap", .{
        .root_source_file = b.path("src/util/mmap.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
        },
    });

    // util/lazy_norm.zig - Lazy Unicode normalization
    const lazy_norm_mod = b.addModule("lazy_norm", .{
        .root_source_file = b.path("src/util/lazy_norm.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "normalization", .module = normalization_mod },
        },
    });

    // ============================================================
    // Extended Features (Phase 7)
    // ============================================================

    // extended/regex.zig - Regular expression support
    const regex_mod = b.addModule("regex", .{
        .root_source_file = b.path("src/extended/regex.zig"),
        .target = target,
        .optimize = optimize,
    });

    // extended/fuzzy.zig - Fuzzy matching algorithms
    const fuzzy_mod = b.addModule("fuzzy", .{
        .root_source_file = b.path("src/extended/fuzzy.zig"),
        .target = target,
        .optimize = optimize,
    });

    // extended/phonetic.zig - Phonetic algorithms
    const phonetic_mod = b.addModule("phonetic", .{
        .root_source_file = b.path("src/extended/phonetic.zig"),
        .target = target,
        .optimize = optimize,
    });

    // extended/locale.zig - Locale-specific formatting
    const locale_mod = b.addModule("locale", .{
        .root_source_file = b.path("src/extended/locale.zig"),
        .target = target,
        .optimize = optimize,
    });

    // extended/icu.zig - ICU compatibility layer
    const icu_mod = b.addModule("icu", .{
        .root_source_file = b.path("src/extended/icu.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types", .module = types_mod },
            .{ .name = "normalization", .module = normalization_mod },
            .{ .name = "grapheme", .module = grapheme_mod },
            .{ .name = "word", .module = word_mod },
            .{ .name = "sentence", .module = sentence_mod },
            .{ .name = "collation", .module = collation_mod },
            .{ .name = "case", .module = case_mod },
        },
    });

    // ============================================================
    // Legacy Encoding Modules (Phase 8)
    // ============================================================

    // encoding/legacy/windows.zig - Windows code pages
    const windows_codepage_mod = b.addModule("windows_codepage", .{
        .root_source_file = b.path("src/encoding/legacy/windows.zig"),
        .target = target,
        .optimize = optimize,
    });

    // encoding/legacy/iso8859.zig - ISO-8859 family
    const iso8859_mod = b.addModule("iso8859", .{
        .root_source_file = b.path("src/encoding/legacy/iso8859.zig"),
        .target = target,
        .optimize = optimize,
    });

    // encoding/legacy/chinese.zig - GB2312/GBK/GB18030
    const chinese_encoding_mod = b.addModule("chinese_encoding", .{
        .root_source_file = b.path("src/encoding/legacy/chinese.zig"),
        .target = target,
        .optimize = optimize,
    });

    // encoding/legacy/japanese.zig - Shift_JIS/EUC-JP
    const japanese_encoding_mod = b.addModule("japanese_encoding", .{
        .root_source_file = b.path("src/encoding/legacy/japanese.zig"),
        .target = target,
        .optimize = optimize,
    });

    // encoding/legacy/korean.zig - EUC-KR/CP949
    const korean_encoding_mod = b.addModule("korean_encoding", .{
        .root_source_file = b.path("src/encoding/legacy/korean.zig"),
        .target = target,
        .optimize = optimize,
    });

    // encoding/legacy/big5.zig - Big5/Big5-HKSCS
    const big5_mod = b.addModule("big5", .{
        .root_source_file = b.path("src/encoding/legacy/big5.zig"),
        .target = target,
        .optimize = optimize,
    });

    // parallel.zig - Spice-based parallel operations
    const parallel_mod = b.addModule("parallel", .{
        .root_source_file = b.path("src/parallel.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "build_options", .module = build_options.createModule() },
        },
    });
    if (spice_mod) |sm| {
        parallel_mod.addImport("spice", sm);
    }


    // ============================================================
    // Main Public API Modules
    // ============================================================

    // zigstr.zig - New unified entry point
    const zigstr_mod = b.addModule("zigstr", .{
        .root_source_file = b.path("src/zigstr.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            // Core types
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            // Encodings
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "utf16", .module = utf16_mod },
            .{ .name = "utf32", .module = utf32_mod },
            .{ .name = "ascii", .module = ascii_mod },
            .{ .name = "latin1", .module = latin1_mod },
            // Unicode
            .{ .name = "categories", .module = categories_mod },
            .{ .name = "normalization", .module = normalization_mod },
            .{ .name = "grapheme", .module = grapheme_mod },
            .{ .name = "word", .module = word_mod },
            .{ .name = "sentence", .module = sentence_mod },
            .{ .name = "case", .module = case_mod },
            .{ .name = "collation", .module = collation_mod },
            .{ .name = "scripts", .module = scripts_mod },
            .{ .name = "line_break", .module = line_break_mod },
            .{ .name = "bidi", .module = bidi_mod },
            .{ .name = "identifier", .module = identifier_mod },
            // Encoding utilities
            .{ .name = "detection", .module = detection_mod },
            .{ .name = "bom", .module = bom_mod },
            .{ .name = "transcoding", .module = transcoding_mod },
            // Iterators
            .{ .name = "iterator", .module = iterator_mod },
            // Operations
            .{ .name = "search", .module = search_mod },
            .{ .name = "comparison", .module = comparison_mod },
            .{ .name = "manipulation", .module = manipulation_mod },
            // Conversion
            .{ .name = "numeric", .module = numeric_mod },
            .{ .name = "formatting", .module = formatting_mod },
            // String types
            .{ .name = "string", .module = string_mod },
            .{ .name = "string16", .module = string16_mod },
            .{ .name = "builder", .module = builder_mod },
            // Utilities
            .{ .name = "simd", .module = simd_mod },
            .{ .name = "pool", .module = pool_mod },
            .{ .name = "rope", .module = rope_mod },
            .{ .name = "mmap", .module = mmap_mod },
            .{ .name = "lazy_norm", .module = lazy_norm_mod },
            // Extended features
            .{ .name = "regex", .module = regex_mod },
            .{ .name = "fuzzy", .module = fuzzy_mod },
            .{ .name = "phonetic", .module = phonetic_mod },
            .{ .name = "locale", .module = locale_mod },
            .{ .name = "icu", .module = icu_mod },
            // Legacy encodings
            .{ .name = "windows_codepage", .module = windows_codepage_mod },
            .{ .name = "iso8859", .module = iso8859_mod },
            .{ .name = "chinese_encoding", .module = chinese_encoding_mod },
            .{ .name = "japanese_encoding", .module = japanese_encoding_mod },
            .{ .name = "korean_encoding", .module = korean_encoding_mod },
            .{ .name = "big5", .module = big5_mod },
            // Parallel operations
            .{ .name = "parallel", .module = parallel_mod },
        },
    });

    // lib.zig - Legacy entry point (re-exports for compatibility)
    const strings_mod = b.addModule("strings", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            // Core types
            .{ .name = "types", .module = types_mod },
            .{ .name = "codepoint", .module = codepoint_mod },
            // Encodings
            .{ .name = "utf8", .module = utf8_mod },
            .{ .name = "utf16", .module = utf16_mod },
            .{ .name = "utf32", .module = utf32_mod },
            .{ .name = "ascii", .module = ascii_mod },
            .{ .name = "latin1", .module = latin1_mod },
            // Unicode
            .{ .name = "categories", .module = categories_mod },
            .{ .name = "normalization", .module = normalization_mod },
            .{ .name = "grapheme", .module = grapheme_mod },
            .{ .name = "word", .module = word_mod },
            .{ .name = "sentence", .module = sentence_mod },
            .{ .name = "case", .module = case_mod },
            .{ .name = "collation", .module = collation_mod },
            .{ .name = "scripts", .module = scripts_mod },
            .{ .name = "line_break", .module = line_break_mod },
            .{ .name = "bidi", .module = bidi_mod },
            .{ .name = "identifier", .module = identifier_mod },
            // Encoding utilities
            .{ .name = "detection", .module = detection_mod },
            .{ .name = "bom", .module = bom_mod },
            .{ .name = "transcoding", .module = transcoding_mod },
            // Iterators
            .{ .name = "iterator", .module = iterator_mod },
            // Operations
            .{ .name = "search", .module = search_mod },
            .{ .name = "comparison", .module = comparison_mod },
            .{ .name = "manipulation", .module = manipulation_mod },
            // Conversion
            .{ .name = "numeric", .module = numeric_mod },
            .{ .name = "formatting", .module = formatting_mod },
            // String types
            .{ .name = "string", .module = string_mod },
            .{ .name = "string16", .module = string16_mod },
            .{ .name = "builder", .module = builder_mod },
            // Utilities
            .{ .name = "simd", .module = simd_mod },
            .{ .name = "pool", .module = pool_mod },
            .{ .name = "rope", .module = rope_mod },
            .{ .name = "mmap", .module = mmap_mod },
            .{ .name = "lazy_norm", .module = lazy_norm_mod },
            // Extended features
            .{ .name = "regex", .module = regex_mod },
            .{ .name = "fuzzy", .module = fuzzy_mod },
            .{ .name = "phonetic", .module = phonetic_mod },
            .{ .name = "locale", .module = locale_mod },
            .{ .name = "icu", .module = icu_mod },
            // Legacy encodings
            .{ .name = "windows_codepage", .module = windows_codepage_mod },
            .{ .name = "iso8859", .module = iso8859_mod },
            .{ .name = "chinese_encoding", .module = chinese_encoding_mod },
            .{ .name = "japanese_encoding", .module = japanese_encoding_mod },
            .{ .name = "korean_encoding", .module = korean_encoding_mod },
            .{ .name = "big5", .module = big5_mod },
            // Parallel operations
            .{ .name = "parallel", .module = parallel_mod },
        },
    });

    // ============================================================
    // Unit Tests
    // ============================================================

    const test_step = b.step("test", "Run all unit tests");

    // Core module tests
    const test_types = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/types.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.dependOn(&b.addRunArtifact(test_types).step);

    const test_codepoint = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/codepoint.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(test_codepoint).step);

    const test_utf8 = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/utf8.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(test_utf8).step);

    const test_utf16 = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/utf16.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(test_utf16).step);

    const test_utf32 = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/utf32.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(test_utf32).step);

    const test_ascii = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ascii.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(test_ascii).step);

    const test_latin1 = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/latin1.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
            },
        }),
    });
    test_step.dependOn(&b.addRunArtifact(test_latin1).step);

    // Main library test
    const test_lib = b.addTest(.{
        .root_module = strings_mod,
    });
    test_step.dependOn(&b.addRunArtifact(test_lib).step);

    // ============================================================
    // Encoding Tests
    // ============================================================

    const test_encoding_step = b.step("test-encoding", "Run encoding tests");

    const test_transcoding = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/encoding/transcoding.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "utf8", .module = utf8_mod },
                .{ .name = "utf16", .module = utf16_mod },
                .{ .name = "utf32", .module = utf32_mod },
                .{ .name = "ascii", .module = ascii_mod },
                .{ .name = "latin1", .module = latin1_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
            },
        }),
    });
    test_encoding_step.dependOn(&b.addRunArtifact(test_transcoding).step);

    // ============================================================
    // Unicode Tests
    // ============================================================

    const test_unicode_step = b.step("test-unicode", "Run Unicode tests");

    const test_categories = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/unicode/categories.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
            },
        }),
    });
    test_unicode_step.dependOn(&b.addRunArtifact(test_categories).step);

    const test_normalization = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/unicode/normalization.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
                .{ .name = "categories", .module = categories_mod },
                .{ .name = "ucd_ccc", .module = ucd_ccc_mod },
                .{ .name = "ucd_decomposition", .module = ucd_decomp_mod },
                .{ .name = "ucd_composition", .module = ucd_comp_mod },
            },
        }),
    });
    test_unicode_step.dependOn(&b.addRunArtifact(test_normalization).step);

    const test_grapheme = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/unicode/grapheme.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
                .{ .name = "categories", .module = categories_mod },
            },
        }),
    });
    test_unicode_step.dependOn(&b.addRunArtifact(test_grapheme).step);

    const test_case = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/unicode/case.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
                .{ .name = "categories", .module = categories_mod },
            },
        }),
    });
    test_unicode_step.dependOn(&b.addRunArtifact(test_case).step);

    const test_scripts = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/unicode/scripts.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "ucd_scripts", .module = ucd_scripts_mod },
            },
        }),
    });
    test_unicode_step.dependOn(&b.addRunArtifact(test_scripts).step);

    const test_line_break = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/unicode/line_break.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "ucd_line_break", .module = ucd_line_break_mod },
            },
        }),
    });
    test_unicode_step.dependOn(&b.addRunArtifact(test_line_break).step);

    const test_bidi = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/unicode/bidi.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "ucd_bidi", .module = ucd_bidi_mod },
            },
        }),
    });
    test_unicode_step.dependOn(&b.addRunArtifact(test_bidi).step);

    const test_identifier = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/unicode/identifier.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "ucd_identifier", .module = ucd_identifier_mod },
            },
        }),
    });
    test_unicode_step.dependOn(&b.addRunArtifact(test_identifier).step);

    // ============================================================
    // Operations Tests
    // ============================================================

    const test_ops_step = b.step("test-ops", "Run operations tests");

    const test_search = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ops/search.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
                .{ .name = "utf8", .module = utf8_mod },
                .{ .name = "iterator", .module = iterator_mod },
            },
        }),
    });
    test_ops_step.dependOn(&b.addRunArtifact(test_search).step);

    const test_manipulation = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ops/manipulation.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
                .{ .name = "utf8", .module = utf8_mod },
                .{ .name = "iterator", .module = iterator_mod },
                .{ .name = "grapheme", .module = grapheme_mod },
                .{ .name = "categories", .module = categories_mod },
            },
        }),
    });
    test_ops_step.dependOn(&b.addRunArtifact(test_manipulation).step);

    const test_comparison = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/ops/comparison.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "codepoint", .module = codepoint_mod },
                .{ .name = "utf8", .module = utf8_mod },
                .{ .name = "case", .module = case_mod },
                .{ .name = "normalization", .module = normalization_mod },
                .{ .name = "collation", .module = collation_mod },
            },
        }),
    });
    test_ops_step.dependOn(&b.addRunArtifact(test_comparison).step);

    // ============================================================
    // String Type Tests
    // ============================================================

    const test_string_step = b.step("test-string", "Run string type tests");

    const test_string = b.addTest(.{
        .root_module = string_mod,
    });
    test_string_step.dependOn(&b.addRunArtifact(test_string).step);

    const test_string16 = b.addTest(.{
        .root_module = string16_mod,
    });
    test_string_step.dependOn(&b.addRunArtifact(test_string16).step);

    const test_builder = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/builder.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "types", .module = types_mod },
                .{ .name = "utf8", .module = utf8_mod },
                .{ .name = "string", .module = string_mod },
            },
        }),
    });
    test_string_step.dependOn(&b.addRunArtifact(test_builder).step);

    // ============================================================
    // Integration Tests
    // ============================================================

    const test_integration_step = b.step("test-integration", "Run integration tests");

    const test_vectors = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/vectors.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "strings", .module = strings_mod },
            },
        }),
    });
    test_integration_step.dependOn(&b.addRunArtifact(test_vectors).step);

    const test_acceptance = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/acceptance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "strings", .module = strings_mod },
            },
        }),
    });
    test_integration_step.dependOn(&b.addRunArtifact(test_acceptance).step);

    // ============================================================
    // Comprehensive Tests
    // ============================================================

    const test_comprehensive_step = b.step("test-comprehensive", "Run comprehensive test suite");

    // Unicode Conformance Tests (UAX #15, #29, #14, #9, #31, #24)
    const test_unicode_conformance = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/unicode_conformance.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "strings", .module = strings_mod },
            },
        }),
    });
    test_comprehensive_step.dependOn(&b.addRunArtifact(test_unicode_conformance).step);

    // Encoding Round-Trip Tests
    const test_encoding_roundtrip = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/encoding_roundtrip.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "strings", .module = strings_mod },
            },
        }),
    });
    test_comprehensive_step.dependOn(&b.addRunArtifact(test_encoding_roundtrip).step);

    // Edge Cases and Stress Tests
    const test_edge_cases = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/edge_cases.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "strings", .module = strings_mod },
            },
        }),
    });
    test_comprehensive_step.dependOn(&b.addRunArtifact(test_edge_cases).step);

    // Extended Features Tests (regex, fuzzy, phonetic, locale, ICU)
    const test_extended_features = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/extended_features.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "strings", .module = strings_mod },
            },
        }),
    });
    test_comprehensive_step.dependOn(&b.addRunArtifact(test_extended_features).step);

    // Legacy Encoding Tests (Windows CP, ISO-8859, CJK)
    const test_legacy_encodings = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/legacy_encodings.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "strings", .module = strings_mod },
            },
        }),
    });
    test_comprehensive_step.dependOn(&b.addRunArtifact(test_legacy_encodings).step);

    // ============================================================
    // ZigStr Module Tests
    // ============================================================

    const test_zigstr_step = b.step("test-zigstr", "Run zigstr module tests");

    const test_zigstr = b.addTest(.{
        .root_module = zigstr_mod,
    });
    test_zigstr_step.dependOn(&b.addRunArtifact(test_zigstr).step);

    // ============================================================
    // All Tests Step
    // ============================================================

    const test_all_step = b.step("test-all", "Run all tests");
    test_all_step.dependOn(test_step);
    test_all_step.dependOn(test_encoding_step);
    test_all_step.dependOn(test_unicode_step);
    test_all_step.dependOn(test_ops_step);
    test_all_step.dependOn(test_string_step);
    test_all_step.dependOn(test_integration_step);
    test_all_step.dependOn(test_zigstr_step);
    test_all_step.dependOn(test_comprehensive_step);

    // ============================================================
    // Benchmarks
    // ============================================================

    const bench_step = b.step("bench", "Run benchmarks");

    // Create benchmark infrastructure module
    const bench_infra_mod = b.addModule("bench_infra", .{
        .root_source_file = b.path("bench/bench.zig"),
        .target = target,
        .optimize = optimize,
    });

    const bench_exe = b.addExecutable(.{
        .name = "bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "bench", .module = bench_infra_mod },
                .{ .name = "utf8", .module = utf8_mod },
                .{ .name = "utf16", .module = utf16_mod },
                .{ .name = "simd", .module = simd_mod },
                .{ .name = "normalization", .module = normalization_mod },
                .{ .name = "grapheme", .module = grapheme_mod },
                .{ .name = "case", .module = case_mod },
                .{ .name = "search", .module = search_mod },
                .{ .name = "manipulation", .module = manipulation_mod },
            },
        }),
    });

    const run_bench = b.addRunArtifact(bench_exe);
    bench_step.dependOn(&run_bench.step);

    // Also add bench-install to just build without running
    const bench_install_step = b.step("bench-install", "Build benchmark executable");
    const bench_install = b.addInstallArtifact(bench_exe, .{});
    bench_install_step.dependOn(&bench_install.step);

    // Parallel benchmark
    const parallel_bench_step = b.step("bench-parallel", "Run parallel operations benchmark");
    const parallel_bench_exe = b.addExecutable(.{
        .name = "parallel_bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("bench/parallel_bench.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "parallel", .module = parallel_mod },
            },
        }),
    });
    const run_parallel_bench = b.addRunArtifact(parallel_bench_exe);
    parallel_bench_step.dependOn(&run_parallel_bench.step);

    // ============================================================
    // Format Check
    // ============================================================

    const fmt = b.addFmt(.{
        .paths = &.{ "src", "tests", "build.zig" },
        .check = true,
    });

    const fmt_step = b.step("fmt-check", "Check formatting");
    fmt_step.dependOn(&fmt.step);
}
