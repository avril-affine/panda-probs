const std = @import("std");

const combinations = @import("combinations.zig");
const StandardDeck = @import("decks/standard.zig").StandardDeck;

const assert = std.debug.assert;
const CombinationIterator = combinations.CombinationIterator;

pub const ComputeType = enum {
    all_hands,
    weighted_rank,
    weighted_rank_threaded,
};

pub fn compute(
    kind: ComputeType,
    strategy: anytype,
) [@TypeOf(strategy).RankFrequency.len]u64 {
    return switch (kind) {
        .all_hands              => compute_all_hands(strategy),
        .weighted_rank          => compute_weighted_rank(strategy),
        .weighted_rank_threaded => compute_weighted_rank_threaded(strategy),
    };
}

/// computes total frequency by iterating over all hands
fn compute_all_hands(
    /// an instance from the strategies/ dir
    strategy: anytype,
) [@TypeOf(strategy).RankFrequency.len]u64 {
    const StrategyType = @TypeOf(strategy);
    const RankFrequency = StrategyType.RankFrequency;

    var indices: [StrategyType.Deck.len]u6 = undefined;
    for (0..StrategyType.Deck.len) |i| { indices[i] = @intCast(i); }

    var i: usize = 0;
    var accumulator = RankFrequency.init();
    var hand_indices_iter = CombinationIterator(u6, 5).init(&indices);
    while (hand_indices_iter.next()) |hand_indices| {
        const frequency = strategy.draw_frequency(hand_indices);
        accumulator.add(&frequency);
        if (i % 10_000 == 0) std.debug.print("\rComputing frequencies: {}", .{i});
        i += 1;
    }
    return accumulator.data;
}

pub const WeightedRankStandardHand = packed struct {
    weight: u64,
    card1: u6,
    card2: u6,
    card3: u6,
    card4: u6,
    card5: u6,
};

const WEIGHTED_RANK_LEN = 134_459;
const weighted_rank_standard_hands_bytes = @embedFile("precompute");
const weighted_rank_standard_hands: *[WEIGHTED_RANK_LEN]WeightedRankStandardHand = @constCast(@ptrCast(@alignCast(weighted_rank_standard_hands_bytes)));

/// computes total frequency by iterating over classes of hands, ignoring suits
fn compute_weighted_rank(
    /// an instance from the strategies/ dir
    strategy: anytype,
) [@TypeOf(strategy).RankFrequency.len]u64 {
    assert(@TypeOf(strategy).Deck == StandardDeck);

    const RankFrequency = @TypeOf(strategy).RankFrequency;
    var accumulator = RankFrequency.init();

    for (weighted_rank_standard_hands) |weighted_rank_hand| {
        var frequency = strategy.draw_frequency(.{
            weighted_rank_hand.card1,
            weighted_rank_hand.card2,                               
            weighted_rank_hand.card3,
            weighted_rank_hand.card4,
            weighted_rank_hand.card5,
        });
        frequency.mul(weighted_rank_hand.weight);
        accumulator.add(&frequency);
    }

    return accumulator.data;
}

/// threaded version of compute_weighted_rank
fn compute_weighted_rank_threaded(
    /// an instance from the strategies/ dir
    strategy: anytype,
) [@TypeOf(strategy).RankFrequency.len]u64 {
    assert(@TypeOf(strategy).Deck == StandardDeck);

    const cpu_count = 16;
    const RankFrequency = @TypeOf(strategy).RankFrequency;

    const Worker = struct {
        strategy   : *const @TypeOf(strategy),
        accumulator: RankFrequency,
        indices    : []usize,
        thread     : usize,

        fn run(self: *@This()) void {
            for (self.indices) |i| {
                const weighted_rank_hand = weighted_rank_standard_hands[i];
                var frequency = self.strategy.draw_frequency(.{
                    weighted_rank_hand.card1,
                    weighted_rank_hand.card2,
                    weighted_rank_hand.card3,
                    weighted_rank_hand.card4,
                    weighted_rank_hand.card5,
                });
                frequency.mul(weighted_rank_hand.weight);
                self.accumulator.add(&frequency);
            }
        }
    };

    var threads: [cpu_count]std.Thread = undefined;
    var workers: [cpu_count]Worker = undefined;
    var all_indices: [WEIGHTED_RANK_LEN]usize = undefined;
    for (0..WEIGHTED_RANK_LEN) |i| { all_indices[i] = i; }
    for (0..cpu_count) |i| {
        const start_idx = WEIGHTED_RANK_LEN * i / cpu_count;
        const end_idx   = WEIGHTED_RANK_LEN * (i+1) / cpu_count;
        workers[i] = Worker{
            .strategy    = &strategy,
            .accumulator = RankFrequency.init(),
            .indices     = all_indices[start_idx..end_idx],
            .thread      = i,
        };
        threads[i] = std.Thread.spawn(.{}, Worker.run, .{&workers[i]})
            catch @panic("couldn't spawn thread");
    }

    var accumulator = RankFrequency.init();
    for (0..cpu_count) |i| {
        threads[i].join();
        accumulator.add(&workers[i].accumulator);
    }

    return accumulator.data;
}
