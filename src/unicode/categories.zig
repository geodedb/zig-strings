// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Unicode character categories (UAX #44).
//!
//! This module provides functions for determining the Unicode General Category
//! of code points and other character properties.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");

pub const Codepoint = types.Codepoint;
pub const GeneralCategory = types.GeneralCategory;

/// Gets the general category of a code point.
/// For full Unicode support, this uses a combination of direct mapping
/// and range-based lookup tables.
pub fn getCategory(cp: Codepoint) GeneralCategory {
    // ASCII optimization
    if (cp <= 0x7F) {
        return getAsciiCategory(cp);
    }

    // Latin-1 supplement (0x80-0xFF)
    if (cp <= 0xFF) {
        return getLatin1Category(cp);
    }

    // Basic categories for common ranges
    // This is a simplified implementation - full Unicode support would use
    // generated lookup tables from UnicodeData.txt

    // Combining Diacritical Marks (U+0300-0x036F) - non-spacing marks
    if (cp >= 0x0300 and cp <= 0x036F) return .Mn;

    // Combining Diacritical Marks Extended (U+1AB0-0x1AFF)
    if (cp >= 0x1AB0 and cp <= 0x1AFF) return .Mn;

    // Combining Diacritical Marks Supplement (U+1DC0-0x1DFF)
    if (cp >= 0x1DC0 and cp <= 0x1DFF) return .Mn;

    // Combining Diacritical Marks for Symbols (U+20D0-0x20FF)
    if (cp >= 0x20D0 and cp <= 0x20FF) return .Mn;

    // Combining Half Marks (U+FE20-0xFE2F)
    if (cp >= 0xFE20 and cp <= 0xFE2F) return .Mn;

    // Devanagari marks (U+0900-U+097F)
    if (cp == 0x0900 or cp == 0x0901 or cp == 0x0902) return .Mn; // Chandrabindu, anusvara
    if (cp == 0x0903) return .Mc; // Visarga (spacing mark)
    if (cp >= 0x093A and cp <= 0x093C) return .Mn;
    if (cp >= 0x093E and cp <= 0x094C) return .Mc; // Dependent vowels (spacing)
    if (cp == 0x094D) return .Mn; // Virama (non-spacing)
    if (cp >= 0x0951 and cp <= 0x0957) return .Mn; // Stress/tone marks
    if (cp == 0x0962 or cp == 0x0963) return .Mn; // Dependent vowel l/ll

    // Bengali marks (U+0980-U+09FF)
    if (cp == 0x0981) return .Mn;
    if (cp == 0x0982 or cp == 0x0983) return .Mc;
    if (cp == 0x09BC) return .Mn; // Nukta
    if (cp >= 0x09BE and cp <= 0x09C0) return .Mc;
    if (cp >= 0x09C1 and cp <= 0x09C4) return .Mn;
    if (cp >= 0x09C7 and cp <= 0x09C8) return .Mc;
    if (cp >= 0x09CB and cp <= 0x09CC) return .Mc;
    if (cp == 0x09CD) return .Mn; // Virama
    if (cp == 0x09D7) return .Mc;

    // Tamil marks (U+0B80-U+0BFF)
    if (cp == 0x0B82) return .Mn;
    if (cp == 0x0B83) return .Mc;
    if (cp >= 0x0BBE and cp <= 0x0BBF) return .Mc;
    if (cp == 0x0BC0) return .Mn;
    if (cp >= 0x0BC1 and cp <= 0x0BC2) return .Mc;
    if (cp >= 0x0BC6 and cp <= 0x0BC8) return .Mc;
    if (cp >= 0x0BCA and cp <= 0x0BCC) return .Mc;
    if (cp == 0x0BCD) return .Mn; // Virama
    if (cp == 0x0BD7) return .Mc;

    // Telugu marks (U+0C00-U+0C7F)
    if (cp == 0x0C00) return .Mn;
    if (cp >= 0x0C01 and cp <= 0x0C03) return .Mc;
    if (cp >= 0x0C3E and cp <= 0x0C40) return .Mn;
    if (cp >= 0x0C41 and cp <= 0x0C44) return .Mc;
    if (cp >= 0x0C46 and cp <= 0x0C48) return .Mn;
    if (cp >= 0x0C4A and cp <= 0x0C4C) return .Mn;
    if (cp == 0x0C4D) return .Mn; // Virama
    if (cp >= 0x0C55 and cp <= 0x0C56) return .Mn;

    // Kannada marks (U+0C80-U+0CFF)
    if (cp == 0x0C81) return .Mn;
    if (cp >= 0x0C82 and cp <= 0x0C83) return .Mc;
    if (cp == 0x0CBC) return .Mn;
    if (cp == 0x0CBE) return .Mc;
    if (cp == 0x0CBF) return .Mn;
    if (cp >= 0x0CC0 and cp <= 0x0CC4) return .Mc;
    if (cp >= 0x0CC6 and cp <= 0x0CC8) return .Mn;
    if (cp >= 0x0CCA and cp <= 0x0CCB) return .Mc;
    if (cp >= 0x0CCC and cp <= 0x0CCD) return .Mn;
    if (cp >= 0x0CD5 and cp <= 0x0CD6) return .Mc;

    // Malayalam marks (U+0D00-U+0D7F)
    if (cp >= 0x0D00 and cp <= 0x0D01) return .Mn;
    if (cp >= 0x0D02 and cp <= 0x0D03) return .Mc;
    if (cp == 0x0D3B or cp == 0x0D3C) return .Mn;
    if (cp >= 0x0D3E and cp <= 0x0D40) return .Mc;
    if (cp >= 0x0D41 and cp <= 0x0D44) return .Mn;
    if (cp >= 0x0D46 and cp <= 0x0D48) return .Mc;
    if (cp >= 0x0D4A and cp <= 0x0D4C) return .Mc;
    if (cp == 0x0D4D) return .Mn;
    if (cp == 0x0D57) return .Mc;

    // Sinhala marks (U+0D80-U+0DFF)
    if (cp == 0x0D82 or cp == 0x0D83) return .Mc;
    if (cp == 0x0DCA) return .Mn;
    if (cp >= 0x0DCF and cp <= 0x0DD1) return .Mc;
    if (cp >= 0x0DD2 and cp <= 0x0DD4) return .Mn;
    if (cp == 0x0DD6) return .Mn;
    if (cp >= 0x0DD8 and cp <= 0x0DDF) return .Mc;
    if (cp >= 0x0DF2 and cp <= 0x0DF3) return .Mc;

    // Thai marks (U+0E00-U+0E7F)
    if (cp == 0x0E31) return .Mn;
    if (cp >= 0x0E34 and cp <= 0x0E3A) return .Mn;
    if (cp >= 0x0E47 and cp <= 0x0E4E) return .Mn;

    // Lao marks (U+0E80-U+0EFF)
    if (cp == 0x0EB1) return .Mn;
    if (cp >= 0x0EB4 and cp <= 0x0EBC) return .Mn;
    if (cp >= 0x0EC8 and cp <= 0x0ECD) return .Mn;

    // Tibetan marks (U+0F00-U+0FFF)
    if (cp == 0x0F18 or cp == 0x0F19) return .Mn;
    if (cp == 0x0F35 or cp == 0x0F37 or cp == 0x0F39) return .Mn;
    if (cp == 0x0F3E or cp == 0x0F3F) return .Mc;
    if (cp >= 0x0F71 and cp <= 0x0F7E) return .Mn;
    if (cp >= 0x0F80 and cp <= 0x0F84) return .Mn;
    if (cp >= 0x0F86 and cp <= 0x0F87) return .Mn;
    if (cp >= 0x0F8D and cp <= 0x0F97) return .Mn;
    if (cp >= 0x0F99 and cp <= 0x0FBC) return .Mn;
    if (cp == 0x0FC6) return .Mn;

    // Myanmar marks (U+1000-U+109F)
    if (cp >= 0x102B and cp <= 0x102C) return .Mc;
    if (cp >= 0x102D and cp <= 0x1030) return .Mn;
    if (cp == 0x1031) return .Mc;
    if (cp >= 0x1032 and cp <= 0x1037) return .Mn;
    if (cp == 0x1038) return .Mc;
    if (cp >= 0x1039 and cp <= 0x103A) return .Mn;
    if (cp >= 0x103B and cp <= 0x103C) return .Mc;
    if (cp >= 0x103D and cp <= 0x103E) return .Mn;
    if (cp >= 0x1056 and cp <= 0x1057) return .Mc;
    if (cp >= 0x1058 and cp <= 0x1059) return .Mn;
    if (cp == 0x105E or cp == 0x105F or cp == 0x1060) return .Mn;
    if (cp == 0x1062 or cp == 0x1063 or cp == 0x1064) return .Mc;
    if (cp >= 0x1067 and cp <= 0x106D) return .Mc;
    if (cp >= 0x1071 and cp <= 0x1074) return .Mn;
    if (cp == 0x1082) return .Mn;
    if (cp >= 0x1083 and cp <= 0x1084) return .Mc;
    if (cp >= 0x1085 and cp <= 0x1086) return .Mn;
    if (cp >= 0x1087 and cp <= 0x108C) return .Mc;
    if (cp == 0x108D) return .Mn;
    if (cp == 0x108F) return .Mc;
    if (cp >= 0x109A and cp <= 0x109C) return .Mc;
    if (cp == 0x109D) return .Mn;

    // Georgian letters (U+10A0-U+10FF)
    if (cp >= 0x10A0 and cp <= 0x10C5) return .Lu;
    if (cp == 0x10C7 or cp == 0x10CD) return .Lu;
    if (cp >= 0x10D0 and cp <= 0x10FA) return .Ll;
    if (cp == 0x10FC) return .Lm;
    if (cp >= 0x10FD and cp <= 0x10FF) return .Ll;

    // Ethiopic (U+1200-U+137F) - syllables
    if (cp >= 0x1200 and cp <= 0x1248) return .Lo;
    if (cp >= 0x124A and cp <= 0x124D) return .Lo;
    if (cp >= 0x1250 and cp <= 0x1256) return .Lo;
    if (cp == 0x1258) return .Lo;
    if (cp >= 0x125A and cp <= 0x125D) return .Lo;
    if (cp >= 0x1260 and cp <= 0x1288) return .Lo;
    if (cp >= 0x128A and cp <= 0x128D) return .Lo;
    if (cp >= 0x1290 and cp <= 0x12B0) return .Lo;
    if (cp >= 0x12B2 and cp <= 0x12B5) return .Lo;
    if (cp >= 0x12B8 and cp <= 0x12BE) return .Lo;
    if (cp == 0x12C0) return .Lo;
    if (cp >= 0x12C2 and cp <= 0x12C5) return .Lo;
    if (cp >= 0x12C8 and cp <= 0x12D6) return .Lo;
    if (cp >= 0x12D8 and cp <= 0x1310) return .Lo;
    if (cp >= 0x1312 and cp <= 0x1315) return .Lo;
    if (cp >= 0x1318 and cp <= 0x135A) return .Lo;

    // Greek uppercase letters (U+0391-0x03A9, excluding U+03A2 which is unassigned)
    if (cp >= 0x0391 and cp <= 0x03A1) return .Lu;
    if (cp >= 0x03A3 and cp <= 0x03A9) return .Lu;

    // Greek lowercase letters (U+03B1-0x03C9)
    if (cp >= 0x03B1 and cp <= 0x03C9) return .Ll;

    // Greek Extended (U+1F00-0x1FFF) - simplified
    if (cp >= 0x1F00 and cp <= 0x1F07) return .Ll; // Greek small letter alpha with psili, etc.
    if (cp >= 0x1F08 and cp <= 0x1F0F) return .Lu; // Greek capital letter alpha with psili, etc.

    // Cyrillic uppercase (U+0400-U+042F)
    if (cp >= 0x0400 and cp <= 0x042F) return .Lu;
    // Cyrillic lowercase (U+0430-U+045F)
    if (cp >= 0x0430 and cp <= 0x045F) return .Ll;
    // Cyrillic extended uppercase
    if (cp >= 0x0460 and cp <= 0x0481 and cp % 2 == 0) return .Lu;
    // Cyrillic extended lowercase
    if (cp >= 0x0461 and cp <= 0x0481 and cp % 2 == 1) return .Ll;
    // Cyrillic other letters
    if (cp >= 0x048A and cp <= 0x04FF) {
        return if (cp % 2 == 0) .Lu else .Ll;
    }
    // Cyrillic Extended-A/B (U+2DE0-U+2DFF, U+A640-U+A69F)
    if (cp >= 0x2DE0 and cp <= 0x2DFF) return .Mn;
    if (cp >= 0xA640 and cp <= 0xA69F) {
        return if (cp % 2 == 0) .Lu else .Ll;
    }

    // Armenian uppercase (U+0531-U+0556)
    if (cp >= 0x0531 and cp <= 0x0556) return .Lu;
    // Armenian lowercase (U+0561-U+0587)
    if (cp >= 0x0561 and cp <= 0x0587) return .Ll;
    // Armenian punctuation
    if (cp >= 0x0589 and cp <= 0x058A) return .Po;

    // Hebrew letters (U+05D0-U+05EA)
    if (cp >= 0x05D0 and cp <= 0x05EA) return .Lo;
    // Hebrew marks (U+0591-U+05BD)
    if (cp >= 0x0591 and cp <= 0x05BD) return .Mn;
    if (cp == 0x05BF) return .Mn;
    if (cp >= 0x05C1 and cp <= 0x05C2) return .Mn;
    if (cp >= 0x05C4 and cp <= 0x05C5) return .Mn;
    if (cp == 0x05C7) return .Mn;
    // Hebrew punctuation
    if (cp == 0x05BE or cp == 0x05C0 or cp == 0x05C3 or cp == 0x05C6) return .Po;
    if (cp >= 0x05F0 and cp <= 0x05F2) return .Lo;
    if (cp >= 0x05F3 and cp <= 0x05F4) return .Po;

    // Arabic letters (U+0620-U+063F, U+0641-U+064A)
    if (cp >= 0x0620 and cp <= 0x063F) return .Lo;
    if (cp >= 0x0641 and cp <= 0x064A) return .Lo;
    if (cp == 0x0640) return .Lm; // Tatweel
    // Arabic marks (U+064B-U+065F)
    if (cp >= 0x064B and cp <= 0x065F) return .Mn;
    // Arabic-Indic digits (U+0660-U+0669)
    if (cp >= 0x0660 and cp <= 0x0669) return .Nd;
    // Extended Arabic-Indic digits (U+06F0-U+06F9)
    if (cp >= 0x06F0 and cp <= 0x06F9) return .Nd;
    // Arabic extended letters
    if (cp >= 0x066E and cp <= 0x066F) return .Lo;
    if (cp >= 0x0671 and cp <= 0x06D3) return .Lo;
    if (cp == 0x06D5) return .Lo;
    if (cp >= 0x06D6 and cp <= 0x06DC) return .Mn;
    if (cp >= 0x06DF and cp <= 0x06E4) return .Mn;
    if (cp >= 0x06E5 and cp <= 0x06E6) return .Lm;
    if (cp >= 0x06E7 and cp <= 0x06E8) return .Mn;
    if (cp >= 0x06EA and cp <= 0x06ED) return .Mn;
    if (cp >= 0x06EE and cp <= 0x06EF) return .Lo;
    if (cp >= 0x06FA and cp <= 0x06FC) return .Lo;
    if (cp == 0x06FF) return .Lo;

    // General Punctuation (U+2000-U+206F)
    if (cp >= 0x2000 and cp <= 0x200A) return .Zs; // Various spaces
    if (cp >= 0x200B and cp <= 0x200D) return .Cf; // Zero-width chars
    if (cp >= 0x200E and cp <= 0x200F) return .Cf; // Directional marks
    if (cp == 0x2010 or cp == 0x2011) return .Pd; // Hyphens
    if (cp >= 0x2012 and cp <= 0x2015) return .Pd; // Dashes
    if (cp >= 0x2016 and cp <= 0x2017) return .Po;
    if (cp == 0x2018 or cp == 0x201B) return .Pi; // Opening quotes
    if (cp == 0x2019 or cp == 0x201A) return .Pf; // Closing quotes
    if (cp == 0x201C or cp == 0x201F) return .Pi;
    if (cp == 0x201D or cp == 0x201E) return .Pf;
    if (cp >= 0x2020 and cp <= 0x2027) return .Po;
    if (cp == 0x2028) return .Zl; // Line separator
    if (cp == 0x2029) return .Zp; // Paragraph separator
    if (cp >= 0x202A and cp <= 0x202E) return .Cf; // Directional formatting
    if (cp == 0x202F) return .Zs; // Narrow no-break space
    if (cp >= 0x2030 and cp <= 0x2038) return .Po;
    if (cp == 0x2039) return .Pi;
    if (cp == 0x203A) return .Pf;
    if (cp >= 0x203B and cp <= 0x203E) return .Po;
    if (cp >= 0x203F and cp <= 0x2040) return .Pc;
    if (cp >= 0x2041 and cp <= 0x2043) return .Po;
    if (cp == 0x2044) return .Sm;
    if (cp == 0x2045) return .Ps;
    if (cp == 0x2046) return .Pe;
    if (cp >= 0x2047 and cp <= 0x2051) return .Po;
    if (cp == 0x2052) return .Sm;
    if (cp >= 0x2053 and cp <= 0x2055) return .Po;
    if (cp == 0x2056) return .Po;
    if (cp == 0x2057) return .Po;
    if (cp >= 0x2058 and cp <= 0x205E) return .Po;
    if (cp == 0x205F) return .Zs; // Medium mathematical space
    if (cp >= 0x2060 and cp <= 0x2064) return .Cf;
    if (cp >= 0x2066 and cp <= 0x206F) return .Cf;

    // Currency Symbols (U+20A0-U+20CF)
    if (cp >= 0x20A0 and cp <= 0x20CF) return .Sc;

    // Letterlike Symbols (U+2100-U+214F)
    if (cp >= 0x2100 and cp <= 0x2101) return .So;
    if (cp == 0x2102) return .Lu; // Double-struck C
    if (cp >= 0x2103 and cp <= 0x2106) return .So;
    if (cp == 0x2107) return .Lu; // Euler constant
    if (cp >= 0x2108 and cp <= 0x2109) return .So;
    if (cp >= 0x210A and cp <= 0x2113) return .Ll;
    if (cp == 0x2115) return .Lu; // Double-struck N
    if (cp >= 0x2119 and cp <= 0x211D) return .Lu;
    if (cp == 0x2124) return .Lu; // Double-struck Z
    if (cp == 0x2126) return .Lu; // Ohm sign
    if (cp == 0x2128) return .Lu; // Black-letter Z
    if (cp >= 0x212A and cp <= 0x212D) return .Lu;
    if (cp == 0x212F) return .Ll;
    if (cp >= 0x2130 and cp <= 0x2133) return .Lu;
    if (cp == 0x2134) return .Ll;
    if (cp >= 0x2135 and cp <= 0x2138) return .Lo; // Hebrew letters
    if (cp == 0x2139) return .Ll;
    if (cp >= 0x213C and cp <= 0x213F) return .Ll;
    if (cp >= 0x2140 and cp <= 0x2144) return .Sm;
    if (cp >= 0x2145 and cp <= 0x2149) return .Lu;
    if (cp == 0x214E) return .Ll;

    // Number Forms (U+2150-U+218F)
    if (cp >= 0x2150 and cp <= 0x215F) return .No; // Fractions
    if (cp >= 0x2160 and cp <= 0x216F) return .Nl; // Roman numerals upper
    if (cp >= 0x2170 and cp <= 0x217F) return .Nl; // Roman numerals lower
    if (cp >= 0x2180 and cp <= 0x2182) return .Nl;
    if (cp == 0x2183) return .Lu;
    if (cp == 0x2184) return .Ll;
    if (cp >= 0x2185 and cp <= 0x2188) return .Nl;

    // Arrows (U+2190-U+21FF)
    if (cp >= 0x2190 and cp <= 0x21FF) return .Sm;

    // Mathematical Operators (U+2200-U+22FF)
    if (cp >= 0x2200 and cp <= 0x22FF) return .Sm;

    // Miscellaneous Technical (U+2300-U+23FF)
    if (cp >= 0x2300 and cp <= 0x23FF) return .So;

    // Box Drawing (U+2500-U+257F)
    if (cp >= 0x2500 and cp <= 0x257F) return .So;

    // Block Elements (U+2580-U+259F)
    if (cp >= 0x2580 and cp <= 0x259F) return .So;

    // Geometric Shapes (U+25A0-U+25FF)
    if (cp >= 0x25A0 and cp <= 0x25FF) return .So;

    // Miscellaneous Symbols (U+2600-U+26FF)
    if (cp >= 0x2600 and cp <= 0x26FF) return .So;

    // Dingbats (U+2700-U+27BF)
    if (cp >= 0x2700 and cp <= 0x27BF) return .So;

    // Supplemental Arrows-A (U+27F0-U+27FF)
    if (cp >= 0x27F0 and cp <= 0x27FF) return .Sm;

    // Braille Patterns (U+2800-U+28FF)
    if (cp >= 0x2800 and cp <= 0x28FF) return .So;

    // Supplemental Mathematical Operators (U+2A00-U+2AFF)
    if (cp >= 0x2A00 and cp <= 0x2AFF) return .Sm;

    // Latin Extended-A (U+0100-0x017F) - pairs of upper/lower
    if (cp >= 0x0100 and cp <= 0x017F) {
        // Most are paired: even = uppercase, odd = lowercase
        if ((cp >= 0x0100 and cp <= 0x012F) or
            (cp >= 0x0132 and cp <= 0x0137) or
            (cp >= 0x014A and cp <= 0x0177))
        {
            return if (cp % 2 == 0) .Lu else .Ll;
        }
    }

    // Latin Extended-B - common letters
    if (cp >= 0x0180 and cp <= 0x024F) {
        // Simplified - use lowercase as default for this range
        return .Ll;
    }

    // CJK ranges
    if (isCjkIdeograph(cp)) return .Lo;

    // Hangul syllables
    if (cp >= 0xAC00 and cp <= 0xD7A3) return .Lo;

    // Hangul Jamo (U+1100-U+11FF)
    if (cp >= 0x1100 and cp <= 0x115F) return .Lo; // Leading consonants
    if (cp >= 0x1160 and cp <= 0x11A7) return .Lo; // Vowels
    if (cp >= 0x11A8 and cp <= 0x11FF) return .Lo; // Trailing consonants

    // Hangul Compatibility Jamo (U+3130-U+318F)
    if (cp >= 0x3131 and cp <= 0x318E) return .Lo;

    // Hangul Jamo Extended-A (U+A960-U+A97F)
    if (cp >= 0xA960 and cp <= 0xA97C) return .Lo;

    // Hangul Jamo Extended-B (U+D7B0-U+D7FF)
    if (cp >= 0xD7B0 and cp <= 0xD7C6) return .Lo;
    if (cp >= 0xD7CB and cp <= 0xD7FB) return .Lo;

    // Hiragana (U+3040-U+309F)
    if (cp >= 0x3041 and cp <= 0x3096) return .Lo;
    if (cp >= 0x3099 and cp <= 0x309A) return .Mn; // Combining marks
    if (cp == 0x309B or cp == 0x309C) return .Sk; // Katakana-Hiragana voiced/semi-voiced marks
    if (cp == 0x309D or cp == 0x309E) return .Lm; // Iteration marks
    if (cp == 0x309F) return .Lo;

    // Katakana (U+30A0-U+30FF)
    if (cp == 0x30A0) return .Pd; // Double hyphen
    if (cp >= 0x30A1 and cp <= 0x30FA) return .Lo;
    if (cp == 0x30FB) return .Po; // Middle dot
    if (cp == 0x30FC) return .Lm; // Prolonged sound mark
    if (cp >= 0x30FD and cp <= 0x30FE) return .Lm;
    if (cp == 0x30FF) return .Lo;

    // Katakana Phonetic Extensions (U+31F0-U+31FF)
    if (cp >= 0x31F0 and cp <= 0x31FF) return .Lo;

    // CJK Symbols and Punctuation (U+3000-U+303F)
    if (cp == 0x3000) return .Zs; // Ideographic space
    if (cp >= 0x3001 and cp <= 0x3003) return .Po;
    if (cp == 0x3004) return .So;
    if (cp == 0x3005) return .Lm; // Ideographic iteration
    if (cp == 0x3006) return .Lo;
    if (cp == 0x3007) return .Nl; // Ideographic number zero
    if (cp >= 0x3008 and cp <= 0x3011) return if (cp % 2 == 0) .Ps else .Pe;
    if (cp >= 0x3012 and cp <= 0x3013) return .So;
    if (cp >= 0x3014 and cp <= 0x301B) return if (cp % 2 == 0) .Ps else .Pe;
    if (cp == 0x301C) return .Pd;
    if (cp == 0x301D) return .Ps;
    if (cp >= 0x301E and cp <= 0x301F) return .Pe;
    if (cp == 0x3020) return .So;
    if (cp >= 0x3021 and cp <= 0x3029) return .Nl; // Hangzhou numerals
    if (cp >= 0x302A and cp <= 0x302D) return .Mn;
    if (cp >= 0x302E and cp <= 0x302F) return .Mc;
    if (cp == 0x3030) return .Pd;
    if (cp >= 0x3031 and cp <= 0x3035) return .Lm;
    if (cp == 0x3036) return .So;
    if (cp == 0x3037) return .So;
    if (cp >= 0x3038 and cp <= 0x303A) return .Nl;
    if (cp == 0x303B) return .Lm;
    if (cp == 0x303C) return .Lo;
    if (cp == 0x303D) return .Po;
    if (cp >= 0x303E and cp <= 0x303F) return .So;

    // Bopomofo (U+3100-U+312F)
    if (cp >= 0x3105 and cp <= 0x312F) return .Lo;

    // Bopomofo Extended (U+31A0-U+31BF)
    if (cp >= 0x31A0 and cp <= 0x31BF) return .Lo;

    // Enclosed CJK Letters and Months (U+3200-U+32FF)
    if (cp >= 0x3200 and cp <= 0x321E) return .So;
    if (cp >= 0x3220 and cp <= 0x3229) return .No;
    if (cp >= 0x322A and cp <= 0x3247) return .So;
    if (cp >= 0x3248 and cp <= 0x324F) return .No;
    if (cp >= 0x3250 and cp <= 0x32FE) return .So;

    // CJK Compatibility (U+3300-U+33FF)
    if (cp >= 0x3300 and cp <= 0x33FF) return .So;

    // Fullwidth Forms (U+FF00-U+FFEF)
    if (cp == 0xFF01) return .Po; // Fullwidth !
    if (cp == 0xFF02) return .Po; // Fullwidth "
    if (cp == 0xFF03) return .Po; // Fullwidth #
    if (cp == 0xFF04) return .Sc; // Fullwidth $
    if (cp == 0xFF05) return .Po; // Fullwidth %
    if (cp == 0xFF06) return .Po; // Fullwidth &
    if (cp == 0xFF07) return .Po; // Fullwidth '
    if (cp == 0xFF08) return .Ps; // Fullwidth (
    if (cp == 0xFF09) return .Pe; // Fullwidth )
    if (cp == 0xFF0A) return .Po; // Fullwidth *
    if (cp == 0xFF0B) return .Sm; // Fullwidth +
    if (cp == 0xFF0C) return .Po; // Fullwidth ,
    if (cp == 0xFF0D) return .Pd; // Fullwidth -
    if (cp == 0xFF0E) return .Po; // Fullwidth .
    if (cp == 0xFF0F) return .Po; // Fullwidth /
    if (cp >= 0xFF10 and cp <= 0xFF19) return .Nd; // Fullwidth digits
    if (cp == 0xFF1A) return .Po; // Fullwidth :
    if (cp == 0xFF1B) return .Po; // Fullwidth ;
    if (cp == 0xFF1C) return .Sm; // Fullwidth <
    if (cp == 0xFF1D) return .Sm; // Fullwidth =
    if (cp == 0xFF1E) return .Sm; // Fullwidth >
    if (cp == 0xFF1F) return .Po; // Fullwidth ?
    if (cp == 0xFF20) return .Po; // Fullwidth @
    if (cp >= 0xFF21 and cp <= 0xFF3A) return .Lu; // Fullwidth A-Z
    if (cp == 0xFF3B) return .Ps; // Fullwidth [
    if (cp == 0xFF3C) return .Po; // Fullwidth \
    if (cp == 0xFF3D) return .Pe; // Fullwidth ]
    if (cp == 0xFF3E) return .Sk; // Fullwidth ^
    if (cp == 0xFF3F) return .Pc; // Fullwidth _
    if (cp == 0xFF40) return .Sk; // Fullwidth `
    if (cp >= 0xFF41 and cp <= 0xFF5A) return .Ll; // Fullwidth a-z
    if (cp == 0xFF5B) return .Ps; // Fullwidth {
    if (cp == 0xFF5C) return .Sm; // Fullwidth |
    if (cp == 0xFF5D) return .Pe; // Fullwidth }
    if (cp == 0xFF5E) return .Sm; // Fullwidth ~
    if (cp == 0xFF5F) return .Ps;
    if (cp == 0xFF60) return .Pe;
    if (cp >= 0xFF61 and cp <= 0xFF64) return .Po; // Halfwidth punctuation
    if (cp >= 0xFF65 and cp <= 0xFF9D) return .Lo; // Halfwidth katakana
    if (cp >= 0xFF9E and cp <= 0xFF9F) return .Lm; // Halfwidth voiced marks
    if (cp >= 0xFFA0 and cp <= 0xFFBE) return .Lo; // Halfwidth Hangul
    if (cp >= 0xFFC2 and cp <= 0xFFCF) return .Lo;
    if (cp >= 0xFFD2 and cp <= 0xFFD7) return .Lo;
    if (cp >= 0xFFDA and cp <= 0xFFDC) return .Lo;
    if (cp >= 0xFFE0 and cp <= 0xFFE1) return .Sc; // Fullwidth cents, pounds
    if (cp == 0xFFE2) return .Sm; // Fullwidth not
    if (cp == 0xFFE3) return .Sk; // Fullwidth macron
    if (cp == 0xFFE4) return .So; // Fullwidth broken bar
    if (cp >= 0xFFE5 and cp <= 0xFFE6) return .Sc; // Fullwidth yen, won
    if (cp == 0xFFE8) return .So;
    if (cp >= 0xFFE9 and cp <= 0xFFEC) return .Sm;
    if (cp >= 0xFFED and cp <= 0xFFEE) return .So;

    // Variation Selectors (U+FE00-U+FE0F)
    if (cp >= 0xFE00 and cp <= 0xFE0F) return .Mn;

    // Vertical Forms (U+FE10-U+FE1F)
    if (cp >= 0xFE10 and cp <= 0xFE16) return .Po;
    if (cp == 0xFE17) return .Ps;
    if (cp == 0xFE18) return .Pe;
    if (cp == 0xFE19) return .Po;

    // Small Form Variants (U+FE50-U+FE6F)
    if (cp >= 0xFE50 and cp <= 0xFE52) return .Po;
    if (cp == 0xFE54 or cp == 0xFE55) return .Po;
    if (cp == 0xFE56 or cp == 0xFE57) return .Po;
    if (cp == 0xFE58) return .Pd;
    if (cp == 0xFE59) return .Ps;
    if (cp == 0xFE5A) return .Pe;
    if (cp == 0xFE5B) return .Ps;
    if (cp == 0xFE5C) return .Pe;
    if (cp == 0xFE5D) return .Ps;
    if (cp == 0xFE5E) return .Pe;
    if (cp >= 0xFE5F and cp <= 0xFE61) return .Po;
    if (cp == 0xFE62) return .Sm;
    if (cp == 0xFE63) return .Pd;
    if (cp >= 0xFE64 and cp <= 0xFE66) return .Sm;
    if (cp == 0xFE68) return .Po;
    if (cp == 0xFE69) return .Sc;
    if (cp >= 0xFE6A and cp <= 0xFE6B) return .Po;

    // Emoji and Pictographs (simplified ranges)
    // Miscellaneous Symbols and Pictographs (U+1F300-U+1F5FF)
    if (cp >= 0x1F300 and cp <= 0x1F5FF) return .So;
    // Emoticons (U+1F600-U+1F64F)
    if (cp >= 0x1F600 and cp <= 0x1F64F) return .So;
    // Transport and Map Symbols (U+1F680-U+1F6FF)
    if (cp >= 0x1F680 and cp <= 0x1F6FF) return .So;
    // Supplemental Symbols and Pictographs (U+1F900-U+1F9FF)
    if (cp >= 0x1F900 and cp <= 0x1F9FF) return .So;
    // Symbols and Pictographs Extended-A (U+1FA00-U+1FA6F)
    if (cp >= 0x1FA00 and cp <= 0x1FA6F) return .So;
    // Symbols and Pictographs Extended-B (U+1FA70-U+1FAFF)
    if (cp >= 0x1FA70 and cp <= 0x1FAFF) return .So;

    // Regional Indicator Symbols (U+1F1E0-U+1F1FF)
    if (cp >= 0x1F1E0 and cp <= 0x1F1FF) return .So;

    // Surrogates (invalid as code points)
    if (types.surrogate.isSurrogate(cp)) return .Cs;

    // Private use areas
    if ((cp >= 0xE000 and cp <= 0xF8FF) or
        (cp >= 0xF0000 and cp <= 0xFFFFD) or
        (cp >= 0x100000 and cp <= 0x10FFFD))
    {
        return .Co;
    }

    // Default to unassigned
    return .Cn;
}

