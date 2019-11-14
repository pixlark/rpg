const std = @import("std");
const sdl = @import("sdl.zig");
const engine = @import("engine.zig");
const ui = @import("ui.zig");
const global = @import("global.zig");

pub fn run(context: *engine.Context) !void {
    if (false) { // TODO(pixlark): Get this actually working at some point
        var background = blk: {
            const fmt = sdl.SDL_PIXELFORMAT_RGBA8888;

            var buffer = try std.heap.c_allocator.alloc(
                u8, @intCast(usize, 4 * context.size.x * context.size.y),
            );
            defer std.heap.c_allocator.free(buffer);
            
            var err = sdl.SDL_RenderReadPixels(
                context.renderer, null, fmt, buffer.ptr, 4 * context.size.x,
            );
            if (err != 0) {
                return error.SDLRenderReadPixelsError;
            }
            
            var surf = sdl.SDL_CreateRGBSurfaceWithFormatFrom(
                buffer.ptr, context.size.x, context.size.y, 32, 4 * context.size.x, fmt,
            ) orelse return error.SDLCreateRGBSurfaceWithFormatFromError;
            defer sdl.SDL_FreeSurface(surf);

            var texture = sdl.SDL_CreateTextureFromSurface(
                context.renderer, surf,
            ) orelse return error.SDLCreateTextureFromSurfaceError;
            
            break :blk engine.Sprite{
                .texture = texture,
                .size = engine.Vec(i32).new(
                    surf.*.w, surf.*.h,
                ),
            };
        };
    }

    var cursor_up = try context.loadSprite(c"res/cursor.png");
    defer cursor_up.destroy();
    var cursor_down = try context.loadSprite(c"res/cursor_down.png");
    defer cursor_down.destroy();
    
    gameloop: while (true) {
        context.frameUpdate();
        while (engine.pollEvent()) |event| {
            switch (event) {
                engine.Event.QuitEvent => return error.UserQuit,
                else => {},
            }
        }

        if (context.keyPressed(.SDL_SCANCODE_ESCAPE)) {
            break :gameloop;
        }
        
        try context.clear(engine.Color.new(0, 0, 0xe, 0xff));
        
        //try context.drawSprite(background, engine.Vec(i32).new(0, 0));
        //try context.clearAlpha(engine.Color.new(0, 0, 0, 0x90));

        try engine.drawCursor(context, cursor_up, cursor_down);
        
        context.flip();
    }
}
