const x11 = @import("X11.zig");
const WindowManager = @import("WindowManager.zig");
const debug = @import("std").debug;
const layout = @import("layout.zig");
const bitmask = @import("bitmask.zig");

pub const Error = error{
    SelectInputFailed,
    MapFailed,
    UnmapFailed,
    MoveFailed,
    ResizeFailed,
    MoveResizeFailed,
    FocusFailed,
    AttributesFailed,
    DestroyFailed,
    ConfigueFailed,
};

const Alignment = layout.Alignment;

pub const Mode = enum { default, floating };

const Handle = x11.Window;

const Mask = bitmask.Mask;

const Display = x11.Display;

// TODO: Make this configurable in the config
const Border = struct {
    const width: u32 = 1;
    const focused_color: u64 = 0x00_55_00_88;
    const unfocused_color: u64 = 0x00_00_00_55;
};

pub fn Window(comptime T: type) type {
    return struct {
        // Representing the X11 window
        handle: Handle,

        // Current window mode
        mode: Mode,

        // Alignment of the window
        alignment: Alignment,

        // Bitmask representing workspaces
        mask: Mask(T),

        const Self = @This();
        pub fn init(window: x11.Window) Self {
            return .{
                .handle = window,
                .mode = .default,
                .alignment = .{},
                .mask = Mask(T).init(0),
            };
        }

        pub fn tag(self: *Self, position: usize) !void {
            self.mask.tag(position);
        }

        pub fn untag(self: *Self, position: usize) !void {
            self.mask.untag(position);
        }

        pub fn selectInput(self: *const Self, display: *Display, mask: c_long) Error!void {
            const result = x11.XSelectInput(
                display,
                self.handle,
                mask,
            );
            if (result == x11.False) return Error.SelectInputFailed;
        }

        pub fn configure(self: *const Self, display: *Display, flags: c_uint, changes: *x11.XWindowChanges) Error!void {
            if (x11.XConfigureWindow(display, self.handle, flags, changes) == x11.False) return Error.ConfigueFailed;
        }

        pub fn map(self: *const Self, display: *Display) Error!void {
            if (x11.XMapWindow(display, self.handle) == x11.False) return Error.MapFailed;
        }

        pub fn unmap(self: *const Self, display: *Display) Error!void {
            if (x11.XUnmapWindow(display, self.handle) == x11.False) return Error.UnmapFailed;
        }

        pub fn move(self: *const Self, display: *Display, x: i32, y: i32) Error!void {
            const result = x11.XMoveWindow(display, self.handle, @intCast(x), @intCast(y));
            if (result == x11.False) return Error.MoveFailed;
        }

        pub fn resize(self: *const Self, display: *Display, width: u32, height: u32) Error!void {
            const result = x11.XResizeWindow(display, self.handle, @intCast(width), @intCast(height));
            if (result == x11.False) return Error.ResizeFailed;
        }

        pub fn raise(self: *const Self, display: *Display) Error!void {
            if (x11.XRaiseWindow(display, self.handle) == x11.False) return Error.FocusFailed;
        }

        pub fn moveResize(self: *const Self, display: *Display, x: i32, y: i32, width: u32, height: u32) Error!void {
            const result = x11.XMoveResizeWindow(display, self.handle, @intCast(x), @intCast(y), @intCast(width), @intCast(height));
            if (result == x11.False) return Error.MoveResizeFailed;
        }

        pub fn focus(self: *const Self, display: *Display) Error!void {
            if (x11.XSetInputFocus(display, self.handle, x11.RevertToPointerRoot, x11.CurrentTime) == x11.False) return Error.FocusFailed;
            if (x11.XSetWindowBorderWidth(display, self.handle, Border.width) == x11.False) return Error.FocusFailed;
            if (x11.XSetWindowBorder(display, self.handle, Border.focused_color) == x11.False) return Error.FocusFailed;
        }

        pub fn unfocus(self: *const Self, display: *Display) Error!void {
            if (x11.XSetWindowBorderWidth(display, self.handle, Border.width) == x11.False) return Error.FocusFailed;
            if (x11.XSetWindowBorder(display, self.handle, Border.unfocused_color) == x11.False) return Error.FocusFailed;
        }

        pub fn updateAlignment(self: *Self, display: *Display) Error!void {
            var attr: x11.XWindowAttributes = undefined;
            if (x11.XGetWindowAttributes(display, self.handle, &attr) == x11.False) {
                return Error.AttributesFailed;
            }

            self.alignment = .{
                .pos = .{
                    .x = @intCast(attr.x),
                    .y = @intCast(attr.y),
                },
                .width = @intCast(attr.width),
                .height = @intCast(attr.height),
            };
        }
        pub fn destroy(self: *Self, display: *Display) Error!void {
            if (x11.XDestroyWindow(display, self.handle) == x11.False) return Error.DestroyFailed;
        }

        pub fn setMode(self: *Self, new_mode: Mode) void {
            self.mode = new_mode;
        }

        pub fn setAlignment(self: *Self, alignment: Alignment) void {
            self.alignment = alignment;
        }
    };
}
