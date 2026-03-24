//! Extended Features Tests
//!
//! Tests for extended functionality:
//! - Regular expressions
//! - Fuzzy matching algorithms
//! - Phonetic algorithms
//! - Locale-specific formatting
//! - ICU compatibility layer

const std = @import("std");
const testing = std.testing;
const strings = @import("strings");

// Import extended feature modules
const regex = strings.regex;
const fuzzy = strings.fuzzy;
const phonetic = strings.phonetic;
const locale = strings.locale;
const icu = strings.icu;

// ============================================================================
// Regular Expression Tests
// ============================================================================

test "Regex literal match" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "hello");
    defer re.deinit();

    try testing.expect(re.find("hello world") != null);
    try testing.expect(re.find("goodbye world") == null);
}

test "Regex case insensitive" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "Hello");
    defer re.deinit();

    // By default, match is case-sensitive
    try testing.expect(re.find("hello world") == null);
    try testing.expect(re.find("Hello world") != null);
}

test "Regex dot metacharacter" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "h.llo");
    defer re.deinit();

    try testing.expect(re.find("hello") != null);
    try testing.expect(re.find("hallo") != null);
    try testing.expect(re.find("hxllo") != null);
}

test "Regex star quantifier" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "ab*c");
    defer re.deinit();

    // * means zero or more b's
    try testing.expect(re.find("ac") != null); // zero b's
    try testing.expect(re.find("abc") != null); // one b
    try testing.expect(re.find("abbc") != null); // two b's
    try testing.expect(re.find("abbbc") != null); // three b's
    try testing.expect(re.find("ad") == null); // no match
}

test "Regex plus quantifier" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "ab+c");
    defer re.deinit();

    // + means one or more b's
    try testing.expect(re.find("ac") == null); // zero b's - no match
    try testing.expect(re.find("abc") != null); // one b
    try testing.expect(re.find("abbc") != null); // two b's
    try testing.expect(re.find("abbbc") != null); // three b's
}

test "Regex question quantifier" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "ab?c");
    defer re.deinit();

    // ? means zero or one b
    try testing.expect(re.find("ac") != null); // zero b's
    try testing.expect(re.find("abc") != null); // one b
    try testing.expect(re.find("abbc") == null); // two b's - no match
}

test "Regex character class" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "[aeiou]");
    defer re.deinit();

    try testing.expect(re.find("a") != null);
    try testing.expect(re.find("e") != null);
    try testing.expect(re.find("x") == null);
}

test "Regex negated character class" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "[^aeiou]");
    defer re.deinit();

    try testing.expect(re.find("a") == null);
    try testing.expect(re.find("b") != null);
    try testing.expect(re.find("x") != null);
}

test "Regex digit class" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "\\d+");
    defer re.deinit();

    try testing.expect(re.find("123") != null);
    try testing.expect(re.find("abc") == null);
}

test "Regex word class" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "\\w+");
    defer re.deinit();

    try testing.expect(re.find("hello123") != null);
    try testing.expect(re.find("   ") == null);
}

test "Regex whitespace class" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "\\s+");
    defer re.deinit();

    try testing.expect(re.find("   ") != null);
    try testing.expect(re.find("abc") == null);
}

test "Regex start anchor" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "^hello");
    defer re.deinit();

    try testing.expect(re.find("hello world") != null);
    try testing.expect(re.find("say hello") == null);
}

test "Regex end anchor" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "world$");
    defer re.deinit();

    try testing.expect(re.find("hello world") != null);
    try testing.expect(re.find("world hello") == null);
}

test "Regex alternation" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "cat|dog");
    defer re.deinit();

    // | means either cat OR dog
    try testing.expect(re.find("cat") != null);
    try testing.expect(re.find("dog") != null);
    try testing.expect(re.find("bird") == null);
    try testing.expect(re.find("the cat runs") != null);
    try testing.expect(re.find("the dog runs") != null);
}

