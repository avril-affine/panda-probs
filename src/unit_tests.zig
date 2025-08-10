comptime {
    _ = @import("combinations.zig");
    _ = @import("strategies.zig");
    _ = @import("decks/standard.zig");
    _ = @import("poker_types/deuces_wild.zig");
    _ = @import("strategies/optimal.zig");
    _ = @import("strategies/optimal_vectorized.zig");
}
