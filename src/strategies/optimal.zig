const std = @import("std");

const combinations = @import("../combinations.zig");

const assert = std.debug.assert;
const CombinationIterator = combinations.CombinationIterator;

const IndexIterator4 = CombinationIterator(usize, 4);
const IndexIterator3 = CombinationIterator(usize, 3);
const IndexIterator2 = CombinationIterator(usize, 2);
const IndexIterator1 = CombinationIterator(usize, 1);

pub fn select(arr: anytype, indices: anytype) [@typeInfo(@TypeOf(indices)).array.len]@typeInfo(@typeInfo(@TypeOf(arr)).pointer.child).array.child {
    const N = @typeInfo(@TypeOf(indices)).array.len;
    const T = @typeInfo(@typeInfo(@TypeOf(arr)).pointer.child).array.child;

    var out: [N]T = undefined;
    for (0..N) |i| {
        out[i] = arr[indices[i]];
    }
    return out;
}

pub fn OptimalStrategy(
    /// generated from src/frequency/deal.zig 
    comptime DealFrequency: type,
) type {

    const HandRank = DealFrequency.HandRank;
    const P = @typeInfo(HandRank).@"enum".fields.len;
    return struct {
        const Self = @This();
        pub const RankFrequency = DealFrequency.RankFrequency;
        pub const Deck = HandRank.Deck;
        const draw_size = Deck.len - 5;
        // normalize the output of `draw_frequency` so that it counts as 47c5
        const DRAW_WEIGHT: [6]u64 = .{
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 0),
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 1),
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 2),
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 3),
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 4),
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 5),
        };

        deal_frequency: DealFrequency,
        paytable: [P]u64,

        pub fn init(deal_frequency: DealFrequency, paytable: [P]u64) Self {
            return .{
                .deal_frequency = deal_frequency,
                .paytable = paytable,
            };
        }

        pub fn draw_frequency(self: *const Self, hand: [5]u6) RankFrequency {
            // hold 5
            const rank_idx = self.deal_frequency.hand5_to_rank_index[Deck.hand_to_index(&hand)];
            var best_frequencies = RankFrequency.init();
            // add
            best_frequencies.inc(rank_idx);
            var best_ev = best_frequencies.get_ev(self.paytable, DRAW_WEIGHT[0]);
            var best_num_hold: u64 = 5;

            // hold 4
            inline for (combinations.indices_5c4) |indices| {
                const indices_hold, _ = indices;
                const hand_idx = Self.get_hand_idx(hand, indices_hold);

                var frequencies = RankFrequency.init();
                // add
                frequencies.add(&self.deal_frequency.hand4_to_rank_freq[hand_idx]);
                // sub
                frequencies.dec(rank_idx);

                const ev = frequencies.get_ev(self.paytable, DRAW_WEIGHT[1]);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 4;
                }
            }

            // hold 3
            inline for (combinations.indices_5c3) |indices| {
                const indices_hold, const indices_disc = indices;
                const hand_hold3_idx = Self.get_hand_idx(hand, indices_hold);

                var frequencies = RankFrequency.init();
                // add
                frequencies.add(&self.deal_frequency.hand3_to_rank_freq[hand_hold3_idx]);
                frequencies.inc(rank_idx);
                // sub
                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc1);
                    frequencies.sub(&self.deal_frequency.hand4_to_rank_freq[hand_hold4_idx]);
                }

                const ev = frequencies.get_ev(self.paytable, DRAW_WEIGHT[2]);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 3;
                }
            }

            // hold 2
            inline for (combinations.indices_5c2) |indices| {
                const indices_hold, const indices_disc = indices;
                const hand_hold2_idx = Self.get_hand_idx(hand, indices_hold);

                var frequencies = RankFrequency.init();
                // add
                frequencies.add(&self.deal_frequency.hand2_to_rank_freq[hand_hold2_idx]);
                var indices_disc2_iter = IndexIterator2.init(&indices_disc);
                while (indices_disc2_iter.next()) |indices_disc2| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc2);
                    frequencies.add(&self.deal_frequency.hand4_to_rank_freq[hand_hold4_idx]);
                }
                // sub
                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold3_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc1);
                    frequencies.sub(&self.deal_frequency.hand3_to_rank_freq[hand_hold3_idx]);
                }
                frequencies.dec(rank_idx);

                const ev = frequencies.get_ev(self.paytable, DRAW_WEIGHT[3]);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 2;
                }
            }

            // hold 1
            inline for (combinations.indices_5c1) |indices| {
                const indices_hold, const indices_disc = indices;
                const hand_hold1_idx = Self.get_hand_idx(hand, indices_hold);

                var frequencies = RankFrequency.init();
                // add
                frequencies.add(&self.deal_frequency.hand1_to_rank_freq[hand_hold1_idx]);
                var indices_disc2_iter = IndexIterator2.init(&indices_disc);
                while (indices_disc2_iter.next()) |indices_disc2| {
                    const hand_hold3_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc2);
                    frequencies.add(&self.deal_frequency.hand3_to_rank_freq[hand_hold3_idx]);
                }
                frequencies.inc(rank_idx);

                // sub
                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold2_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc1);
                    frequencies.sub(&self.deal_frequency.hand2_to_rank_freq[hand_hold2_idx]);
                }
                var indices_disc3_iter = IndexIterator3.init(&indices_disc);
                while (indices_disc3_iter.next()) |indices_disc3| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc3);
                    frequencies.sub(&self.deal_frequency.hand4_to_rank_freq[hand_hold4_idx]);
                }

                const ev = frequencies.get_ev(self.paytable, DRAW_WEIGHT[4]);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 1;
                }
            }

            // hold 0
            {
                const indices_disc = [_]usize{0, 1, 2, 3, 4};

                var frequencies = RankFrequency.init();
                // add
                frequencies.add(self.deal_frequency.hand0_to_rank_freq);
                var indices_disc2_iter = IndexIterator2.init(&indices_disc);
                while (indices_disc2_iter.next()) |indices_disc2| {
                    const hand_hold2_idx = Self.get_hand_idx(hand, indices_disc2);
                    frequencies.add(&self.deal_frequency.hand2_to_rank_freq[hand_hold2_idx]);
                }
                var indices_disc4_iter = IndexIterator4.init(&indices_disc);
                while (indices_disc4_iter.next()) |indices_disc4| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_disc4);
                    frequencies.add(&self.deal_frequency.hand4_to_rank_freq[hand_hold4_idx]);
                }
                // sub
                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold1_idx = Self.get_hand_idx(hand, indices_disc1);
                    frequencies.sub(&self.deal_frequency.hand1_to_rank_freq[hand_hold1_idx]);
                }
                var indices_disc3_iter = IndexIterator3.init(&indices_disc);
                while (indices_disc3_iter.next()) |indices_disc3| {
                    const hand_hold3_idx = Self.get_hand_idx(hand, indices_disc3);
                    frequencies.sub(&self.deal_frequency.hand3_to_rank_freq[hand_hold3_idx]);
                }
                frequencies.dec(rank_idx);

                const ev = frequencies.get_ev(self.paytable, DRAW_WEIGHT[5]);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 0;
                }
            }

            best_frequencies.mul(DRAW_WEIGHT[5-best_num_hold]);
            return best_frequencies;
        }

        fn get_hand_idx(hand: [5]u6, indices: anytype) u64 {
            return Deck.hand_to_index(&select(&hand, indices));
        }
    };
}

