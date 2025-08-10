const std = @import("std");

const combinations = @import("../combinations.zig");

const assert = std.debug.assert;
const choose_lookup = combinations.choose_lookup;
const CombinationIterator = combinations.CombinationIterator;

pub const StandardDeck = struct {
    cards: [N]Card,

    pub const N = 52;
    const indices: [N]u8 = blk: {
        var result: [N]u8 = undefined;
        for (0..N) |i| { result[i] = @as(u8, @intCast(i)); }
        break :blk result;
    };

    pub const Card = struct {
        rank: Rank,
        suit: Suit,

        pub const Rank = enum(u8) {
            two,
            three,
            four,
            five,
            six,
            seven,
            eight,
            nine,
            ten,
            jack,
            queen,
            king,
            ace,

            pub fn format(self: *const Rank, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
                switch (self.*) {
                    .two   => try writer.print("2", .{}),
                    .three => try writer.print("3", .{}),
                    .four  => try writer.print("4", .{}),
                    .five  => try writer.print("5", .{}),
                    .six   => try writer.print("6", .{}),
                    .seven => try writer.print("7", .{}),
                    .eight => try writer.print("8", .{}),
                    .nine  => try writer.print("9", .{}),
                    .ten   => try writer.print("T", .{}),
                    .jack  => try writer.print("J", .{}),
                    .queen => try writer.print("Q", .{}),
                    .king  => try writer.print("K", .{}),
                    .ace   => try writer.print("A", .{}),
                }
            }
        };

        pub const Suit = enum(u8) {
            heart,
            diamond,
            club,
            spade,

            pub fn format(self: *const Suit, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
                switch (self.*) {
                    .heart   => try writer.print("h", .{}),
                    .diamond => try writer.print("d", .{}),
                    .club    => try writer.print("c", .{}),
                    .spade   => try writer.print("s", .{}),
                }
            }
        };

        pub fn init(i: u8) Card {
            assert(i < StandardDeck.N);
            return .{
                .rank = @enumFromInt(i / 4),
                .suit = @enumFromInt(i % 4),
            };
        }

        pub fn index(self: Card) u8 {
            return @intFromEnum(self.rank) * 4 + @intFromEnum(self.suit);
        }

        pub fn format(self: *const Card, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
            try writer.print("{}{}", .{self.rank, self.suit});
        }
    };

    pub fn init() StandardDeck {
        var cards: [StandardDeck.N]Card = undefined;
        for (0..StandardDeck.N) |index| {
            cards[index] = Card.init(@intCast(index));
        }
        return .{.cards = cards};
    }

    /// computes a unique index for an array of card indices.
    /// this uses a bit mask to "sort" the array.
    pub fn hand_to_index(hand: []const u8) u64 {
        var bit_mask: u64 = 0;
        for (hand) |card| {
            bit_mask |= (@as(u64, 1) << @as(u6, @intCast(card)));
        }

        var k: u8 = @intCast(hand.len);
        var prev_card = @ctz(bit_mask);
        var result = choose_lookup(StandardDeck.N, k) - choose_lookup(StandardDeck.N-prev_card, k);
        bit_mask &= bit_mask - 1;  // remove least significant bit
        k -= 1;
        while (bit_mask != 0) : ({
            bit_mask &= bit_mask - 1;
            k -= 1;
        }) {
            const card = @ctz(bit_mask);
            const n_1 = StandardDeck.N - 1 - prev_card;
            const n_2 = StandardDeck.N - card;
            result += choose_lookup(n_1, k) - choose_lookup(n_2, k);
            prev_card = card;
        }
        return result;
    }

    pub fn hand_iter(self: *const StandardDeck) CombinationIterator(Card, 5) {
        return CombinationIterator(Card, 5).init(&self.cards);
    }
};

test "StandardDeck.Card roundtrip" {
    for (0..52) |i| {
        const card = StandardDeck.Card.init(@intCast(i));
        const roundtrip = StandardDeck.Card.init(card.index());
        try std.testing.expectEqualDeep(card, roundtrip);
    }
}

test "StandardDeck rank order" {
    const deck = StandardDeck.init();
    var current_rank: StandardDeck.Card.Rank = @enumFromInt(0);

    for (deck.cards) |card| {
        try std.testing.expect(@intFromEnum(current_rank) <= @intFromEnum(card.rank));
        current_rank = card.rank;
    }
}

test "StandardDeck.hand_to_index" {
    try combinations.init(std.testing.allocator);
    defer combinations.deinit();

    try std.testing.expectEqual(0, StandardDeck.hand_to_index(&.{0, 1}));

    try std.testing.expectEqual(1, StandardDeck.hand_to_index(&.{0, 2}));

    try std.testing.expectEqual(2598959, StandardDeck.hand_to_index(&.{47, 48, 49, 50, 51}));
}
