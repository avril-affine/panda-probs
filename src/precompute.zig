const std = @import("std");

const WeightedRankStandardHand = @import("strategies.zig").WeightedRankStandardHand;
const StandardDeck = @import("decks/standard.zig").StandardDeck;

const suits_and_weight_four_of_a_kind = .{
    .{ 0, 1, 2, 3, 0, 4 },
};
const suits_and_weight_full_house = .{
    .{ 0, 1, 0, 1, 2, 12 },
    .{ 0, 3, 0, 1, 2, 12 },
};
const suits_and_weight_three_of_a_kind = .{
    .{ 0, 1, 2, 0, 1, 24 },
    .{ 0, 1, 2, 0, 3, 12 },
    .{ 0, 1, 2, 3, 0, 12 },
    .{ 0, 1, 2, 0, 0, 12 },
    .{ 0, 1, 2, 3, 3, 4 },
};
const suits_and_weight_two_pair = .{
    .{ 0, 1, 2, 3, 0, 12 },
    .{ 0, 1, 2, 3, 2, 12 },
    .{ 0, 1, 0, 2, 0, 24 },
    .{ 0, 1, 0, 2, 1, 24 },
    .{ 0, 1, 0, 2, 2, 24 },
    .{ 0, 1, 0, 2, 3, 24 },
    .{ 0, 1, 0, 1, 0, 12 },
    .{ 0, 1, 0, 1, 2, 12 },
};
const suits_and_weight_pair = .{
    .{ 0, 1, 0, 0, 0, 12 },
    .{ 0, 1, 0, 0, 1, 12 },
    .{ 0, 1, 0, 1, 0, 12 },
    .{ 0, 1, 1, 0, 0, 12 },
    .{ 0, 1, 0, 0, 2, 24 },
    .{ 0, 1, 0, 2, 0, 24 },
    .{ 0, 1, 2, 0, 0, 24 },
    .{ 0, 1, 0, 2, 2, 24 },
    .{ 0, 1, 2, 0, 2, 24 },
    .{ 0, 1, 2, 2, 0, 24 },
    .{ 0, 1, 2, 2, 2, 12 },
    .{ 0, 1, 0, 1, 2, 24 },
    .{ 0, 1, 0, 2, 1, 24 },
    .{ 0, 1, 2, 0, 1, 24 },
    .{ 0, 1, 2, 3, 3, 12 },
    .{ 0, 1, 3, 2, 3, 12 },
    .{ 0, 1, 3, 3, 2, 12 },
    .{ 0, 1, 0, 2, 3, 24 },
    .{ 0, 1, 2, 0, 3, 24 },
    .{ 0, 1, 2, 3, 0, 24 },
};
const suits_and_weight_five_singletons = .{
    .{ 0, 0, 0, 0, 0, 4 },
    .{ 1, 0, 0, 0, 0, 12 },
    .{ 0, 1, 0, 0, 0, 12 },
    .{ 0, 0, 1, 0, 0, 12 },
    .{ 0, 0, 0, 1, 0, 12 },
    .{ 0, 0, 0, 0, 1, 12 },
    .{ 1, 1, 0, 0, 0, 12 },
    .{ 1, 0, 1, 0, 0, 12 },
    .{ 1, 0, 0, 1, 0, 12 },
    .{ 1, 0, 0, 0, 1, 12 },
    .{ 0, 1, 1, 0, 0, 12 },
    .{ 0, 1, 0, 1, 0, 12 },
    .{ 0, 1, 0, 0, 1, 12 },
    .{ 0, 0, 1, 1, 0, 12 },
    .{ 0, 0, 1, 0, 1, 12 },
    .{ 0, 0, 0, 1, 1, 12 },
    .{ 1, 2, 0, 0, 0, 24 },
    .{ 1, 0, 2, 0, 0, 24 },
    .{ 1, 0, 0, 2, 0, 24 },
    .{ 1, 0, 0, 0, 2, 24 },
    .{ 0, 1, 2, 0, 0, 24 },
    .{ 0, 1, 0, 2, 0, 24 },
    .{ 0, 1, 0, 0, 2, 24 },
    .{ 0, 0, 1, 2, 0, 24 },
    .{ 0, 0, 1, 0, 2, 24 },
    .{ 0, 0, 0, 1, 2, 24 },
    .{ 0, 0, 1, 1, 2, 24 },
    .{ 0, 1, 0, 1, 2, 24 },
    .{ 0, 1, 1, 0, 2, 24 },
    .{ 0, 0, 1, 2, 1, 24 },
    .{ 0, 1, 0, 2, 1, 24 },
    .{ 0, 1, 1, 2, 0, 24 },
    .{ 0, 0, 2, 1, 1, 24 },
    .{ 0, 1, 2, 0, 1, 24 },
    .{ 0, 1, 2, 1, 0, 24 },
    .{ 0, 2, 0, 1, 1, 24 },
    .{ 0, 2, 1, 0, 1, 24 },
    .{ 0, 2, 1, 1, 0, 24 },
    .{ 2, 0, 0, 1, 1, 24 },
    .{ 2, 0, 1, 0, 1, 24 },
    .{ 2, 0, 1, 1, 0, 24 },
    .{ 3, 3, 0, 1, 2, 24 },
    .{ 3, 0, 3, 1, 2, 24 },
    .{ 3, 1, 2, 3, 0, 24 },
    .{ 3, 0, 1, 2, 3, 24 },
    .{ 0, 3, 3, 1, 2, 24 },
    .{ 0, 3, 1, 3, 2, 24 },
    .{ 0, 3, 1, 2, 3, 24 },
    .{ 1, 2, 3, 3, 0, 24 },
    .{ 1, 2, 3, 0, 3, 24 },
    .{ 0, 1, 2, 3, 3, 24 },
};