fn getAsciiCategory(cp: Codepoint) GeneralCategory {
    return switch (cp) {
        0x00...0x1F => .Cc, // Control characters
        0x20 => .Zs, // Space
        '!'...'/' => .Po, // Punctuation
        '0'...'9' => .Nd, // Digits
        ':'...';' => .Po,
        '<'...'>' => .Sm, // Math symbols
        '?' => .Po,
        '@' => .Po,
        'A'...'Z' => .Lu, // Uppercase letters
        '[' => .Ps, // Open bracket
        '\\' => .Po,
        ']' => .Pe, // Close bracket
        '^' => .Sk, // Modifier symbol
        '_' => .Pc, // Connector punctuation
        '`' => .Sk,
        'a'...'z' => .Ll, // Lowercase letters
        '{' => .Ps,
        '|' => .Sm,
        '}' => .Pe,
        '~' => .Sm,
        0x7F => .Cc, // DEL
        else => .Cn,
    };
}

fn getLatin1Category(cp: Codepoint) GeneralCategory {
    return switch (cp) {
        0x80...0x9F => .Cc, // C1 control characters
        0xA0 => .Zs, // No-break space
        0xA1 => .Po, // Inverted exclamation
        0xA2...0xA5 => .Sc, // Currency symbols
        0xA6 => .So, // Broken bar
        0xA7 => .Po, // Section sign
        0xA8 => .Sk, // Diaeresis
        0xA9 => .So, // Copyright
        0xAA => .Lo, // Feminine ordinal
        0xAB => .Pi, // Left guillemet
        0xAC => .Sm, // Not sign
        0xAD => .Cf, // Soft hyphen
        0xAE => .So, // Registered
        0xAF => .Sk, // Macron
        0xB0 => .So, // Degree
        0xB1 => .Sm, // Plus-minus
        0xB2...0xB3 => .No, // Superscript 2, 3
        0xB4 => .Sk, // Acute accent
        0xB5 => .Ll, // Micro sign
        0xB6 => .Po, // Pilcrow
        0xB7 => .Po, // Middle dot
        0xB8 => .Sk, // Cedilla
        0xB9 => .No, // Superscript 1
        0xBA => .Lo, // Masculine ordinal
        0xBB => .Pf, // Right guillemet
        0xBC...0xBE => .No, // Fractions
        0xBF => .Po, // Inverted question
        0xC0...0xD6 => .Lu, // Uppercase letters
        0xD7 => .Sm, // Multiplication
        0xD8...0xDE => .Lu, // Uppercase letters
        0xDF => .Ll, // Sharp s
        0xE0...0xF6 => .Ll, // Lowercase letters
        0xF7 => .Sm, // Division
        0xF8...0xFF => .Ll, // Lowercase letters
        else => .Cn,
    };
}

