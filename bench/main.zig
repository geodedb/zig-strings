//! ZigStr Benchmark Suite
//!
//! Run with: zig build bench
//! For release mode: zig build bench -Doptimize=ReleaseFast

const std = @import("std");
const bench = @import("bench");

// Import string library modules
const utf8 = @import("utf8");
const utf16 = @import("utf16");
const simd = @import("simd");
const normalization = @import("normalization");
const grapheme = @import("grapheme");
const case = @import("case");
const search = @import("search");
const manipulation = @import("manipulation");

const TestData = bench.TestData;
const runBench = bench.runBenchmark;
const config = bench.Config{};

// ============================================================
// UTF-8 Benchmarks
// ============================================================

fn benchUtf8Validation() void {
    std.mem.doNotOptimizeAway(utf8.isValid(TestData.ascii_1kb));
}

fn benchUtf8ValidationCjk() void {
    std.mem.doNotOptimizeAway(utf8.isValid(TestData.cjk));
}

fn benchUtf8Decode() void {
    var iter = utf8.iterator(TestData.mixed_utf8);
    while (iter.next()) |cp| {
        std.mem.doNotOptimizeAway(cp);
    }
}

fn benchUtf8CountCodepoints() void {
    std.mem.doNotOptimizeAway(utf8.countCodepoints(TestData.mixed_utf8));
}

fn benchUtf8CountCodepointsCjk() void {
    std.mem.doNotOptimizeAway(utf8.countCodepoints(TestData.cjk));
}

// ============================================================
// SIMD Benchmarks
// ============================================================

fn benchSimdFindByte() void {
    std.mem.doNotOptimizeAway(simd.findByte(TestData.ascii_1kb, 'z'));
}

fn benchScalarFindByte() void {
    std.mem.doNotOptimizeAway(std.mem.indexOfScalar(u8, TestData.ascii_1kb, 'z'));
}

fn benchSimdIsAllAscii() void {
    std.mem.doNotOptimizeAway(simd.isAllAscii(TestData.ascii_1kb));
}

fn benchScalarIsAllAscii() void {
    var result = true;
    for (TestData.ascii_1kb) |b| {
        if (b > 127) {
            result = false;
            break;
        }
    }
    std.mem.doNotOptimizeAway(result);
}

fn benchSimdCountByte() void {
    std.mem.doNotOptimizeAway(simd.countByte(TestData.ascii_1kb, 'e'));
}

fn benchScalarCountByte() void {
    std.mem.doNotOptimizeAway(std.mem.count(u8, TestData.ascii_1kb, "e"));
}

var lower_buf: [TestData.ascii_1kb.len]u8 = undefined;

fn benchSimdToLower() void {
    simd.toLowerAscii(&lower_buf, TestData.ascii_1kb);
    std.mem.doNotOptimizeAway(&lower_buf);
}

