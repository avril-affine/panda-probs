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

fn PayoutFrequencyType(P: usize) type {
    return struct {
        const Self = @This();
        pub const len = P;

        data: [P]i64,

        pub fn init() Self {
            return . { .data = @splat(0) };
        }

        fn allocate_array(allocator: std.mem.Allocator, comptime size: u64) !*[size]Self {
            const arr = try allocator.create([size]Self);
            for (arr) |*elem| {
                elem.data = .{0} ** P;
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
            for (0..P) |i| { self.data[i] += other.data[i]; }
        }

        pub fn sub(self: *Self, other: *const Self) void {
            for (0..P) |i| { self.data[i] -= other.data[i]; }
        }

        pub fn mul(self: *Self, val: i64) void {
            for (0..P) |i| { self.data[i] *= val; }
        }
    };
}

pub fn OptimalStrategy(
    /// a u8 enum representing the different hand ranks
    comptime HandRank: type,
) type {

    const P = @typeInfo(HandRank).@"enum".fields.len;
    const DEAL_CHOOSE_5 = combinations.choose(HandRank.Deck.N, 5);
    const DEAL_CHOOSE_4 = combinations.choose(HandRank.Deck.N, 4);
    const DEAL_CHOOSE_3 = combinations.choose(HandRank.Deck.N, 3);
    const DEAL_CHOOSE_2 = combinations.choose(HandRank.Deck.N, 2);
    const DEAL_CHOOSE_1 = combinations.choose(HandRank.Deck.N, 1);

    return struct {
        // holdN is slightly a misnomer.
        // it doesn't consider the discarded cards in the count.
        // so holdN is the same as with a full deck.
        hand_to_rank_index: *const [DEAL_CHOOSE_5]usize,
        hold4: *const [DEAL_CHOOSE_4]PayoutFrequency,
        hold3: *const [DEAL_CHOOSE_3]PayoutFrequency,
        hold2: *const [DEAL_CHOOSE_2]PayoutFrequency,
        hold1: *const [DEAL_CHOOSE_1]PayoutFrequency,
        hold0: *const PayoutFrequency,
        paytable: [P]u64,
        allocator: std.mem.Allocator,

        pub const PayoutFrequency = PayoutFrequencyType(P);
        pub const Deck = HandRank.Deck;
        pub const num_payouts = P;
        const Self = @This();
        const draw_size = Deck.N - 5;
        // normalize the output of `draw_frequency` so that it counts as 47c5
        const DRAW_WEIGHT: [6]i64 = .{
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 0),
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 1),
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 2),
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 3),
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 4),
            combinations.choose(draw_size, 5) * 5 / combinations.choose(draw_size, 5),
        };

        pub fn init(allocator: std.mem.Allocator, paytable: [P]u64) !Self {
            const hand_to_rank_index = try allocator.create([DEAL_CHOOSE_5]usize);
            @memset(hand_to_rank_index, 0);
            const hold4 = try PayoutFrequency.allocate_array(allocator, DEAL_CHOOSE_4);
            const hold3 = try PayoutFrequency.allocate_array(allocator, DEAL_CHOOSE_3);
            const hold2 = try PayoutFrequency.allocate_array(allocator, DEAL_CHOOSE_2);
            const hold1 = try PayoutFrequency.allocate_array(allocator, DEAL_CHOOSE_1);
            const hold0 = try allocator.create(PayoutFrequency);
            hold0.data = .{0} ** P;

            const deck = Deck.init();
            var hand_iter = deck.hand_iter();
            while (hand_iter.next()) |*hand| {
                const score: usize = @intFromEnum(HandRank.from_hand(hand));
                const hand_indices: [5]u8 = blk: {
                    var result: [5]u8 = undefined;
                    for (0..5) |i| { result[i] = hand[i].index(); }
                    break :blk result;
                };
                hand_to_rank_index[Deck.hand_to_index(&hand_indices)] = score;
                // discard 1
                var hand_hold4_iter = CombinationIterator(u8, 4).init(&hand_indices);
                while (hand_hold4_iter.next()) |hand_discard| {
                    const hand_discard_idx = Deck.hand_to_index(&hand_discard);
                    hold4[hand_discard_idx].inc(score);
                }
                // discard 2
                var hand_hold3_iter = CombinationIterator(u8, 3).init(&hand_indices);
                while (hand_hold3_iter.next()) |hand_discard| {
                    const hand_discard_idx = Deck.hand_to_index(&hand_discard);
                    hold3[hand_discard_idx].inc(score);
                }
                // discard 3
                var hand_hold2_iter = CombinationIterator(u8, 2).init(&hand_indices);
                while (hand_hold2_iter.next()) |hand_discard| {
                    const hand_discard_idx = Deck.hand_to_index(&hand_discard);
                    hold2[hand_discard_idx].inc(score);
                }
                // discard 4
                var hand_hold1_iter = CombinationIterator(u8, 1).init(&hand_indices);
                while (hand_hold1_iter.next()) |hand_discard| {
                    const hand_discard_idx = Deck.hand_to_index(&hand_discard);
                    hold1[hand_discard_idx].inc(score);
                }
                // discard 5
                hold0.inc(score);
            }

            return .{
                .hand_to_rank_index = hand_to_rank_index,
                .hold4 = hold4,
                .hold3 = hold3,
                .hold2 = hold2,
                .hold1 = hold1,
                .hold0 = hold0,
                .paytable = paytable,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.hand_to_rank_index);
            self.allocator.free(self.hold4);
            self.allocator.free(self.hold3);
            self.allocator.free(self.hold2);
            self.allocator.free(self.hold1);
            self.allocator.destroy(self.hold0);
        }

        pub fn draw_frequency(self: *const Self, hand: [5]u8) PayoutFrequency {
            // hold 5
            const payout_idx = self.hand_to_rank_index[Deck.hand_to_index(&hand)];
            var best_frequencies = PayoutFrequency.init();
            best_frequencies.inc(payout_idx);
            var best_ev = self.get_ev(best_frequencies, 5);
            var best_num_hold: u64 = 5;

            // hold 4
            inline for (combinations.indices_5c4) |indices| {
                const indices_hold, _ = indices;
                var frequencies = PayoutFrequency.init();

                const hand_idx = Self.get_hand_idx(hand, indices_hold);
                frequencies.add(&self.hold4[hand_idx]);
                frequencies.dec(payout_idx);

                const ev = self.get_ev(frequencies, 4);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 4;
                }
            }

            // hold 3
            inline for (combinations.indices_5c3) |indices| {
                const indices_hold, const indices_disc = indices;
                var frequencies = PayoutFrequency.init();

                const hand_hold3_idx = Self.get_hand_idx(hand, indices_hold);
                frequencies.add(&self.hold3[hand_hold3_idx]);

                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc1);
                    frequencies.sub(&self.hold4[hand_hold4_idx]);
                }
                frequencies.inc(payout_idx);

                const ev = self.get_ev(frequencies, 3);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 3;
                }
            }

            // hold 2
            inline for (combinations.indices_5c2) |indices| {
                const indices_hold, const indices_disc = indices;
                var frequencies = PayoutFrequency.init();

                const hand_hold2_idx = Self.get_hand_idx(hand, indices_hold);
                frequencies.add(&self.hold2[hand_hold2_idx]);

                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold3_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc1);
                    frequencies.sub(&self.hold3[hand_hold3_idx]);
                }
                var indices_disc2_iter = IndexIterator2.init(&indices_disc);
                while (indices_disc2_iter.next()) |indices_disc2| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc2);
                    frequencies.add(&self.hold4[hand_hold4_idx]);
                }
                frequencies.dec(payout_idx);

                const ev = self.get_ev(frequencies, 2);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 2;
                }
            }

            // hold 1
            inline for (combinations.indices_5c1) |indices| {
                const indices_hold, const indices_disc = indices;
                var frequencies = PayoutFrequency.init();

                const hand_hold1_idx = Self.get_hand_idx(hand, indices_hold);
                frequencies.add(&self.hold1[hand_hold1_idx]);

                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold2_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc1);
                    frequencies.sub(&self.hold2[hand_hold2_idx]);
                }
                var indices_disc2_iter = IndexIterator2.init(&indices_disc);
                while (indices_disc2_iter.next()) |indices_disc2| {
                    const hand_hold3_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc2);
                    frequencies.add(&self.hold3[hand_hold3_idx]);
                }
                var indices_disc3_iter = IndexIterator3.init(&indices_disc);
                while (indices_disc3_iter.next()) |indices_disc3| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc3);
                    frequencies.sub(&self.hold4[hand_hold4_idx]);
                }
                frequencies.inc(payout_idx);

                const ev = self.get_ev(frequencies, 1);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 1;
                }
            }

            // hold 0
            {
                var frequencies = PayoutFrequency.init();

                frequencies.add(self.hold0);

                const indices_disc = [_]usize{0, 1, 2, 3, 4};
                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold1_idx = Self.get_hand_idx(hand, indices_disc1);
                    frequencies.sub(&self.hold1[hand_hold1_idx]);
                }
                var indices_disc2_iter = IndexIterator2.init(&indices_disc);
                while (indices_disc2_iter.next()) |indices_disc2| {
                    const hand_hold2_idx = Self.get_hand_idx(hand, indices_disc2);
                    frequencies.add(&self.hold2[hand_hold2_idx]);
                }
                var indices_disc3_iter = IndexIterator3.init(&indices_disc);
                while (indices_disc3_iter.next()) |indices_disc3| {
                    const hand_hold3_idx = Self.get_hand_idx(hand, indices_disc3);
                    frequencies.sub(&self.hold3[hand_hold3_idx]);
                }
                var indices_disc4_iter = IndexIterator4.init(&indices_disc);
                while (indices_disc4_iter.next()) |indices_disc4| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_disc4);
                    frequencies.add(&self.hold4[hand_hold4_idx]);
                }
                frequencies.dec(payout_idx);

                const ev = self.get_ev(frequencies, 0);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 0;
                }
            }

            best_frequencies.mul(DRAW_WEIGHT[5-best_num_hold]);

            return best_frequencies;
        }

        fn get_hand_idx(hand: [5]u8, indices: anytype) u64 {
            return Deck.hand_to_index(&select(&hand, indices));
        }

        fn get_ev(self: *const Self, frequencies: PayoutFrequency, num_hold: u64) u64 {
            assert(num_hold <= 5);
            const sum: u64 = blk: {
                var x: u64 = 0;
                for (0..P) |i| { x += self.paytable[i] * @as(u64, @intCast(frequencies.data[i])); }
                break :blk x;
            };
            const weight = @as(u64, @intCast(DRAW_WEIGHT[5-num_hold]));
            return sum * weight;
        }
    };
}

