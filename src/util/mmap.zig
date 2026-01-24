// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Memory-Mapped String Support
//!
//! Provides efficient memory-mapped file access for large string data.
//! Uses mmap on POSIX systems and MapViewOfFile on Windows to map
//! files directly into virtual memory without copying.
//!
//! Benefits:
//! - Zero-copy access to file contents
//! - OS handles paging automatically
//! - Efficient for large files (GBs)
//! - Read-only view prevents accidental modification
//!
//! Usage:
//! ```zig
//! var mstr = try MappedString.open(allocator, "large_file.txt");
//! defer mstr.close();
//!
//! // Access data directly
//! const slice = mstr.bytes();
//! std.debug.print("First line: {s}\n", .{mstr.lineAt(0)});
//! ```

const std = @import("std");
const builtin = @import("builtin");

/// Error types for memory mapping operations
pub const MmapError = error{
    /// File could not be opened
    FileOpenFailed,
    /// Memory mapping failed
    MappingFailed,
    /// File is empty
    EmptyFile,
    /// Offset exceeds file size
    OffsetOutOfRange,
    /// File stat failed
    StatFailed,
    /// Invalid arguments
    InvalidArgument,
    /// System error
    SystemError,
    /// Out of memory
    OutOfMemory,
};

/// Whether to use true mmap (POSIX) or fallback to allocated memory
const use_mmap = switch (builtin.os.tag) {
    .linux, .macos, .freebsd, .netbsd, .openbsd, .dragonfly, .ios, .tvos, .watchos => true,
    else => false,
};

