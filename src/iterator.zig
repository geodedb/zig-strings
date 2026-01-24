// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! String iterators for various segmentation levels.
//!
//! This module provides unified iterator interfaces for iterating over
//! strings at different granularities: bytes, code points, grapheme clusters,
//! words, sentences, and lines.

const std = @import("std");
const types = @import("types");
const codepoint_mod = @import("codepoint");
const utf8 = @import("utf8");
const utf16 = @import("utf16");
const grapheme = @import("grapheme");
const word = @import("word");
const sentence = @import("sentence");

pub const Codepoint = types.Codepoint;

/// Iterator over UTF-8 code points
pub const CodepointIterator = utf8.Iterator;

/// Iterator over UTF-16 code points
pub const Utf16CodepointIterator = utf16.Iterator;

/// Iterator over grapheme clusters
pub const GraphemeIterator = grapheme.Iterator;

/// Iterator over words
pub const WordIterator = word.Iterator;

/// Iterator over sentences
pub const SentenceIterator = sentence.Iterator;

/// Iterator over lines (split by line terminators)
pub const LineIterator = struct {
    bytes: []const u8,
    index: usize,
    include_terminator: bool,

    pub fn init(bytes: []const u8, options: LineOptions) LineIterator {
        return .{
            .bytes = bytes,
            .index = 0,
            .include_terminator = options.include_terminator,
        };
    }

    pub fn next(self: *LineIterator) ?[]const u8 {
        if (self.index >= self.bytes.len) {
            return null;
        }

        const start = self.index;
        var end = start;

        // Find line terminator
        while (end < self.bytes.len) {
            if (self.bytes[end] == '\n') {
                if (self.include_terminator) {
                    end += 1;
                }
                self.index = end + @intFromBool(!self.include_terminator);
                return self.bytes[start..end];
            }
            if (self.bytes[end] == '\r') {
                const line_end = end;
                end += 1;
                // Check for CRLF
                if (end < self.bytes.len and self.bytes[end] == '\n') {
                    end += 1;
                }
                if (self.include_terminator) {
                    self.index = end;
                    return self.bytes[start..end];
                } else {
                    self.index = end;
                    return self.bytes[start..line_end];
                }
            }
            end += 1;
        }

        // No terminator found - return rest of string
        self.index = self.bytes.len;
        return self.bytes[start..];
    }

    pub fn reset(self: *LineIterator) void {
        self.index = 0;
    }
};

/// Options for line iteration
pub const LineOptions = struct {
    /// Include line terminators in output
    include_terminator: bool = false,
};

/// Creates a line iterator
pub fn lines(bytes: []const u8) LineIterator {
    return LineIterator.init(bytes, .{});
}

/// Creates a line iterator with options
pub fn linesWithOptions(bytes: []const u8, options: LineOptions) LineIterator {
    return LineIterator.init(bytes, options);
}

/// Creates a code point iterator
pub fn codepoints(bytes: []const u8) CodepointIterator {
    return CodepointIterator.init(bytes);
}

/// Creates a grapheme cluster iterator
pub fn graphemes(bytes: []const u8) GraphemeIterator {
    return GraphemeIterator.init(bytes);
}

/// Creates a word iterator
pub fn words(bytes: []const u8) WordIterator {
    return WordIterator.init(bytes);
}

/// Creates a sentence iterator
pub fn sentences(bytes: []const u8) SentenceIterator {
    return SentenceIterator.init(bytes);
}

/// Reverse iterator over code points
pub const ReverseCodepointIterator = struct {
    bytes: []const u8,
    index: usize,

    pub fn init(bytes: []const u8) ReverseCodepointIterator {
        return .{
            .bytes = bytes,
            .index = bytes.len,
        };
    }

    pub fn next(self: *ReverseCodepointIterator) ?Codepoint {
        if (self.index == 0) {
            return null;
        }

        // Find start of code point (scan back for non-continuation byte)
        var start = self.index - 1;
        while (start > 0 and utf8.isContinuationByte(self.bytes[start])) {
            start -= 1;
        }

        const result = utf8.decode(self.bytes[start..self.index]) catch {
            self.index -= 1;
            return types.replacement_character;
        };

        self.index = start;
        return result.value;
    }

    pub fn reset(self: *ReverseCodepointIterator) void {
        self.index = self.bytes.len;
    }
};

