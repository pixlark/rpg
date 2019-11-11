const std = @import("std");
const List = std.ArrayList;
const engine = @import("engine.zig");
const c_alloc = std.heap.c_allocator;

const screen_width  = 800;
const screen_height = 600;

fn drawCursor(context: *engine.Context, normal_sprite: engine.Sprite, click_sprite: engine.Sprite) !void {
    try context.drawSprite(
        if (context.mouseDown(.Left))
             click_sprite
        else normal_sprite,
        context.mousePos(),
    );
}

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
    Nothing: void,
    Potion: void,
};

const Node = struct {
    object: NodeObject = NodeObject{ .Nothing = {} },
    rect: engine.Rect(i32),
};

const NodeGraph = struct {
    nodes: []Node,
    graph: Graph(Node),
};

fn generateNodeGraph(n: usize) !NodeGraph {
    var ng = NodeGraph {
        .nodes = try c_alloc.alloc(Node, n),
        .graph = try Graph(Node).new(n, c_alloc),
    };
    
    const node_size = 60;
    var pos = engine.Vec(i32).new(
        screen_width / 2 - node_size / 2,
        node_size,
    );

    var lastIndex: ?usize = null;
    for (ng.nodes) |*node, i| {
        var rect = engine.Rect(i32).new(
            pos.x, pos.y,
            node_size, node_size,
        );
        node.* = Node{ .rect = rect };

        if (lastIndex) |j| {
            try ng.graph.connect(j, i);
        }
        
        pos.y += node_size + 20;
        var dx: i32 = 1;
        if (engine.rng.random.boolean()) {
            dx = -1;
        }
        pos.x += dx * 60;

        lastIndex = i;
    }
    
    return ng;
}

fn runGame(context: *engine.Context) !void {
    var cursor_up = try context.loadSprite(c"res/cursor.png");
    var cursor_down = try context.loadSprite(c"res/cursor_down.png");

    var graph_memory: [1024]u8 = undefined;
    var graph_allocator =
        std.heap.FixedBufferAllocator.init(graph_memory[0..]);
    var ng = try generateNodeGraph(6);

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
                if (engine.isVecInsideRect(mouse_pos, node.rect)) {
                    if (try ng.graph.connected(player_pos, i)) {
                        player_pos = i;
                    }
                }
            }
        }
        
        try context.clear(engine.Color.new(0, 0, 0, 0xff));

        // Draw nodes @DevArt
        for (ng.nodes) |node| {
            try context.drawRect(
                node.rect,
                engine.Color.new(0, 0, 0xff, 0xff)
            );
            switch (node.object) {
                .Nothing => {},
                .Potion => try context.fillRect(
                    node.rect,
                    engine.Color.new(0xff, 0, 0, 0x40),
                ),
            }
        }

        // Draw connection lines @DevArt
        for (ng.nodes) |node1, i| {
            for (ng.nodes[i..]) |node2, j| {
                if (try ng.graph.connected(i, i + j)) {
                    try context.drawLine(
                        node1.rect.center(), node2.rect.center(),
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
                    player_node.rect.getX() + 5,
                    player_node.rect.getY() + 5,
                    player_node.rect.getW() - 10,
                    player_node.rect.getH() - 10,
                ),
                engine.Color.new(0, 0, 0xff, 0xff),
            );
        }
        
        try drawCursor(context, cursor_up, cursor_down);
        context.flip();
    }
}

fn gameMain() !void {
    try engine.init();
    var context = try engine.createContext(
        c"RPG", engine.vec(i32, screen_width, screen_height)
    );

    try runGame(&context);
}

pub fn main() void {
    gameMain() catch |err| {
        std.debug.warn("The game ran into an unexpected error, and is closing.\n");
        std.debug.warn("---> {}\n", err);
    };
}