fn benchScalarToLower() void {
    for (TestData.ascii_1kb, 0..) |c, i| {
        lower_buf[i] = if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
    std.mem.doNotOptimizeAway(&lower_buf);
}

fn benchSimdEqual() void {
    std.mem.doNotOptimizeAway(simd.equal(TestData.ascii_1kb, TestData.ascii_1kb));
}

fn benchScalarEqual() void {
    std.mem.doNotOptimizeAway(std.mem.eql(u8, TestData.ascii_1kb, TestData.ascii_1kb));
}

// ============================================================
// Normalization Benchmarks
// ============================================================

var norm_arena: std.heap.ArenaAllocator = undefined;

fn benchNfdNormalize() void {
    const result = normalization.normalize(norm_arena.allocator(), TestData.nfc_text, .nfd) catch return;
    std.mem.doNotOptimizeAway(result);
    _ = norm_arena.reset(.retain_capacity);
}

fn benchNfcNormalize() void {
    const result = normalization.normalize(norm_arena.allocator(), TestData.nfd_text, .nfc) catch return;
    std.mem.doNotOptimizeAway(result);
    _ = norm_arena.reset(.retain_capacity);
}

fn benchIsNormalized() void {
    std.mem.doNotOptimizeAway(normalization.isNormalized(TestData.nfc_text, .nfc));
}

// ============================================================
// Grapheme Benchmarks
// ============================================================

fn benchGraphemeCount() void {
    std.mem.doNotOptimizeAway(grapheme.count(TestData.mixed_utf8));
}

fn benchGraphemeCountEmoji() void {
    std.mem.doNotOptimizeAway(grapheme.count(TestData.emoji));
}

fn benchGraphemeIterate() void {
    var iter = grapheme.iterator(TestData.mixed_utf8);
    while (iter.next()) |g| {
        std.mem.doNotOptimizeAway(g);
    }
}

// ============================================================
// Case Conversion Benchmarks
// ============================================================

var case_arena: std.heap.ArenaAllocator = undefined;

fn benchToLowerUnicode() void {
    const result = case.toLowerString(case_arena.allocator(), TestData.latin_extended) catch return;
    std.mem.doNotOptimizeAway(result);
    _ = case_arena.reset(.retain_capacity);
}

fn benchToUpperUnicode() void {
    const result = case.toUpperString(case_arena.allocator(), TestData.latin_extended) catch return;
    std.mem.doNotOptimizeAway(result);
    _ = case_arena.reset(.retain_capacity);
}

fn benchCaseConvertCodepoint() void {
    // Benchmark codepoint-level case conversion
    var iter = utf8.iterator(TestData.latin_extended);
    while (iter.next()) |cp| {
        std.mem.doNotOptimizeAway(case.toLower(cp));
    }
}

// ============================================================
// Search Benchmarks
// ============================================================

fn benchContains() void {
    std.mem.doNotOptimizeAway(search.contains(TestData.ascii_1kb, "lazy dog"));
}

fn benchContainsMissing() void {
    std.mem.doNotOptimizeAway(search.contains(TestData.ascii_1kb, "xyz123"));
}

fn benchIndexOf() void {
    std.mem.doNotOptimizeAway(search.indexOf(TestData.ascii_1kb, "lazy"));
}

fn benchLastIndexOf() void {
    std.mem.doNotOptimizeAway(search.lastIndexOf(TestData.ascii_1kb, "the"));
}

fn benchCount() void {
    std.mem.doNotOptimizeAway(search.count(TestData.ascii_1kb, "the"));
}

// ============================================================
// Manipulation Benchmarks
// ============================================================

var manip_arena: std.heap.ArenaAllocator = undefined;

fn benchSplit() void {
    const parts = manipulation.split(manip_arena.allocator(), TestData.ascii_1kb, " ") catch return;
    std.mem.doNotOptimizeAway(parts);
    _ = manip_arena.reset(.retain_capacity);
}

fn benchTrim() void {
    std.mem.doNotOptimizeAway(manipulation.trim(TestData.ascii_1kb));
}

fn benchReplace() void {
    const result = manipulation.replace(manip_arena.allocator(), TestData.ascii_1kb, "the", "THE") catch return;
    std.mem.doNotOptimizeAway(result);
    _ = manip_arena.reset(.retain_capacity);
}

// ============================================================
// Main Entry Point
// ============================================================

pub fn main() void {
    bench.printSystemInfo();

    // Initialize allocators for benchmarks that need them
    norm_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer norm_arena.deinit();
    case_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer case_arena.deinit();
    manip_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer manip_arena.deinit();

    // UTF-8 Benchmarks
    bench.printHeader("UTF-8 Operations");
    runBench("utf8.isValid (ASCII 1KB)", benchUtf8Validation, TestData.ascii_1kb.len, config).print();
    runBench("utf8.isValid (CJK)", benchUtf8ValidationCjk, TestData.cjk.len, config).print();
    runBench("utf8.decode iteration", benchUtf8Decode, TestData.mixed_utf8.len, config).print();
    runBench("utf8.countCodepoints (Mixed)", benchUtf8CountCodepoints, TestData.mixed_utf8.len, config).print();
    runBench("utf8.countCodepoints (CJK)", benchUtf8CountCodepointsCjk, TestData.cjk.len, config).print();

    // SIMD vs Scalar Comparison
    bench.printHeader("SIMD vs Scalar Comparison");
    runBench("simd.findByte (1KB)", benchSimdFindByte, TestData.ascii_1kb.len, config).print();
    runBench("scalar findByte (1KB)", benchScalarFindByte, TestData.ascii_1kb.len, config).print();
    runBench("simd.isAllAscii (1KB)", benchSimdIsAllAscii, TestData.ascii_1kb.len, config).print();
    runBench("scalar isAllAscii (1KB)", benchScalarIsAllAscii, TestData.ascii_1kb.len, config).print();
    runBench("simd.countByte (1KB)", benchSimdCountByte, TestData.ascii_1kb.len, config).print();
    runBench("scalar countByte (1KB)", benchScalarCountByte, TestData.ascii_1kb.len, config).print();
    runBench("simd.toLowerAscii (1KB)", benchSimdToLower, TestData.ascii_1kb.len, config).print();
    runBench("scalar toLower (1KB)", benchScalarToLower, TestData.ascii_1kb.len, config).print();
    runBench("simd.equal (1KB)", benchSimdEqual, TestData.ascii_1kb.len, config).print();
    runBench("scalar equal (1KB)", benchScalarEqual, TestData.ascii_1kb.len, config).print();

    // Normalization Benchmarks
    bench.printHeader("Unicode Normalization");
    runBench("NFD normalize", benchNfdNormalize, TestData.nfc_text.len, config).print();
    runBench("NFC normalize", benchNfcNormalize, TestData.nfd_text.len, config).print();
    runBench("isNormalized check", benchIsNormalized, TestData.nfc_text.len, config).print();

    // Grapheme Benchmarks
    bench.printHeader("Grapheme Operations");
    runBench("grapheme.count (Mixed)", benchGraphemeCount, TestData.mixed_utf8.len, config).print();
    runBench("grapheme.count (Emoji)", benchGraphemeCountEmoji, TestData.emoji.len, config).print();
    runBench("grapheme.iterate (Mixed)", benchGraphemeIterate, TestData.mixed_utf8.len, config).print();

    // Case Conversion Benchmarks
    bench.printHeader("Case Conversion");
    runBench("case.toLowerString (Unicode)", benchToLowerUnicode, TestData.latin_extended.len, config).print();
    runBench("case.toUpperString (Unicode)", benchToUpperUnicode, TestData.latin_extended.len, config).print();
    runBench("case.toLower (per codepoint)", benchCaseConvertCodepoint, TestData.latin_extended.len, config).print();

    // Search Benchmarks
    bench.printHeader("Search Operations");
    runBench("search.contains (found)", benchContains, TestData.ascii_1kb.len, config).print();
    runBench("search.contains (not found)", benchContainsMissing, TestData.ascii_1kb.len, config).print();
    runBench("search.indexOf", benchIndexOf, TestData.ascii_1kb.len, config).print();
    runBench("search.lastIndexOf", benchLastIndexOf, TestData.ascii_1kb.len, config).print();
    runBench("search.count", benchCount, TestData.ascii_1kb.len, config).print();

    // Manipulation Benchmarks
    bench.printHeader("String Manipulation");
    runBench("manipulation.split (1KB)", benchSplit, TestData.ascii_1kb.len, config).print();
    runBench("manipulation.trim", benchTrim, TestData.ascii_1kb.len, config).print();
    runBench("manipulation.replace", benchReplace, TestData.ascii_1kb.len, config).print();

    std.debug.print("\nBenchmarks complete.\n", .{});
}
