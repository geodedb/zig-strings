// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Locale-Specific Formatting
//!
//! Provides locale-aware formatting for:
//! - Numbers (decimal separator, grouping)
//! - Currency
//! - Dates and times
//! - Percentages
//! - Lists
//!
//! Usage:
//! ```zig
//! const en_us = Locale.get(.en_US);
//! const formatted = try en_us.formatNumber(allocator, 1234567.89);
//! // "1,234,567.89"
//!
//! const de_de = Locale.get(.de_DE);
//! const german = try de_de.formatNumber(allocator, 1234567.89);
//! // "1.234.567,89"
//!
//! const currency = try en_us.formatCurrency(allocator, 1234.56, .USD);
//! // "$1,234.56"
//! ```

const std = @import("std");

/// Locale identifier
pub const LocaleId = enum {
    // English
    en_US, // United States
    en_GB, // United Kingdom
    en_AU, // Australia
    en_CA, // Canada

    // European
    de_DE, // Germany
    fr_FR, // France
    es_ES, // Spain
    it_IT, // Italy
    pt_BR, // Brazil
    pt_PT, // Portugal
    nl_NL, // Netherlands
    pl_PL, // Poland
    ru_RU, // Russia

    // Asian
    zh_CN, // China (Simplified)
    zh_TW, // Taiwan (Traditional)
    ja_JP, // Japan
    ko_KR, // Korea

    // Other
    ar_SA, // Saudi Arabia
    he_IL, // Israel
    hi_IN, // India
    tr_TR, // Turkey

    // Default
    root, // Root locale (no specific region)
};

/// Currency codes (ISO 4217)
pub const Currency = enum {
    USD, // US Dollar
    EUR, // Euro
    GBP, // British Pound
    JPY, // Japanese Yen
    CNY, // Chinese Yuan
    KRW, // Korean Won
    INR, // Indian Rupee
    RUB, // Russian Ruble
    BRL, // Brazilian Real
    CAD, // Canadian Dollar
    AUD, // Australian Dollar
    CHF, // Swiss Franc
    MXN, // Mexican Peso
    SEK, // Swedish Krona
    NOK, // Norwegian Krone
    DKK, // Danish Krone
    PLN, // Polish Zloty
    TRY, // Turkish Lira
    SAR, // Saudi Riyal
    ILS, // Israeli Shekel
};

/// Number format specification
pub const NumberFormat = struct {
    /// Decimal separator ('.' or ',')
    decimal_sep: u8 = '.',
    /// Grouping separator (',' or '.' or ' ')
    group_sep: u8 = ',',
    /// Digits per group (usually 3)
    group_size: u8 = 3,
    /// Minimum fraction digits
    min_fraction: u8 = 0,
    /// Maximum fraction digits
    max_fraction: u8 = 3,
    /// Use grouping
    use_grouping: bool = true,
    /// Negative format prefix
    negative_prefix: []const u8 = "-",
    /// Negative format suffix
    negative_suffix: []const u8 = "",
};

/// Currency format specification
pub const CurrencyFormat = struct {
    /// Currency symbol
    symbol: []const u8,
    /// Symbol position (before or after number)
    symbol_before: bool = true,
    /// Space between symbol and number
    space_between: bool = false,
    /// Decimal places for currency
    decimal_places: u8 = 2,
};

/// Date format specification
pub const DateFormat = struct {
    /// Short date format pattern
    short: []const u8,
    /// Medium date format pattern
    medium: []const u8,
    /// Long date format pattern
    long: []const u8,
    /// Full date format pattern
    full: []const u8,
};

/// Time format specification
pub const TimeFormat = struct {
    /// Short time format
    short: []const u8,
    /// Medium time format
    medium: []const u8,
    /// Long time format
    long: []const u8,
    /// Use 24-hour clock
    hour_24: bool,
    /// AM/PM designators
    am: []const u8,
    pm: []const u8,
};

/// List format specification
pub const ListFormat = struct {
    /// Separator between items
    separator: []const u8 = ", ",
    /// Separator before last item (e.g., ", and " or ", ")
    last_separator: []const u8 = ", and ",
    /// Separator for two items
    pair_separator: []const u8 = " and ",
};

