const std = @import("std");
const engine = @import("engine.zig");
const ui = @import("ui.zig");
const global = @import("global.zig");
const battle = @import("battle.zig");

const List = std.ArrayList;
const cm = std.heap.c_allocator;

fn Graph(comptime T: type) type {
    return struct {
        matrix: []bool,
        size: usize,
        fn new(n: usize, a: *std.mem.Allocator) !Graph(T) {
            var g = Graph(T){
                .matrix = try a.alloc(bool, n * n),
                .size = n,
            };
            var i: usize = 0;
            while (i < g.size * g.size) : (i += 1) {
                g.matrix[i] = false;
            }
            return g;
        }
        fn connect(self: *Graph(T), from: usize, to: usize) !void {
            if (from >= self.size or to >= self.size) {
                return error.IndicesTooLarge;
            }
            self.matrix[from * self.size + to] = true;
        }
        fn connected(self: *Graph(T), a: usize, b: usize) !bool {
            if (a >= self.size or b >= self.size) {
                return error.IndicesTooLarge;
            }
            return self.matrix[a * self.size + b] or
                self.matrix[b * self.size + a];
        }
    };
}

const NodeObject = union(enum) {
    // u8 rather than void becuase of https://github.com/ziglang/zig/issues/3681
    Nothing: u8,
    Apple: u8,
    Enemy: battle.Enemy,
};

const Node = struct {
    object: NodeObject = NodeObject{ .Nothing = 0 },
    pos: engine.Vec(i32),
    fn rect(self: *const Node) engine.Rect(i32) {
        return engine.Rect(i32).new(self.pos.x, self.pos.y, node_size, node_size);
    }
};

const NodeGraph = struct {
    nodes: []Node,
    graph: Graph(Node),
};

const node_size = 60;

fn obtainTestGraph() !NodeGraph {
    const test_graph_node_count = 9;
    const test_graph_nodes = [test_graph_node_count]Node{
        Node{ .object = NodeObject{ .Nothing = 0 }, // #0
             .pos = engine.Vec(i32).new(110, 160) },
        Node{ .object = NodeObject{ .Nothing = 0 }, // #1
             .pos = engine.Vec(i32).new(380, 165) },
        Node{ .object = NodeObject{ .Nothing = 0 }, // #2
             .pos = engine.Vec(i32).new(620, 150) },
        Node{ .object = NodeObject{ .Enemy = .Rat }, // #3
             .pos = engine.Vec(i32).new(250, 300) },
        Node{ .object = NodeObject{ .Nothing = 0 }, // #4
             .pos = engine.Vec(i32).new(450, 360) },
        Node{ .object = NodeObject{ .Nothing = 0 }, // #5
             .pos = engine.Vec(i32).new(50, 400) },
        Node{ .object = NodeObject{ .Apple = 0 },   // #6
             .pos = engine.Vec(i32).new(630, 440) },
        Node{ .object = NodeObject{ .Apple = 0 },   // #7
             .pos = engine.Vec(i32).new(230, 515) },
        Node{ .object = NodeObject{ .Nothing = 0 }, // #8
             .pos = engine.Vec(i32).new(380, 520) },
    };

    var ng = NodeGraph{
        .nodes = try cm.alloc(Node, test_graph_node_count),
        .graph = try Graph(Node).new(test_graph_node_count, cm),
    };

    for (test_graph_nodes) |node, i| {
        ng.nodes[i] = test_graph_nodes[i];
    }

    const test_graph_connections = [_]usize {
        0, 5,
        5, 7,
        7, 3,
        3, 0,
        3, 1,
        1, 4,
        4, 8,
        8, 7,
        4, 2,
        2, 6,
    };

    var i: usize = 0;
    while (i < test_graph_connections.len) : (i += 2) {
        try ng.graph.connect(test_graph_connections[i], test_graph_connections[i + 1]);
    }
    
    return ng;
}

