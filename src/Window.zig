const x11 = @import("X11.zig");
const bitmask = @import("bitmask.zig");
const WM = @import("WindowManager.zig");
const debug = @import("std").debug;
const layout = @import("layout.zig");

const Alignment = layout.Alignment;

const Mode = enum { Default, Floating };

pub fn Window(comptime T: type) type {
    return struct {
        const Self = @This();
        mask: bitmask.Mask(T) = bitmask.Mask(T).init(0),
        window: x11.Window,
        mode: Mode = .Default,
        alignment: Alignment = .{},

        pub fn map(self: *const Self, display: *x11.Display) void {
            _ = x11.XMapWindow(display, self.window);
        }

        pub fn unmap(self: *const Self, display: *x11.Display) void {
            _ = x11.XUnmapWindow(display, self.window);
        }

        pub fn arrange(self: *const Self, display: *x11.Display) void {
            _ = x11.XMoveResizeWindow(display, self.window, self.alignment.pos.x, self.alignment.pos.y, self.alignment.width, self.alignment.height);
        }
    };
}
