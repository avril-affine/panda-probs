const std = @import("std");

const combinations = @import("../combinations.zig");
const CombinationIterator = combinations.CombinationIterator;
const RankFrequencyArray = @import("rank_array.zig").RankFrequencyArray;
const RankFrequencyVector = @import("rank_vector.zig").RankFrequencyVector;

pub fn DealFrequency(
    comptime HandRankType: type,
    comptime RankFrequencyType: type,
) type {
    const Deck = HandRankType.Deck;
    const DEAL_CHOOSE_5 = combinations.choose(Deck.len, 5);
    const DEAL_CHOOSE_4 = combinations.choose(Deck.len, 4);
    const DEAL_CHOOSE_3 = combinations.choose(Deck.len, 3);
    const DEAL_CHOOSE_2 = combinations.choose(Deck.len, 2);
    const DEAL_CHOOSE_1 = combinations.choose(Deck.len, 1);

    return struct {
        const Self = @This();
        pub const RankFrequency = RankFrequencyType;
        pub const HandRank = HandRankType;

        hand5_to_rank_index: *const [DEAL_CHOOSE_5]usize,
        hand4_to_rank_freq: *const [DEAL_CHOOSE_4]RankFrequency,
        hand3_to_rank_freq: *const [DEAL_CHOOSE_3]RankFrequency,
        hand2_to_rank_freq: *const [DEAL_CHOOSE_2]RankFrequency,
        hand1_to_rank_freq: *const [DEAL_CHOOSE_1]RankFrequency,
        hand0_to_rank_freq: *const RankFrequency,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator) !Self {
            const hand5_to_rank_index = try allocator.create([DEAL_CHOOSE_5]usize);
            @memset(hand5_to_rank_index, 0);
            const hand4_to_rank_freq = try RankFrequency.allocate_array(allocator, DEAL_CHOOSE_4);
            const hand3_to_rank_freq = try RankFrequency.allocate_array(allocator, DEAL_CHOOSE_3);
            const hand2_to_rank_freq = try RankFrequency.allocate_array(allocator, DEAL_CHOOSE_2);
            const hand1_to_rank_freq = try RankFrequency.allocate_array(allocator, DEAL_CHOOSE_1);
            const hand0_to_rank_freq: *RankFrequency = @ptrCast(try RankFrequency.allocate_array(allocator, 1));

            const deck = Deck.init();
            var hand_iter = deck.hand_iter();
            while (hand_iter.next()) |*hand| {
                const hand_rank: usize = @intFromEnum(HandRank.from_hand(hand));
                var hand_indices: [5]u6 = undefined;
                for (0..5) |i| { hand_indices[i] = hand[i].index(); }

                // 5 card hand == hand_rank
                hand5_to_rank_index[HandRank.Deck.hand_to_index(&hand_indices)] = hand_rank;

                // 4 card hands that can make hand_rank
                var hand_hold4_iter = CombinationIterator(u6, 4).init(&hand_indices);
                while (hand_hold4_iter.next()) |hand_discard| {
                    const hand_discard_idx = Deck.hand_to_index(&hand_discard);
                    hand4_to_rank_freq[hand_discard_idx].inc(hand_rank);
                }
                // 3 card hands that can make hand_rank
                var hand_hold3_iter = CombinationIterator(u6, 3).init(&hand_indices);
                while (hand_hold3_iter.next()) |hand_discard| {
                    const hand_discard_idx = Deck.hand_to_index(&hand_discard);
                    hand3_to_rank_freq[hand_discard_idx].inc(hand_rank);
                }
                // 2 card hands that can make hand_rank
                var hand_hold2_iter = CombinationIterator(u6, 2).init(&hand_indices);
                while (hand_hold2_iter.next()) |hand_discard| {
                    const hand_discard_idx = Deck.hand_to_index(&hand_discard);
                    hand2_to_rank_freq[hand_discard_idx].inc(hand_rank);
                }
                // 1 card hands that can make hand_rank
                var hand_hold1_iter = CombinationIterator(u6, 1).init(&hand_indices);
                while (hand_hold1_iter.next()) |hand_discard| {
                    const hand_discard_idx = Deck.hand_to_index(&hand_discard);
                    hand1_to_rank_freq[hand_discard_idx].inc(hand_rank);
                }
                // 0 card hands that can make hand_rank
                hand0_to_rank_freq.inc(hand_rank);
            }

            return .{
                .hand5_to_rank_index = hand5_to_rank_index,
                .hand4_to_rank_freq = hand4_to_rank_freq,
                .hand3_to_rank_freq = hand3_to_rank_freq,
                .hand2_to_rank_freq = hand2_to_rank_freq,
                .hand1_to_rank_freq = hand1_to_rank_freq,
                .hand0_to_rank_freq = hand0_to_rank_freq,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.hand5_to_rank_index);
            self.allocator.free(self.hand4_to_rank_freq);
            self.allocator.free(self.hand3_to_rank_freq);
            self.allocator.free(self.hand2_to_rank_freq);
            self.allocator.free(self.hand1_to_rank_freq);
            self.allocator.destroy(self.hand0_to_rank_freq);
        }

        pub fn serialize(self: *const Self, writer: anytype) !void {
            try writer.writeAll(std.mem.asBytes(self.hand5_to_rank_index));
            for (self.hand4_to_rank_freq) |rank_frequency| {
                try writer.writeAll(std.mem.asBytes(&rank_frequency.data));
            }
            for (self.hand3_to_rank_freq) |rank_frequency| {
                try writer.writeAll(std.mem.asBytes(&rank_frequency.data));
            }
            for (self.hand2_to_rank_freq) |rank_frequency| {
                try writer.writeAll(std.mem.asBytes(&rank_frequency.data));
            }
            for (self.hand1_to_rank_freq) |rank_frequency| {
                try writer.writeAll(std.mem.asBytes(&rank_frequency.data));
            }
            try writer.writeAll(std.mem.asBytes(&self.hand0_to_rank_freq.data));
        }

        pub fn deserialize(allocator: std.mem.Allocator, reader: anytype) !Self {
            const hand5_to_rank_index = try allocator.create([DEAL_CHOOSE_5]usize);
            const hand4_to_rank_freq = try RankFrequency.allocate_array(allocator, DEAL_CHOOSE_4);
            const hand3_to_rank_freq = try RankFrequency.allocate_array(allocator, DEAL_CHOOSE_3);
            const hand2_to_rank_freq = try RankFrequency.allocate_array(allocator, DEAL_CHOOSE_2);
            const hand1_to_rank_freq = try RankFrequency.allocate_array(allocator, DEAL_CHOOSE_1);
            const hand0_to_rank_freq = try allocator.create(RankFrequency);

            try reader.readNoEof(std.mem.asBytes(hand5_to_rank_index));
            for (hand4_to_rank_freq) |*rank_frequency| { try reader.readNoEof(std.mem.asBytes(rank_frequency)); }
            for (hand3_to_rank_freq) |*rank_frequency| { try reader.readNoEof(std.mem.asBytes(rank_frequency)); }
            for (hand2_to_rank_freq) |*rank_frequency| { try reader.readNoEof(std.mem.asBytes(rank_frequency)); }
            for (hand1_to_rank_freq) |*rank_frequency| { try reader.readNoEof(std.mem.asBytes(rank_frequency)); }
            try reader.readNoEof(std.mem.asBytes(&hand0_to_rank_freq.data));

            return .{
                .hand5_to_rank_index = hand5_to_rank_index,
                .hand4_to_rank_freq = hand4_to_rank_freq,
                .hand3_to_rank_freq = hand3_to_rank_freq,
                .hand2_to_rank_freq = hand2_to_rank_freq,
                .hand1_to_rank_freq = hand1_to_rank_freq,
                .hand0_to_rank_freq = hand0_to_rank_freq,
                .allocator = allocator,
            };
        }
    };
}
