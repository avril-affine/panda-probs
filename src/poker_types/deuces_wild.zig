const std = @import("std");

const deck = @import("../decks/standard.zig");

const assert = std.debug.assert;

pub const DeucesWild = enum(u8) {
    none,
    three_of_a_kind,
    straight,
    flush,
    full_house,
    four_of_a_kind,
    straight_flush,
    five_of_a_kind,
    wild_royal_flush,
    four_deuces,
    royal_flush,

    pub const Deck = deck.StandardDeck;
    pub const Card = Deck.Card;
    pub const Rank = Deck.Card.Rank;
    pub const Suit = Deck.Card.Suit;
    const STRAIGHT_TEN_TO_ACE = [_]Rank{ Rank.ten, Rank.jack, Rank.queen, Rank.king, Rank.ace };

    pub fn from_hand(hand: *const [5]Card) DeucesWild {
        // NOTE: assume sorted by rank

        var rank_count = std.mem.zeroes([@typeInfo(Rank).@"enum".fields.len]u8);
        var rank_min_nonwild = @intFromEnum(Rank.ace);
        var rank_max_nonwild = @intFromEnum(Rank.three);
        var suit_count = std.mem.zeroes([@typeInfo(Suit).@"enum".fields.len]u8);
        var suit_count_nonwild = std.mem.zeroes([@typeInfo(Suit).@"enum".fields.len]u8);

        for (hand) |card| {
            const rank = @intFromEnum(card.rank);
            const suit = @intFromEnum(card.suit);
            rank_count[rank] += 1;
            suit_count[suit] += 1;
            if (card.rank != Rank.two) {
                rank_min_nonwild = @min(rank_min_nonwild, @intFromEnum(card.rank));
                rank_max_nonwild = @max(rank_max_nonwild, @intFromEnum(card.rank));
                suit_count_nonwild[suit] += 1;
            }
        }

        const suit_count_max = std.mem.max(u8, &suit_count);

        // royal_flush
        if (suit_count_max == 5) {
            var is_royal_flush = true;
            for (hand, STRAIGHT_TEN_TO_ACE) |card, card_straight| {
                if (card.rank != card_straight) {
                    is_royal_flush = false;
                }
            }
            if (is_royal_flush) {
                return .royal_flush;
            }
        }

        const wild_count = rank_count[@intFromEnum(Rank.two)];

        // four_deuces
        if (wild_count == 4) {
            return .four_deuces;
        }

        const rank_count_max_nonwild = std.mem.max(u8, rank_count[1..]);
        const suit_count_max_nonwild = std.mem.max(u8, &suit_count_nonwild);
        const is_flush = suit_count_max_nonwild == 5 - wild_count;
        const is_straight = blk: {
            // if there's a non-wild pair, then it can't be a straight
            if (rank_count_max_nonwild > 1) break :blk false;

            if (rank_max_nonwild - rank_min_nonwild <= 4) break :blk true;
            // if there's an ace, check that all other cards <= 5
            if (rank_max_nonwild == @intFromEnum(Rank.ace)) {
                for (hand[0..4]) |card| {
                    if (@intFromEnum(card.rank) > @intFromEnum(Rank.five)) break :blk false;
                }
                break :blk true;
            }
            break :blk false;
        };

        // wild_royal_flush
        if (is_flush and is_straight and rank_min_nonwild >= @intFromEnum(Rank.ten)) {
            return .wild_royal_flush;
        }

        // five_of_a_kind
        if (wild_count + rank_count_max_nonwild == 5) {
            return .five_of_a_kind;
        }

        // straight_flush
        if (is_flush and is_straight) {
            return .straight_flush;
        }

        // four_of_a_kind
        if (rank_count_max_nonwild + wild_count == 4) {
            return .four_of_a_kind;
        }

        // full_house
        var pairs: u8 = 0;
        for (rank_count[1..]) |count| {
            if (count == 2) pairs += 1;
        }
        if ((rank_count_max_nonwild == 3 and pairs == 1) or (pairs == 2 and wild_count == 1)) {
            return .full_house;
        }

        // flush
        if (is_flush) {
            return .flush;
        }

        // straight
        if (is_straight) {
            return .straight;
        }

        // three_of_a_kind
        if (rank_count_max_nonwild + wild_count == 3) {
            return .three_of_a_kind;
        }

        return .none;
    }
};

