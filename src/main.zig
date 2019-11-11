const std = @import("std");
const engine = @import("engine.zig");
const alloc = std.heap.c_allocator;

fn runGame(context: *engine.Context) !void {
    var cursor = try context.loadSprite(c"res/cursor.png");
    var cursor_down = try context.loadSprite(c"res/cursor_down.png");
    
    gameloop: while (true) {
        context.updateInput();
        while (engine.pollEvent()) |event| {
            switch (event) {
                engine.Event.QuitEvent => break :gameloop,
                else => {},
            }
        }

        if (context.mousePressed(.Left)) {
            std.debug.warn("Clicked!\n");
        }
        
        try context.clear(engine.Color.new(0, 0, 0, 0xff));
        var mouse_pos = context.mousePos();
        try context.drawSprite(
            if (context.mouseDown(.Left))
                cursor_down else cursor,
            mouse_pos,
        );
        context.flip();
    }
}

fn gameMain() !void {
    try engine.init();
    var context = try engine.createContext(c"RPG", engine.vec(i32, 800, 600));

    try runGame(&context);
}

pub fn main() void {
    gameMain() catch |err| {
        std.debug.warn("The game ran into an unexpected error, and is closing.\n");
        std.debug.warn("---> {}\n", err);
    };
}