pub fn main() !void {
    var args_iter = try std.process.argsWithAllocator(std.heap.page_allocator);
    defer args_iter.deinit();
    _ = args_iter.next();
    const out_path = args_iter.next() orelse {
        std.debug.print("missing out path", .{});
        return error.MissingArg;
    };
    try std.fs.cwd().makePath(std.fs.path.dirname(out_path) orelse ".");

    var result: [134_459]WeightedRankStandardHand = undefined;
    const Card = StandardDeck.Card;
    const Rank = Card.Rank;

    var i: usize = 0;
    // four of a kind
    for (0..13) |r1_idx| {
        for (0..13) |r2_idx| {
            if (r1_idx == r2_idx) continue;
            const r1: Rank = @enumFromInt(r1_idx);
            const r2: Rank = @enumFromInt(r2_idx);

            inline for (suits_and_weight_four_of_a_kind) |suits_and_weight| {
                const s1, const s2, const s3, const s4, const s5, const weight = suits_and_weight;
                result[i] = .{
                    .weight = weight,
                    .card1 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s1) }),
                    .card2 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s2) }),
                    .card3 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s3) }),
                    .card4 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s4) }),
                    .card5 = Card.index(.{ .rank = r2, .suit = @enumFromInt(s5) }),
                };
                i += 1;
            }
        }
    }

    // full house
    for (0..13) |r1_idx| {
        for (0..13) |r2_idx| {
            if (r1_idx == r2_idx) continue;
            const r1: Rank = @enumFromInt(r1_idx);
            const r2: Rank = @enumFromInt(r2_idx);

            inline for (suits_and_weight_full_house) |suits_and_weight| {
                const s1, const s2, const s3, const s4, const s5, const weight = suits_and_weight;
                result[i] = .{
                    .weight = weight,
                    .card1 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s1) }),
                    .card2 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s2) }),
                    .card3 = Card.index(.{ .rank = r2, .suit = @enumFromInt(s3) }),
                    .card4 = Card.index(.{ .rank = r2, .suit = @enumFromInt(s4) }),
                    .card5 = Card.index(.{ .rank = r2, .suit = @enumFromInt(s5) }),
                };
                i += 1;
            }
        }
    }

    // three of a kind
    for (0..13) |r1_idx| {
        for (0..12) |r2_idx| {
            for (r2_idx+1..13) |r3_idx| {
                if (r1_idx == r2_idx or r1_idx == r3_idx) continue;
                const r1: Rank = @enumFromInt(r1_idx);
                const r2: Rank = @enumFromInt(r2_idx);
                const r3: Rank = @enumFromInt(r3_idx);

                inline for (suits_and_weight_three_of_a_kind) |suits_and_weight| {
                    const s1, const s2, const s3, const s4, const s5, const weight = suits_and_weight;
                    result[i] = .{
                        .weight = weight,
                        .card1 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s1) }),
                        .card2 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s2) }),
                        .card3 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s3) }),
                        .card4 = Card.index(.{ .rank = r2, .suit = @enumFromInt(s4) }),
                        .card5 = Card.index(.{ .rank = r3, .suit = @enumFromInt(s5) }),
                    };
                    i += 1;
                }
            }
        }
    }

    // two pair
    for (0..12) |r1_idx| {
        for (r1_idx+1..13) |r2_idx| {
            for (0..13) |r3_idx| {
                if (r3_idx == r1_idx or r3_idx == r2_idx) continue;
                const r1: Rank = @enumFromInt(r1_idx);
                const r2: Rank = @enumFromInt(r2_idx);
                const r3: Rank = @enumFromInt(r3_idx);

                inline for (suits_and_weight_two_pair) |suits_and_weight| {
                    const s1, const s2, const s3, const s4, const s5, const weight = suits_and_weight;
                    result[i] = .{
                        .weight = weight,
                        .card1 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s1) }),
                        .card2 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s2) }),
                        .card3 = Card.index(.{ .rank = r2, .suit = @enumFromInt(s3) }),
                        .card4 = Card.index(.{ .rank = r2, .suit = @enumFromInt(s4) }),
                        .card5 = Card.index(.{ .rank = r3, .suit = @enumFromInt(s5) }),
                    };
                    i += 1;
                }
            }
        }
    }

    // pair
    for (0..13) |r1_idx| {
        for (0..11) |r2_idx| {
            for (r2_idx+1..12) |r3_idx| {
                for (r3_idx+1..13) |r4_idx| {
                    if (r1_idx == r2_idx or r1_idx == r3_idx or r1_idx == r4_idx) continue;
                    const r1: Rank = @enumFromInt(r1_idx);
                    const r2: Rank = @enumFromInt(r2_idx);
                    const r3: Rank = @enumFromInt(r3_idx);
                    const r4: Rank = @enumFromInt(r4_idx);

                    inline for (suits_and_weight_pair) |suits_and_weight| {
                        const s1, const s2, const s3, const s4, const s5, const weight = suits_and_weight;
                        result[i] = .{
                            .weight = weight,
                            .card1 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s1) }),
                            .card2 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s2) }),
                            .card3 = Card.index(.{ .rank = r2, .suit = @enumFromInt(s3) }),
                            .card4 = Card.index(.{ .rank = r3, .suit = @enumFromInt(s4) }),
                            .card5 = Card.index(.{ .rank = r4, .suit = @enumFromInt(s5) }),
                        };
                        i += 1;
                    }
                }
            }
        }
    }

    // five singletons
    for (0..9) |r1_idx| {
        for (r1_idx+1..10) |r2_idx| {
            for (r2_idx+1..11) |r3_idx| {
                for (r3_idx+1..12) |r4_idx| {
                    for (r4_idx+1..13) |r5_idx| {
                        const r1: Rank = @enumFromInt(r1_idx);
                        const r2: Rank = @enumFromInt(r2_idx);
                        const r3: Rank = @enumFromInt(r3_idx);
                        const r4: Rank = @enumFromInt(r4_idx);
                        const r5: Rank = @enumFromInt(r5_idx);

                        inline for (suits_and_weight_five_singletons) |suits_and_weight| {
                            const s1, const s2, const s3, const s4, const s5, const weight = suits_and_weight;
                            result[i] = .{
                                .weight = weight,
                                .card1 = Card.index(.{ .rank = r1, .suit = @enumFromInt(s1) }),
                                .card2 = Card.index(.{ .rank = r2, .suit = @enumFromInt(s2) }),
                                .card3 = Card.index(.{ .rank = r3, .suit = @enumFromInt(s3) }),
                                .card4 = Card.index(.{ .rank = r4, .suit = @enumFromInt(s4) }),
                                .card5 = Card.index(.{ .rank = r5, .suit = @enumFromInt(s5) }),
                            };
                            i += 1;
                        }
                    }
                }
            }
        }
    }

    std.debug.assert(i == 134_459);
    const file = try std.fs.cwd().createFile(out_path, .{});
    defer file.close();
    try file.writeAll(std.mem.asBytes(&result));
}