/// A string backed by a memory-mapped file (or allocated memory on non-POSIX)
pub const MappedString = struct {
    /// The memory-mapped region (null if empty)
    /// On POSIX: actual mmap'd region
    /// On other platforms: allocated memory buffer
    data: ?[]align(std.mem.page_size) const u8,

    /// Fallback allocated data (non-page-aligned, for non-POSIX platforms)
    allocated_data: ?[]const u8,

    /// The file handle (for cleanup)
    file: ?std.fs.File,

    /// Total size of the mapped region
    len: usize,

    /// Original file path (for debugging/reopening)
    path: ?[]const u8,

    /// Allocator used for path and data storage
    allocator: ?std.mem.Allocator,

    /// Whether this uses true mmap (false = allocated memory fallback)
    is_mmap: bool,

    const Self = @This();

    /// Open a file and map it into memory
    pub fn open(allocator: std.mem.Allocator, path: []const u8) MmapError!Self {
        return openAdvanced(allocator, path, .{});
    }

    /// Options for advanced opening
    pub const OpenOptions = struct {
        /// Offset from start of file (must be page-aligned)
        offset: usize = 0,
        /// Length to map (0 = entire file from offset)
        length: usize = 0,
        /// Store the path for later reference
        store_path: bool = true,
    };

    /// Open a file with advanced options
    pub fn openAdvanced(allocator: std.mem.Allocator, path: []const u8, options: OpenOptions) MmapError!Self {
        // Open the file
        const file = std.fs.cwd().openFile(path, .{ .mode = .read_only }) catch {
            return MmapError.FileOpenFailed;
        };
        errdefer file.close();

        // Get file size
        const stat = file.stat() catch {
            return MmapError.StatFailed;
        };
        const file_size = stat.size;

        if (file_size == 0) {
            file.close();
            return Self{
                .data = null,
                .allocated_data = null,
                .file = null,
                .len = 0,
                .path = if (options.store_path) allocator.dupe(u8, path) catch return MmapError.OutOfMemory else null,
                .allocator = if (options.store_path) allocator else null,
                .is_mmap = false,
            };
        }

        // Validate offset
        if (options.offset >= file_size) {
            return MmapError.OffsetOutOfRange;
        }

        // Calculate length to map
        const map_len = if (options.length == 0)
            file_size - options.offset
        else
            @min(options.length, file_size - options.offset);

        // Store path if requested
        const stored_path: ?[]const u8 = if (options.store_path)
            allocator.dupe(u8, path) catch return MmapError.OutOfMemory
        else
            null;
        errdefer if (stored_path) |p| allocator.free(p);

        // Use mmap on POSIX, fallback to allocation on other platforms
        if (use_mmap) {
            // POSIX memory mapping
            const mapped = std.posix.mmap(
                null,
                map_len,
                std.posix.PROT.READ,
                .{ .TYPE = .PRIVATE },
                file.handle,
                @intCast(options.offset),
            ) catch {
                return MmapError.MappingFailed;
            };

            return Self{
                .data = mapped,
                .allocated_data = null,
                .file = file,
                .len = map_len,
                .path = stored_path,
                .allocator = if (options.store_path) allocator else null,
                .is_mmap = true,
            };
        } else {
            // Fallback: read file into allocated memory
            // Seek to offset first
            if (options.offset > 0) {
                file.seekTo(options.offset) catch {
                    return MmapError.SystemError;
                };
            }

            // Allocate buffer and read
            const buffer = allocator.alloc(u8, map_len) catch {
                return MmapError.OutOfMemory;
            };
            errdefer allocator.free(buffer);

            const bytes_read = file.readAll(buffer) catch {
                return MmapError.SystemError;
            };

            // Close file - we don't need it anymore for the fallback case
            file.close();

            return Self{
                .data = null,
                .allocated_data = buffer[0..bytes_read],
                .file = null,
                .len = bytes_read,
                .path = stored_path,
                .allocator = allocator, // Always need allocator for fallback
                .is_mmap = false,
            };
        }
    }

    /// Create a MappedString from an existing slice (doesn't own memory)
    pub fn fromSlice(input: []const u8) Self {
        // Cast the slice - we don't own it so we need to track that
        return Self{
            .data = null, // Can't cast arbitrary slice to page-aligned
            .allocated_data = input, // Reference the input slice
            .file = null,
            .len = input.len,
            .path = null,
            .allocator = null, // null means we don't own it
            .is_mmap = false,
        };
    }

    /// Close the memory mapping and release resources
    pub fn close(self: *Self) void {
        // Unmap or free the data
        if (self.is_mmap) {
            // POSIX mmap case
            if (self.data) |data| {
                std.posix.munmap(data);
                self.data = null;
            }
        } else {
            // Fallback allocation case - only free if we own it (allocator is set)
            if (self.allocator) |alloc| {
                if (self.allocated_data) |d| {
                    alloc.free(d);
                }
            }
            self.allocated_data = null;
        }

        // Close file handle if open
        if (self.file) |file| {
            file.close();
            self.file = null;
        }

        // Free path string if we allocated it
        if (self.allocator) |alloc| {
            if (self.path) |p| {
                alloc.free(p);
                self.path = null;
            }
        }

        self.len = 0;
    }

    /// Get the bytes of the mapped region
    pub fn bytes(self: Self) []const u8 {
        // Try mmap'd data first
        if (self.data) |data| {
            return data[0..self.len];
        }
        // Then try allocated/referenced data
        if (self.allocated_data) |data| {
            return data[0..self.len];
        }
        return "";
    }

    /// Get the length of the mapped data
    pub fn length(self: Self) usize {
        return self.len;
    }

    /// Check if the mapped region is empty
    pub fn isEmpty(self: Self) bool {
        return self.len == 0;
    }

    /// Get a slice of the mapped data
    pub fn slice(self: Self, start: usize, end: usize) []const u8 {
        const data = self.bytes();
        if (start >= data.len) return "";
        const actual_end = @min(end, data.len);
        return data[start..actual_end];
    }

    /// Get data starting at index
    pub fn from(self: Self, start: usize) []const u8 {
        const data = self.bytes();
        if (start >= data.len) return "";
        return data[start..];
    }

    /// Iterator over lines in the mapped data
    pub fn lines(self: Self) LineIterator {
        return LineIterator.init(self.bytes());
    }

    /// Count the number of lines
    pub fn lineCount(self: Self) usize {
        var count: usize = 0;
        var iter = self.lines();
        while (iter.next()) |_| {
            count += 1;
        }
        return count;
    }

    /// Get a specific line by index (0-based)
    pub fn lineAt(self: Self, index: usize) ?[]const u8 {
        var iter = self.lines();
        var current: usize = 0;
        while (iter.next()) |line| {
            if (current == index) return line;
            current += 1;
        }
        return null;
    }

    /// Search for a byte in the mapped data
    pub fn indexOf(self: Self, needle: u8) ?usize {
        return std.mem.indexOfScalar(u8, self.bytes(), needle);
    }

    /// Search for a substring in the mapped data
    pub fn indexOfString(self: Self, needle: []const u8) ?usize {
        return std.mem.indexOf(u8, self.bytes(), needle);
    }

    /// Check if the mapped data contains a substring
    pub fn contains(self: Self, needle: []const u8) bool {
        return self.indexOfString(needle) != null;
    }

    /// Check if the data starts with the given prefix
    pub fn startsWith(self: Self, prefix: []const u8) bool {
        return std.mem.startsWith(u8, self.bytes(), prefix);
    }

    /// Check if the data ends with the given suffix
    pub fn endsWith(self: Self, suffix: []const u8) bool {
        return std.mem.endsWith(u8, self.bytes(), suffix);
    }
};