/// Complete locale data
pub const Locale = struct {
    id: LocaleId,
    /// Language code (ISO 639-1)
    language: []const u8,
    /// Country/Region code (ISO 3166-1)
    region: []const u8,
    /// Number formatting
    number: NumberFormat,
    /// Date formatting
    date: DateFormat,
    /// Time formatting
    time: TimeFormat,
    /// List formatting
    list: ListFormat,

    /// Get locale by ID
    pub fn get(id: LocaleId) Locale {
        return switch (id) {
            .en_US => en_US,
            .en_GB => en_GB,
            .en_AU => en_AU,
            .en_CA => en_CA,
            .de_DE => de_DE,
            .fr_FR => fr_FR,
            .es_ES => es_ES,
            .it_IT => it_IT,
            .pt_BR => pt_BR,
            .pt_PT => pt_PT,
            .nl_NL => nl_NL,
            .pl_PL => pl_PL,
            .ru_RU => ru_RU,
            .zh_CN => zh_CN,
            .zh_TW => zh_TW,
            .ja_JP => ja_JP,
            .ko_KR => ko_KR,
            .ar_SA => ar_SA,
            .he_IL => he_IL,
            .hi_IN => hi_IN,
            .tr_TR => tr_TR,
            .root => root_locale,
        };
    }

    /// Format a number according to locale
    pub fn formatNumber(self: Locale, allocator: std.mem.Allocator, value: f64) ![]u8 {
        return formatNumberWithOpts(allocator, value, self.number);
    }

    /// Format an integer according to locale
    pub fn formatInteger(self: Locale, allocator: std.mem.Allocator, value: i64) ![]u8 {
        var opts = self.number;
        opts.min_fraction = 0;
        opts.max_fraction = 0;
        return formatNumberWithOpts(allocator, @floatFromInt(value), opts);
    }

    /// Format currency
    pub fn formatCurrency(self: Locale, allocator: std.mem.Allocator, value: f64, currency: Currency) ![]u8 {
        const fmt = getCurrencyFormat(currency, self.id);
        var num_opts = self.number;
        num_opts.min_fraction = fmt.decimal_places;
        num_opts.max_fraction = fmt.decimal_places;

        const num_str = try formatNumberWithOpts(allocator, @abs(value), num_opts);
        defer allocator.free(num_str);

        var result: std.ArrayListUnmanaged(u8) = .{};
        errdefer result.deinit(allocator);

        // Handle negative
        if (value < 0) {
            try result.appendSlice(allocator, self.number.negative_prefix);
        }

        // Format with symbol
        if (fmt.symbol_before) {
            try result.appendSlice(allocator, fmt.symbol);
            if (fmt.space_between) try result.append(allocator, ' ');
            try result.appendSlice(allocator, num_str);
        } else {
            try result.appendSlice(allocator, num_str);
            if (fmt.space_between) try result.append(allocator, ' ');
            try result.appendSlice(allocator, fmt.symbol);
        }

        if (value < 0) {
            try result.appendSlice(allocator, self.number.negative_suffix);
        }

        return result.toOwnedSlice(allocator);
    }

    /// Format percentage
    pub fn formatPercent(self: Locale, allocator: std.mem.Allocator, value: f64) ![]u8 {
        const pct_value = value * 100;
        const num_str = try self.formatNumber(allocator, pct_value);
        defer allocator.free(num_str);

        var result = try allocator.alloc(u8, num_str.len + 1);
        @memcpy(result[0..num_str.len], num_str);
        result[num_str.len] = '%';
        return result;
    }

    /// Format a list of items
    pub fn formatList(self: Locale, allocator: std.mem.Allocator, items: []const []const u8) ![]u8 {
        if (items.len == 0) return allocator.dupe(u8, "");
        if (items.len == 1) return allocator.dupe(u8, items[0]);

        var result: std.ArrayListUnmanaged(u8) = .{};
        errdefer result.deinit(allocator);

        if (items.len == 2) {
            try result.appendSlice(allocator, items[0]);
            try result.appendSlice(allocator, self.list.pair_separator);
            try result.appendSlice(allocator, items[1]);
        } else {
            for (items[0 .. items.len - 1], 0..) |item, i| {
                try result.appendSlice(allocator, item);
                if (i < items.len - 2) {
                    try result.appendSlice(allocator, self.list.separator);
                } else {
                    try result.appendSlice(allocator, self.list.last_separator);
                }
            }
            try result.appendSlice(allocator, items[items.len - 1]);
        }

        return result.toOwnedSlice(allocator);
    }

    /// Format date (simple implementation).
    /// Note: Currently returns English-only formatting regardless of locale.
    /// Locale-specific date formatting is not yet implemented.
    /// The `self` (locale) parameter is accepted for API forward-compatibility
    /// but is currently unused.
    pub fn formatDate(
        self: Locale,
        allocator: std.mem.Allocator,
        year: u16,
        month: u8,
        day: u8,
        style: enum { short, medium, long, full },
    ) ![]u8 {
        _ = self;
        var result: std.ArrayListUnmanaged(u8) = .{};
        errdefer result.deinit(allocator);

        switch (style) {
            .short => {
                // MM/DD/YY or DD.MM.YY depending on locale
                try result.writer(allocator).print("{d:0>2}/{d:0>2}/{d:0>2}", .{ month, day, @mod(year, 100) });
            },
            .medium => {
                try result.writer(allocator).print("{s} {d}, {d}", .{ monthName(month, false), day, year });
            },
            .long => {
                try result.writer(allocator).print("{s} {d}, {d}", .{ monthName(month, true), day, year });
            },
            .full => {
                // Full ISO format
                try result.writer(allocator).print("{d}-{d:0>2}-{d:0>2}", .{ year, month, day });
            },
        }

        return result.toOwnedSlice(allocator);
    }
};

