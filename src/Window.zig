const x = @import("X11.zig");
const bitmask = @import("bitmask.zig");
const WM = @import("WindowManager.zig");
const debug = @import("std").debug;

const Mode = enum { Default, Floating };

pub fn Window(comptime T: type) type {
    return struct {
        const Self = @This();
        mask: bitmask.Mask(T) = bitmask.Mask(T).init(0),
        window: x.Window,
        x: i16 = 0,
        y: i16 = 0,
        width: u16 = 0,
        height: u16 = 0,
        mode: Mode = .Default,

        pub fn map(self: *Self, display: *x.Display) void {
            _ = x.XMapWindow(display, self.window);
        }

        pub fn unmap(self: *Self, display: *x.Display) void {
            _ = x.XUnmapWindow(display, self.window);
        }
    };
}
