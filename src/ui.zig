usingnamespace @import("engine.zig");

pub const Button = struct {
    rect: Rect(i32),
    color: Color = Color.Black,
    outline_color: Color = Color.White,
    highlight_color: Color = Color.new(0xff, 0xff, 0xff, 0x40),
};

pub fn drawButton(context: *Context, bs: Button) !void {
    var mouse_pos = context.mousePos();
    
    try context.fillRect(bs.rect, bs.color);
    if (isVecInsideRect(mouse_pos, bs.rect)) {
        try context.fillRect(bs.rect, bs.highlight_color);
    }
    try context.drawRect(bs.rect, bs.outline_color);
}