/// Checks if a code point is a CJK ideograph
pub fn isCjkIdeograph(cp: Codepoint) bool {
    return (cp >= 0x4E00 and cp <= 0x9FFF) or // CJK Unified Ideographs
        (cp >= 0x3400 and cp <= 0x4DBF) or // CJK Extension A
        (cp >= 0x20000 and cp <= 0x2A6DF) or // CJK Extension B
        (cp >= 0x2A700 and cp <= 0x2B73F) or // CJK Extension C
        (cp >= 0x2B740 and cp <= 0x2B81F) or // CJK Extension D
        (cp >= 0x2B820 and cp <= 0x2CEAF) or // CJK Extension E
        (cp >= 0x2CEB0 and cp <= 0x2EBEF) or // CJK Extension F
        (cp >= 0x30000 and cp <= 0x3134F) or // CJK Extension G
        (cp >= 0x31350 and cp <= 0x323AF); // CJK Extension H
}

/// Checks if a code point is a letter (L*)
pub fn isLetter(cp: Codepoint) bool {
    return getCategory(cp).isLetter();
}

/// Checks if a code point is a mark (M*)
pub fn isMark(cp: Codepoint) bool {
    return getCategory(cp).isMark();
}

/// Checks if a code point is a number (N*)
pub fn isNumber(cp: Codepoint) bool {
    return getCategory(cp).isNumber();
}