test "Regex groups" {
    const allocator = testing.allocator;

    var re = try regex.Regex.compile(allocator, "(ab)+");
    defer re.deinit();

    try testing.expect(re.find("ab") != null);
    try testing.expect(re.find("abab") != null);
}

// ============================================================================
// Fuzzy Matching Tests
// ============================================================================

test "Levenshtein identical strings" {
    const distance = fuzzy.levenshtein("hello", "hello");
    try testing.expectEqual(@as(usize, 0), distance);
}

test "Levenshtein substitution" {
    const distance = fuzzy.levenshtein("hello", "hallo");
    try testing.expectEqual(@as(usize, 1), distance);
}

test "Levenshtein insertion" {
    const distance = fuzzy.levenshtein("hello", "helllo");
    try testing.expectEqual(@as(usize, 1), distance);
}

test "Levenshtein deletion" {
    const distance = fuzzy.levenshtein("hello", "helo");
    try testing.expectEqual(@as(usize, 1), distance);
}

test "Levenshtein completely different" {
    const distance = fuzzy.levenshtein("abc", "xyz");
    try testing.expectEqual(@as(usize, 3), distance);
}

test "Levenshtein empty strings" {
    try testing.expectEqual(@as(usize, 0), fuzzy.levenshtein("", ""));
    try testing.expectEqual(@as(usize, 5), fuzzy.levenshtein("", "hello"));
    try testing.expectEqual(@as(usize, 5), fuzzy.levenshtein("hello", ""));
}

test "Damerau-Levenshtein transposition" {
    const distance = fuzzy.damerauLevenshtein("ab", "ba");
    try testing.expectEqual(@as(usize, 1), distance);
}

test "Jaro identical strings" {
    const similarity = fuzzy.jaro("hello", "hello");
    try testing.expectApproxEqAbs(@as(f64, 1.0), similarity, 0.001);
}

test "Jaro similar strings" {
    const similarity = fuzzy.jaro("hello", "hallo");
    try testing.expect(similarity > 0.8);
}

test "Jaro completely different" {
    const similarity = fuzzy.jaro("abc", "xyz");
    try testing.expect(similarity < 0.5);
}

test "Jaro-Winkler prefix bonus" {
    const jw = fuzzy.jaroWinkler("hello", "helli");
    const j = fuzzy.jaro("hello", "helli");
    // Jaro-Winkler should be >= Jaro due to common prefix bonus
    try testing.expect(jw >= j);
}

test "LCS length" {
    const length = fuzzy.lcsLength("abcdef", "acdf");
    try testing.expectEqual(@as(usize, 4), length);
}

test "Cosine similarity" {
    const similarity = fuzzy.cosineSimilarity("hello world", "world hello");
    // Same words, should be highly similar
    try testing.expect(similarity > 0.9);
}

test "Fuzzy search" {
    const allocator = testing.allocator;
    const candidates = [_][]const u8{ "apple", "apply", "maple", "banana" };

    const results = try fuzzy.fuzzySearch(allocator, "aple", &candidates, 3);
    defer allocator.free(results);

    try testing.expect(results.len > 0);
    try testing.expect(results.len <= 3);
}

// ============================================================================
// Phonetic Algorithm Tests
// ============================================================================

test "Soundex Robert" {
    const code = phonetic.soundex("Robert");
    try testing.expectEqualSlices(u8, "R163", &code);
}

test "Soundex Rupert" {
    const code = phonetic.soundex("Rupert");
    try testing.expectEqualSlices(u8, "R163", &code);
}

test "Soundex Smith vs Smyth" {
    const smith = phonetic.soundex("Smith");
    const smyth = phonetic.soundex("Smyth");
    try testing.expectEqualSlices(u8, &smith, &smyth);
}

test "Soundex empty string" {
    const code = phonetic.soundex("");
    try testing.expectEqualSlices(u8, "0000", &code);
}

test "Soundex vowels ignored" {
    // All vowels except first letter should be ignored
    const ashcraft = phonetic.soundex("Ashcraft");
    try testing.expectEqual(@as(u8, 'A'), ashcraft[0]);
}

