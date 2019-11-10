const engine = @import("engine.zig");

pub const SceneResultType = enum {
    Normal,
};

pub const SceneResult = union(SceneResultType) {
    Normal: void,
};

pub const Scene = struct {
    wakeup: fn()anyerror!SceneResult = defaultWakeup,
    event: fn(engine.Event)anyerror!SceneResult = defaultEvent,
    update: fn(f32)anyerror!SceneResult = defaultUpdate,
    render: fn(*engine.Context)anyerror!SceneResult = defaultRender,
    die: fn()anyerror!void = defaultDie,
};

fn defaultWakeup() anyerror!SceneResult {
    return SceneResult{ .Normal = {} };
}

fn defaultEvent(e: engine.Event) anyerror!SceneResult {
    return SceneResult{ .Normal = {} };
}

fn defaultUpdate(dt: f32) anyerror!SceneResult {
    return SceneResult{ .Normal = {} };
}

fn defaultRender(context: *engine.Context) anyerror!SceneResult {
    try context.clear(engine.Color.new(0, 0, 0, 0xff));
    context.flip();
    return SceneResult{ .Normal = {} };
}

fn defaultDie() anyerror!void {}