/// Checks if a code point is punctuation (P*)
pub fn isPunctuation(cp: Codepoint) bool {
    return getCategory(cp).isPunctuation();
}

/// Checks if a code point is a symbol (S*)
pub fn isSymbol(cp: Codepoint) bool {
    return getCategory(cp).isSymbol();
}

/// Checks if a code point is a separator (Z*)
pub fn isSeparator(cp: Codepoint) bool {
    return getCategory(cp).isSeparator();
}

/// Checks if a code point is "other" (C*)
pub fn isOther(cp: Codepoint) bool {
    return getCategory(cp).isOther();
}

/// Checks if a code point is alphanumeric (letter or number)
pub fn isAlphanumeric(cp: Codepoint) bool {
    const cat = getCategory(cp);
    return cat.isLetter() or cat.isNumber();
}

/// Checks if a code point is a control character
pub fn isControl(cp: Codepoint) bool {
    return getCategory(cp) == .Cc;
}

/// Checks if a code point is a format character
pub fn isFormat(cp: Codepoint) bool {
    return getCategory(cp) == .Cf;
}

/// Checks if a code point is printable (not control, format, surrogate, or unassigned)
pub fn isPrintable(cp: Codepoint) bool {
    const cat = getCategory(cp);
    return switch (cat) {
        .Cc, .Cf, .Cs, .Co, .Cn => false,
        else => true,
    };
}