/// Creates a reverse code point iterator
pub fn codepointsReverse(bytes: []const u8) ReverseCodepointIterator {
    return ReverseCodepointIterator.init(bytes);
}

/// Split iterator - splits on a delimiter
pub const SplitIterator = struct {
    bytes: []const u8,
    delimiter: []const u8,
    index: ?usize,
    done: bool,

    pub fn init(bytes: []const u8, delimiter: []const u8) SplitIterator {
        return .{
            .bytes = bytes,
            .delimiter = delimiter,
            .index = 0,
            .done = false,
        };
    }

    pub fn next(self: *SplitIterator) ?[]const u8 {
        if (self.done) return null;

        const start = self.index orelse return null;

        // Find next delimiter
        if (std.mem.indexOfPos(u8, self.bytes, start, self.delimiter)) |pos| {
            self.index = pos + self.delimiter.len;
            return self.bytes[start..pos];
        }

        // No more delimiters
        self.done = true;
        self.index = null;
        return self.bytes[start..];
    }

    pub fn reset(self: *SplitIterator) void {
        self.index = 0;
        self.done = false;
    }
};

/// Creates a split iterator
pub fn split(bytes: []const u8, delimiter: []const u8) SplitIterator {
    return SplitIterator.init(bytes, delimiter);
}

/// Chunk iterator - yields fixed-size chunks
pub const ChunkIterator = struct {
    bytes: []const u8,
    chunk_size: usize,
    index: usize,

    pub fn init(bytes: []const u8, chunk_size: usize) ChunkIterator {
        return .{
            .bytes = bytes,
            .chunk_size = chunk_size,
            .index = 0,
        };
    }

    pub fn next(self: *ChunkIterator) ?[]const u8 {
        if (self.index >= self.bytes.len) {
            return null;
        }

        const end = @min(self.index + self.chunk_size, self.bytes.len);
        const chunk = self.bytes[self.index..end];
        self.index = end;
        return chunk;
    }

    pub fn reset(self: *ChunkIterator) void {
        self.index = 0;
    }
};

/// Creates a chunk iterator
pub fn chunks(bytes: []const u8, chunk_size: usize) ChunkIterator {
    return ChunkIterator.init(bytes, chunk_size);
}

test "line iterator" {
    const testing = std.testing;

    var iter = lines("line1\nline2\r\nline3");
    try testing.expectEqualSlices(u8, "line1", iter.next().?);
    try testing.expectEqualSlices(u8, "line2", iter.next().?);
    try testing.expectEqualSlices(u8, "line3", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "line iterator with terminator" {
    const testing = std.testing;

    var iter = linesWithOptions("line1\nline2\n", .{ .include_terminator = true });
    try testing.expectEqualSlices(u8, "line1\n", iter.next().?);
    try testing.expectEqualSlices(u8, "line2\n", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "reverse codepoint iterator" {
    const testing = std.testing;

    var iter = codepointsReverse("ABC");
    try testing.expectEqual(@as(?Codepoint, 'C'), iter.next());
    try testing.expectEqual(@as(?Codepoint, 'B'), iter.next());
    try testing.expectEqual(@as(?Codepoint, 'A'), iter.next());
    try testing.expectEqual(@as(?Codepoint, null), iter.next());
}

test "split iterator" {
    const testing = std.testing;

    var iter = split("a,b,c", ",");
    try testing.expectEqualSlices(u8, "a", iter.next().?);
    try testing.expectEqualSlices(u8, "b", iter.next().?);
    try testing.expectEqualSlices(u8, "c", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "chunk iterator" {
    const testing = std.testing;

    var iter = chunks("abcdefg", 3);
    try testing.expectEqualSlices(u8, "abc", iter.next().?);
    try testing.expectEqualSlices(u8, "def", iter.next().?);
    try testing.expectEqualSlices(u8, "g", iter.next().?);
    try testing.expect(iter.next() == null);
}

test "codepoint iterator" {
    const testing = std.testing;

    var iter = codepoints("A\xC3\xA9"); // "Aé"
    try testing.expectEqual(@as(?Codepoint, 'A'), iter.next());
    try testing.expectEqual(@as(?Codepoint, 0x00E9), iter.next());
    try testing.expectEqual(@as(?Codepoint, null), iter.next());
}
