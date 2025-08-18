const std = @import("std");

const deck = @import("../decks/standard.zig");

const assert = std.debug.assert;

pub const JacksOrBetter = enum(u8) {
    none,
    jacks_or_better,
    two_pair,
    three_of_a_kind,
    straight,
    flush,
    full_house,
    four_of_a_kind,
    straight_flush,
    royal_flush,

    pub const Deck = deck.StandardDeck;
    pub const Card = Deck.Card;
    pub const Rank = Deck.Card.Rank;
    pub const Suit = Deck.Card.Suit;

    pub fn from_hand(hand: *const [5]Card) JacksOrBetter {
        // NOTE: assume sorted by rank

        const is_flush: bool =
            hand[0].suit == hand[1].suit
            and hand[0].suit == hand[2].suit
            and hand[0].suit == hand[3].suit
            and hand[0].suit == hand[4].suit;
        const is_straight: bool = blk: {
            if (
                hand[0].rank == hand[1].rank
                or hand[1].rank == hand[2].rank
                or hand[2].rank == hand[3].rank
                or hand[3].rank == hand[4].rank
            ) break :blk false;
            if (@intFromEnum(hand[4].rank) - @intFromEnum(hand[0].rank) == 4) break :blk true;
            if (hand[3].rank == Rank.five and hand[4].rank == Rank.ace) break :blk true;
            break :blk false;
        };

        if (is_straight and is_flush) {
            if (hand[0].rank == Rank.ten and hand[4].rank == Rank.ace) return .royal_flush;
            return .straight_flush;
        }
        if (is_flush) return .flush;
        if (is_straight) return .straight;
        if (hand[0].rank == hand[3].rank) return .four_of_a_kind;
        if (hand[1].rank == hand[4].rank) return .four_of_a_kind;
        if (hand[0].rank == hand[2].rank and hand[3].rank == hand[4].rank) return .full_house;
        if (hand[0].rank == hand[1].rank and hand[2].rank == hand[4].rank) return .full_house;
        if (hand[0].rank == hand[2].rank) return .three_of_a_kind;
        if (hand[1].rank == hand[3].rank) return .three_of_a_kind;
        if (hand[2].rank == hand[4].rank) return .three_of_a_kind;
        if (hand[0].rank == hand[1].rank and hand[2].rank == hand[3].rank) return .two_pair;
        if (hand[0].rank == hand[1].rank and hand[3].rank == hand[4].rank) return .two_pair;
        if (hand[1].rank == hand[2].rank and hand[3].rank == hand[4].rank) return .two_pair;
        if (hand[0].rank == hand[1].rank and @intFromEnum(hand[0].rank) >= @intFromEnum(Rank.jack)) return .jacks_or_better;
        if (hand[1].rank == hand[2].rank and @intFromEnum(hand[1].rank) >= @intFromEnum(Rank.jack)) return .jacks_or_better;
        if (hand[2].rank == hand[3].rank and @intFromEnum(hand[2].rank) >= @intFromEnum(Rank.jack)) return .jacks_or_better;
        if (hand[3].rank == hand[4].rank and @intFromEnum(hand[3].rank) >= @intFromEnum(Rank.jack)) return .jacks_or_better;
        return .none;
    }
};

test "JacksOrBetter royal_flush" {
    try std.testing.expectEqual(
        JacksOrBetter.royal_flush,
        JacksOrBetter.from_hand(&.{
            .{ .rank = .ten, .suit = .heart },
            .{ .rank = .jack, .suit = .heart },
            .{ .rank = .queen, .suit = .heart },
            .{ .rank = .king, .suit = .heart },
            .{ .rank = .ace, .suit = .heart },
        }),
    );
}