/// Checks if a code point is whitespace (general category Zs, Zl, Zp, or specific controls)
pub fn isWhitespace(cp: Codepoint) bool {
    return switch (cp) {
        // ASCII whitespace
        0x09...0x0D, 0x20 => true,
        // Unicode whitespace
        0x85, // NEL
        0xA0, // NBSP
        0x1680, // Ogham space
        0x2000...0x200A, // Various spaces
        0x2028,
        0x2029, // Line/paragraph separator
        0x202F, // Narrow NBSP
        0x205F, // Medium mathematical space
        0x3000, // Ideographic space
        => true,
        else => false,
    };
}

/// Checks if a code point is a decimal digit (Nd)
pub fn isDecimalDigit(cp: Codepoint) bool {
    return getCategory(cp) == .Nd;
}

/// Checks if a code point is uppercase (Lu)
pub fn isUppercase(cp: Codepoint) bool {
    return getCategory(cp) == .Lu;
}

/// Checks if a code point is lowercase (Ll)
pub fn isLowercase(cp: Codepoint) bool {
    return getCategory(cp) == .Ll;
}

/// Checks if a code point is titlecase (Lt)
pub fn isTitlecase(cp: Codepoint) bool {
    return getCategory(cp) == .Lt;
}

/// Checks if a code point has casing (Lu, Ll, or Lt)
pub fn isCased(cp: Codepoint) bool {
    const cat = getCategory(cp);
    return cat == .Lu or cat == .Ll or cat == .Lt;
}

