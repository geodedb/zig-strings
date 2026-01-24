// SPDX-License-Identifier: Apache-2.0
// Copyright (c) 2024-2025 CodePros

//! Rope Data Structure
//!
//! A rope is a binary tree used for efficiently storing and manipulating
//! very long strings. It provides O(log n) concatenation, insertion, and
//! deletion operations instead of O(n) for contiguous strings.
//!
//! Key advantages:
//! - Efficient concatenation: O(log n) instead of O(n)
//! - Efficient insertion/deletion: O(log n)
//! - Memory-efficient: can share structure between copies
//! - Good cache locality for sequential access
//!
//! Use cases:
//! - Text editors with large documents
//! - Log aggregation
//! - Building large strings incrementally

const std = @import("std");

/// Maximum size of a leaf node (bytes)
pub const LEAF_SIZE: usize = 1024;

/// Minimum leaf size before merging
pub const MIN_LEAF_SIZE: usize = LEAF_SIZE / 4;

/// Rope node - either a leaf containing data or an internal node with children
pub const Node = union(enum) {
    leaf: Leaf,
    branch: Branch,

    pub const Leaf = struct {
        data: []const u8,
        owned: bool, // Whether we own the data and should free it

        pub fn deinit(self: *Leaf, allocator: std.mem.Allocator) void {
            if (self.owned) {
                allocator.free(self.data);
            }
        }
    };

    pub const Branch = struct {
        left: *Node,
        right: *Node,
        len: usize, // Total length of this subtree
        depth: u32, // Height of subtree for balancing

        pub fn deinit(self: *Branch, allocator: std.mem.Allocator) void {
            self.left.deinit(allocator);
            allocator.destroy(self.left);
            self.right.deinit(allocator);
            allocator.destroy(self.right);
        }
    };

    pub fn deinit(self: *Node, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .leaf => |*l| l.deinit(allocator),
            .branch => |*b| b.deinit(allocator),
        }
    }

    pub fn len(self: Node) usize {
        return switch (self) {
            .leaf => |l| l.data.len,
            .branch => |b| b.len,
        };
    }

    pub fn depth(self: Node) u32 {
        return switch (self) {
            .leaf => 0,
            .branch => |b| b.depth,
        };
    }
};

