const x = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/cursorfont.h");
});

const Type = enum(u8) {
    Hover = x.XC_left_ptr,
    Resize = x.XC_sizing,
    Move = x.XC_fleur,
};

const Self = @This();

type: Type,
cursor: *x.Cursor = undefined,

pub fn init(self: Self, display: *x.Display) !void {
    self.cursor = x.XCreateFontCursor(display, @intFromEnum(self.type));
}

pub fn deinit(self: *Self) void {
    if (self.cursor) x.XFreeCursor(self.cursor);
}

pub fn createHover() Self {
    return Self{
        .type = .Hover,
    };
}

pub fn createResize() Self {
    return Self{
        .type = .Resize,
    };
}

pub fn createMove() Self {
    return Self{
        .type = .Move,
    };
}
