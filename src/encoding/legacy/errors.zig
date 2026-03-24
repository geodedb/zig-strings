// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Shared error types for legacy encoding modules.
//!
//! All legacy encoding modules (Big5, Chinese, Japanese, Korean,
//! Windows code pages, ISO-8859) share the same error semantics.
//! This module provides a single canonical error set to avoid
//! duplicating identical definitions across six files.

/// Errors that can occur during legacy encoding/decoding operations.
pub const LegacyEncodingError = error{
    /// The input byte sequence is not valid for the encoding.
    InvalidSequence,
    /// The Unicode codepoint cannot be represented in the target encoding.
    UnmappableCharacter,
    /// Memory allocation failed.
    OutOfMemory,
};
