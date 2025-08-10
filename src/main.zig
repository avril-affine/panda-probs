const std = @import("std");

const combinations = @import("combinations.zig");
const strategies = @import("strategies.zig");
const deuces_wild = @import("poker_types/deuces_wild.zig");
const optimal_strategy = @import("strategies/optimal.zig");

const DeucesWild = deuces_wild.DeucesWild;
const DeucesWildFullPay = deuces_wild.DeucesWildFullPay;
const OptimalStrategy = optimal_strategy.OptimalStrategy;

fn measure_time(msg: []const u8, f: anytype, args: anytype) @TypeOf(@call(.auto, f, args)) {
    var timer = std.time.Timer.start() catch @panic("timer not supported on system");
    const result = @call(.auto, f, args);
    const elapsed_ns = timer.read();
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / std.time.ns_per_s;
    std.debug.print("{s} took {d:.3} seconds\n", .{msg, elapsed_s});
    return result;
}

fn run() !void {
    const allocator = std.heap.page_allocator;

    try combinations.init(allocator);
    defer combinations.deinit();

    const DeucesWildOptimalStrategy = OptimalStrategy(DeucesWild);
    var strategy = try measure_time(
        "strategy init",
        DeucesWildOptimalStrategy.init,
        .{allocator, DeucesWildFullPay},
    );
    defer strategy.deinit();

    const frequencies = measure_time("Compute strategy:", strategies.compute, .{strategy});
    const total: u64 = blk: {
        var x: u64 = 0;
        for (frequencies) |f| { x += @intCast(f); }
        break :blk x;
    };
    const ev: f64 = blk: {
        var result: f64 = 0.0;
        const total_f64 = @as(f64, @floatFromInt(total));
        for (frequencies, DeucesWildFullPay, 0..) |f, p, r| {
            const prob = @as(f64, @floatFromInt(f)) / total_f64;
            const payout_f64: f64 = @as(f64, @floatFromInt(f * p));
            const payout_ev = payout_f64 / total_f64;
            result += payout_ev;
            const rank: DeucesWild = @enumFromInt(r);
            std.debug.print("{s:>16}: {d:>16}    {d:.6}\n", .{@tagName(rank), f, prob});
        }
        std.debug.print("{s:>16}: {d:>16}\n", .{"Total", total});
        break :blk result;
    };
    std.debug.print("\nEV: {d:.6}\n", .{ev});
}

pub fn main() !void {
    try measure_time("Total:", run, .{});
}