fn monthName(month: u8, full: bool) []const u8 {
    const short_names = [_][]const u8{
        "Jan", "Feb", "Mar", "Apr", "May", "Jun",
        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    };
    const full_names = [_][]const u8{
        "January",   "February", "March",    "April",
        "May",       "June",     "July",     "August",
        "September", "October",  "November", "December",
    };

    if (month < 1 or month > 12) return "";
    return if (full) full_names[month - 1] else short_names[month - 1];
}

fn formatNumberWithOpts(allocator: std.mem.Allocator, value: f64, opts: NumberFormat) (error{InvalidNumber} || std.mem.Allocator.Error)![]u8 {
    // Reject NaN and Inf at the boundary -- these have no meaningful numeric formatting
    // and would cause undefined behavior in @intFromFloat below.
    if (std.math.isNan(value) or std.math.isInf(value)) return error.InvalidNumber;

    var result: std.ArrayListUnmanaged(u8) = .{};
    errdefer result.deinit(allocator);

    const is_negative = value < 0;
    const abs_value = @abs(value);

    if (is_negative) {
        try result.appendSlice(allocator, opts.negative_prefix);
    }

    // Split into integer and fractional parts
    const int_part: u64 = @intFromFloat(abs_value);
    const frac_part = abs_value - @as(f64, @floatFromInt(int_part));

    // Format integer part with grouping
    // A u64 max is 20 digits; 32 bytes is sufficient. Use bufPrint with error
    // propagation instead of catch unreachable for safety.
    var int_buf: [32]u8 = undefined;
    const int_str = std.fmt.bufPrint(&int_buf, "{d}", .{int_part}) catch return error.InvalidNumber;
    const int_len = int_str.len;

    if (opts.use_grouping and int_len > opts.group_size) {
        var i: usize = 0;
        const first_group = int_len % opts.group_size;
        if (first_group > 0) {
            try result.appendSlice(allocator, int_str[0..first_group]);
            i = first_group;
        }
        while (i < int_len) {
            if (i > 0) try result.append(allocator, opts.group_sep);
            try result.appendSlice(allocator, int_str[i .. i + opts.group_size]);
            i += opts.group_size;
        }
    } else {
        try result.appendSlice(allocator, int_str);
    }

    // Format fractional part
    if (opts.max_fraction > 0) {
        const has_fraction = frac_part >= 0.0000001 or opts.min_fraction > 0;
        if (has_fraction) {
            try result.append(allocator, opts.decimal_sep);

            var frac = frac_part;
            var digits: usize = 0;
            while (digits < opts.max_fraction) {
                frac *= 10;
                const digit: u8 = @intFromFloat(@mod(frac, 10));
                try result.append(allocator, '0' + digit);
                digits += 1;

                if (frac - @floor(frac) < 0.0000001 and digits >= opts.min_fraction) {
                    break;
                }
            }
        }
    }

    if (is_negative) {
        try result.appendSlice(allocator, opts.negative_suffix);
    }

    return result.toOwnedSlice(allocator);
}

