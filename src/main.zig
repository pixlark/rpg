const std = @import("std");
const engine = @import("engine.zig");
const global = @import("global.zig");
const overworld = @import("overworld.zig");

fn gameMain() !void {
    try engine.init();
    var context = try engine.createContext(
        c"RPG", engine.vec(i32, global.screen_width, global.screen_height)
    );

    try overworld.run(&context);
}

pub fn main() void {
    gameMain() catch |err| {
        std.debug.warn("The game ran into an unexpected error, and is closing.\n");
        std.debug.warn("---> {}\n", err);
    };
}