test "Metaphone basic" {
    const allocator = testing.allocator;

    const result = try phonetic.metaphone(allocator, "Knight");
    defer allocator.free(result);

    // Knight should encode to "NT" (K is silent before N)
    try testing.expectEqualStrings("NT", result);
}

test "Double Metaphone" {
    const allocator = testing.allocator;

    var result = try phonetic.doubleMetaphone(allocator, "Schmidt");
    defer result.deinit(allocator);

    // Should have primary code
    try testing.expect(result.primary.len > 0);
}

test "NYSIIS basic" {
    const allocator = testing.allocator;

    const result = try phonetic.nysiis(allocator, "Johnson");
    defer allocator.free(result);

    try testing.expect(result.len > 0);
}

test "Phonetic match using soundex" {
    try testing.expect(phonetic.phoneticMatch("Robert", "Rupert", .soundex));
    try testing.expect(!phonetic.phoneticMatch("Robert", "John", .soundex));
}

// ============================================================================
// Locale Formatting Tests
// ============================================================================

test "Locale en_US number formatting" {
    const allocator = testing.allocator;
    const en_us = locale.Locale.get(.en_US);

    const result = try en_us.formatNumber(allocator, 1234567.89);
    defer allocator.free(result);

    // US format uses comma as thousands separator
    try testing.expect(std.mem.indexOf(u8, result, ",") != null);
}

test "Locale de_DE number formatting" {
    const allocator = testing.allocator;
    const de_de = locale.Locale.get(.de_DE);

    const result = try de_de.formatNumber(allocator, 1234567.89);
    defer allocator.free(result);

    // German format uses period as thousands separator
    try testing.expect(std.mem.indexOf(u8, result, ".") != null);
}

test "Locale currency formatting" {
    const allocator = testing.allocator;
    const en_us = locale.Locale.get(.en_US);

    const result = try en_us.formatCurrency(allocator, 1234.56, .USD);
    defer allocator.free(result);

    // Should contain dollar sign
    try testing.expect(std.mem.indexOf(u8, result, "$") != null);
}

test "Locale percent formatting" {
    const allocator = testing.allocator;
    const en_us = locale.Locale.get(.en_US);

    const result = try en_us.formatPercent(allocator, 0.75);
    defer allocator.free(result);

    // Should contain percent sign
    try testing.expect(std.mem.indexOf(u8, result, "%") != null);
}

test "Locale list formatting" {
    const allocator = testing.allocator;
    const en_us = locale.Locale.get(.en_US);

    const items = [_][]const u8{ "apples", "oranges", "bananas" };
    const result = try en_us.formatList(allocator, &items);
    defer allocator.free(result);

    // Should contain all items
    try testing.expect(std.mem.indexOf(u8, result, "apples") != null);
    try testing.expect(std.mem.indexOf(u8, result, "oranges") != null);
    try testing.expect(std.mem.indexOf(u8, result, "bananas") != null);
}

test "Locale ja_JP number formatting" {
    const allocator = testing.allocator;
    const ja_jp = locale.Locale.get(.ja_JP);

    const result = try ja_jp.formatNumber(allocator, 1234567.89);
    defer allocator.free(result);

    // Japanese also uses comma as thousands separator
    try testing.expect(result.len > 0);
}

test "Locale fr_FR number formatting" {
    const allocator = testing.allocator;
    const fr_fr = locale.Locale.get(.fr_FR);

    const result = try fr_fr.formatNumber(allocator, 1234567.89);
    defer allocator.free(result);

    // French uses space as thousands separator and comma for decimal
    try testing.expect(result.len > 0);
}

// ============================================================================
// ICU Compatibility Tests
// ============================================================================

test "ICU UnicodeString from UTF-8" {
    const allocator = testing.allocator;

    var ustr = try icu.UnicodeString.fromUtf8(allocator, "Hello, World!");
    defer ustr.deinit();

    try testing.expectEqual(@as(usize, 13), ustr.length());
}

