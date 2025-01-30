const std = @import("std");
const Window = @import("Window.zig");

const Layout = enum { Monocle, Floating, Recursive };

const Self = @This();

layout: Layout,
windows: std.ArrayList(*const Window),

pub fn tag(self: *Self, window: *const Window) void {
    for (self.windows, 0..) |w, index| {
        if (window == w) {
            self.windows.swapRemove(index);
            return;
        }
    }

    self.windows.append(window);
}
