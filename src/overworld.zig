const std = @import("std");
const engine = @import("engine.zig");
const ui = @import("ui.zig");
const global = @import("global.zig");

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
        Node{ .object = NodeObject{ .Nothing = 0 }, // #3
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
    var cursor_down = try context.loadSprite(c"res/cursor_down.png");

    var ng = try obtainTestGraph();

    var player_pos: usize = 0;
    
    gameloop: while (true) {
        context.updateInput();
        while (engine.pollEvent()) |event| {
            switch (event) {
                engine.Event.QuitEvent => break :gameloop,
                else => {},
            }
        }

        var mouse_pos = context.mousePos();

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
        
        try context.clear(engine.Color.new(0, 0, 0, 0xff));

        // Draw ENTER button
        try ui.drawButton(context, ui.Button{
            .rect = engine.Rect(i32).new(5, 5, 200, 50),
            .color = engine.Color.new(0x22, 0x22, 0x22, 0xff),
        });
        
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
                    engine.Color.new(0xff, 0, 0, 0x40),
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
                engine.Rect(i32).new(
                    player_node.rect().getX() + 5,
                    player_node.rect().getY() + 5,
                    player_node.rect().getW() - 10,
                    player_node.rect().getH() - 10,
                ),
                engine.Color.new(0, 0, 0xff, 0xff),
            );
        }
        
        try engine.drawCursor(context, cursor_up, cursor_down);
        context.flip();
    }
}