/// Rope - an efficient data structure for manipulating long strings
pub const Rope = struct {
    root: ?*Node,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Creates an empty rope
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{
            .root = null,
            .allocator = allocator,
        };
    }

    /// Creates a rope from a string slice (does not copy the data)
    pub fn fromSlice(allocator: std.mem.Allocator, data: []const u8) !Self {
        if (data.len == 0) {
            return init(allocator);
        }

        var rope = init(allocator);
        rope.root = try createLeafNodes(allocator, data, false);
        return rope;
    }

    /// Creates a rope from owned data (takes ownership of the memory)
    pub fn fromOwned(allocator: std.mem.Allocator, data: []const u8) !Self {
        if (data.len == 0) {
            return init(allocator);
        }

        var rope = init(allocator);
        rope.root = try createLeafNodes(allocator, data, true);
        return rope;
    }

    /// Creates a rope by copying the input string
    pub fn fromCopy(allocator: std.mem.Allocator, data: []const u8) !Self {
        if (data.len == 0) {
            return init(allocator);
        }

        const copy = try allocator.dupe(u8, data);
        return fromOwned(allocator, copy);
    }

    /// Frees all memory associated with the rope
    pub fn deinit(self: *Self) void {
        if (self.root) |root| {
            root.deinit(self.allocator);
            self.allocator.destroy(root);
            self.root = null;
        }
    }

    /// Returns the total length of the rope
    pub fn len(self: Self) usize {
        return if (self.root) |root| root.len() else 0;
    }

    /// Returns true if the rope is empty
    pub fn isEmpty(self: Self) bool {
        return self.len() == 0;
    }

    /// Gets the byte at the given index
    pub fn byteAt(self: Self, index: usize) ?u8 {
        if (self.root) |root| {
            return getByteAt(root, index);
        }
        return null;
    }

    /// Concatenates two ropes, returning a new rope
    /// This is O(log n) operation
    pub fn concat(self: Self, other: Self) !Self {
        if (self.root == null) {
            return other.clone();
        }
        if (other.root == null) {
            return self.clone();
        }

        var result = Self{
            .root = try concatNodes(self.allocator, self.root.?, other.root.?),
            .allocator = self.allocator,
        };

        // Rebalance if needed
        if (needsRebalance(result.root.?)) {
            result = try result.rebalance();
        }

        return result;
    }

    /// Appends a string to the rope
    pub fn append(self: *Self, data: []const u8) !void {
        if (data.len == 0) return;

        const copy = try self.allocator.dupe(u8, data);
        const new_node = try createLeafNodes(self.allocator, copy, true);

        if (self.root) |root| {
            self.root = try concatNodes(self.allocator, root, new_node);
            if (needsRebalance(self.root.?)) {
                var rebalanced = try self.rebalance();
                self.root = rebalanced.root;
                rebalanced.root = null;
            }
        } else {
            self.root = new_node;
        }
    }

    /// Prepends a string to the rope
    pub fn prepend(self: *Self, data: []const u8) !void {
        if (data.len == 0) return;

        const copy = try self.allocator.dupe(u8, data);
        const new_node = try createLeafNodes(self.allocator, copy, true);

        if (self.root) |root| {
            self.root = try concatNodes(self.allocator, new_node, root);
            if (needsRebalance(self.root.?)) {
                var rebalanced = try self.rebalance();
                self.root = rebalanced.root;
                rebalanced.root = null;
            }
        } else {
            self.root = new_node;
        }
    }

    /// Returns a substring of the rope
    pub fn slice(self: Self, start: usize, end_opt: ?usize) !Self {
        const total_len = self.len();
        const end = end_opt orelse total_len;

        if (start >= total_len or start >= end) {
            return init(self.allocator);
        }

        const actual_end = @min(end, total_len);

        if (self.root) |root| {
            var result = init(self.allocator);
            result.root = try sliceNode(self.allocator, root, start, actual_end);
            return result;
        }

        return init(self.allocator);
    }

    /// Inserts a string at the given position
    pub fn insert(self: *Self, index: usize, data: []const u8) !void {
        if (data.len == 0) return;

        const total_len = self.len();
        const actual_index = @min(index, total_len);

        // Split at index, then concat: left + data + right
        const left = try self.slice(0, actual_index);
        defer {
            var l = left;
            l.deinit();
        }

        const right = try self.slice(actual_index, null);
        defer {
            var r = right;
            r.deinit();
        }

        const copy = try self.allocator.dupe(u8, data);
        var middle = try fromOwned(self.allocator, copy);
        defer middle.deinit();

        const left_middle = try left.concat(middle);
        defer {
            var lm = left_middle;
            lm.deinit();
        }

        var result = try left_middle.concat(right);

        self.deinit();
        self.root = result.root;
        result.root = null;
    }

    /// Deletes a range from the rope
    pub fn delete(self: *Self, start: usize, end_opt: ?usize) !void {
        const total_len = self.len();
        const end = @min(end_opt orelse total_len, total_len);

        if (start >= end or start >= total_len) return;

        // Concat: [0, start) + [end, len)
        const left = try self.slice(0, start);
        defer {
            var l = left;
            l.deinit();
        }

        const right = try self.slice(end, null);
        defer {
            var r = right;
            r.deinit();
        }

        var result = try left.concat(right);

        self.deinit();
        self.root = result.root;
        result.root = null;
    }

    /// Clones the rope (creates a new rope sharing structure where possible)
    pub fn clone(self: Self) !Self {
        if (self.root == null) {
            return init(self.allocator);
        }

        return Self{
            .root = try cloneNode(self.allocator, self.root.?),
            .allocator = self.allocator,
        };
    }

    /// Converts the rope to a contiguous string
    /// The caller owns the returned memory
    pub fn toString(self: Self) ![]u8 {
        const total_len = self.len();
        if (total_len == 0) {
            return self.allocator.alloc(u8, 0);
        }

        const result = try self.allocator.alloc(u8, total_len);
        var offset: usize = 0;
        if (self.root) |root| {
            collectBytes(root, result, &offset);
        }
        return result;
    }

    /// Creates an iterator over the rope's bytes
    pub fn iterator(self: Self) Iterator {
        return Iterator.init(self);
    }

    /// Rebalances the rope for better performance
    fn rebalance(self: Self) !Self {
        const data = try self.toString();
        defer self.allocator.free(data);
        return fromOwned(self.allocator, try self.allocator.dupe(u8, data));
    }

    /// Iterator over rope bytes
    pub const Iterator = struct {
        stack: std.ArrayList(*const Node),
        current_leaf: ?[]const u8,
        leaf_index: usize,

        pub fn init(rope: Rope) Iterator {
            var iter = Iterator{
                .stack = std.ArrayList(*const Node).init(rope.allocator),
                .current_leaf = null,
                .leaf_index = 0,
            };

            if (rope.root) |root| {
                iter.pushLeftPath(root);
            }

            return iter;
        }

        pub fn deinit(self: *Iterator) void {
            self.stack.deinit();
        }

        pub fn next(self: *Iterator) ?u8 {
            // Try to get from current leaf
            if (self.current_leaf) |leaf| {
                if (self.leaf_index < leaf.len) {
                    const result = leaf[self.leaf_index];
                    self.leaf_index += 1;
                    return result;
                }
            }

            // Move to next leaf
            self.current_leaf = null;
            self.leaf_index = 0;

            while (self.stack.items.len > 0) {
                const node = self.stack.pop();

                switch (node.*) {
                    .leaf => |l| {
                        if (l.data.len > 0) {
                            self.current_leaf = l.data;
                            self.leaf_index = 1;
                            return l.data[0];
                        }
                    },
                    .branch => |b| {
                        self.stack.append(b.right) catch return null;
                        self.pushLeftPath(b.left);
                        continue;
                    },
                }
            }

            return null;
        }

        fn pushLeftPath(self: *Iterator, node: *const Node) void {
            var current: *const Node = node;
            while (true) {
                switch (current.*) {
                    .leaf => {
                        self.stack.append(current) catch return;
                        return;
                    },
                    .branch => |b| {
                        self.stack.append(current) catch return;
                        current = b.left;
                    },
                }
            }
        }
    };
};