test "OptimalStrategy DeucesWild" {
    const DeucesWild = @import("../poker_types/deuces_wild.zig").DeucesWild;
    const DeucesWildFullPay = @import("../poker_types/deuces_wild.zig").DeucesWildFullPay;
    const Card = DeucesWild.Card;

    try combinations.init(std.testing.allocator);
    defer combinations.deinit();

    const DeucesWildOptimalStrategy = OptimalStrategy(DeucesWild);
    var strategy = try DeucesWildOptimalStrategy.init(std.testing.allocator, DeucesWildFullPay);
    defer strategy.deinit();

    const hold0_total: i64 = blk: {
        var x: i64 = 0;
        for (strategy.hold0.data) |y| { x += y; }
        break :blk x;
    };
    try std.testing.expectEqual(2_598_960, hold0_total);
    const hold1_all_equal = blk: {
        const first_sum: i64 = blk1: {
            var x: i64 = 0;
            for (strategy.hold1[0].data) |y| { x += y; }
            break :blk1 x;
        };
        for (strategy.hold1) |arr| {
            const sum: i64 = blk1: {
                var x: i64 = 0;
                for (arr.data) |y| { x += y; }
                break :blk1 x;
            };
            if (sum != first_sum) break :blk false;
        }
        break :blk true;
    };
    try std.testing.expect(hold1_all_equal);
    const hold1_total = blk: {
        var total: i64 = 0;
        for (strategy.hold1) |arr| {
            for (arr.data) |y| { total += y; }
        }
        break :blk total;
    };
    try std.testing.expectEqual(2_598_960 * 5, hold1_total);
    const hold2_all_equal = blk: {
        const first_sum = blk1: {
            var x: i64 = 0;
            for (strategy.hold2[0].data) |y| { x += y; }
            break :blk1 x;
        };
        for (strategy.hold2) |arr| {
            const sum = blk1: {
                var x: i64 = 0;
                for (arr.data) |y| { x += y; }
                break :blk1 x;
            };
            if (sum != first_sum) break :blk false;
        }
        break :blk true;
    };
    try std.testing.expect(hold2_all_equal);
    const hold2_total = blk: {
        var total: i64 = 0;
        for (strategy.hold2) |arr| {
            for (arr.data) |y| { total += y; }
        }
        break :blk total;
    };
    try std.testing.expectEqual(2_598_960 * 10, hold2_total);
    const hold3_all_equal = blk: {
        const first_sum = blk1: {
            var x: i64 = 0;
            for (strategy.hold3[0].data) |y| { x += y; }
            break :blk1 x;
        };
        for (strategy.hold3) |arr| {
            const sum = blk1: {
                var x: i64 = 0;
                for (arr.data) |y| { x += y; }
                break :blk1 x;
            };
            if (sum != first_sum) break :blk false;
        }
        break :blk true;
    };
    try std.testing.expect(hold3_all_equal);
    const hold3_total = blk: {
        var total: i64 = 0;
        for (strategy.hold3) |arr| {
            for (arr.data) |y| { total += y; }
        }
        break :blk total;
    };
    try std.testing.expectEqual(2_598_960 * 10, hold3_total);
    const hold4_all_equal = blk: {
        const first_sum = blk1: {
            var x: i64 = 0;
            for (strategy.hold4[0].data) |y| { x += y; }
            break :blk1 x;
        };
        for (strategy.hold4) |arr| {
            const sum = blk1: {
                var x: i64 = 0;
                for (arr.data) |y| { x += y; }
                break :blk1 x;
            };
            if (sum != first_sum) break :blk false;
        }
        break :blk true;
    };
    try std.testing.expect(hold4_all_equal);
    const hold4_total = blk: {
        var total: i64 = 0;
        for (strategy.hold4) |arr| {
            for (arr.data) |y| { total += y; }
        }
        break :blk total;
    };
    try std.testing.expectEqual(2_598_960 * 5, hold4_total);

    // royal flush: 4 suits
    try std.testing.expectEqual(4, strategy.hold0.data[@intFromEnum(DeucesWild.royal_flush)]);
    // four deuces: choose last card = 48
    try std.testing.expectEqual(48, strategy.hold0.data[@intFromEnum(DeucesWild.four_deuces)]);

    // royal flush: 0 discards
    const hand_royal_flush: [5]Card = .{
        .{ .rank = .ten, .suit = .heart },
        .{ .rank = .jack, .suit = .heart },
        .{ .rank = .queen, .suit = .heart },
        .{ .rank = .king, .suit = .heart },
        .{ .rank = .ace, .suit = .heart },
    };
    var hand_royal_flush_indices: [5]u8 = undefined;
    for (0.., hand_royal_flush) |i, card| { hand_royal_flush_indices[i] = card.index(); }
    try std.testing.expectEqualDeep(
        [_]i64{
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
    var hand_four_to_royal_indices: [5]u8 = undefined;
    for (0.., hand_four_to_royal) |i, card| { hand_four_to_royal_indices[i] = card.index(); }
    try std.testing.expectEqualDeep(
        [_]i64{
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
    var hand_four_deuces_indices: [5]u8 = undefined;
    for (0.., hand_four_deuces) |i, card| { hand_four_deuces_indices[i] = card.index(); }
    try std.testing.expectEqualDeep(
        [_]i64{
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
    var hand_three_deuces_indices: [5]u8 = undefined;
    for (0.., hand_three_deuces) |i, card| { hand_three_deuces_indices[i] = card.index(); }
    try std.testing.expectEqualDeep(
        [_]i64{
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
