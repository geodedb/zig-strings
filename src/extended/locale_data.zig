// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Predefined Locale Data
//!
//! Contains locale-specific data constants for all supported locales.
//! Each locale defines number, date, time, and list formatting rules.

const locale = @import("locale.zig");
const Locale = locale.Locale;

pub const root_locale = Locale{
    .id = .root,
    .language = "",
    .region = "",
    .number = .{},
    .date = .{ .short = "yyyy-MM-dd", .medium = "yyyy-MM-dd", .long = "yyyy-MM-dd", .full = "yyyy-MM-dd" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss", .hour_24 = true, .am = "AM", .pm = "PM" },
    .list = .{},
};

pub const en_US = Locale{
    .id = .en_US,
    .language = "en",
    .region = "US",
    .number = .{ .decimal_sep = '.', .group_sep = ',' },
    .date = .{ .short = "M/d/yy", .medium = "MMM d, yyyy", .long = "MMMM d, yyyy", .full = "EEEE, MMMM d, yyyy" },
    .time = .{ .short = "h:mm a", .medium = "h:mm:ss a", .long = "h:mm:ss a z", .hour_24 = false, .am = "AM", .pm = "PM" },
    .list = .{ .separator = ", ", .last_separator = ", and ", .pair_separator = " and " },
};

pub const en_GB = Locale{
    .id = .en_GB,
    .language = "en",
    .region = "GB",
    .number = .{ .decimal_sep = '.', .group_sep = ',' },
    .date = .{ .short = "dd/MM/yyyy", .medium = "d MMM yyyy", .long = "d MMMM yyyy", .full = "EEEE, d MMMM yyyy" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss z", .hour_24 = true, .am = "am", .pm = "pm" },
    .list = .{ .separator = ", ", .last_separator = " and ", .pair_separator = " and " },
};

pub const en_AU = Locale{
    .id = .en_AU,
    .language = "en",
    .region = "AU",
    .number = .{ .decimal_sep = '.', .group_sep = ',' },
    .date = .{ .short = "d/M/yy", .medium = "d MMM yyyy", .long = "d MMMM yyyy", .full = "EEEE, d MMMM yyyy" },
    .time = .{ .short = "h:mm a", .medium = "h:mm:ss a", .long = "h:mm:ss a z", .hour_24 = false, .am = "am", .pm = "pm" },
    .list = .{ .separator = ", ", .last_separator = " and ", .pair_separator = " and " },
};

pub const en_CA = Locale{
    .id = .en_CA,
    .language = "en",
    .region = "CA",
    .number = .{ .decimal_sep = '.', .group_sep = ',' },
    .date = .{ .short = "yyyy-MM-dd", .medium = "MMM d, yyyy", .long = "MMMM d, yyyy", .full = "EEEE, MMMM d, yyyy" },
    .time = .{ .short = "h:mm a", .medium = "h:mm:ss a", .long = "h:mm:ss a z", .hour_24 = false, .am = "a.m.", .pm = "p.m." },
    .list = .{ .separator = ", ", .last_separator = ", and ", .pair_separator = " and " },
};

pub const de_DE = Locale{
    .id = .de_DE,
    .language = "de",
    .region = "DE",
    .number = .{ .decimal_sep = ',', .group_sep = '.' },
    .date = .{ .short = "dd.MM.yy", .medium = "dd.MM.yyyy", .long = "d. MMMM yyyy", .full = "EEEE, d. MMMM yyyy" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss z", .hour_24 = true, .am = "", .pm = "" },
    .list = .{ .separator = ", ", .last_separator = " und ", .pair_separator = " und " },
};

pub const fr_FR = Locale{
    .id = .fr_FR,
    .language = "fr",
    .region = "FR",
    .number = .{ .decimal_sep = ',', .group_sep = ' ' },
    .date = .{ .short = "dd/MM/yyyy", .medium = "d MMM yyyy", .long = "d MMMM yyyy", .full = "EEEE d MMMM yyyy" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss z", .hour_24 = true, .am = "", .pm = "" },
    .list = .{ .separator = ", ", .last_separator = " et ", .pair_separator = " et " },
};

pub const es_ES = Locale{
    .id = .es_ES,
    .language = "es",
    .region = "ES",
    .number = .{ .decimal_sep = ',', .group_sep = '.' },
    .date = .{ .short = "d/M/yy", .medium = "d MMM yyyy", .long = "d 'de' MMMM 'de' yyyy", .full = "EEEE, d 'de' MMMM 'de' yyyy" },
    .time = .{ .short = "H:mm", .medium = "H:mm:ss", .long = "H:mm:ss z", .hour_24 = true, .am = "", .pm = "" },
    .list = .{ .separator = ", ", .last_separator = " y ", .pair_separator = " y " },
};

pub const it_IT = Locale{
    .id = .it_IT,
    .language = "it",
    .region = "IT",
    .number = .{ .decimal_sep = ',', .group_sep = '.' },
    .date = .{ .short = "dd/MM/yy", .medium = "d MMM yyyy", .long = "d MMMM yyyy", .full = "EEEE d MMMM yyyy" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss z", .hour_24 = true, .am = "", .pm = "" },
    .list = .{ .separator = ", ", .last_separator = " e ", .pair_separator = " e " },
};

pub const pt_BR = Locale{
    .id = .pt_BR,
    .language = "pt",
    .region = "BR",
    .number = .{ .decimal_sep = ',', .group_sep = '.' },
    .date = .{ .short = "dd/MM/yyyy", .medium = "d 'de' MMM 'de' yyyy", .long = "d 'de' MMMM 'de' yyyy", .full = "EEEE, d 'de' MMMM 'de' yyyy" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss z", .hour_24 = true, .am = "", .pm = "" },
    .list = .{ .separator = ", ", .last_separator = " e ", .pair_separator = " e " },
};

pub const pt_PT = Locale{
    .id = .pt_PT,
    .language = "pt",
    .region = "PT",
    .number = .{ .decimal_sep = ',', .group_sep = ' ' },
    .date = .{ .short = "dd/MM/yyyy", .medium = "d 'de' MMM 'de' yyyy", .long = "d 'de' MMMM 'de' yyyy", .full = "EEEE, d 'de' MMMM 'de' yyyy" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss z", .hour_24 = true, .am = "", .pm = "" },
    .list = .{ .separator = ", ", .last_separator = " e ", .pair_separator = " e " },
};

pub const nl_NL = Locale{
    .id = .nl_NL,
    .language = "nl",
    .region = "NL",
    .number = .{ .decimal_sep = ',', .group_sep = '.' },
    .date = .{ .short = "d-M-yy", .medium = "d MMM yyyy", .long = "d MMMM yyyy", .full = "EEEE d MMMM yyyy" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss z", .hour_24 = true, .am = "", .pm = "" },
    .list = .{ .separator = ", ", .last_separator = " en ", .pair_separator = " en " },
};

pub const pl_PL = Locale{
    .id = .pl_PL,
    .language = "pl",
    .region = "PL",
    .number = .{ .decimal_sep = ',', .group_sep = ' ' },
    .date = .{ .short = "dd.MM.yyyy", .medium = "d MMM yyyy", .long = "d MMMM yyyy", .full = "EEEE, d MMMM yyyy" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss z", .hour_24 = true, .am = "", .pm = "" },
    .list = .{ .separator = ", ", .last_separator = " i ", .pair_separator = " i " },
};

pub const ru_RU = Locale{
    .id = .ru_RU,
    .language = "ru",
    .region = "RU",
    .number = .{ .decimal_sep = ',', .group_sep = ' ' },
    .date = .{ .short = "dd.MM.yy", .medium = "d MMM yyyy", .long = "d MMMM yyyy '\u{0433}.'", .full = "EEEE, d MMMM yyyy '\u{0433}.'" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss z", .hour_24 = true, .am = "", .pm = "" },
    .list = .{ .separator = ", ", .last_separator = " \u{0438} ", .pair_separator = " \u{0438} " },
};

pub const zh_CN = Locale{
    .id = .zh_CN,
    .language = "zh",
    .region = "CN",
    .number = .{ .decimal_sep = '.', .group_sep = ',' },
    .date = .{ .short = "yyyy/M/d", .medium = "yyyy\u{5e74}M\u{6708}d\u{65e5}", .long = "yyyy\u{5e74}M\u{6708}d\u{65e5}", .full = "yyyy\u{5e74}M\u{6708}d\u{65e5}EEEE" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "z HH:mm:ss", .hour_24 = true, .am = "\u{4e0a}\u{5348}", .pm = "\u{4e0b}\u{5348}" },
    .list = .{ .separator = "\u{3001}", .last_separator = "\u{548c}", .pair_separator = "\u{548c}" },
};

pub const zh_TW = Locale{
    .id = .zh_TW,
    .language = "zh",
    .region = "TW",
    .number = .{ .decimal_sep = '.', .group_sep = ',' },
    .date = .{ .short = "yyyy/M/d", .medium = "yyyy\u{5e74}M\u{6708}d\u{65e5}", .long = "yyyy\u{5e74}M\u{6708}d\u{65e5}", .full = "yyyy\u{5e74}M\u{6708}d\u{65e5} EEEE" },
    .time = .{ .short = "ah:mm", .medium = "ah:mm:ss", .long = "z ah:mm:ss", .hour_24 = false, .am = "\u{4e0a}\u{5348}", .pm = "\u{4e0b}\u{5348}" },
    .list = .{ .separator = "\u{3001}", .last_separator = "\u{548c}", .pair_separator = "\u{548c}" },
};

pub const ja_JP = Locale{
    .id = .ja_JP,
    .language = "ja",
    .region = "JP",
    .number = .{ .decimal_sep = '.', .group_sep = ',' },
    .date = .{ .short = "yyyy/MM/dd", .medium = "yyyy\u{5e74}M\u{6708}d\u{65e5}", .long = "yyyy\u{5e74}M\u{6708}d\u{65e5}", .full = "yyyy\u{5e74}M\u{6708}d\u{65e5}EEEE" },
    .time = .{ .short = "H:mm", .medium = "H:mm:ss", .long = "H:mm:ss z", .hour_24 = true, .am = "\u{5348}\u{524d}", .pm = "\u{5348}\u{5f8c}" },
    .list = .{ .separator = "\u{3001}", .last_separator = "\u{3001}", .pair_separator = "\u{3068}" },
};

pub const ko_KR = Locale{
    .id = .ko_KR,
    .language = "ko",
    .region = "KR",
    .number = .{ .decimal_sep = '.', .group_sep = ',' },
    .date = .{ .short = "yy. M. d.", .medium = "yyyy. M. d.", .long = "yyyy\u{b144} M\u{c6d4} d\u{c77c}", .full = "yyyy\u{b144} M\u{c6d4} d\u{c77c} EEEE" },
    .time = .{ .short = "a h:mm", .medium = "a h:mm:ss", .long = "a h\u{c2dc} m\u{bd84} s\u{cd08} z", .hour_24 = false, .am = "\u{c624}\u{c804}", .pm = "\u{c624}\u{d6c4}" },
    .list = .{ .separator = ", ", .last_separator = " \u{bc0f} ", .pair_separator = " \u{bc0f} " },
};

pub const ar_SA = Locale{
    .id = .ar_SA,
    .language = "ar",
    .region = "SA",
    .number = .{ .decimal_sep = '.', .group_sep = ',' },
    .date = .{ .short = "d/M/yy", .medium = "dd/MM/yyyy", .long = "d MMMM yyyy", .full = "EEEE\u{060c} d MMMM yyyy" },
    .time = .{ .short = "h:mm a", .medium = "h:mm:ss a", .long = "h:mm:ss a z", .hour_24 = false, .am = "\u{0635}", .pm = "\u{0645}" },
    .list = .{ .separator = "\u{060c} ", .last_separator = "\u{060c} \u{0648}", .pair_separator = " \u{0648}" },
};

pub const he_IL = Locale{
    .id = .he_IL,
    .language = "he",
    .region = "IL",
    .number = .{ .decimal_sep = '.', .group_sep = ',' },
    .date = .{ .short = "d.M.yyyy", .medium = "d \u{05d1}MMM yyyy", .long = "d \u{05d1}MMMM yyyy", .full = "EEEE, d \u{05d1}MMMM yyyy" },
    .time = .{ .short = "H:mm", .medium = "H:mm:ss", .long = "H:mm:ss z", .hour_24 = true, .am = "", .pm = "" },
    .list = .{ .separator = ", ", .last_separator = " \u{05d5}", .pair_separator = " \u{05d5}" },
};

pub const hi_IN = Locale{
    .id = .hi_IN,
    .language = "hi",
    .region = "IN",
    .number = .{ .decimal_sep = '.', .group_sep = ',', .group_size = 2 },
    .date = .{ .short = "d/M/yy", .medium = "d MMM yyyy", .long = "d MMMM yyyy", .full = "EEEE, d MMMM yyyy" },
    .time = .{ .short = "h:mm a", .medium = "h:mm:ss a", .long = "h:mm:ss a z", .hour_24 = false, .am = "\u{092a}\u{0942}\u{0930}\u{094d}\u{0935}\u{093e}\u{0939}\u{094d}\u{0928}", .pm = "\u{0905}\u{092a}\u{0930}\u{093e}\u{0939}\u{094d}\u{0928}" },
    .list = .{ .separator = ", ", .last_separator = ", \u{0914}\u{0930} ", .pair_separator = " \u{0914}\u{0930} " },
};

pub const tr_TR = Locale{
    .id = .tr_TR,
    .language = "tr",
    .region = "TR",
    .number = .{ .decimal_sep = ',', .group_sep = '.' },
    .date = .{ .short = "d.MM.yyyy", .medium = "d MMM yyyy", .long = "d MMMM yyyy", .full = "d MMMM yyyy EEEE" },
    .time = .{ .short = "HH:mm", .medium = "HH:mm:ss", .long = "HH:mm:ss z", .hour_24 = true, .am = "\u{00d6}\u{00d6}", .pm = "\u{00d6}S" },
    .list = .{ .separator = ", ", .last_separator = " ve ", .pair_separator = " ve " },
};