/// Iterator over lines in memory-mapped data
pub const LineIterator = struct {
    data: []const u8,
    pos: usize,

    const Self = @This();

    pub fn init(data: []const u8) Self {
        return Self{
            .data = data,
            .pos = 0,
        };
    }

    pub fn next(self: *Self) ?[]const u8 {
        if (self.pos >= self.data.len) return null;

        const start = self.pos;

        // Find end of line
        while (self.pos < self.data.len and self.data[self.pos] != '\n') {
            self.pos += 1;
        }

        // Get the line (excluding \n)
        var end = self.pos;

        // Handle \r\n
        if (end > start and self.data[end - 1] == '\r') {
            end -= 1;
        }

        // Skip the newline
        if (self.pos < self.data.len) {
            self.pos += 1;
        }

        return self.data[start..end];
    }

    pub fn reset(self: *Self) void {
        self.pos = 0;
    }
};

/// Memory-mapped string pool for multiple files
pub const MappedStringPool = struct {
    mappings: std.ArrayList(MappedString),
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .mappings = std.ArrayList(MappedString).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.mappings.items) |*mapping| {
            mapping.close();
        }
        self.mappings.deinit();
    }

    /// Add a file to the pool
    pub fn add(self: *Self, path: []const u8) MmapError!usize {
        var mapping = try MappedString.open(self.allocator, path);
        errdefer mapping.close();

        self.mappings.append(mapping) catch return MmapError.OutOfMemory;
        return self.mappings.items.len - 1;
    }

    /// Get a mapping by index
    pub fn get(self: Self, index: usize) ?MappedString {
        if (index >= self.mappings.items.len) return null;
        return self.mappings.items[index];
    }

    /// Get bytes from a mapping
    pub fn getBytes(self: Self, index: usize) []const u8 {
        if (self.get(index)) |mapping| {
            return mapping.bytes();
        }
        return "";
    }

    /// Count total mapped bytes
    pub fn totalBytes(self: Self) usize {
        var total: usize = 0;
        for (self.mappings.items) |mapping| {
            total += mapping.len;
        }
        return total;
    }
};

/// Helper to check if mmap is available on this platform
pub fn isMmapAvailable() bool {
    return use_mmap;
}

/// Check if a specific MappedString instance is using true mmap
pub fn isTrueMmap(mstr: MappedString) bool {
    return mstr.is_mmap;
}

// ============================================================
// Tests
// ============================================================

test "MappedString basic operations" {
    const testing = std.testing;

    // Create a temporary file for testing
    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content = "Hello, World!\nLine 2\nLine 3\n";
    const tmp_file = try tmp_dir.dir.createFile("test.txt", .{});
    try tmp_file.writeAll(content);
    tmp_file.close();

    // Get the full path
    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp_dir.dir.realpath("test.txt", &path_buf);

    var mstr = try MappedString.open(testing.allocator, path);
    defer mstr.close();

    try testing.expectEqual(content.len, mstr.length());
    try testing.expectEqualStrings(content, mstr.bytes());
    try testing.expect(!mstr.isEmpty());
}

test "MappedString line iteration" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content = "Line 1\nLine 2\nLine 3\n";
    const tmp_file = try tmp_dir.dir.createFile("lines.txt", .{});
    try tmp_file.writeAll(content);
    tmp_file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp_dir.dir.realpath("lines.txt", &path_buf);

    var mstr = try MappedString.open(testing.allocator, path);
    defer mstr.close();

    try testing.expectEqual(@as(usize, 4), mstr.lineCount()); // 3 lines + empty after trailing \n
    try testing.expectEqualStrings("Line 1", mstr.lineAt(0).?);
    try testing.expectEqualStrings("Line 2", mstr.lineAt(1).?);
    try testing.expectEqualStrings("Line 3", mstr.lineAt(2).?);
}

