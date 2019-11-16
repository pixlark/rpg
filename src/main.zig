const std = @import("std");
const engine = @import("engine.zig");
const global = @import("global.zig");
const overworld = @import("overworld.zig");

fn gameMain() !void {
    try engine.init();
    var context = try engine.createContext(
        c"RPG", engine.Vec(i32).new(800, 600)
    );

    try overworld.run(&context);
}

pub fn main() void {
    gameMain() catch |err| {
        switch (err) {
            error.UserQuit => {},
            else => {
                std.debug.warn("The game ran into an unexpected error, and is closing.\n");
                std.debug.warn("---> {}\n", err);
            },
        }
    };
}
