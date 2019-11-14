const std = @import("std");
const engine = @import("engine.zig");
const ui = @import("ui.zig");
const pause = @import("pause.zig");

const field_bounds = engine.Rect(i32).new(50, 50, 500, 500);

fn fieldToScreen(vec: engine.Vec(f32)) engine.Vec(i32) {
    return engine.Vec(i32).new(
        field_bounds.getX() + @floatToInt(i32, vec.x * @intToFloat(f32, field_bounds.getW())),
        field_bounds.getY() + @floatToInt(i32, vec.y * @intToFloat(f32, field_bounds.getH())),
    );
}

fn clamp(comptime T: type, x: T, lo: T, hi: T) T {
    return if (x <= lo) lo else (if (x >= hi) hi else x);
}

const Player = struct {
    pos: engine.Vec(f32),
    radius: i32 = 10,
};

pub const Enemy = enum {
    Rat,
};

pub fn run(context: *engine.Context, enemy: Enemy) !void {
    // Fade-in
    var fading_in = true;
    const fade_in_time = 0.4;
    var fade_in_timer: f32 = fade_in_time;
    //

    var player = Player{ .pos = engine.Vec(f32).new(0.5, 0.5) };

    gameloop: while (true) {
        context.frameUpdate();
        while (engine.pollEvent()) |event| {
            switch (event) {
                engine.Event.QuitEvent => return error.UserQuit,
                else => {},
            }
        }

        //
        // Update
        //

        // Pausing
        if (context.keyPressed(.SDL_SCANCODE_ESCAPE)) {
            try pause.run(context);
        }
        
        // Obtain mouse motion
        var absolute_mouse_pos = context.mousePos();
        var mouse_motion = engine.Vec(i32).new(
            absolute_mouse_pos.x - @divTrunc(context.size.x, 2),
            absolute_mouse_pos.y - @divTrunc(context.size.y, 2),
        );

        // Move player
        player.pos.x += @intToFloat(f32, mouse_motion.x) / @intToFloat(f32, context.size.x);
        player.pos.y += @intToFloat(f32, mouse_motion.y) / @intToFloat(f32, context.size.y);

        // Clamp player to bounds of field
        player.pos.x = clamp(f32, player.pos.x, 0.0, 1.0);
        player.pos.y = clamp(f32, player.pos.y, 0.0, 1.0);

        // Move mouse back to center
        context.setMousePos(engine.Vec(i32).new(
            @divTrunc(context.size.x, 2),
            @divTrunc(context.size.y, 2),
        ));
        
        // Fade-in
        if (fading_in) {
            fade_in_timer -= 1.0 * context.delta_time;
            if (fade_in_timer <= 0.0) {
                fade_in_timer = 0.0;
                fading_in = false;
            }
        }

        //
        // Render
        //
        
        try context.clear(engine.Color.new(0, 0, 0, 0xff));

        // Playing field @DevArt
        try context.drawRect(field_bounds, engine.Color.White);
        try context.drawRect(field_bounds.offset_about_center(5), engine.Color.White);

        // Player @DevArt
        try context.fillRect(
            engine.Rect(i32).fromCenter(
                fieldToScreen(player.pos), engine.Vec(i32).new(
                    @divTrunc(player.radius, 2), @divTrunc(player.radius, 2),
                ),
            ),
            engine.Color.White,
        );
        
        // Fade-in
        if (fading_in) {
            var ratio = fade_in_timer / fade_in_time;
            try context.clearAlpha(
                engine.Color.new(0, 0, 0, @floatToInt(u8, ratio * 0xff)),
            );
        }
        
        context.flip();
    }
}
