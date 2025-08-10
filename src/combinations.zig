const std = @import("std");

fn CombinationIndices(k: comptime_int, d: comptime_int) type {
    return struct {
        hold: [k]usize,
        disc: [d]usize,
    };
}

pub const indices_5c4: [5]CombinationIndices(4, 1) = .{
    .{ .hold = .{0, 1, 2, 3}, .disc = .{4} },
    .{ .hold = .{0, 1, 2, 4}, .disc = .{3} },
    .{ .hold = .{0, 1, 3, 4}, .disc = .{2} },
    .{ .hold = .{0, 2, 3, 4}, .disc = .{1} },
    .{ .hold = .{1, 2, 3, 4}, .disc = .{0} },
};
pub const indices_5c3: [10]CombinationIndices(3, 2) = .{
    .{ .hold = .{0, 1, 2}, .disc = .{3, 4} },
    .{ .hold = .{0, 1, 3}, .disc = .{2, 4} },
    .{ .hold = .{0, 1, 4}, .disc = .{2, 3} },
    .{ .hold = .{0, 2, 3}, .disc = .{1, 4} },
    .{ .hold = .{0, 2, 4}, .disc = .{1, 3} },
    .{ .hold = .{0, 3, 4}, .disc = .{1, 2} },
    .{ .hold = .{1, 2, 3}, .disc = .{0, 4} },
    .{ .hold = .{1, 2, 4}, .disc = .{0, 3} },
    .{ .hold = .{1, 3, 4}, .disc = .{0, 2} },
    .{ .hold = .{2, 3, 4}, .disc = .{0, 1} },
};
pub const indices_5c2: [10]CombinationIndices(2, 3) = .{
    .{ .hold = .{0, 1}, .disc = .{2, 3, 4} },
    .{ .hold = .{0, 2}, .disc = .{1, 3, 4} },
    .{ .hold = .{0, 3}, .disc = .{1, 2, 4} },
    .{ .hold = .{0, 4}, .disc = .{1, 2, 3} },
    .{ .hold = .{1, 2}, .disc = .{0, 3, 4} },
    .{ .hold = .{1, 3}, .disc = .{0, 2, 4} },
    .{ .hold = .{1, 4}, .disc = .{0, 2, 3} },
    .{ .hold = .{2, 3}, .disc = .{0, 1, 4} },
    .{ .hold = .{2, 4}, .disc = .{0, 1, 3} },
    .{ .hold = .{3, 4}, .disc = .{0, 1, 2} },
};
pub const indices_5c1: [5]CombinationIndices(1, 4) = .{
    .{ .hold = .{0}, .disc = .{1, 2, 3, 4} },
    .{ .hold = .{1}, .disc = .{0, 2, 3, 4} },
    .{ .hold = .{2}, .disc = .{0, 1, 3, 4} },
    .{ .hold = .{3}, .disc = .{0, 1, 2, 4} },
    .{ .hold = .{4}, .disc = .{0, 1, 2, 3} },
};

const N = 53;
const K = 6;
var lookup: ?*[N][K]u64 = null;
var this_allocator: ?std.mem.Allocator = null;

pub fn init(allocator: std.mem.Allocator) !void {
    lookup = try allocator.create([N][K]u64);
    this_allocator = allocator;
    for (0..N) |n| {
        for (0..K) |k| {
            lookup.?[n][k] = choose(n, k);
        }
    }
}

pub fn deinit() void {
    this_allocator.?.free(lookup.?);
}

pub fn choose_lookup(n: u8, k: u8) u64 {
    if (lookup) |l| {
        return l[n][k];
    } else {
        unreachable;
    }
}

pub fn choose(n: u64, k: u64) u64 {
    if (k == 0 or k == n) {
        return 1;
    } else if (k > n) {
        return 0;
    }

    var result: u64 = 1;
    var i: u64 = 1;
    const min_k = if (k < n - k) k else n - k; // Optimization: C(n, k) == C(n, n - k)

    while (i <= min_k) : (i += 1) {
        result = (result * (n - i + 1)) / i;
    }
    return result;
}

pub fn CombinationIterator(comptime T: type, R: usize) type {
    return struct {
        const Self = @This();

        data: []const T,
        indices: ?[R]u8 = null,
        done: bool = false,

        pub fn init(data: []const T) Self {
            return .{.data = data};
        }

        pub fn next(self: *Self) ?[R]T {
            if (self.done) {
                return null;
            }

            if (self.indices == null) {
                self.indices = [_]u8{0} ** R;
                for (0..R) |i| {
                    self.indices.?[i] = @intCast(i);
                }
                return self.to_result();
            }

            // reverse scan indices
            const n = self.data.len;
            var i: isize = @intCast(R - 1);
            while (i >= 0) : (i -= 1) {
                const idx: usize = @intCast(i);
                if (self.indices.?[idx] != idx + n - R) {
                    break;
                }
            }

            if (i < 0) {
                self.done = true;
                return null;
            }

            // increment all indices to the right of i
            const idx: usize = @intCast(i);
            self.indices.?[idx] += 1;
            for (idx+1..R) |j| {
                self.indices.?[j] = self.indices.?[j-1] + 1;
            }
            return self.to_result();
        }

        fn to_result(self: *Self) [R]T {
            var result: [R]T = undefined;
            for (0.., self.indices.?) |i_res, i| {
                result[i_res] = self.data[i];
            }
            return result;
        }
    };
}

test "n choose k" {
    for (0..53) |n| {
        try std.testing.expectEqual(1, choose(n, 0));
    }
    for (0..53) |n| {
        try std.testing.expectEqual(n, choose(n, 1));
    }

    try std.testing.expectEqual(choose(52, 5), 2_598_960);
    try std.testing.expectEqual(choose(52, 4), 270_725);
    try std.testing.expectEqual(choose(52, 3), 22_100);
    try std.testing.expectEqual(choose(52, 2), 1_326);
    try std.testing.expectEqual(choose(52, 1), 52);
    try std.testing.expectEqual(choose(51, 5), 2_349_060);
}
