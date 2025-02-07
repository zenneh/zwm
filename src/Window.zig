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

        pub fn focus(self: *const Self, display: *x11.Display) void {
            _ = x11.XSetInputFocus(display, self.window, x11.RevertToPointerRoot, x11.CurrentTime);
            _ = x11.XRaiseWindow(display, self.window);
            _ = x11.XSetWindowBorderWidth(display, self.window, 1);
            _ = x11.XSetWindowBorder(display, self.window, 0x00_FF_00_00);
        }

        pub fn unfocus(self: *const Self, display: *x11.Display) void {
            _ = x11.XSetWindowBorderWidth(display, self.window, 0);
            _ = x11.XSetWindowBorder(display, self.window, 0x00_00_00_00);
        }

        pub fn fromX11Window(window: x11.Window) Self {
            return .{
                .window = window,
            };
        }

        pub fn updateAlignment(self: *Self, display: *x11.Display) void {
            var attr: x11.XWindowAttributes = undefined;
            _ = x11.XGetWindowAttributes(display, self.window, &attr);

            self.alignment.pos = .{ .x = @intCast(attr.x), .y = @intCast(attr.y) };
            self.alignment.width = @intCast(attr.width);
            self.alignment.height = @intCast(attr.height);
        }
    };
}
