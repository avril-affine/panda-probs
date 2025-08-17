const std = @import("std");

const combinations   = @import("combinations.zig");
const strategies     = @import("strategies.zig");
const deuces_wild    = @import("poker_types/deuces_wild.zig");

const ComputeType         = strategies.ComputeType;
const DeucesWild          = deuces_wild.DeucesWild;
const DealFrequency       = @import("frequency/deal.zig").DealFrequency;
// const RankFrequencyArray  = @import("frequency/rank_array.zig").RankFrequencyArray;
const RankFrequencyVector = @import("frequency/rank_vector.zig").RankFrequencyVector;
const OptimalStrategy     = @import("strategies/optimal.zig").OptimalStrategy;

fn measure_time(msg: []const u8, f: anytype, args: anytype) @TypeOf(@call(.auto, f, args)) {
    var timer = std.time.Timer.start() catch @panic("timer not supported on system");
    const result = @call(.auto, f, args);
    const elapsed_ns = timer.read();
    const elapsed_s = @as(f64, @floatFromInt(elapsed_ns)) / std.time.ns_per_s;
    std.debug.print("{s} took {d:.3} seconds\n", .{msg, elapsed_s});
    return result;
}

const Config = struct {
    paytable_path: []const u8,
    compute_type: ComputeType,
};

fn parse_args(args_iter: *std.process.ArgIterator) !Config {
    _ = args_iter.next();
    var paytable_path: []const u8 = "paytables/deuces_wild_full_pay.json";
    var compute_type: ComputeType = ComputeType.weighted_rank_threaded;
    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--compute")) {
            const val = args_iter.next() orelse return error.InvalidCompute;
            compute_type = std.meta.stringToEnum(ComputeType, val) orelse return error.InvalidCompute;
        } else if (std.mem.eql(u8, arg, "--compute")) {
            paytable_path = args_iter.next() orelse return error.InvalidCompute;
        } else {
            return error.UnknownArg;
        }
    }
    return .{
        .paytable_path = paytable_path,
        .compute_type = compute_type,
    };
}

fn run() !void {
    const allocator = std.heap.page_allocator;

    try combinations.init(allocator);
    defer combinations.deinit();

    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();
    const config = try parse_args(&args_iter);

    const PokerType = DeucesWild;
    const paytable_len = @typeInfo(PokerType).@"enum".fields.len;

    const paytable: [paytable_len]u64 = blk: {
        const file = try std.fs.cwd().openFile(config.paytable_path, .{});
        defer file.close();

        const json_buf = try allocator.alloc(u8, try file.getEndPos());
        _ = try file.readAll(json_buf);

        const json_array = try std.json.parseFromSlice([paytable_len]u64, allocator, json_buf, .{});
        break :blk json_array.value;
    };

    const DeucesWildFrequency = DealFrequency(DeucesWild, RankFrequencyVector(paytable_len));
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, ".cache/{s}.bin", .{@typeName(PokerType)});
    var deal_frequency: DeucesWildFrequency = blk: {
        const file_result = std.fs.cwd().openFile(path, .{ .mode = .read_only });
        if (file_result) |file| {
            defer file.close();
            break :blk try measure_time(
                "strategy deserialize",
                DeucesWildFrequency.deserialize,
                .{allocator, file.reader()}
            );
        } else |_| {
            break :blk try measure_time(
                "strategy init",
                DeucesWildFrequency.init,
                .{allocator},
            );
        }
    };
    defer deal_frequency.deinit();

    const strategy = OptimalStrategy(DeucesWildFrequency).init(deal_frequency, paytable);

    const frequencies = measure_time(
        "Compute strategy:",
        strategies.compute,
        .{config.compute_type, strategy},
    );
    const total: u64 = blk: {
        var x: u64 = 0;
        for (frequencies) |f| { x += @intCast(f); }
        break :blk x;
    };
    const N = DeucesWildFrequency.HandRank.Deck.len;
    const ev: f64 = blk: {
        var result: f64 = 0.0;
        const total_f64 = @as(f64, @floatFromInt(total));
        for (frequencies, paytable, 0..) |f, p, r| {
            const prob = @as(f64, @floatFromInt(f)) / total_f64;
            const payout_f64: f64 = @as(f64, @floatFromInt(f * p));
            const payout_ev = payout_f64 / total_f64;
            result += payout_ev;
            const rank: PokerType = @enumFromInt(r);
            std.debug.print("{s:>16}: {d:>16}    {d:.6}\n", .{@tagName(rank), f, prob});
        }
        std.debug.print("{s:>16}: {d:>16}\n", .{"Total", total});
        std.debug.assert(total == combinations.choose(N, 5) * combinations.choose(N-5, 5) * 5);
        break :blk result;
    };
    std.debug.print("\nEV: {d:.6}\n", .{ev});

    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();
    try deal_frequency.serialize(file.writer());
}

pub fn main() !void {
    try measure_time("Total:", run, .{});
}
