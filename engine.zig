const std = @import("std");
const sdl = @cImport(@cInclude("SDL2/SDL.h"));

pub fn Vec(comptime T: type) type {
    return struct {
        x: T, y: T,
    };
}

pub fn vec(comptime T: type, x: T, y: T) Vec(T) {
    return Vec(T) { .x = x, .y = y };
}

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

pub const Color = struct {
    r: u8, g: u8, b: u8, a: u8,
    pub fn new(r: u8, g: u8, b: u8, a: u8) Color {
        return Color { .r = r, .g = g, .b = b, .a = a };
    }
};

pub fn init() !void {
    var err = sdl.SDL_Init(sdl.SDL_INIT_VIDEO);
    if (err != 0) {
        return error.InitializeError;
    }
}

pub const Context = struct {
    window:   ?*sdl.SDL_Window,
    renderer: ?*sdl.SDL_Renderer,
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

pub const EventType = enum {
    QuitEvent,
};

pub const Event = union(EventType) {
    QuitEvent: void,
};

pub fn pollEvent() ?Event {
    var e: sdl.SDL_Event = undefined;
    if (sdl.SDL_PollEvent(&e) == 0) {
        return null;
    }
    switch (e.type) {
        sdl.SDL_QUIT => return Event{ .QuitEvent = {} },
        else => return null,
    }
}
