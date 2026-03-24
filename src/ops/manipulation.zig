// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String manipulation operations.
//!
//! This module provides functions for manipulating strings including
//! split, join, trim, pad, repeat, reverse, and replace operations.
//!
//! Implementation is split across sub-modules for maintainability:
//!   - splitting.zig: split, join, fields operations
//!   - trimming.zig: trim, character membership operations
//!   - transform.zig: pad, repeat, reverse, replace, concat, map operations

const std = @import("std");
const types = @import("types");

pub const Codepoint = types.Codepoint;
pub const StringError = types.StringError;
pub const TrimOptions = types.TrimOptions;
pub const SplitOptions = types.SplitOptions;

// ============================================================================
// Sub-module imports
// ============================================================================

const splitting = @import("splitting.zig");
const trimming = @import("trimming.zig");
const transform = @import("transform.zig");

// ============================================================================
// Splitting and joining operations (from splitting.zig)
// ============================================================================

pub const split = splitting.split;
pub const splitWithOptions = splitting.splitWithOptions;
pub const join = splitting.join;
pub const fields = splitting.fields;
pub const fieldsFunc = splitting.fieldsFunc;
pub const splitN = splitting.splitN;
pub const splitAfter = splitting.splitAfter;
pub const splitAfterN = splitting.splitAfterN;

// ============================================================================
// Trimming and character membership operations (from trimming.zig)
// ============================================================================

pub const trim = trimming.trim;
pub const trimLeft = trimming.trimLeft;
pub const trimRight = trimming.trimRight;
pub const trimChars = trimming.trimChars;
pub const trimLeftChars = trimming.trimLeftChars;
pub const trimRightChars = trimming.trimRightChars;
pub const trimLeftFunc = trimming.trimLeftFunc;
pub const trimRightFunc = trimming.trimRightFunc;
pub const trimFunc = trimming.trimFunc;
pub const cutPrefix = trimming.cutPrefix;
pub const cutSuffix = trimming.cutSuffix;
pub const trimPrefix = trimming.trimPrefix;
pub const trimSuffix = trimming.trimSuffix;
pub const containsAny = trimming.containsAny;
pub const containsFunc = trimming.containsFunc;

// ============================================================================
// Transform operations (from transform.zig)
// ============================================================================

pub const padLeft = transform.padLeft;
pub const padRight = transform.padRight;
pub const repeat = transform.repeat;
pub const reverse = transform.reverse;
pub const replace = transform.replace;
pub const replaceN = transform.replaceN;
pub const substring = transform.substring;
pub const concat = transform.concat;
pub const CutResult = transform.CutResult;
pub const cut = transform.cut;
pub const mapFunc = transform.mapFunc;
pub const toValidUtf8 = transform.toValidUtf8;

// ============================================================================
// Tests -- pull in sub-module tests so `zig test` on this file runs them all
// ============================================================================

test {
    std.testing.refAllDecls(@This());
    _ = splitting;
    _ = trimming;
    _ = transform;
}