test "MappedString search operations" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content = "The quick brown fox jumps over the lazy dog";
    const tmp_file = try tmp_dir.dir.createFile("search.txt", .{});
    try tmp_file.writeAll(content);
    tmp_file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp_dir.dir.realpath("search.txt", &path_buf);

    var mstr = try MappedString.open(testing.allocator, path);
    defer mstr.close();

    try testing.expect(mstr.contains("fox"));
    try testing.expect(!mstr.contains("cat"));
    try testing.expect(mstr.startsWith("The"));
    try testing.expect(mstr.endsWith("dog"));
    try testing.expectEqual(@as(?usize, 16), mstr.indexOfString("fox"));
}

test "MappedStringPool" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    // Create test files
    const file1 = try tmp_dir.dir.createFile("file1.txt", .{});
    try file1.writeAll("File 1 content");
    file1.close();

    const file2 = try tmp_dir.dir.createFile("file2.txt", .{});
    try file2.writeAll("File 2 content here");
    file2.close();

    var path_buf1: [std.fs.max_path_bytes]u8 = undefined;
    const path1 = try tmp_dir.dir.realpath("file1.txt", &path_buf1);

    var path_buf2: [std.fs.max_path_bytes]u8 = undefined;
    const path2 = try tmp_dir.dir.realpath("file2.txt", &path_buf2);

    var pool = MappedStringPool.init(testing.allocator);
    defer pool.deinit();

    const idx1 = try pool.add(path1);
    const idx2 = try pool.add(path2);

    try testing.expectEqual(@as(usize, 0), idx1);
    try testing.expectEqual(@as(usize, 1), idx2);
    try testing.expectEqualStrings("File 1 content", pool.getBytes(0));
    try testing.expectEqualStrings("File 2 content here", pool.getBytes(1));
    try testing.expectEqual(@as(usize, 33), pool.totalBytes());
}

test "LineIterator" {
    const testing = std.testing;

    const data = "Line 1\nLine 2\r\nLine 3";
    var iter = LineIterator.init(data);

    try testing.expectEqualStrings("Line 1", iter.next().?);
    try testing.expectEqualStrings("Line 2", iter.next().?);
    try testing.expectEqualStrings("Line 3", iter.next().?);
    try testing.expectEqual(@as(?[]const u8, null), iter.next());

    iter.reset();
    try testing.expectEqualStrings("Line 1", iter.next().?);
}

test "empty file" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const tmp_file = try tmp_dir.dir.createFile("empty.txt", .{});
    tmp_file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp_dir.dir.realpath("empty.txt", &path_buf);

    var mstr = try MappedString.open(testing.allocator, path);
    defer mstr.close();

    try testing.expect(mstr.isEmpty());
    try testing.expectEqual(@as(usize, 0), mstr.length());
    try testing.expectEqualStrings("", mstr.bytes());
}

test "fromSlice creates non-owning reference" {
    const testing = std.testing;

    const data = "Hello from slice!";
    var mstr = MappedString.fromSlice(data);
    // Don't call close - we don't own the data

    try testing.expectEqual(@as(usize, data.len), mstr.length());
    try testing.expectEqualStrings(data, mstr.bytes());
    try testing.expect(!mstr.is_mmap);
    try testing.expect(!isTrueMmap(mstr));
}

test "isMmapAvailable returns correct value for platform" {
    const testing = std.testing;

    // This test verifies that isMmapAvailable matches use_mmap constant
    try testing.expectEqual(use_mmap, isMmapAvailable());

    // On Linux, we expect true mmap to be available
    if (builtin.os.tag == .linux) {
        try testing.expect(isMmapAvailable());
    }
}

test "MappedString reports mmap status correctly" {
    const testing = std.testing;

    var tmp_dir = testing.tmpDir(.{});
    defer tmp_dir.cleanup();

    const content = "Test content for mmap status check";
    const tmp_file = try tmp_dir.dir.createFile("mmap_status.txt", .{});
    try tmp_file.writeAll(content);
    tmp_file.close();

    var path_buf: [std.fs.max_path_bytes]u8 = undefined;
    const path = try tmp_dir.dir.realpath("mmap_status.txt", &path_buf);

    var mstr = try MappedString.open(testing.allocator, path);
    defer mstr.close();

    // Verify content is correct regardless of mmap vs fallback
    try testing.expectEqualStrings(content, mstr.bytes());

    // On POSIX systems, should use true mmap; on others, should use fallback
    try testing.expectEqual(use_mmap, mstr.is_mmap);
    try testing.expectEqual(use_mmap, isTrueMmap(mstr));
}