pub fn run(context: *engine.Context) !void {
    var cursor_up = try context.loadSprite(c"res/cursor.png");
    defer cursor_up.destroy();
    var cursor_down = try context.loadSprite(c"res/cursor_down.png");
    defer cursor_down.destroy();

    var ng = try obtainTestGraph();

    var player_pos: usize = 0;

    // Fade-in
    var fading_in = true;
    const fade_in_time = 0.4;
    var fade_in_timer: f32 = fade_in_time;
    //
    
    // Battles
    var entering_battle = false;
    var next_opponent: battle.Enemy = undefined;
    const battle_transition_time = 1.0;
    var battle_timer: f32 = 0.0;
    //
    
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

        var mouse_pos = context.mousePos();

        // Fade-in
        if (fading_in) {
            fade_in_timer -= 1 * context.delta_time;
            if (fade_in_timer <= 0.0) {
                fade_in_timer = 0.0;
                fading_in = false;
            }
        }
        
        // Moving to new nodes
        if (context.mousePressed(engine.MouseButton.Left)) {
            for (ng.nodes) |node, i| {
                if (engine.isVecInsideRect(mouse_pos, node.rect())) {
                    if (try ng.graph.connected(player_pos, i)) {
                        player_pos = i;
                    }
                }
            }
        }

        // Possibly enter battle
        if (entering_battle) {
            battle_timer -= 1 * context.delta_time;
            if (battle_timer <= 0.0) {
                battle_timer = 0.0;
                entering_battle = false;
                try battle.run(context, next_opponent);
            }
        }
        
        // Did we land on an important node?
        switch (ng.nodes[player_pos].object) {
            .Enemy => |enemy| {
                if (!entering_battle) {
                    entering_battle = true;
                    next_opponent = enemy;
                    battle_timer = battle_transition_time;
                }
            },
            .Apple => {}, // TODO(pixlark): Heal and remove apple
            else => {},
        }

        //
        // Render
        //
        
        try context.clear(engine.Color.new(0, 0, 0, 0xff));

        if (false) {
            // Draw ENTER button
            try ui.drawButton(context, ui.Button{
                .rect = engine.Rect(i32).new(5, 5, 200, 50),
                .color = engine.Color.new(0x22, 0x22, 0x22, 0xff),
            });
        }
        
        // Draw nodes @DevArt
        for (ng.nodes) |node| {
            try context.drawRect(
                node.rect(),
                engine.Color.new(0, 0, 0xff, 0xff)
            );
            switch (node.object) {
                .Nothing => {},
                .Apple => try context.fillRect(
                    node.rect(),
                    engine.Color.new(0, 0xff, 0, 0x40),
                ),
                .Enemy => try context.fillRect(
                    node.rect(),
                    engine.Color.new(0xff, 0, 0, 0x60),
                ),
            }
        }

        // Draw connection lines @DevArt
        for (ng.nodes) |node1, i| {
            for (ng.nodes[i..]) |node2, j| {
                if (try ng.graph.connected(i, i + j)) {
                    try context.drawLine(
                        node1.rect().center(), node2.rect().center(),
                        engine.Color.new(0, 0xff, 0, 0xff),
                    );
                }
            }
        }

        // Draw player @DevArt
        {
            var player_node = ng.nodes[player_pos];
            try context.fillRect(
                player_node.rect().offset_about_center(-5),
                engine.Color.new(0, 0, 0xff, 0xff),
            );
        }

        // Transition to battle, if we're entering one
        if (entering_battle) {
            var ratio = 1.0 - (battle_timer / battle_transition_time);
            try context.clearAlpha(
                engine.Color.new(0, 0, 0, @floatToInt(u8, ratio * 0xff)),
            );
        }

        // Fade-in
        if (fading_in) {
            var ratio = fade_in_timer / fade_in_time;
            try context.clearAlpha(
                engine.Color.new(0, 0, 0, @floatToInt(u8, ratio * 0xff)),
            );
        }
        
        try engine.drawCursor(context, cursor_up, cursor_down);
        context.flip();
    }
}
