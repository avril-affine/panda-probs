const std = @import("std");

pub fn RankFrequencyArray(N: usize) type {
    return struct {
        const Self = @This();
        pub const len = N;

        data: [N]u64,

        pub fn init() Self {
            return . { .data = .{0} ** N };
        }

        pub fn allocate_array(allocator: std.mem.Allocator, comptime size: u64) !*[size]Self {
            const arr = try allocator.create([size]Self);
            for (arr) |*elem| {
                elem.data = .{0} ** N;
            }
            return arr;
        }

        pub fn inc(self: *Self, index: usize) void {
            self.data[index] += 1;
        }

        pub fn dec(self: *Self, index: usize) void {
            self.data[index] -= 1;
        }

        pub fn add(self: *Self, other: *const Self) void {
            for (0..N) |i| { self.data[i] += other.data[i]; }
        }

        pub fn sub(self: *Self, other: *const Self) void {
            for (0..N) |i| { self.data[i] -= other.data[i]; }
        }

        pub fn mul(self: *Self, val: u64) void {
            for (0..N) |i| { self.data[i] *= val; }
        }

        pub fn get_ev(self: *const Self, paytable: [N]u64, weight: u64) u64 {
            const sum: u64 = blk: {
                var x: u64 = 0;
                for (0..N) |i| { x += paytable[i] * self.data[i]; }
                break :blk x;
            };
            return sum * weight;
        }
    };
}

