const std = @import("std");
const engine = @import("engine.zig");
const ui = @import("ui.zig");
const global = @import("global.zig");

const field_bounds = engine.Rect(i32).new(50, 50, 500, 500);

fn fieldToScreen(vec: engine.Vec(f32)) engine.Vec(i32) {
    return engine.Vec(i32).new(
        field_bounds.getX() + @floatToInt(i32, vec.x * @intToFloat(f32, field_bounds.getW())),
        field_bounds.getY() + @floatToInt(i32, vec.y * @intToFloat(f32, field_bounds.getH())),
    );
}

const Player = struct {
    pos: engine.Vec(f32),
    radius: i32 = 10,
};

pub fn run(context: *engine.Context) !void {
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
                engine.Event.QuitEvent => {
                    context.quitting = true;
                    break :gameloop;
                },
                else => {},
            }
        }

        //
        // Update
        //

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
