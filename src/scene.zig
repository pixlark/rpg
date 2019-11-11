const std = @import("std");
const engine = @import("engine.zig");
const alloc = std.heap.c_allocator;

const max_scenes = 100;

pub const SceneManager = struct {
    scenes: [max_scenes]Scene = undefined,
    cursor: usize = 0,
    modified: bool = false,
    //
    // Functions that trigger the `modify` flag
    //
    pub fn push(self: *SceneManager, scene: Scene) anyerror!void {
        if (self.cursor >= max_scenes) {
            return error.ExceededMaxScenes;
        }
        self.scenes[self.cursor] = scene;
        self.cursor += 1;

        var cur = self.current() orelse unreachable;
        try cur.wakeup(cur, self);

        self.modified = true;
    }
    pub fn pop(self: *SceneManager) anyerror!void {
        // We are assuming this will only ever get called from the top
        // scene on the stack
        if (self.done()) {
            return error.TriedToPopEmptySceneManager;
        }
        var cur = self.current() orelse unreachable;
        try cur.die(cur, self);
        self.cursor -= 1;
    }
    //
    // Functions that *DON'T* trigger the `modify` flag
    //
    pub fn reset_flags(self: *SceneManager) void {
        self.modified = false;
    }
    pub fn done(self: *SceneManager) bool {
        return self.cursor == 0;
    }
    pub fn current(self: *SceneManager) ?*Scene {
        if (self.done()) {
            return null;
        }
        return &self.scenes[self.cursor - 1];
    }
};

pub const Scene = struct {
    wakeup: fn(*Scene, *SceneManager)anyerror!void = defaultWakeup,
    event: fn(*Scene, *SceneManager, engine.Event)anyerror!void = defaultEvent,
    update: fn(*Scene, *SceneManager, f32)anyerror!void = defaultUpdate,
    render: fn(*Scene, *SceneManager, *engine.Context)anyerror!void = defaultRender,
    die: fn(*Scene, *SceneManager)anyerror!void = defaultDie,
};

//
// Default implementations for Scene
//
fn defaultWakeup(scene: *Scene, sm: *SceneManager) anyerror!void {}
fn defaultEvent(scene: *Scene, sm: *SceneManager, e: engine.Event) anyerror!void {}
fn defaultUpdate(scene: *Scene, sm: *SceneManager, dt: f32) anyerror!void {}
fn defaultRender(scene: *Scene, sm: *SceneManager, context: *engine.Context) anyerror!void {
    try context.clear(engine.Color.new(0, 0, 0, 0xff));
    context.flip();
}
fn defaultDie(scene: *Scene, sm: *SceneManager) anyerror!void {}
