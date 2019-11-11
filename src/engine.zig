const std = @import("std");
const sdl = @cImport(@cInclude("SDL2/SDL.h"));
const img = @cImport(@cInclude("SDL2/SDL_image.h"));

// Vec

pub fn Vec(comptime T: type) type {
    return struct {
        x: T, y: T,
    };
}

pub fn vec(comptime T: type, x: T, y: T) Vec(T) {
    return Vec(T) { .x = x, .y = y };
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
    };
}

fn sdlRect(r: Rect(i32)) sdl.SDL_Rect {
    return sdl.SDL_Rect {
        .x = r.pos.x, .y = r.pos.y,
        .w = r.size.x, .h = r.size.y,
    };
}

// Color

pub const Color = struct {
    r: u8, g: u8, b: u8, a: u8,
    pub fn new(r: u8, g: u8, b: u8, a: u8) Color {
        return Color { .r = r, .g = g, .b = b, .a = a };
    }
};

// Sprite

pub const Sprite = struct {
    texture: *sdl.SDL_Texture,
    size: Vec(i32),
};

// Context

pub const Context = struct {
    window:   ?*sdl.SDL_Window,
    renderer: ?*sdl.SDL_Renderer,
    // Basic rendering
    fn setDrawColor(self: *Context, color: Color) !void {
        if (sdl.SDL_SetRenderDrawColor(self.renderer, color.r, color.g, color.b, color.a) != 0) {
            return error.SDLSetRenderDrawColorError;
        }
    }
    pub fn clear(self: *Context, color: Color) !void {
        try self.setDrawColor(color);
        if (sdl.SDL_RenderClear(self.renderer) != 0) {
            return error.SDLRenderClearError;
        }
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
            return error.SDLRenderDrawRectError;
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
    buttonsLastFrame: [@memberCount(MouseButton)]bool = [_]bool{ false, false, false },
    buttonsThisFrame: [@memberCount(MouseButton)]bool = [_]bool{ false, false, false },
    pub fn updateInput(self: *Context) void {
        var state = sdl.SDL_GetMouseState(null, null);
        
        var button: @TagType(MouseButton) = 0;
        while (button < @memberCount(MouseButton)) : (button += 1) {
            self.buttonsLastFrame[button] =
                self.buttonsThisFrame[button];
            self.buttonsThisFrame[button] =
                (state & (@intCast(u32, 1) << button)) != 0;
        }
        
    }
    pub fn mouseDown(self: *Context, button: MouseButton) bool {
        return self.buttonsThisFrame[@enumToInt(button)];
    }
    pub fn mouseUp(self: *Context, button: MouseButton) bool {
        return !self.buttonsThisFrame[@enumToInt(button)];
    }
    pub fn mousePressed(self: *Context, button: MouseButton) bool {
        return self.mouseDown(button) and
            !self.buttonsLastFrame[@enumToInt(button)];
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
};

pub const MouseButton = enum(u5) {
    Left, Middle, Right,
};

pub fn createContext(title: [*]const u8, size: Vec(i32)) !Context {
    var window = sdl.SDL_CreateWindow(title, 0, 0, size.x, size.y, 0);
    if (window == null) {
        return error.SDLCreateWindowError;
    }
    var renderer = sdl.SDL_CreateRenderer(window, -1, 0);
    if (renderer == null) {
        return error.SDLCreateRendererError;
    }
    return Context {
        .window = window, .renderer = renderer,
    };
}

// Initialization

pub fn init() !void {
    // SDL
    var err = sdl.SDL_Init(sdl.SDL_INIT_VIDEO);
    if (err != 0) {
        return error.SDLInitializeError;
    }
    _ = sdl.SDL_ShowCursor(sdl.SDL_DISABLE); // Silently fail if we
                                             // can't hide cursor
    // SDL_image
    const img_flags = img.IMG_INIT_PNG;
    err = img.IMG_Init(img_flags);
    if (err & img_flags != img_flags) {
        return error.SDLImgInitializeError;
    }
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
