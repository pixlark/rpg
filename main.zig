const std = @import("std");
const engine = @import("engine.zig");
usingnamespace @import("scene.zig");
const alloc = std.heap.c_allocator;

fn testRender(context: *engine.Context) !SceneResult {
    try context.clear(engine.Color.new(0, 0, 0xff, 0xff));
    context.flip();
    return SceneResult{ .Normal = {} };
}

pub fn gameMain() !void {
    try engine.init();
    var context = try engine.createContext(c"RPG", engine.vec(i32, 800, 600));

    var scenes = std.ArrayList(Scene){ .items = [0]Scene{}, .len = 0, .allocator = alloc };

    {
        var starting_scene = Scene{ .render = testRender };
        _ = try starting_scene.wakeup();
        try scenes.append(starting_scene);
    }
    
    gameloop: while (scenes.count() > 0) {
        var this_scene = scenes.toSlice()[0];
        
        while (engine.pollEvent()) |event| {
            switch (event) {
                engine.Event.QuitEvent => break :gameloop,
                else => {
                    _ = try this_scene.event(event);
                },
            }
        }
        _ = try this_scene.update(0.0);
        _ = try this_scene.render(&context);
    }
}

pub fn main() void {
    gameMain() catch |err| {
        std.debug.warn("The game ran into an unexpected error, and is closing.\n");
        std.debug.warn("---> {}\n", err);
    };
}
