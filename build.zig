const builtin = @import("builtin");
const Builder = @import("std").build.Builder;

const Mode = enum { Debug, Release };
const mode = Mode.Debug;

pub fn build(builder: *Builder) void {
    // Make all our executables ReleaseSafe
    builder.setPreferredReleaseMode(builtin.Mode.ReleaseSafe);

    // Create a new executable for our game
    const exe = builder.addExecutable("rpg", "src/main.zig");
    switch (mode) {
        Mode.Debug => exe.setBuildMode(builtin.Mode.Debug),
        Mode.Release => exe.setBuildMode(builder.standardReleaseOptions()),
    }

    // Link required C libraries
    exe.linkSystemLibrary("c");
    exe.linkSystemLibrary("SDL2");
    exe.linkSystemLibrary("SDL2_image");

    // The game executable gets *installed* (to zig-cache/bin) on `zig build`
    builder.installArtifact(exe);

    // Create the `play` and `run` subcommands (aliases of one another)
    const run = exe.run();
    run.step.dependOn(&exe.step);
    builder.step("play", "Play the RPG").dependOn(&run.step);
    builder.step("run", "Play the RPG").dependOn(&run.step);
}
