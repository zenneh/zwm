const x = @import("X11.zig").x;
const Alloc = @import("std").mem.Allocator;

const Type = enum(u8) {
    Hover = x.XC_left_ptr,
    Resize = x.XC_sizing,
    Move = x.XC_fleur,
};

const Self = @This();

type: Type,
cursor: x.Cursor = undefined,

pub fn init(self: *Self, display: *x.Display) void {
    self.cursor = x.XCreateFontCursor(display, @intCast(@intFromEnum(self.type)));
}

pub fn deinit(self: *Self) void {
    if (self.cursor) x.XFreeCursor(self.cursor);
}

pub fn createHover(allocator: *const Alloc) !*Self {
    const cursor = try allocator.create(Self);
    cursor.* = .{
        .type = .Hover,
    };
    return cursor;
}

pub fn createResize(allocator: *const Alloc) !*Self {
    const cursor = try allocator.create(Self);
    cursor.* = .{
        .type = .Resize,
    };
    return cursor;
}

pub fn createMove(allocator: *const Alloc) !*Self {
    const cursor = try allocator.create(Self);
    cursor.* = .{
        .type = .Resize,
    };
    return cursor;
}