pub const DeucesWildFullPay = [_]u64{0, 1, 2, 2, 3, 5, 9, 15, 25, 200, 800};

test "DeucesWild royal_flush" {
    try std.testing.expectEqual(
        DeucesWild.royal_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
            .{ .rank = .ace, .suit = .heart },
        }),
    );
}

test "DeucesWild four_deuces" {
    try std.testing.expectEqual(
        DeucesWild.four_deuces,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .two, .suit = .diamond },
            .{ .rank = .two, .suit = .club },
            .{ .rank = .two, .suit = .spade },
            .{ .rank = .ace, .suit = .heart },
        }),
    );
}

test "DeucesWild wild_royal_flush" {
    try std.testing.expectEqual(
        DeucesWild.wild_royal_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .diamond },
            .{ .rank = .jack, .suit = .diamond },
            .{ .rank = .queen, .suit = .diamond },
            .{ .rank = .king, .suit = .diamond },
            .{ .rank = .ace, .suit = .diamond },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.wild_royal_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .ten, .suit = .club },
            .{ .rank = .jack, .suit = .club },
            .{ .rank = .two, .suit = .club },
            .{ .rank = .king, .suit = .club },
            .{ .rank = .ace, .suit = .club },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.wild_royal_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .ten, .suit = .spade },
            .{ .rank = .jack, .suit = .spade },
            .{ .rank = .queen, .suit = .spade },
            .{ .rank = .king, .suit = .spade },
            .{ .rank = .two, .suit = .club },
        }),
    );
}

test "DeucesWild five_of_a_kind" {
    try std.testing.expectEqual(
        DeucesWild.five_of_a_kind,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .two, .suit = .diamond },
            .{ .rank = .two, .suit = .club },
            .{ .rank = .eight, .suit = .heart },
            .{ .rank = .eight, .suit = .spade },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.five_of_a_kind,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .two, .suit = .diamond },
            .{ .rank = .three, .suit = .club },
            .{ .rank = .three, .suit = .heart },
            .{ .rank = .three, .suit = .spade },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.five_of_a_kind,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .ace, .suit = .diamond },
            .{ .rank = .ace, .suit = .club },
            .{ .rank = .ace, .suit = .heart },
            .{ .rank = .ace, .suit = .spade },
        }),
    );
}

test "DeucesWild straight_flush" {
    try std.testing.expectEqual(
        DeucesWild.straight_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .three, .suit = .diamond },
            .{ .rank = .four, .suit = .diamond },
            .{ .rank = .five, .suit = .diamond },
            .{ .rank = .six, .suit = .diamond },
            .{ .rank = .seven, .suit = .diamond },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.straight_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .three, .suit = .club },
            .{ .rank = .four, .suit = .club },
            .{ .rank = .five, .suit = .club },
            .{ .rank = .ace, .suit = .club },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.straight_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .nine, .suit = .club },
            .{ .rank = .jack, .suit = .club },
            .{ .rank = .queen, .suit = .club },
            .{ .rank = .king, .suit = .club },
        }),
    );
}