// ============================================================
// Internal Helper Functions
// ============================================================

fn createLeafNodes(allocator: std.mem.Allocator, data: []const u8, owned: bool) !*Node {
    if (data.len <= LEAF_SIZE) {
        const node = try allocator.create(Node);
        node.* = .{ .leaf = .{ .data = data, .owned = owned } };
        return node;
    }

    // Split into multiple leaves
    const mid = data.len / 2;

    // For owned data, we need to be careful about splitting
    // The first half keeps the original pointer, second half is offset
    const left_data = data[0..mid];
    const right_data = data[mid..];

    // Only the first leaf owns the data
    const left = try createLeafNodes(allocator, left_data, owned);
    const right = try createLeafNodes(allocator, right_data, false);

    const node = try allocator.create(Node);
    node.* = .{
        .branch = .{
            .left = left,
            .right = right,
            .len = data.len,
            .depth = @max(left.depth(), right.depth()) + 1,
        },
    };

    return node;
}

fn getByteAt(node: *const Node, index: usize) ?u8 {
    switch (node.*) {
        .leaf => |l| {
            if (index < l.data.len) {
                return l.data[index];
            }
            return null;
        },
        .branch => |b| {
            const left_len = b.left.len();
            if (index < left_len) {
                return getByteAt(b.left, index);
            }
            return getByteAt(b.right, index - left_len);
        },
    }
}

fn concatNodes(allocator: std.mem.Allocator, left: *Node, right: *Node) !*Node {
    const node = try allocator.create(Node);
    node.* = .{
        .branch = .{
            .left = left,
            .right = right,
            .len = left.len() + right.len(),
            .depth = @max(left.depth(), right.depth()) + 1,
        },
    };
    return node;
}

fn sliceNode(allocator: std.mem.Allocator, node: *const Node, start: usize, end: usize) !?*Node {
    if (start >= end) return null;

    switch (node.*) {
        .leaf => |l| {
            if (start >= l.data.len) return null;
            const actual_end = @min(end, l.data.len);
            const slice_data = l.data[start..actual_end];

            // Copy the slice data
            const copy = try allocator.dupe(u8, slice_data);
            const new_node = try allocator.create(Node);
            new_node.* = .{ .leaf = .{ .data = copy, .owned = true } };
            return new_node;
        },
        .branch => |b| {
            const left_len = b.left.len();

            if (end <= left_len) {
                // Entirely in left subtree
                return sliceNode(allocator, b.left, start, end);
            } else if (start >= left_len) {
                // Entirely in right subtree
                return sliceNode(allocator, b.right, start - left_len, end - left_len);
            } else {
                // Spans both subtrees
                const left_slice = try sliceNode(allocator, b.left, start, left_len);
                const right_slice = try sliceNode(allocator, b.right, 0, end - left_len);

                if (left_slice == null) return right_slice;
                if (right_slice == null) return left_slice;

                return try concatNodes(allocator, left_slice.?, right_slice.?);
            }
        },
    }
}

