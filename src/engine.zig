const std = @import("std");
const sdl = @import("sdl.zig");
const img = @cImport(@cInclude("SDL2/SDL_image.h"));

pub const Scancode = sdl.SDL_Scancode;

// Vec

pub fn Vec(comptime T: type) type {
    return struct {
        x: T, y: T,
        pub fn new(x: T, y: T) Vec(T) {
            return Vec(T){ .x = x, .y = y };
        }
    };
}

pub fn vec(comptime T: type, x: T, y: T) Vec(T) { // @Deprecated
    return Vec(T) { .x = x, .y = y };
}

pub fn linearly_interpolate(start: Vec(i32), end: Vec(i32), time: f32) Vec(i32) {
    var x = start.x + time * (end.x - start.x);
    var y = (start.y * (end.x - x) + end.y * (x - start.x)) / (end.x - start.x);
    return vec(i32, x, y);
}

// Rect

pub fn Rect(comptime T: type) type {
    return struct {
        pos:  Vec(T),
        size: Vec(T),
        pub fn new(x: T, y: T, w: T, h: T) Rect(T) {
            return Rect(T) {
                .pos = Vec(T) {
                    .x = x, .y = y,
                },
                .size = Vec(T) {
                    .x = w, .y = h,
                },
            };
        }
        pub fn fromCenter(pos: Vec(T), half_size: Vec(T)) Rect(T) {
            return Rect(T) {
                .pos = Vec(T) {
                    .x = pos.x - half_size.x, .y = pos.y - half_size.y,
                },
                .size = Vec(T) {
                    .x = half_size.x * 2, .y = half_size.y * 2,
                },
            };
        }
        pub fn getX(self: *const Rect(T)) T {
            return self.pos.x;
        }
        pub fn getY(self: *const Rect(T)) T {
            return self.pos.y;
        }
        pub fn getW(self: *const Rect(T)) T {
            return self.size.x;
        }
        pub fn getH(self: *const Rect(T)) T {
            return self.size.y;
        }
        pub fn left(self: *const Rect(T)) T {
            return self.pos.x;
        }
        pub fn right(self: *const Rect(T)) T {
            return self.pos.x + self.size.x;
        }
        pub fn top(self: *const Rect(T)) T {
            return self.pos.y;
        }
        pub fn bottom(self: *const Rect(T)) T {
            return self.pos.y + self.size.y;
        }
        pub fn center(self: *const Rect(T)) Vec(T) {
            return Vec(T) {
                .x = self.getX() + @divTrunc(self.getW(), 2),
                .y = self.getY() + @divTrunc(self.getH(), 2),
            };
        }
        pub fn offset_about_center(self: *const Rect(T), offset: T) Rect(T) {
            return Rect(T).new(
                self.getX() - offset,
                self.getY() - offset,
                self.getW() + offset * 2,
                self.getH() + offset * 2,
            );
        }
    };
}

fn sdlRect(r: Rect(i32)) sdl.SDL_Rect {
    return sdl.SDL_Rect {
        .x = r.pos.x, .y = r.pos.y,
        .w = r.size.x, .h = r.size.y,
    };
}

pub fn isVecInsideRect(v: Vec(i32), b: Rect(i32)) bool {
    return
        v.x >= b.left() and v.x <= b.right() and
        v.y >= b.top()  and v.y <= b.bottom();
}

pub fn doRectsIntersect(b1: Rect(i32), b2: Rect(i32)) bool {
    var horiz =
        (b1.left() >= b2.left() and b1.left() <= b2.right()) or
        (b1.right() >= b2.left() and b1.right() <= b2.right());
    var vert =
        (b1.top() >= b2.top() and b1.top() <= b2.bottom()) or
        (b1.bottom() >= b2.top() and b1.bottom() <= b2.bottom());
    return horiz and vert;
}

// Color

pub const Color = struct {
    pub const White = Color.new(0xff, 0xff, 0xff, 0xff);
    pub const Black = Color.new(0, 0, 0, 0xff);
    r: u8, g: u8, b: u8, a: u8,
    pub fn new(r: u8, g: u8, b: u8, a: u8) Color {
        return Color { .r = r, .g = g, .b = b, .a = a };
    }
};

// Sprite

pub const Sprite = struct {
    texture: *sdl.SDL_Texture,
    size: Vec(i32),
    pub fn destroy(self: *Sprite) void {
        sdl.SDL_DestroyTexture(self.texture);
    }
};

// Context