/// Returns the currency format (symbol, placement, decimal places) for the
/// given currency code.
///
/// Note: Currently returns English-only formatting regardless of locale.
/// Locale-specific currency formatting (e.g., symbol placement, grouping)
/// is not yet implemented. The `locale` parameter is accepted for API
/// forward-compatibility but is currently unused.
fn getCurrencyFormat(currency: Currency, locale: LocaleId) CurrencyFormat {
    _ = locale;
    return switch (currency) {
        .USD => .{ .symbol = "$", .symbol_before = true, .decimal_places = 2 },
        .EUR => .{ .symbol = "\xe2\x82\xac", .symbol_before = false, .space_between = true, .decimal_places = 2 },
        .GBP => .{ .symbol = "\xc2\xa3", .symbol_before = true, .decimal_places = 2 },
        .JPY => .{ .symbol = "\xc2\xa5", .symbol_before = true, .decimal_places = 0 },
        .CNY => .{ .symbol = "\xc2\xa5", .symbol_before = true, .decimal_places = 2 },
        .KRW => .{ .symbol = "\xe2\x82\xa9", .symbol_before = true, .decimal_places = 0 },
        .INR => .{ .symbol = "\xe2\x82\xb9", .symbol_before = true, .decimal_places = 2 },
        .RUB => .{ .symbol = "\xe2\x82\xbd", .symbol_before = false, .space_between = true, .decimal_places = 2 },
        .BRL => .{ .symbol = "R$", .symbol_before = true, .space_between = true, .decimal_places = 2 },
        .CAD => .{ .symbol = "$", .symbol_before = true, .decimal_places = 2 },
        .AUD => .{ .symbol = "$", .symbol_before = true, .decimal_places = 2 },
        .CHF => .{ .symbol = "CHF", .symbol_before = false, .space_between = true, .decimal_places = 2 },
        .MXN => .{ .symbol = "$", .symbol_before = true, .decimal_places = 2 },
        .SEK => .{ .symbol = "kr", .symbol_before = false, .space_between = true, .decimal_places = 2 },
        .NOK => .{ .symbol = "kr", .symbol_before = false, .space_between = true, .decimal_places = 2 },
        .DKK => .{ .symbol = "kr", .symbol_before = false, .space_between = true, .decimal_places = 2 },
        .PLN => .{ .symbol = "z\xc5\x82", .symbol_before = false, .space_between = true, .decimal_places = 2 },
        .TRY => .{ .symbol = "\xe2\x82\xba", .symbol_before = true, .decimal_places = 2 },
        .SAR => .{ .symbol = "\xef\xb7\xbc", .symbol_before = true, .decimal_places = 2 },
        .ILS => .{ .symbol = "\xe2\x82\xaa", .symbol_before = true, .decimal_places = 2 },
    };
}

// ============================================================
// Predefined Locales (imported from locale_data.zig)
// ============================================================

const locale_data = @import("locale_data.zig");

const root_locale = locale_data.root_locale;
const en_US = locale_data.en_US;
const en_GB = locale_data.en_GB;
const en_AU = locale_data.en_AU;
const en_CA = locale_data.en_CA;
const de_DE = locale_data.de_DE;
const fr_FR = locale_data.fr_FR;
const es_ES = locale_data.es_ES;
const it_IT = locale_data.it_IT;
const pt_BR = locale_data.pt_BR;
const pt_PT = locale_data.pt_PT;
const nl_NL = locale_data.nl_NL;
const pl_PL = locale_data.pl_PL;
const ru_RU = locale_data.ru_RU;
const zh_CN = locale_data.zh_CN;
const zh_TW = locale_data.zh_TW;
const ja_JP = locale_data.ja_JP;
const ko_KR = locale_data.ko_KR;
const ar_SA = locale_data.ar_SA;
const he_IL = locale_data.he_IL;
const hi_IN = locale_data.hi_IN;
const tr_TR = locale_data.tr_TR;