test "OptimalStrategy DeucesWild" {
    const DealFrequency = @import("../frequency/deal.zig").DealFrequency;
    const DeucesWild = @import("../poker_types/deuces_wild.zig").DeucesWild;
    const DeucesWildFullPay = @import("../poker_types/deuces_wild.zig").DeucesWildFullPay;
    const Card = DeucesWild.Card;

    try combinations.init(std.testing.allocator);
    defer combinations.deinit();

    const DeucesWildDealFrequncy = DealFrequency(DeucesWild, .array);
    const DeucesWildOptimalStrategy = OptimalStrategy(DeucesWildDealFrequncy);
    var deal_frequency = try DeucesWildDealFrequncy.init(std.testing.allocator);
    defer deal_frequency.deinit();
    var strategy = DeucesWildOptimalStrategy.init(deal_frequency, DeucesWildFullPay);

    const hold0_total: u64 = blk: {
        var x: u64 = 0;
        for (strategy.deal_frequency.hand0_to_rank_freq.data) |y| { x += y; }
        break :blk x;
    };
    try std.testing.expectEqual(2_598_960, hold0_total);
    const hold1_all_equal = blk: {
        const first_sum: u64 = blk1: {
            var x: u64 = 0;
            for (strategy.deal_frequency.hand1_to_rank_freq[0].data) |y| { x += y; }
            break :blk1 x;
        };
        for (strategy.deal_frequency.hand1_to_rank_freq) |arr| {
            const sum: u64 = blk1: {
                var x: u64 = 0;
                for (arr.data) |y| { x += y; }
                break :blk1 x;
            };
            if (sum != first_sum) break :blk false;
        }
        break :blk true;
    };
    try std.testing.expect(hold1_all_equal);
    const hold1_total = blk: {
        var total: u64 = 0;
        for (strategy.deal_frequency.hand1_to_rank_freq) |arr| {
            for (arr.data) |y| { total += y; }
        }
        break :blk total;
    };
    try std.testing.expectEqual(2_598_960 * 5, hold1_total);
    const hold2_all_equal = blk: {
        const first_sum = blk1: {
            var x: u64 = 0;
            for (strategy.deal_frequency.hand2_to_rank_freq[0].data) |y| { x += y; }
            break :blk1 x;
        };
        for (strategy.deal_frequency.hand2_to_rank_freq) |arr| {
            const sum = blk1: {
                var x: u64 = 0;
                for (arr.data) |y| { x += y; }
                break :blk1 x;
            };
            if (sum != first_sum) break :blk false;
        }
        break :blk true;
    };
    try std.testing.expect(hold2_all_equal);
    const hold2_total = blk: {
        var total: u64 = 0;
        for (strategy.deal_frequency.hand2_to_rank_freq) |arr| {
            for (arr.data) |y| { total += y; }
        }
        break :blk total;
    };
    try std.testing.expectEqual(2_598_960 * 10, hold2_total);
    const hold3_all_equal = blk: {
        const first_sum = blk1: {
            var x: u64 = 0;
            for (strategy.deal_frequency.hand3_to_rank_freq[0].data) |y| { x += y; }
            break :blk1 x;
        };
        for (strategy.deal_frequency.hand3_to_rank_freq) |arr| {
            const sum = blk1: {
                var x: u64 = 0;
                for (arr.data) |y| { x += y; }
                break :blk1 x;
            };
            if (sum != first_sum) break :blk false;
        }
        break :blk true;
    };
    try std.testing.expect(hold3_all_equal);
    const hold3_total = blk: {
        var total: u64 = 0;
        for (strategy.deal_frequency.hand3_to_rank_freq) |arr| {
            for (arr.data) |y| { total += y; }
        }
        break :blk total;
    };
    try std.testing.expectEqual(2_598_960 * 10, hold3_total);
    const hold4_all_equal = blk: {
        const first_sum = blk1: {
            var x: u64 = 0;
            for (strategy.deal_frequency.hand4_to_rank_freq[0].data) |y| { x += y; }
            break :blk1 x;
        };
        for (strategy.deal_frequency.hand4_to_rank_freq) |arr| {
            const sum = blk1: {
                var x: u64 = 0;
                for (arr.data) |y| { x += y; }
                break :blk1 x;
            };
            if (sum != first_sum) break :blk false;
        }
        break :blk true;
    };
    try std.testing.expect(hold4_all_equal);
    const hold4_total = blk: {
        var total: u64 = 0;
        for (strategy.deal_frequency.hand4_to_rank_freq) |arr| {
            for (arr.data) |y| { total += y; }
        }
        break :blk total;
    };
    try std.testing.expectEqual(2_598_960 * 5, hold4_total);

    // royal flush: 4 suits
    try std.testing.expectEqual(4, strategy.deal_frequency.hand0_to_rank_freq.data[@intFromEnum(DeucesWild.royal_flush)]);
    // four deuces: choose last card = 48
    try std.testing.expectEqual(48, strategy.deal_frequency.hand0_to_rank_freq.data[@intFromEnum(DeucesWild.four_deuces)]);

    // royal flush: 0 discards
    const hand_royal_flush: [5]Card = .{
        .{ .rank = .ten, .suit = .heart },
        .{ .rank = .jack, .suit = .heart },
        .{ .rank = .queen, .suit = .heart },
        .{ .rank = .king, .suit = .heart },
        .{ .rank = .ace, .suit = .heart },
    };
    var hand_royal_flush_indices: [5]u6 = undefined;
    for (0.., hand_royal_flush) |i, card| { hand_royal_flush_indices[i] = card.index(); }
    try std.testing.expectEqualDeep(
        [_]u64{
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            1 * DeucesWildOptimalStrategy.DRAW_WEIGHT[0],
        },
        strategy.draw_frequency(hand_royal_flush_indices).data,
    );
    // 4 to royal: 1 discard
    const hand_four_to_royal: [5]Card = .{
        .{ .rank = .three, .suit = .heart },
        .{ .rank = .ten, .suit = .heart },
        .{ .rank = .jack, .suit = .heart },
        .{ .rank = .queen, .suit = .heart },
        .{ .rank = .king, .suit = .heart },
    };
    var hand_four_to_royal_indices: [5]u6 = undefined;
    for (0.., hand_four_to_royal) |i, card| { hand_four_to_royal_indices[i] = card.index(); }
    try std.testing.expectEqualDeep(
        [_]u64{
            30 * DeucesWildOptimalStrategy.DRAW_WEIGHT[1],
            0,
            6 * DeucesWildOptimalStrategy.DRAW_WEIGHT[1],
            5 * DeucesWildOptimalStrategy.DRAW_WEIGHT[1],
            0,
            0,
            1 * DeucesWildOptimalStrategy.DRAW_WEIGHT[1],
            0,
            4 * DeucesWildOptimalStrategy.DRAW_WEIGHT[1],
            0,
            1 * DeucesWildOptimalStrategy.DRAW_WEIGHT[1],
        },
        strategy.draw_frequency(hand_four_to_royal_indices).data,
    );
    // 4 deuces: 0 discards
    const hand_four_deuces: [5]Card = .{
        .{ .rank = .two, .suit = .heart },
        .{ .rank = .two, .suit = .diamond },
        .{ .rank = .two, .suit = .club },
        .{ .rank = .two, .suit = .spade },
        .{ .rank = .king, .suit = .heart },
    };
    var hand_four_deuces_indices: [5]u6 = undefined;
    for (0.., hand_four_deuces) |i, card| { hand_four_deuces_indices[i] = card.index(); }
    try std.testing.expectEqualDeep(
        [_]u64{
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            0,
            1 * DeucesWildOptimalStrategy.DRAW_WEIGHT[0],
            0,
        },
        strategy.draw_frequency(hand_four_deuces_indices).data,
    );
    // 3 deuces: 2 discard
    const draw_weight_2 = DeucesWildOptimalStrategy.DRAW_WEIGHT[2];
    const hand_three_deuces: [5]Card = .{
        .{ .rank = .two, .suit = .heart },
        .{ .rank = .two, .suit = .diamond },
        .{ .rank = .two, .suit = .club },
        .{ .rank = .three, .suit = .spade },
        .{ .rank = .nine, .suit = .heart },
    };
    var hand_three_deuces_indices: [5]u6 = undefined;
    for (0.., hand_three_deuces) |i, card| { hand_three_deuces_indices[i] = card.index(); }
    try std.testing.expectEqualDeep(
        [_]u64{
            0,
            0,
            0,
            0,
            0,
            818 * draw_weight_2,  // 1081 - rest
            111 * draw_weight_2,  // 5c2 * 4, (3-7)= 5c2 * 4 suits                           = 40
                                  // + 4 * 6 * 4, (48,58,68,78)=4 * (4-8)-(9-K)=6 * 4 suits  = 96
                                  // + 3 * 3, (A3,A4,A5)=3 * 3                               = 9
                                  // - 4, 3s + (4-7)s                                        = -4
                                  // - 8, 9h + (5-K)h                                        = -8
                                  // - 6, (6T,7T,7J,8T,8J,8Q)                                = -6
                                  // -16?
            66 * draw_weight_2,   // 3c2 * 2, for the 3 and 9
                                  // + 4c2 * 10, rest
            40 * draw_weight_2,   // 5c2 * 4, (10-A)=5 * 4 suits
            46 * draw_weight_2,   // last 2 * any other card
            0,
        },
        strategy.draw_frequency(hand_three_deuces_indices).data,
    );
}