pub const Context = struct {
    size: Vec(i32),
    window:   ?*sdl.SDL_Window,
    renderer: ?*sdl.SDL_Renderer,
    desired_framerate: u32 = 60,

    // TODO(pixlark): Cleanup procedures, although they're not urgent at all
    
    // Every frame
    pub fn frameUpdate(self: *Context) void {
        self.mouseUpdate();
        self.keyboardUpdate();
        self.timeUpdate();
    }

    // Delta time
    delta_time: f32 = 1.0 / 30.0,
    last_time_marker: u64,
    fn timeUpdate(self: *Context) void {
        // Wait extra time to reach desired framarate.
        const target_delta = 1.0 / @intToFloat(f32, self.desired_framerate);
        var cycles_per_frame = @floatToInt(
            usize, target_delta * @intToFloat(f32, sdl.SDL_GetPerformanceFrequency()),
        );
        while (sdl.SDL_GetPerformanceCounter() - self.last_time_marker < cycles_per_frame) {
            sdl.SDL_Delay(1);
        }

        // Calculate delta time
        var time_marker = sdl.SDL_GetPerformanceCounter();
        var delta = time_marker - self.last_time_marker;
        self.delta_time =
            @intToFloat(f32, delta) / @intToFloat(f32, sdl.SDL_GetPerformanceFrequency());
        self.last_time_marker = time_marker;
        std.debug.warn("{}           \r", 1.0 / self.delta_time);
    }
    
    // Basic rendering
    fn setDrawColor(self: *Context, color: Color) !void {
        if (sdl.SDL_SetRenderDrawColor(
            self.renderer, color.r, color.g, color.b, color.a) != 0) {
            return error.SDLSetRenderDrawColorError;
        }
    }
    pub fn clear(self: *Context, color: Color) !void {
        try self.setDrawColor(color);
        var err = sdl.SDL_RenderClear(self.renderer);
        if (err != 0) {
            return error.SDLRenderClearError;
        }
    }
    pub fn clearAlpha(self: *Context, color: Color) !void {
        try self.setDrawColor(color);
        try self.fillRect(
            Rect(i32).new(
                0, 0, self.size.x, self.size.y,
            ),
            color,
        );        
    }
    pub fn drawRect(self: *Context, rect: Rect(i32), color: Color) !void {
        try self.setDrawColor(color);
        var sdl_rect = sdlRect(rect);
        if (sdl.SDL_RenderDrawRect(self.renderer, &sdl_rect) != 0) {
            return error.SDLRenderDrawRectError;
        }
    }
    pub fn fillRect(self: *Context, rect: Rect(i32), color: Color) !void {
        try self.setDrawColor(color);
        var sdl_rect = sdlRect(rect);
        if (sdl.SDL_RenderFillRect(self.renderer, &sdl_rect) != 0) {
            return error.SDLRenderFillRectError;
        }
    }
    pub fn drawLine(self: *Context, start: Vec(i32), end: Vec(i32), color: Color) !void {
        try self.setDrawColor(color);
        var err = sdl.SDL_RenderDrawLine(
            self.renderer, start.x, start.y, end.x, end.y
        );
        if (err != 0) {
            return error.SDLRenderDrawLineError;
        }
    }
    pub fn flip(self: *Context) void {
        sdl.SDL_RenderPresent(self.renderer);
    }
    // Sprites
    pub fn loadSprite(self: *Context, path: [*]const u8) !Sprite {
        var surface = img.IMG_Load(path) orelse
            return error.SpritePathNotFound;
        defer img.SDL_FreeSurface(surface);
        
        var texture = sdl.SDL_CreateTextureFromSurface(
            self.renderer,
            @ptrCast(*sdl.SDL_Surface, surface),
        ) orelse return error.CreateTetxureFromSurfaceError;
        
        return Sprite {
            .texture = texture,
            .size = Vec(usize){
                .x = surface.*.w,
                .y = surface.*.h,
            },
        };
    }
    pub fn drawSprite(self: *Context, sprite: Sprite, pos: Vec(i32)) !void {
        var rect = sdlRect(Rect(i32).new(
            pos.x, pos.y, sprite.size.x, sprite.size.y
        ));
        var err = sdl.SDL_RenderCopy(
            self.renderer,
            sprite.texture,
            null,
            &rect
        );
        if (err != 0) {
            return error.SDLRenderCopyError;
        }
    }
    // Mouse Input
    buttons_last_frame: [@memberCount(MouseButton)]bool = [_]bool{ false, false, false },
    buttons_this_frame: [@memberCount(MouseButton)]bool = [_]bool{ false, false, false },

    fn mouseUpdate(self: *Context) void {
        var state = sdl.SDL_GetMouseState(null, null);
        
        var button: @TagType(MouseButton) = 0;
        while (button < @memberCount(MouseButton)) : (button += 1) {
            self.buttons_last_frame[button] =
                self.buttons_this_frame[button];
            self.buttons_this_frame[button] =
                (state & (@intCast(u32, 1) << button)) != 0;
        }
    }
    pub fn mouseDown(self: *Context, button: MouseButton) bool {
        return self.buttons_this_frame[@enumToInt(button)];
    }
    pub fn mouseUp(self: *Context, button: MouseButton) bool {
        return !self.buttons_this_frame[@enumToInt(button)];
    }
    pub fn mousePressed(self: *Context, button: MouseButton) bool {
        return self.mouseDown(button) and
            !self.buttons_last_frame[@enumToInt(button)];
    }
    pub fn mousePos(self: *Context) Vec(i32) {
        var x: i32 = undefined;
        var y: i32 = undefined;
        comptime {
            std.debug.assert(@sizeOf([*c]c_int) == @sizeOf(*i32));
        }
        _ = sdl.SDL_GetMouseState(
            @ptrCast([*c]c_int, &x),
            @ptrCast([*c]c_int, &y),
        );
        return vec(i32, x, y);
    }
    // Keyboard Input
    keys_last_frame: []u8 = undefined,
    keys_this_frame: []const u8 = undefined,

    fn keyboardUpdate(self: *Context) void {
        for (self.keys_this_frame) |key, i| {
            self.keys_last_frame[i] = key;
        }
        self.keys_this_frame = keyboardState();
    }
    pub fn keyDown(self: *Context, scancode: Scancode) bool {
        return self.keys_this_frame[@intCast(usize, @enumToInt(scancode))] != 0;
    }
    pub fn keyUp(self: *Context, scancode: Scancode) bool {
        return self.keys_this_frame[@intCast(usize, @enumToInt(scancode))] == 0;
    }
    pub fn keyPressed(self: *Context, scancode: Scancode) bool {
        return self.keys_this_frame[@intCast(usize, @enumToInt(scancode))] != 0 and
            self.keys_last_frame[@intCast(usize, @enumToInt(scancode))] == 0;
    }
    
    // Misc
    pub fn setMousePos(self: *Context, pos: Vec(i32)) void {
        sdl.SDL_WarpMouseInWindow(
            self.window, pos.x, pos.y,
        );
    }
};