fn cloneNode(allocator: std.mem.Allocator, node: *const Node) !*Node {
    switch (node.*) {
        .leaf => |l| {
            const copy = try allocator.dupe(u8, l.data);
            const new_node = try allocator.create(Node);
            new_node.* = .{ .leaf = .{ .data = copy, .owned = true } };
            return new_node;
        },
        .branch => |b| {
            const left = try cloneNode(allocator, b.left);
            const right = try cloneNode(allocator, b.right);

            const new_node = try allocator.create(Node);
            new_node.* = .{
                .branch = .{
                    .left = left,
                    .right = right,
                    .len = b.len,
                    .depth = b.depth,
                },
            };
            return new_node;
        },
    }
}

fn collectBytes(node: *const Node, buffer: []u8, offset: *usize) void {
    switch (node.*) {
        .leaf => |l| {
            @memcpy(buffer[offset.*..][0..l.data.len], l.data);
            offset.* += l.data.len;
        },
        .branch => |b| {
            collectBytes(b.left, buffer, offset);
            collectBytes(b.right, buffer, offset);
        },
    }
}

fn needsRebalance(node: *const Node) bool {
    // Simple heuristic: rebalance if depth > 2 * log2(length)
    const d = node.depth();
    const l = node.len();
    if (l == 0) return false;
    const target_depth = std.math.log2(l) + 2;
    return d > @as(u32, @intCast(target_depth));
}

// ============================================================
// Tests
// ============================================================

test "rope - basic operations" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var rope = try Rope.fromCopy(allocator, "Hello, World!");
    defer rope.deinit();

    try testing.expectEqual(@as(usize, 13), rope.len());
    try testing.expectEqual(@as(u8, 'H'), rope.byteAt(0).?);
    try testing.expectEqual(@as(u8, '!'), rope.byteAt(12).?);
}

test "rope - empty" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var rope = Rope.init(allocator);
    defer rope.deinit();

    try testing.expect(rope.isEmpty());
    try testing.expectEqual(@as(usize, 0), rope.len());
}

test "rope - append" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var rope = try Rope.fromCopy(allocator, "Hello");
    defer rope.deinit();

    try rope.append(", World!");

    const str = try rope.toString();
    defer allocator.free(str);

    try testing.expectEqualSlices(u8, "Hello, World!", str);
}

test "rope - concat" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var rope1 = try Rope.fromCopy(allocator, "Hello");
    defer rope1.deinit();

    var rope2 = try Rope.fromCopy(allocator, ", World!");
    defer rope2.deinit();

    var result = try rope1.concat(rope2);
    defer result.deinit();

    const str = try result.toString();
    defer allocator.free(str);

    try testing.expectEqualSlices(u8, "Hello, World!", str);
}

test "rope - slice" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var rope = try Rope.fromCopy(allocator, "Hello, World!");
    defer rope.deinit();

    var slice_rope = try rope.slice(0, 5);
    defer slice_rope.deinit();

    const str = try slice_rope.toString();
    defer allocator.free(str);

    try testing.expectEqualSlices(u8, "Hello", str);
}

test "rope - insert" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var rope = try Rope.fromCopy(allocator, "Hello!");
    defer rope.deinit();

    try rope.insert(5, ", World");

    const str = try rope.toString();
    defer allocator.free(str);

    try testing.expectEqualSlices(u8, "Hello, World!", str);
}

test "rope - delete" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var rope = try Rope.fromCopy(allocator, "Hello, World!");
    defer rope.deinit();

    try rope.delete(5, 7); // Delete ", "

    const str = try rope.toString();
    defer allocator.free(str);

    try testing.expectEqualSlices(u8, "HelloWorld!", str);
}

test "rope - large string" {
    const testing = std.testing;
    const allocator = testing.allocator;

    // Create a large string
    const large_data = "a" ** 10000;
    var rope = try Rope.fromCopy(allocator, large_data);
    defer rope.deinit();

    try testing.expectEqual(@as(usize, 10000), rope.len());

    // Test iteration
    var iter = rope.iterator();
    defer iter.deinit();

    var count: usize = 0;
    while (iter.next()) |_| {
        count += 1;
    }
    try testing.expectEqual(@as(usize, 10000), count);
}

test "rope - iterator" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var rope = try Rope.fromCopy(allocator, "Hello");
    defer rope.deinit();

    var iter = rope.iterator();
    defer iter.deinit();

    try testing.expectEqual(@as(?u8, 'H'), iter.next());
    try testing.expectEqual(@as(?u8, 'e'), iter.next());
    try testing.expectEqual(@as(?u8, 'l'), iter.next());
    try testing.expectEqual(@as(?u8, 'l'), iter.next());
    try testing.expectEqual(@as(?u8, 'o'), iter.next());
    try testing.expectEqual(@as(?u8, null), iter.next());
}