// ============================================================
// Tests
// ============================================================

test "formatNumber en_US" {
    const testing = std.testing;
    const locale = Locale.get(.en_US);

    const result = try locale.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("1,234,567.89", result);
}

test "formatNumber de_DE" {
    const testing = std.testing;
    const locale = Locale.get(.de_DE);

    const result = try locale.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("1.234.567,89", result);
}

test "formatNumber fr_FR" {
    const testing = std.testing;
    const locale = Locale.get(.fr_FR);

    const result = try locale.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("1 234 567,89", result);
}

test "formatInteger" {
    const testing = std.testing;
    const locale = Locale.get(.en_US);

    const result = try locale.formatInteger(testing.allocator, 1234567);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("1,234,567", result);
}

test "formatCurrency USD" {
    const testing = std.testing;
    const locale = Locale.get(.en_US);

    const result = try locale.formatCurrency(testing.allocator, 1234.56, .USD);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("$1,234.56", result);
}

test "formatPercent" {
    const testing = std.testing;
    const locale = Locale.get(.en_US);

    const result = try locale.formatPercent(testing.allocator, 0.1234);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("12.34%", result);
}

test "formatList en_US" {
    const testing = std.testing;
    const locale = Locale.get(.en_US);

    const items = [_][]const u8{ "apples", "oranges", "bananas" };
    const result = try locale.formatList(testing.allocator, &items);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("apples, oranges, and bananas", result);
}

test "formatList two items" {
    const testing = std.testing;
    const locale = Locale.get(.en_US);

    const items = [_][]const u8{ "apples", "oranges" };
    const result = try locale.formatList(testing.allocator, &items);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("apples and oranges", result);
}

test "formatList de_DE" {
    const testing = std.testing;
    const locale = Locale.get(.de_DE);

    const items = [_][]const u8{ "Apfel", "Orange" };
    const result = try locale.formatList(testing.allocator, &items);
    defer testing.allocator.free(result);

    try testing.expectEqualStrings("Apfel und Orange", result);
}

test "formatDate short outputs US format regardless of locale" {
    const testing = std.testing;

    // en_US short date
    {
        const locale = Locale.get(.en_US);
        const result = try locale.formatDate(testing.allocator, 2025, 3, 15, .short);
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("03/15/25", result);
    }

    // de_DE also outputs US format (locale is currently ignored)
    {
        const locale = Locale.get(.de_DE);
        const result = try locale.formatDate(testing.allocator, 2025, 3, 15, .short);
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("03/15/25", result);
    }

    // Medium style
    {
        const locale = Locale.get(.en_US);
        const result = try locale.formatDate(testing.allocator, 2025, 12, 25, .medium);
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("Dec 25, 2025", result);
    }

    // Full style (ISO format)
    {
        const locale = Locale.get(.en_US);
        const result = try locale.formatDate(testing.allocator, 2025, 1, 5, .full);
        defer testing.allocator.free(result);
        try testing.expectEqualStrings("2025-01-05", result);
    }
}

test "formatNumber NaN returns error" {
    const testing = std.testing;
    const locale = Locale.get(.en_US);

    try testing.expectError(error.InvalidNumber, locale.formatNumber(testing.allocator, std.math.nan(f64)));
}

test "formatNumber positive infinity returns error" {
    const testing = std.testing;
    const locale = Locale.get(.en_US);

    try testing.expectError(error.InvalidNumber, locale.formatNumber(testing.allocator, std.math.inf(f64)));
}

test "formatNumber negative infinity returns error" {
    const testing = std.testing;
    const locale = Locale.get(.en_US);

    try testing.expectError(error.InvalidNumber, locale.formatNumber(testing.allocator, -std.math.inf(f64)));
}

// ============================================================
// Locale data coverage tests (Q-LOC1)
// Tests for all locale definitions in locale_data.zig
// ============================================================