test "DeucesWild four_of_a_kind" {
    try std.testing.expectEqual(
        DeucesWild.four_of_a_kind,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .two, .suit = .diamond },
            .{ .rank = .two, .suit = .club },
            .{ .rank = .eight, .suit = .spade },
            .{ .rank = .ace, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.four_of_a_kind,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .two, .suit = .diamond },
            .{ .rank = .eight, .suit = .heart },
            .{ .rank = .ace, .suit = .spade },
            .{ .rank = .ace, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.four_of_a_kind,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .three, .suit = .diamond },
            .{ .rank = .three, .suit = .heart },
            .{ .rank = .three, .suit = .spade },
            .{ .rank = .jack, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.four_of_a_kind,
        DeucesWild.from_hand(&.{
            .{ .rank = .four, .suit = .heart },
            .{ .rank = .ace, .suit = .heart },
            .{ .rank = .ace, .suit = .diamond },
            .{ .rank = .ace, .suit = .spade },
            .{ .rank = .ace, .suit = .club },
        }),
    );
}

test "DeucesWild full_house" {
    try std.testing.expectEqual(
        DeucesWild.full_house,
        DeucesWild.from_hand(&.{
            .{ .rank = .five, .suit = .heart },
            .{ .rank = .five, .suit = .diamond },
            .{ .rank = .five, .suit = .club },
            .{ .rank = .seven, .suit = .spade },
            .{ .rank = .seven, .suit = .club },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.full_house,
        DeucesWild.from_hand(&.{
            .{ .rank = .nine, .suit = .heart },
            .{ .rank = .nine, .suit = .diamond },
            .{ .rank = .jack, .suit = .club },
            .{ .rank = .jack, .suit = .spade },
            .{ .rank = .jack, .suit = .club },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.full_house,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .six, .suit = .diamond },
            .{ .rank = .six, .suit = .club },
            .{ .rank = .king, .suit = .spade },
            .{ .rank = .king, .suit = .club },
        }),
    );
}

test "DeucesWild flush" {
    try std.testing.expectEqual(
        DeucesWild.flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .four, .suit = .spade },
            .{ .rank = .five, .suit = .spade },
            .{ .rank = .nine, .suit = .spade },
            .{ .rank = .king, .suit = .spade },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .three, .suit = .club },
            .{ .rank = .six, .suit = .club },
            .{ .rank = .jack, .suit = .club },
            .{ .rank = .queen, .suit = .club },
            .{ .rank = .king, .suit = .club },
        }),
    );
}

test "DeucesWild straight" {
    try std.testing.expectEqual(
        DeucesWild.straight,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .two, .suit = .diamond },
            .{ .rank = .nine, .suit = .club },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .club },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.straight,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .three, .suit = .diamond },
            .{ .rank = .four, .suit = .club },
            .{ .rank = .five, .suit = .heart },
            .{ .rank = .ace, .suit = .club },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.straight,
        DeucesWild.from_hand(&.{
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .spade },
            .{ .rank = .king, .suit = .heart },
            .{ .rank = .ace, .suit = .heart },
        }),
    );
}

test "DeucesWild three_of_a_kind" {
    try std.testing.expectEqual(
        DeucesWild.three_of_a_kind,
        DeucesWild.from_hand(&.{
            .{ .rank = .five, .suit = .heart },
            .{ .rank = .five, .suit = .diamond },
            .{ .rank = .five, .suit = .club },
            .{ .rank = .seven, .suit = .spade },
            .{ .rank = .eight, .suit = .club },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.three_of_a_kind,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .four, .suit = .diamond },
            .{ .rank = .five, .suit = .club },
            .{ .rank = .eight, .suit = .spade },
            .{ .rank = .eight, .suit = .club },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.three_of_a_kind,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .two, .suit = .diamond },
            .{ .rank = .five, .suit = .club },
            .{ .rank = .eight, .suit = .spade },
            .{ .rank = .king, .suit = .club },
        }),
    );
}

test "DeucesWild none" {
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .three, .suit = .diamond },
            .{ .rank = .five, .suit = .club },
            .{ .rank = .eight, .suit = .spade },
            .{ .rank = .king, .suit = .club },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .three, .suit = .diamond },
            .{ .rank = .four, .suit = .heart },
            .{ .rank = .five, .suit = .club },
            .{ .rank = .eight, .suit = .spade },
            .{ .rank = .king, .suit = .club },
        }),
    );
}