test "ICU UnicodeString to UTF-8" {
    const allocator = testing.allocator;

    var ustr = try icu.UnicodeString.fromUtf8(allocator, "Hello");
    defer ustr.deinit();

    const utf8 = try ustr.toUtf8String(allocator);
    defer allocator.free(utf8);

    try testing.expectEqualStrings("Hello", utf8);
}

test "ICU Normalizer2 NFC" {
    const allocator = testing.allocator;

    // Get NFC normalizer
    const normalizer = icu.Normalizer2.getInstance(.UNORM_NFC);

    // NFD form of é (e + combining acute)
    const nfd = "e\xCC\x81";
    const result = try normalizer.normalize(allocator, nfd);
    defer allocator.free(result);

    // Should normalize to precomposed form
    try testing.expectEqualStrings("\xC3\xA9", result);
}

test "ICU BreakIterator character" {
    // Create character break iterator
    var bi = try icu.BreakIterator.createCharacterInstance("Hello");

    var count: usize = 0;
    while (bi.next() != icu.BreakIterator.DONE) {
        count += 1;
    }

    try testing.expectEqual(@as(usize, 5), count);
}

test "ICU BreakIterator word" {
    // Create word break iterator
    var bi = try icu.BreakIterator.createWordInstance("Hello World");

    var count: usize = 0;
    while (bi.next() != icu.BreakIterator.DONE) {
        count += 1;
    }

    // Should find word boundaries
    try testing.expect(count > 0);
}

test "ICU Collator primary comparison" {
    var collator = icu.Collator.createInstance();
    collator.setStrength(.UCOL_PRIMARY);

    // Primary strength ignores case and accents
    const result = collator.compare("Hello", "HELLO");
    try testing.expectEqual(icu.UCollationResult.UCOL_EQUAL, result);
}

test "ICU UCharacter properties" {
    // Check if 'A' is uppercase
    try testing.expect(icu.UCharacter.isUpperCase('A'));
    try testing.expect(!icu.UCharacter.isUpperCase('a'));

    // Check if '5' is a digit
    try testing.expect(icu.UCharacter.isDigit('5'));
    try testing.expect(!icu.UCharacter.isDigit('A'));

    // Check if ' ' is whitespace
    try testing.expect(icu.UCharacter.isWhitespace(' '));
    try testing.expect(!icu.UCharacter.isWhitespace('A'));
}

test "ICU UnicodeString case conversion" {
    const allocator = testing.allocator;

    var ustr = try icu.UnicodeString.fromUtf8(allocator, "Hello World");
    defer ustr.deinit();

    var upper = try ustr.toUpper(allocator);
    defer upper.deinit();
    const upper_utf8 = try upper.toUtf8String(allocator);
    defer allocator.free(upper_utf8);
    try testing.expectEqualStrings("HELLO WORLD", upper_utf8);

    var lower = try ustr.toLower(allocator);
    defer lower.deinit();
    const lower_utf8 = try lower.toUtf8String(allocator);
    defer allocator.free(lower_utf8);
    try testing.expectEqualStrings("hello world", lower_utf8);
}

// ============================================================================
// Edge Cases
// ============================================================================

test "Regex empty pattern" {
    const allocator = testing.allocator;

    // Empty pattern should match anything
    var re = try regex.Regex.compile(allocator, "");
    defer re.deinit();

    try testing.expect(re.find("anything") != null);
}

test "Fuzzy empty strings" {
    // Empty vs empty should have distance 0
    try testing.expectEqual(@as(usize, 0), fuzzy.levenshtein("", ""));

    // Empty vs non-empty should equal length
    try testing.expectEqual(@as(usize, 3), fuzzy.levenshtein("", "abc"));
    try testing.expectEqual(@as(usize, 3), fuzzy.levenshtein("abc", ""));
}

test "Locale root locale" {
    const allocator = testing.allocator;
    const root = locale.Locale.get(.root);

    const result = try root.formatNumber(allocator, 1234.56);
    defer allocator.free(result);

    try testing.expect(result.len > 0);
}
