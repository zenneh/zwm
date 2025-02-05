const Window = @import("WindowManager.zig").Window;
const x = @import("X11.zig");
const Alloc = std.mem.Allocator;
const Layout = @import("layout.zig").Layout;
const Layouts = @import("layout.zig").Layouts;

const std = @import("std");

const Self = @This();
const WindowList = std.ArrayList(*Window);

layout: Layout,
windows: WindowList,

pub fn init(alloc: Alloc, comptime layout: Layouts) Self {
    return .{
        .layout = layout.asLayout(),
        .windows = WindowList.init(alloc),
    };
}

pub fn tag(self: *Self, window: *Window) void {
    for (self.windows.items) |w| {
        if (window == w) return;
    }

    self.windows.append(window) catch return;
}

pub fn untag(self: *Self, window: *Window) void {
    for (self.windows.items, 0..) |w, index| {
        if (window == w) {
            _ = self.windows.swapRemove(index);
            return;
        }
    }
}

pub fn mapAll(self: *Self, display: *x.Display) void {
    for (self.windows.items) |window| {
        window.map(display);
    }
}
pub fn unmapAll(self: *Self, display: *x.Display) void {
    for (self.windows.items) |window| {
        window.unmap(display);
    }
}

pub fn arrange(self: *Self, display: *x.Display) void {
    self.layout.arrange(self.windows.items, display);
}