test "ASCII categories" {
    const testing = std.testing;

    try testing.expectEqual(GeneralCategory.Lu, getCategory('A'));
    try testing.expectEqual(GeneralCategory.Ll, getCategory('a'));
    try testing.expectEqual(GeneralCategory.Nd, getCategory('5'));
    try testing.expectEqual(GeneralCategory.Zs, getCategory(' '));
    try testing.expectEqual(GeneralCategory.Cc, getCategory('\n'));
    try testing.expectEqual(GeneralCategory.Po, getCategory('!'));
}

test "Latin-1 categories" {
    const testing = std.testing;

    try testing.expectEqual(GeneralCategory.Lu, getCategory(0xC9)); // É
    try testing.expectEqual(GeneralCategory.Ll, getCategory(0xE9)); // é
    try testing.expectEqual(GeneralCategory.Sc, getCategory(0xA3)); // £
    try testing.expectEqual(GeneralCategory.Sm, getCategory(0xD7)); // ×
}

test "character properties" {
    const testing = std.testing;

    try testing.expect(isLetter('A'));
    try testing.expect(isLetter(0x4E2D)); // 中
    try testing.expect(!isLetter('5'));

    try testing.expect(isDecimalDigit('0'));
    try testing.expect(!isDecimalDigit('A'));

    try testing.expect(isWhitespace(' '));
    try testing.expect(isWhitespace('\t'));
    try testing.expect(isWhitespace(0x3000)); // Ideographic space
    try testing.expect(!isWhitespace('A'));

    try testing.expect(isUppercase('A'));
    try testing.expect(!isUppercase('a'));
    try testing.expect(isLowercase('a'));
    try testing.expect(!isLowercase('A'));
}

test "CJK detection" {
    const testing = std.testing;

    try testing.expect(isCjkIdeograph(0x4E2D)); // 中
    try testing.expect(isCjkIdeograph(0x6587)); // 文
    try testing.expect(!isCjkIdeograph('A'));
    try testing.expect(!isCjkIdeograph(0x3042)); // Hiragana あ
}
