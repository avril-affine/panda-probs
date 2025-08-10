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

fn PayoutFrequencyVectorizedType(P: usize) type {
    return struct {
        const Self = @This();
        pub const len = P;

        data: @Vector(P, u64),

        pub fn init() Self {
            return . { .data = @splat(0) };
        }

        fn allocate_array(allocator: std.mem.Allocator, comptime size: u64) !*[size]Self {
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
    };
}

pub fn OptimalStrategyVectorized(
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
        paytable: @Vector(P, u64),
        allocator: std.mem.Allocator,

        pub const PayoutFrequency = PayoutFrequencyVectorizedType(P);
        pub const Deck = HandRank.Deck;
        pub const num_payouts = P;
        const Self = @This();
        const draw_size = Deck.N - 5;
        // normalize the output of `draw_frequency` so that it counts as 47c5
        const DRAW_WEIGHT: [6]u64 = .{
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
            hold0.data = @splat(0);

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

                // add
                const hand_hold3_idx = Self.get_hand_idx(hand, indices_hold);
                frequencies.add(&self.hold3[hand_hold3_idx]);
                frequencies.inc(payout_idx);

                // sub
                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc1);
                    frequencies.sub(&self.hold4[hand_hold4_idx]);
                }

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

                // add
                const hand_hold2_idx = Self.get_hand_idx(hand, indices_hold);
                frequencies.add(&self.hold2[hand_hold2_idx]);
                var indices_disc2_iter = IndexIterator2.init(&indices_disc);
                while (indices_disc2_iter.next()) |indices_disc2| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc2);
                    frequencies.add(&self.hold4[hand_hold4_idx]);
                }

                // sub
                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold3_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc1);
                    frequencies.sub(&self.hold3[hand_hold3_idx]);
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

                // add
                const hand_hold1_idx = Self.get_hand_idx(hand, indices_hold);
                frequencies.add(&self.hold1[hand_hold1_idx]);
                var indices_disc2_iter = IndexIterator2.init(&indices_disc);
                while (indices_disc2_iter.next()) |indices_disc2| {
                    const hand_hold3_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc2);
                    frequencies.add(&self.hold3[hand_hold3_idx]);
                }
                frequencies.inc(payout_idx);

                
                // sub
                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold2_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc1);
                    frequencies.sub(&self.hold2[hand_hold2_idx]);
                }
                var indices_disc3_iter = IndexIterator3.init(&indices_disc);
                while (indices_disc3_iter.next()) |indices_disc3| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_hold ++ indices_disc3);
                    frequencies.sub(&self.hold4[hand_hold4_idx]);
                }

                const ev = self.get_ev(frequencies, 1);
                if (ev > best_ev) {
                    best_ev = ev;
                    best_frequencies = frequencies;
                    best_num_hold = 1;
                }
            }

            // hold 0
            {
                const indices_disc = [_]usize{0, 1, 2, 3, 4};
                var frequencies = PayoutFrequency.init();

                // add
                frequencies.add(self.hold0);
                var indices_disc2_iter = IndexIterator2.init(&indices_disc);
                while (indices_disc2_iter.next()) |indices_disc2| {
                    const hand_hold2_idx = Self.get_hand_idx(hand, indices_disc2);
                    frequencies.add(&self.hold2[hand_hold2_idx]);
                }
                var indices_disc4_iter = IndexIterator4.init(&indices_disc);
                while (indices_disc4_iter.next()) |indices_disc4| {
                    const hand_hold4_idx = Self.get_hand_idx(hand, indices_disc4);
                    frequencies.add(&self.hold4[hand_hold4_idx]);
                }

                // sub
                var indices_disc1_iter = IndexIterator1.init(&indices_disc);
                while (indices_disc1_iter.next()) |indices_disc1| {
                    const hand_hold1_idx = Self.get_hand_idx(hand, indices_disc1);
                    frequencies.sub(&self.hold1[hand_hold1_idx]);
                }
                var indices_disc3_iter = IndexIterator3.init(&indices_disc);
                while (indices_disc3_iter.next()) |indices_disc3| {
                    const hand_hold3_idx = Self.get_hand_idx(hand, indices_disc3);
                    frequencies.sub(&self.hold3[hand_hold3_idx]);
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
            const sum = @reduce(.Add, self.paytable * frequencies.data);
            return sum * DRAW_WEIGHT[5-num_hold];
        }
    };
}

test "OptimalStrategyVectorized DeucesWild" {
}