fn keyboardState() []const u8 {
    var nums: i32 = undefined;
    var raw_keys = sdl.SDL_GetKeyboardState(@ptrCast([*c]c_int, &nums));
    return @ptrCast([*]const u8, raw_keys)[0..@intCast(usize, nums)];
}

pub const MouseButton = enum(u5) {
    Left, Middle, Right,
};

pub fn createContext(title: [*]const u8, size: Vec(i32)) !Context {
    var window = sdl.SDL_CreateWindow(title, -1, -1, size.x, size.y, 0);
    if (window == null) {
        return error.SDLCreateWindowError;
    }
    var renderer = sdl.SDL_CreateRenderer(window, -1, 0);
    if (renderer == null) {
        return error.SDLCreateRendererError;
    }
    var err = sdl.SDL_SetRenderDrawBlendMode(
        renderer, @intToEnum(sdl.SDL_BlendMode, sdl.SDL_BLENDMODE_BLEND)
    );
    // @SilentFail
    if (err != 0) {
        std.debug.warn("Warning: SDL_SetRenderDrawBlendMode failed. Alpha blend will not function correctly.\n");
    }
    var key_state = keyboardState();
    return Context {
        .size = size,
        .window = window,
        .renderer = renderer,
        .last_time_marker = sdl.SDL_GetPerformanceCounter(),
        .keys_last_frame = try std.heap.c_allocator.alloc(u8, key_state.len),
        .keys_this_frame = key_state,
    };
}

// Miscellaneous Drawing Routines

pub fn drawCursor(context: *Context, normal_sprite: Sprite, click_sprite: Sprite) !void {
    try context.drawSprite(
        if (context.mouseDown(.Left))
             click_sprite
        else normal_sprite,
        context.mousePos(),
    );
}

// Initialization

pub fn init() !void {
    // SDL
    var err = sdl.SDL_Init(sdl.SDL_INIT_VIDEO);
    if (err != 0) {
        return error.SDLInitializeError;
    }
    
    // @SilentFail -- TODO(pixlark): Log this somewhere
    _ = sdl.SDL_ShowCursor(sdl.SDL_DISABLE);
    
    // SDL_image
    const img_flags = img.IMG_INIT_PNG;
    err = img.IMG_Init(img_flags);
    if (err & img_flags != img_flags) {
        return error.SDLImgInitializeError;
    }

    // RNG
    rng = std.rand.DefaultPrng.init(std.time.milliTimestamp());
}

// Events

pub const MouseClickEvent = enum {
    LeftUp, LeftDown, RightUp, RightDown,
};

pub const Event = union(enum) {
    QuitEvent: void,
    MouseClick: MouseClickEvent,
};

pub fn pollEvent() ?Event {
    var e: sdl.SDL_Event = undefined;
    if (sdl.SDL_PollEvent(&e) == 0) {
        return null;
    }
    switch (e.type) {
        sdl.SDL_QUIT => return Event{ .QuitEvent = {} },
        sdl.SDL_MOUSEBUTTONDOWN => switch (e.button.button) {
            sdl.SDL_BUTTON_LEFT  => return Event{ .MouseClick = MouseClickEvent.LeftDown },
            sdl.SDL_BUTTON_RIGHT => return Event{ .MouseClick = MouseClickEvent.RightDown },
            else => return pollEvent(),
        },
        sdl.SDL_MOUSEBUTTONUP => switch (e.button.button) {
            sdl.SDL_BUTTON_LEFT  => return Event{ .MouseClick = MouseClickEvent.LeftUp },
            sdl.SDL_BUTTON_RIGHT => return Event{ .MouseClick = MouseClickEvent.RightUp },
            else => return pollEvent(),
        },
        else => return null,
    }
}

// RNG

pub var rng: std.rand.DefaultPrng = undefined;
