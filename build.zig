// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

const std = @import("std");

/// Creates a named build module with the given source file and import
/// dependencies. Centralizes the repetitive target/optimize/imports
/// boilerplate that every module declaration shares.
fn addLibModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    name: []const u8,
    source: []const u8,
    imports: []const std.Build.Module.Import,
) *std.Build.Module {
    return b.addModule(name, .{
        .root_source_file = b.path(source),
        .target = target,
        .optimize = optimize,
        .imports = imports,
    });
}

/// Creates a test compilation unit for a source file with the given
/// import dependencies. Centralizes the repetitive target/optimize
/// boilerplate that every test declaration shares.
fn addLibTest(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    source: []const u8,
    imports: []const std.Build.Module.Import,
) *std.Build.Step.Compile {
    return b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path(source),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        }),
    });
}

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

    const types_mod = addLibModule(b, target, optimize, "types", "src/types.zig", &.{});

    const codepoint_mod = addLibModule(b, target, optimize, "codepoint", "src/codepoint.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    // ============================================================
    // Encoding Modules - UTF-8, UTF-16, UTF-32, ASCII, Latin-1
    // ============================================================

    const utf8_mod = addLibModule(b, target, optimize, "utf8", "src/utf8.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    });

    const utf16_mod = addLibModule(b, target, optimize, "utf16", "src/utf16.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    });

    const utf32_mod = addLibModule(b, target, optimize, "utf32", "src/utf32.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    });

    const ascii_mod = addLibModule(b, target, optimize, "ascii", "src/ascii.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const latin1_mod = addLibModule(b, target, optimize, "latin1", "src/latin1.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    });

    // ============================================================
    // Unicode Modules - Categories, Normalization, Boundaries
    // ============================================================

    const categories_mod = addLibModule(b, target, optimize, "categories", "src/unicode/categories.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    });

    // ============================================================
    // Unicode Data Modules - Generated from UCD
    // ============================================================

    const ucd_ccc_mod = addLibModule(b, target, optimize, "ucd_ccc", "src/unicode/data/ccc.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const ucd_decomp_mod = addLibModule(b, target, optimize, "ucd_decomposition", "src/unicode/data/decomposition.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const ucd_comp_mod = addLibModule(b, target, optimize, "ucd_composition", "src/unicode/data/composition.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const ucd_nfc_qc_mod = addLibModule(b, target, optimize, "ucd_nfc_qc", "src/unicode/data/nfc_qc.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const ucd_nfkc_qc_mod = addLibModule(b, target, optimize, "ucd_nfkc_qc", "src/unicode/data/nfkc_qc.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const ucd_scripts_mod = addLibModule(b, target, optimize, "ucd_scripts", "src/unicode/data/scripts.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const ucd_line_break_mod = addLibModule(b, target, optimize, "ucd_line_break", "src/unicode/data/line_break.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const ucd_bidi_mod = addLibModule(b, target, optimize, "ucd_bidi", "src/unicode/data/bidi.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const ucd_identifier_mod = addLibModule(b, target, optimize, "ucd_identifier", "src/unicode/data/identifier.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const ucd_general_category_mod = addLibModule(b, target, optimize, "ucd_general_category", "src/unicode/data/general_category.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const ucd_grapheme_break_mod = addLibModule(b, target, optimize, "ucd_grapheme_break", "src/unicode/data/grapheme_break.zig", &.{});

    // Wire generated UCD General Category table into categories module
    categories_mod.addImport("ucd_general_category", ucd_general_category_mod);

    const normalization_mod = addLibModule(b, target, optimize, "normalization", "src/unicode/normalization.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "categories", .module = categories_mod },
        .{ .name = "ucd_ccc", .module = ucd_ccc_mod },
        .{ .name = "ucd_decomposition", .module = ucd_decomp_mod },
        .{ .name = "ucd_composition", .module = ucd_comp_mod },
        .{ .name = "ucd_nfc_qc", .module = ucd_nfc_qc_mod },
        .{ .name = "ucd_nfkc_qc", .module = ucd_nfkc_qc_mod },
    });

    const grapheme_mod = addLibModule(b, target, optimize, "grapheme", "src/unicode/grapheme.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "categories", .module = categories_mod },
    });
    // Wire generated UCD Grapheme Break table into grapheme module
    grapheme_mod.addImport("ucd_grapheme_break", ucd_grapheme_break_mod);

    const word_mod = addLibModule(b, target, optimize, "word", "src/unicode/word.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "categories", .module = categories_mod },
    });

    const sentence_mod = addLibModule(b, target, optimize, "sentence", "src/unicode/sentence.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "categories", .module = categories_mod },
    });

    const case_mod = addLibModule(b, target, optimize, "case", "src/unicode/case.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "categories", .module = categories_mod },
    });

    const collation_mod = addLibModule(b, target, optimize, "collation", "src/unicode/collation.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "categories", .module = categories_mod },
        .{ .name = "normalization", .module = normalization_mod },
    });

    const scripts_mod = addLibModule(b, target, optimize, "scripts", "src/unicode/scripts.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "ucd_scripts", .module = ucd_scripts_mod },
    });

    const line_break_mod = addLibModule(b, target, optimize, "line_break", "src/unicode/line_break.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "ucd_line_break", .module = ucd_line_break_mod },
    });

    const bidi_mod = addLibModule(b, target, optimize, "bidi", "src/unicode/bidi.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "ucd_bidi", .module = ucd_bidi_mod },
    });

    const identifier_mod = addLibModule(b, target, optimize, "identifier", "src/unicode/identifier.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "ucd_identifier", .module = ucd_identifier_mod },
    });

    // ============================================================
    // Encoding Detection and Conversion
    // ============================================================

    const detection_mod = addLibModule(b, target, optimize, "detection", "src/encoding/detection.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "utf16", .module = utf16_mod },
        .{ .name = "ascii", .module = ascii_mod },
    });

    const bom_mod = addLibModule(b, target, optimize, "bom", "src/encoding/bom.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const transcoding_mod = addLibModule(b, target, optimize, "transcoding", "src/encoding/transcoding.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "utf16", .module = utf16_mod },
        .{ .name = "utf32", .module = utf32_mod },
        .{ .name = "ascii", .module = ascii_mod },
        .{ .name = "latin1", .module = latin1_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    });

    // ============================================================
    // Iterator Modules
    // ============================================================

    const iterator_mod = addLibModule(b, target, optimize, "iterator", "src/iterator.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "utf16", .module = utf16_mod },
        .{ .name = "grapheme", .module = grapheme_mod },
        .{ .name = "word", .module = word_mod },
        .{ .name = "sentence", .module = sentence_mod },
    });

    // ============================================================
    // Core String Operations
    // ============================================================

    const search_mod = addLibModule(b, target, optimize, "search", "src/ops/search.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "iterator", .module = iterator_mod },
    });

    const comparison_mod = addLibModule(b, target, optimize, "comparison", "src/ops/comparison.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "case", .module = case_mod },
        .{ .name = "normalization", .module = normalization_mod },
        .{ .name = "collation", .module = collation_mod },
    });

    const manipulation_mod = addLibModule(b, target, optimize, "manipulation", "src/ops/manipulation.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "iterator", .module = iterator_mod },
        .{ .name = "grapheme", .module = grapheme_mod },
        .{ .name = "categories", .module = categories_mod },
    });

    // ============================================================
    // Conversion Modules
    // ============================================================

    const numeric_mod = addLibModule(b, target, optimize, "numeric", "src/conversion/numeric.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "ascii", .module = ascii_mod },
    });

    const formatting_mod = addLibModule(b, target, optimize, "formatting", "src/conversion/formatting.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "numeric", .module = numeric_mod },
    });

    // ============================================================
    // High-Level String Types
    // ============================================================

    const string_mod = addLibModule(b, target, optimize, "string", "src/string.zig", &.{
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
    });

    const string16_mod = addLibModule(b, target, optimize, "string16", "src/string16.zig", &.{
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
    });

    const builder_mod = addLibModule(b, target, optimize, "builder", "src/builder.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "string", .module = string_mod },
    });

    // ============================================================
    // Utility Modules
    // ============================================================

    const simd_mod = addLibModule(b, target, optimize, "simd", "src/util/simd.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    // Wire SIMD acceleration into case and normalization modules for fast ASCII paths
    case_mod.addImport("simd", simd_mod);
    normalization_mod.addImport("simd", simd_mod);

    const pool_mod = addLibModule(b, target, optimize, "pool", "src/util/pool.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "string", .module = string_mod },
    });

    const rope_mod = addLibModule(b, target, optimize, "rope", "src/util/rope.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const mmap_mod = addLibModule(b, target, optimize, "mmap", "src/util/mmap.zig", &.{
        .{ .name = "types", .module = types_mod },
    });

    const lazy_norm_mod = addLibModule(b, target, optimize, "lazy_norm", "src/util/lazy_norm.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "normalization", .module = normalization_mod },
    });

    // ============================================================
    // Extended Features (Phase 7)
    // ============================================================

    const regex_mod = addLibModule(b, target, optimize, "regex", "src/extended/regex.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "categories", .module = categories_mod },
    });

    const fuzzy_mod = addLibModule(b, target, optimize, "fuzzy", "src/extended/fuzzy.zig", &.{});
    const phonetic_mod = addLibModule(b, target, optimize, "phonetic", "src/extended/phonetic.zig", &.{});
    const locale_mod = addLibModule(b, target, optimize, "locale", "src/extended/locale.zig", &.{});

    const icu_mod = addLibModule(b, target, optimize, "icu", "src/extended/icu.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "normalization", .module = normalization_mod },
        .{ .name = "grapheme", .module = grapheme_mod },
        .{ .name = "word", .module = word_mod },
        .{ .name = "sentence", .module = sentence_mod },
        .{ .name = "collation", .module = collation_mod },
        .{ .name = "case", .module = case_mod },
    });

    // ============================================================
    // Legacy Encoding Modules (Phase 8)
    // ============================================================

    const legacy_encoding_errors_mod = addLibModule(b, target, optimize, "legacy_encoding_errors", "src/encoding/legacy/errors.zig", &.{});

    const legacy_err_import = [_]std.Build.Module.Import{
        .{ .name = "legacy_encoding_errors", .module = legacy_encoding_errors_mod },
    };

    const windows_codepage_mod = addLibModule(b, target, optimize, "windows_codepage", "src/encoding/legacy/windows.zig", &legacy_err_import);
    const iso8859_mod = addLibModule(b, target, optimize, "iso8859", "src/encoding/legacy/iso8859.zig", &legacy_err_import);
    const chinese_encoding_mod = addLibModule(b, target, optimize, "chinese_encoding", "src/encoding/legacy/chinese.zig", &legacy_err_import);
    const japanese_encoding_mod = addLibModule(b, target, optimize, "japanese_encoding", "src/encoding/legacy/japanese.zig", &legacy_err_import);
    const korean_encoding_mod = addLibModule(b, target, optimize, "korean_encoding", "src/encoding/legacy/korean.zig", &legacy_err_import);
    const big5_mod = addLibModule(b, target, optimize, "big5", "src/encoding/legacy/big5.zig", &legacy_err_import);

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

    // Shared imports for all public API entry points (zigstr and strings).
    // Defined once to avoid maintaining two identical ~60-line import lists.
    const public_api_imports = [_]std.Build.Module.Import{
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
    };

    // zigstr.zig - New unified entry point
    const zigstr_mod = b.addModule("zigstr", .{
        .root_source_file = b.path("src/zigstr.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &public_api_imports,
    });

    // lib.zig - Legacy entry point (re-exports for compatibility)
    const strings_mod = b.addModule("strings", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &public_api_imports,
    });

    // ============================================================
    // Unit Tests
    // ============================================================

    const test_step = b.step("test", "Run all unit tests");

    // Core module tests
    test_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/types.zig", &.{})).step);
    test_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/codepoint.zig", &.{
        .{ .name = "types", .module = types_mod },
    })).step);
    test_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/utf8.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    })).step);
    test_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/utf16.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    })).step);
    test_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/utf32.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    })).step);
    test_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/ascii.zig", &.{
        .{ .name = "types", .module = types_mod },
    })).step);
    test_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/latin1.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    })).step);

    // Main library test
    const test_lib = b.addTest(.{
        .root_module = strings_mod,
    });
    test_step.dependOn(&b.addRunArtifact(test_lib).step);

    // Parallel module test (special: conditional spice import)
    const test_parallel = addLibTest(b, target, optimize, "src/parallel.zig", &.{
        .{ .name = "build_options", .module = build_options.createModule() },
    });
    if (spice_mod) |sm| {
        test_parallel.root_module.addImport("spice", sm);
    }
    test_step.dependOn(&b.addRunArtifact(test_parallel).step);

    test_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/extended/regex.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "categories", .module = categories_mod },
    })).step);

    // ============================================================
    // Encoding Tests
    // ============================================================

    const test_encoding_step = b.step("test-encoding", "Run encoding tests");

    test_encoding_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/encoding/transcoding.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "utf16", .module = utf16_mod },
        .{ .name = "utf32", .module = utf32_mod },
        .{ .name = "ascii", .module = ascii_mod },
        .{ .name = "latin1", .module = latin1_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
    })).step);

    // ============================================================
    // Unicode Tests
    // ============================================================

    const test_unicode_step = b.step("test-unicode", "Run Unicode tests");

    test_unicode_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/unicode/categories.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "ucd_general_category", .module = ucd_general_category_mod },
    })).step);
    test_unicode_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/unicode/normalization.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "categories", .module = categories_mod },
        .{ .name = "ucd_ccc", .module = ucd_ccc_mod },
        .{ .name = "ucd_decomposition", .module = ucd_decomp_mod },
        .{ .name = "ucd_composition", .module = ucd_comp_mod },
        .{ .name = "ucd_nfc_qc", .module = ucd_nfc_qc_mod },
        .{ .name = "ucd_nfkc_qc", .module = ucd_nfkc_qc_mod },
        .{ .name = "simd", .module = simd_mod },
    })).step);
    test_unicode_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/unicode/grapheme.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "categories", .module = categories_mod },
        .{ .name = "ucd_grapheme_break", .module = ucd_grapheme_break_mod },
    })).step);
    test_unicode_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/unicode/case.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "categories", .module = categories_mod },
        .{ .name = "simd", .module = simd_mod },
    })).step);
    test_unicode_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/unicode/scripts.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "ucd_scripts", .module = ucd_scripts_mod },
    })).step);
    test_unicode_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/unicode/line_break.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "ucd_line_break", .module = ucd_line_break_mod },
    })).step);
    test_unicode_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/unicode/bidi.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "ucd_bidi", .module = ucd_bidi_mod },
    })).step);
    test_unicode_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/unicode/identifier.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "ucd_identifier", .module = ucd_identifier_mod },
    })).step);

    // ============================================================
    // Operations Tests
    // ============================================================

    const test_ops_step = b.step("test-ops", "Run operations tests");

    test_ops_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/ops/search.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "iterator", .module = iterator_mod },
    })).step);
    test_ops_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/ops/manipulation.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "iterator", .module = iterator_mod },
        .{ .name = "grapheme", .module = grapheme_mod },
        .{ .name = "categories", .module = categories_mod },
    })).step);
    test_ops_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/ops/comparison.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "codepoint", .module = codepoint_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "case", .module = case_mod },
        .{ .name = "normalization", .module = normalization_mod },
        .{ .name = "collation", .module = collation_mod },
    })).step);

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

    test_string_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "src/builder.zig", &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "utf8", .module = utf8_mod },
        .{ .name = "string", .module = string_mod },
    })).step);

    // ============================================================
    // Integration Tests
    // ============================================================

    const test_integration_step = b.step("test-integration", "Run integration tests");

    const strings_import = [_]std.Build.Module.Import{
        .{ .name = "strings", .module = strings_mod },
    };
    test_integration_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "tests/vectors.zig", &strings_import)).step);
    test_integration_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "tests/acceptance.zig", &strings_import)).step);

    // ============================================================
    // Comprehensive Tests
    // ============================================================

    const test_comprehensive_step = b.step("test-comprehensive", "Run comprehensive test suite");

    test_comprehensive_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "tests/unicode_conformance.zig", &strings_import)).step);
    test_comprehensive_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "tests/unicode_conformance_vectors.zig", &strings_import)).step);
    test_comprehensive_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "tests/encoding_roundtrip.zig", &strings_import)).step);
    test_comprehensive_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "tests/edge_cases.zig", &strings_import)).step);
    test_comprehensive_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "tests/extended_features.zig", &strings_import)).step);
    test_comprehensive_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "tests/legacy_encodings.zig", &strings_import)).step);

    // ============================================================
    // Unicode Conformance Test Vectors (GAP-0035)
    // ============================================================

    const test_conformance_step = b.step("test-conformance", "Run Unicode conformance test vectors (NormalizationTest.txt, GraphemeBreakTest.txt)");
    test_conformance_step.dependOn(&b.addRunArtifact(addLibTest(b, target, optimize, "tests/unicode_conformance_vectors.zig", &strings_import)).step);

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
    test_all_step.dependOn(test_conformance_step);

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
        .paths = &.{ "src", "tests", "bench", "examples", "build.zig" },
        .check = true,
    });

    const fmt_step = b.step("fmt-check", "Check formatting");
    fmt_step.dependOn(&fmt.step);
}
