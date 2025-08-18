const std = @import("std");

const combinations   = @import("combinations.zig");
const strategies     = @import("strategies.zig");

const ComputeType         = strategies.ComputeType;
const JacksOrBetter       = @import("poker_types/jacks_or_better.zig").JacksOrBetter;
const DeucesWild          = @import("poker_types/deuces_wild.zig").DeucesWild;
const DealFrequencyType   = @import("frequency/deal.zig").DealFrequencyType;
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

const PokerType = JacksOrBetter;
const default_pay_table = "paytables/jacks_or_better.json";

const Config = struct {
    paytable_path: []const u8,
    compute_type: ComputeType,
};

fn parse_args(args_iter: *std.process.ArgIterator) !Config {
    _ = args_iter.next();
    var paytable_path: []const u8 = default_pay_table;
    var compute_type: ComputeType = ComputeType.weighted_rank_threaded;
    while (args_iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "--compute")) {
            const val = args_iter.next() orelse return error.InvalidCompute;
            compute_type = std.meta.stringToEnum(ComputeType, val) orelse return error.InvalidCompute;
        } else if (std.mem.eql(u8, arg, "--paytable")) {
            paytable_path = args_iter.next() orelse return error.InvalidPaytable;
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

    const paytable_len = @typeInfo(PokerType).@"enum".fields.len;

    const paytable: [paytable_len]u64 = blk: {
        const file = std.fs.cwd().openFile(config.paytable_path, .{})
            catch return error.InvalidPaytablePath;
        defer file.close();

        const json_buf = try allocator.alloc(u8, try file.getEndPos());
        _ = try file.readAll(json_buf);

        const json_array = std.json.parseFromSlice([paytable_len]u64, allocator, json_buf, .{})
            catch return error.InvalidPaytable;
        break :blk json_array.value;
    };

    const DealFrequency = DealFrequencyType(PokerType, RankFrequencyVector(paytable_len));
    var path_buf: [256]u8 = undefined;
    const path = try std.fmt.bufPrint(&path_buf, ".cache/{s}.bin", .{@typeName(PokerType)});
    var deal_frequency: DealFrequency = blk: {
        const file_result = std.fs.cwd().openFile(path, .{ .mode = .read_only });
        if (file_result) |file| {
            defer file.close();
            break :blk try measure_time(
                "strategy deserialize",
                DealFrequency.deserialize,
                .{allocator, file.reader()}
            );
        } else |_| {
            break :blk try measure_time(
                "strategy init",
                DealFrequency.init,
                .{allocator},
            );
        }
    };
    defer deal_frequency.deinit();

    const strategy = OptimalStrategy(DealFrequency).init(deal_frequency, paytable);

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
    const N = DealFrequency.HandRank.Deck.len;
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
