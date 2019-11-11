const std = @import("std");
const engine = @import("engine.zig");
usingnamespace @import("scene.zig");
const alloc = std.heap.c_allocator;

const TestScene = struct {
    scene: Scene,
    some_data: i32,
    fn create() !*TestScene {
        return (try alloc.create(TestScene))
        TestScene{
            .scene = Scene{
                .event = testEvent,
                .render = testRender,
            },
            .some_data = 5,
        };
    }
};

fn tempUpdate(scene: *Scene, sm: *SceneManager, dt: f32) anyerror!void {
    std.debug.warn("Hello from a temporary scene!\n");
    try sm.pop();
}

fn testEvent(scene: *Scene, sm: *SceneManager, event: engine.Event) anyerror!void {
    var self = @fieldParentPtr(TestScene, "scene", scene);
    switch (event) {
        engine.Event.MouseClick => {
            if (event.MouseClick == engine.MouseClickEvent.LeftUp) {
                std.debug.warn("{}\n", self.some_data);
                try sm.push(Scene{ .update = tempUpdate });
            }
        },
        else => {},
    }
}

fn testRender(scene: *Scene, sm: *SceneManager, context: *engine.Context) !void {
    try context.clear(engine.Color.new(0, 0, 0xff, 0xff));
    context.flip();
}

pub fn gameMain() !void {
    try engine.init();
    var context = try engine.createContext(c"RPG", engine.vec(i32, 800, 600));

    var scene_manager = SceneManager{};

    {
        var scene = try TestScene.create();
        try scene_manager.push(scene.scene);
    }
    
    gameloop: while (!scene_manager.done()) {
        scene_manager.reset_flags();
        var this_scene = scene_manager.current() orelse unreachable;
        
        while (engine.pollEvent()) |event| {
            switch (event) {
                engine.Event.QuitEvent => break :gameloop,
                else => {
                    try this_scene.event(this_scene, &scene_manager, event);
                    if (scene_manager.modified) {
                        continue :gameloop;
                    }
                },
            }
        }
        
        try this_scene.update(this_scene, &scene_manager, 0.0);
        if (scene_manager.modified) {
            continue :gameloop;
        }

        try this_scene.render(this_scene, &scene_manager, &context);
        if (scene_manager.modified) {
            continue :gameloop;
        }
    }
}

pub fn main() void {
    gameMain() catch |err| {
        std.debug.warn("The game ran into an unexpected error, and is closing.\n");
        std.debug.warn("---> {}\n", err);
    };
}
