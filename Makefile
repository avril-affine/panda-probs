.PHONY: run run-safe run-fast test test-filter

run:
	zig build run

run-safe:
	zig build run -Doptimize=ReleaseSafe

run-fast:
	zig build run -Doptimize=ReleaseFast

test:
	zig build test

test-filter:
	zig test --test-filter "$(ARG)" src/unit_tests.zig
