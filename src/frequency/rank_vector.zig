const std = @import("std");

pub fn RankFrequencyVector(N: usize) type {
    return struct {
        const Self = @This();
        pub const len = N;

        data: @Vector(N, u64),

        pub fn init() Self {
            return . { .data = @splat(0) };
        }

        pub fn allocate_array(allocator: std.mem.Allocator, comptime size: u64) !*[size]Self {
            const arr = try allocator.create([size]Self);
            for (arr) |*elem| { elem.data = @splat(0); }
            return arr;
        }

        pub fn inc(self: *Self, index: usize) void {
            self.data[index] += 1;
        }

        pub fn dec(self: *Self, index: usize) void {
            self.data[index] -= 1;
        }

        pub fn add(self: *Self, other: *const Self) void {
            self.data += other.data;
        }

        pub fn sub(self: *Self, other: *const Self) void {
            self.data -= other.data;
        }

        pub fn mul(self: *Self, val: u64) void {
            self.data *= @splat(val);
        }

        pub fn get_ev(self: *const Self, paytable: [N]u64, weight: u64) u64 {
            const sum = @reduce(.Add, paytable * self.data);
            return sum * weight;
        }
    };
}