test "locale data en_GB" {
    const testing = std.testing;
    const l = Locale.get(.en_GB);

    try testing.expectEqualStrings("en", l.language);
    try testing.expectEqualStrings("GB", l.region);
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);
    try testing.expect(l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,234,567.89", num);

    const items = [_][]const u8{ "apples", "oranges" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("apples and oranges", list);
}

test "locale data en_AU" {
    const testing = std.testing;
    const l = Locale.get(.en_AU);

    try testing.expectEqualStrings("en", l.language);
    try testing.expectEqualStrings("AU", l.region);
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);
    try testing.expect(!l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,234,567.89", num);

    const items = [_][]const u8{ "one", "two", "three" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("one, two and three", list);
}

test "locale data en_CA" {
    const testing = std.testing;
    const l = Locale.get(.en_CA);

    try testing.expectEqualStrings("en", l.language);
    try testing.expectEqualStrings("CA", l.region);
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);
    try testing.expect(!l.time.hour_24);
    try testing.expectEqualStrings("a.m.", l.time.am);
    try testing.expectEqualStrings("p.m.", l.time.pm);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,234,567.89", num);
}

test "locale data es_ES" {
    const testing = std.testing;
    const l = Locale.get(.es_ES);

    try testing.expectEqualStrings("es", l.language);
    try testing.expectEqualStrings("ES", l.region);
    try testing.expectEqual(@as(u8, ','), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, '.'), l.number.group_sep);
    try testing.expect(l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1.234.567,89", num);

    const items = [_][]const u8{ "uno", "dos" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("uno y dos", list);
}

test "locale data it_IT" {
    const testing = std.testing;
    const l = Locale.get(.it_IT);

    try testing.expectEqualStrings("it", l.language);
    try testing.expectEqualStrings("IT", l.region);
    try testing.expectEqual(@as(u8, ','), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, '.'), l.number.group_sep);
    try testing.expect(l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1.234.567,89", num);

    const items = [_][]const u8{ "uno", "due" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("uno e due", list);
}

test "locale data pt_BR" {
    const testing = std.testing;
    const l = Locale.get(.pt_BR);

    try testing.expectEqualStrings("pt", l.language);
    try testing.expectEqualStrings("BR", l.region);
    try testing.expectEqual(@as(u8, ','), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, '.'), l.number.group_sep);
    try testing.expect(l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1.234.567,89", num);

    const items = [_][]const u8{ "um", "dois" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("um e dois", list);

    // Test currency (BRL)
    const currency = try l.formatCurrency(testing.allocator, 1234.56, .BRL);
    defer testing.allocator.free(currency);
    try testing.expectEqualStrings("R$ 1.234,56", currency);
}

test "locale data pt_PT" {
    const testing = std.testing;
    const l = Locale.get(.pt_PT);

    try testing.expectEqualStrings("pt", l.language);
    try testing.expectEqualStrings("PT", l.region);
    try testing.expectEqual(@as(u8, ','), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ' '), l.number.group_sep);
    try testing.expect(l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1 234 567,89", num);

    const items = [_][]const u8{ "um", "dois", "tres" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("um, dois e tres", list);
}

test "locale data nl_NL" {
    const testing = std.testing;
    const l = Locale.get(.nl_NL);

    try testing.expectEqualStrings("nl", l.language);
    try testing.expectEqualStrings("NL", l.region);
    try testing.expectEqual(@as(u8, ','), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, '.'), l.number.group_sep);
    try testing.expect(l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1.234.567,89", num);

    const items = [_][]const u8{ "een", "twee" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("een en twee", list);
}

test "locale data pl_PL" {
    const testing = std.testing;
    const l = Locale.get(.pl_PL);

    try testing.expectEqualStrings("pl", l.language);
    try testing.expectEqualStrings("PL", l.region);
    try testing.expectEqual(@as(u8, ','), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ' '), l.number.group_sep);
    try testing.expect(l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1 234 567,89", num);

    const items = [_][]const u8{ "jeden", "dwa" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("jeden i dwa", list);
}

test "locale data ru_RU" {
    const testing = std.testing;
    const l = Locale.get(.ru_RU);

    try testing.expectEqualStrings("ru", l.language);
    try testing.expectEqualStrings("RU", l.region);
    try testing.expectEqual(@as(u8, ','), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ' '), l.number.group_sep);
    try testing.expect(l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1 234 567,89", num);

    // Russian list separator uses Cyrillic "и" (U+0438)
    const items = [_][]const u8{ "one", "two" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("one \u{0438} two", list);
}

test "locale data zh_CN" {
    const testing = std.testing;
    const l = Locale.get(.zh_CN);

    try testing.expectEqualStrings("zh", l.language);
    try testing.expectEqualStrings("CN", l.region);
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);
    try testing.expect(l.time.hour_24);
    try testing.expectEqualStrings("\u{4e0a}\u{5348}", l.time.am); // 上午
    try testing.expectEqualStrings("\u{4e0b}\u{5348}", l.time.pm); // 下午

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,234,567.89", num);

    // Chinese list separator is ideographic comma U+3001, connector is U+548C (和)
    const items = [_][]const u8{ "a", "b" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("a\u{548c}b", list);
}

test "locale data zh_TW" {
    const testing = std.testing;
    const l = Locale.get(.zh_TW);

    try testing.expectEqualStrings("zh", l.language);
    try testing.expectEqualStrings("TW", l.region);
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);
    try testing.expect(!l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,234,567.89", num);
}

test "locale data ja_JP" {
    const testing = std.testing;
    const l = Locale.get(.ja_JP);

    try testing.expectEqualStrings("ja", l.language);
    try testing.expectEqualStrings("JP", l.region);
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);
    try testing.expect(l.time.hour_24);
    try testing.expectEqualStrings("\u{5348}\u{524d}", l.time.am); // 午前
    try testing.expectEqualStrings("\u{5348}\u{5f8c}", l.time.pm); // 午後

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,234,567.89", num);

    // Japanese list separator is ideographic comma U+3001, pair separator is U+3068 (と)
    const items = [_][]const u8{ "a", "b" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("a\u{3068}b", list);

    // Three items: separator is U+3001, last_separator is also U+3001
    const items3 = [_][]const u8{ "a", "b", "c" };
    const list3 = try l.formatList(testing.allocator, &items3);
    defer testing.allocator.free(list3);
    try testing.expectEqualStrings("a\u{3001}b\u{3001}c", list3);

    // Test JPY currency (zero decimal places)
    const currency = try l.formatCurrency(testing.allocator, 1234.0, .JPY);
    defer testing.allocator.free(currency);
    try testing.expectEqualStrings("\xc2\xa51,234", currency);
}

test "locale data ko_KR" {
    const testing = std.testing;
    const l = Locale.get(.ko_KR);

    try testing.expectEqualStrings("ko", l.language);
    try testing.expectEqualStrings("KR", l.region);
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);
    try testing.expect(!l.time.hour_24);
    try testing.expectEqualStrings("\u{c624}\u{c804}", l.time.am); // 오전
    try testing.expectEqualStrings("\u{c624}\u{d6c4}", l.time.pm); // 오후

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,234,567.89", num);

    // Korean list pair separator uses U+BC0F (및)
    const items = [_][]const u8{ "a", "b" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("a \u{bc0f} b", list);

    // Test KRW currency (zero decimal places)
    const currency = try l.formatCurrency(testing.allocator, 50000.0, .KRW);
    defer testing.allocator.free(currency);
    try testing.expectEqualStrings("\xe2\x82\xa950,000", currency);
}

test "locale data ar_SA" {
    const testing = std.testing;
    const l = Locale.get(.ar_SA);

    try testing.expectEqualStrings("ar", l.language);
    try testing.expectEqualStrings("SA", l.region);
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);
    try testing.expect(!l.time.hour_24);
    try testing.expectEqualStrings("\u{0635}", l.time.am); // ص
    try testing.expectEqualStrings("\u{0645}", l.time.pm); // م

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,234,567.89", num);

    // Arabic list separator uses Arabic comma U+060C followed by space, connector uses U+0648 (و)
    const items = [_][]const u8{ "a", "b" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("a \u{0648}b", list);
}

test "locale data he_IL" {
    const testing = std.testing;
    const l = Locale.get(.he_IL);

    try testing.expectEqualStrings("he", l.language);
    try testing.expectEqualStrings("IL", l.region);
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);
    try testing.expect(l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,234,567.89", num);

    // Hebrew list pair separator uses U+05D5 (ו)
    const items = [_][]const u8{ "a", "b" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("a \u{05d5}b", list);
}

test "locale data hi_IN" {
    const testing = std.testing;
    const l = Locale.get(.hi_IN);

    try testing.expectEqualStrings("hi", l.language);
    try testing.expectEqualStrings("IN", l.region);
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);
    try testing.expectEqual(@as(u8, 2), l.number.group_size); // Indian grouping
    try testing.expect(!l.time.hour_24);

    // Hindi AM/PM designators (Devanagari)
    try testing.expectEqualStrings("\u{092a}\u{0942}\u{0930}\u{094d}\u{0935}\u{093e}\u{0939}\u{094d}\u{0928}", l.time.am); // पूर्वाह्न
    try testing.expectEqualStrings("\u{0905}\u{092a}\u{0930}\u{093e}\u{0939}\u{094d}\u{0928}", l.time.pm); // अपराह्न

    // Hindi uses group_size=2 (Indian numbering: 12,34,567)
    // Note: formatNumber uses the group_size for grouping, but with group_size=2,
    // 1234567 -> first group is 1234567 % 2 = 1, then groups of 2: 1,23,45,67
    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,23,45,67.89", num);

    // Hindi list pair separator uses U+0914 U+0930 (और)
    const items = [_][]const u8{ "a", "b" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("a \u{0914}\u{0930} b", list);
}

test "locale data tr_TR" {
    const testing = std.testing;
    const l = Locale.get(.tr_TR);

    try testing.expectEqualStrings("tr", l.language);
    try testing.expectEqualStrings("TR", l.region);
    try testing.expectEqual(@as(u8, ','), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, '.'), l.number.group_sep);
    try testing.expect(l.time.hour_24);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1.234.567,89", num);

    // Turkish list separator
    const items = [_][]const u8{ "bir", "iki" };
    const list = try l.formatList(testing.allocator, &items);
    defer testing.allocator.free(list);
    try testing.expectEqualStrings("bir ve iki", list);

    // Turkish TRY currency
    const currency = try l.formatCurrency(testing.allocator, 1234.56, .TRY);
    defer testing.allocator.free(currency);
    try testing.expectEqualStrings("\xe2\x82\xba1.234,56", currency);
}

test "locale data root" {
    const testing = std.testing;
    const l = Locale.get(.root);

    try testing.expectEqualStrings("", l.language);
    try testing.expectEqualStrings("", l.region);
    // Root locale uses defaults
    try testing.expectEqual(@as(u8, '.'), l.number.decimal_sep);
    try testing.expectEqual(@as(u8, ','), l.number.group_sep);

    const num = try l.formatNumber(testing.allocator, 1234567.89);
    defer testing.allocator.free(num);
    try testing.expectEqualStrings("1,234,567.89", num);
}

test "all locale IDs resolve via Locale.get" {
    // Exhaustive test: every LocaleId variant returns a valid Locale
    const testing = std.testing;
    const ids = [_]LocaleId{
        .en_US, .en_GB, .en_AU, .en_CA,
        .de_DE, .fr_FR, .es_ES, .it_IT,
        .pt_BR, .pt_PT, .nl_NL, .pl_PL,
        .ru_RU, .zh_CN, .zh_TW, .ja_JP,
        .ko_KR, .ar_SA, .he_IL, .hi_IN,
        .tr_TR, .root,
    };

    for (ids) |id| {
        const l = Locale.get(id);
        try testing.expectEqual(id, l.id);
        // Every locale must have valid number format separators (non-zero)
        try testing.expect(l.number.decimal_sep != 0);
        try testing.expect(l.number.group_sep != 0);
        // Every locale must produce a valid formatted number
        const num = try l.formatNumber(testing.allocator, 42.5);
        defer testing.allocator.free(num);
        try testing.expect(num.len > 0);
    }
}
