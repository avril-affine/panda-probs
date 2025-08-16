const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // precompute
    const precompute_file = "zig-out/gen/weighted_rank_standard_hands.bin";
    const precompute_mod = b.createModule(.{
        .root_source_file = b.path("src/precompute.zig"),
        .target = target,
        .optimize = optimize,
    });
    const precompute_exe = b.addExecutable(.{
        .name = "precompute",
        .root_module = precompute_mod,
    });
    const precompute_run = b.addRunArtifact(precompute_exe);
    precompute_run.addArg(precompute_file);

    // main
    const main_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const main_exe = b.addExecutable(.{
        .name = "panda_probs",
        .root_module = main_mod,
    });
    main_mod.addAnonymousImport("precompute", .{.root_source_file = b.path(precompute_file)});
    main_exe.step.dependOn(&precompute_run.step);
    b.installArtifact(main_exe);

    // run
    const run_cmd = b.addRunArtifact(main_exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // test
    const unit_tests = b.addTest(.{
        .root_source_file = b.path("src/unit_tests.zig"),
        .target = target,
        .optimize = optimize,
    });
    const run_unit_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