test "DeucesWild 4 to royal" {
    try std.testing.expectEqual(
        DeucesWild.wild_royal_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .heart },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.wild_royal_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .diamond },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.wild_royal_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .club },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.wild_royal_flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .two, .suit = .spade },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .three, .suit = .heart },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .three, .suit = .diamond },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .three, .suit = .club },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .three, .suit = .spade },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .four, .suit = .heart },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .four, .suit = .diamond },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .four, .suit = .club },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .four, .suit = .spade },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .five, .suit = .heart },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .five, .suit = .diamond },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .five, .suit = .club },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .five, .suit = .spade },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .six, .suit = .heart },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .six, .suit = .diamond },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .six, .suit = .club },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .six, .suit = .spade },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.flush,
        DeucesWild.from_hand(&.{
            .{ .rank = .seven, .suit = .heart },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .seven, .suit = .diamond },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .seven, .suit = .club },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .seven, .suit = .spade },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.from_hand(&.{
            .{ .rank = .eight, .suit = .heart },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
        DeucesWild.flush,
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .eight, .suit = .diamond },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .eight, .suit = .club },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
    try std.testing.expectEqual(
        DeucesWild.none,
        DeucesWild.from_hand(&.{
            .{ .rank = .eight, .suit = .spade },
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
        }),
    );
}

test "DeucesWild 3 deuces to straight flush" {
    const Card = deck.StandardDeck.Card;
    const Rank = deck.StandardDeck.Card.Rank;
    // var count: usize = 0;
    // var sf: usize = 0;
    for (@intFromEnum(Rank.two)..@intFromEnum(Rank.ace)+1) |r1| {
        const s1_start: usize = if (r1 == @intFromEnum(Rank.two)) 3 else 0;
        for (s1_start..4) |s1| {
            for (r1..@intFromEnum(Rank.ace)+1) |r2| {
                const s2_start: usize = if (r1 == r2) s1+1 else 0;
                for (s2_start..4) |s2| {
                    const expected =
                        if (r1 == @intFromEnum(Rank.two)) DeucesWild.four_deuces
                        else if (r1 >= @intFromEnum(Rank.ten) and r1 != r2 and s1 == s2) DeucesWild.wild_royal_flush
                        else if (r1 == r2) DeucesWild.five_of_a_kind
                        else if (r2 - r1 <= 4 and s1 == s2) DeucesWild.straight_flush
                        else if (r2 == @intFromEnum(Rank.ace) and r1 <= @intFromEnum(Rank.five) and s1 == s2) DeucesWild.straight_flush
                        else DeucesWild.four_of_a_kind
                    ;
                    const card1 = Card{ .rank = @enumFromInt(r1), .suit = @enumFromInt(s1) };
                    const card2 = Card{ .rank = @enumFromInt(r2), .suit = @enumFromInt(s2) };
                    // const is_three_spade = 
                    //     (card1.rank == .three and card1.suit == .spade)
                    //     or (card2.rank == .three and card2.suit == .spade)
                    // ;
                    // const is_nine_heart =
                    //     (card1.rank == .nine and card1.suit == .heart)
                    //     or (card2.rank == .nine and card2.suit == .heart)
                    // ;
                    // if (!is_three_spade and !is_nine_heart) {
                    //     count += 1;
                    //     if (expected == DeucesWild.straight_flush) {
                    //         sf += 1;
                    //     }
                    // }
                    try std.testing.expectEqual(
                        expected,
                        DeucesWild.from_hand(&.{
                            .{ .rank = .two, .suit = .heart },
                            .{ .rank = .two, .suit = .diamond },
                            .{ .rank = .two, .suit = .club },
                            card1,
                            card2,
                        }),
                    );
                }
            }
        }
    }
    // std.debug.print("COUNT {} SF {}\n", .{count, sf});
}
