const std = @import("std");

const combinations = @import("combinations.zig");

const assert = std.debug.assert;
const CombinationIterator = combinations.CombinationIterator;

pub fn compute(
    /// an instance from the strategies/ dir
    strategy: anytype,
) [@TypeOf(strategy).num_payouts]u64 {
    const StrategyType = @TypeOf(strategy);
    const PayoutFrequency = StrategyType.PayoutFrequency;

    var indices: [StrategyType.Deck.N]u8 = undefined;
    for (0..StrategyType.Deck.N) |i| { indices[i] = @intCast(i); }

    var i: usize = 0;
    var total_frequency = PayoutFrequency.init();
    var hand_indices_iter = CombinationIterator(u8, 5).init(&indices);
    while (hand_indices_iter.next()) |hand_indices| {
        const frequency = strategy.draw_frequency(hand_indices);
        total_frequency.add(&frequency);
        if (i % 10_000 == 0) std.debug.print("\rComputing frequencies: {}", .{i});
        i += 1;
    }
    return @bitCast(total_frequency.data);
}
