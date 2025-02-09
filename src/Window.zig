const x11 = @import("X11.zig");
const WM = @import("WindowManager.zig");
const debug = @import("std").debug;
const layout = @import("layout.zig");

pub const Error = error{
    SelectInputFailed,
    MapFailed,
    UnmapFailed,
    ArrangeFailed,
    FocusFailed,
    AttributesFailed,
    DestroyFailed,
};

const Alignment = layout.Alignment;

pub const Mode = enum { default, floating };

// TODO: Make this configurable in the config
const Border = struct {
    const width: u32 = 1;
    const focused_color: u64 = 0x00_00_00_88;
    const unfocused_color: u64 = 0x00_00_00_55;
};

const Self = @This();

// Representing the X11 window
handle: x11.Window,

// Current window mode
mode: Mode,

// Alignment of the window
alignment: Alignment,

pub fn init(window: x11.Window) Self {
    return .{
        .handle = window,
        .mode = .default,
        .alignment = .{},
    };
}

pub fn selectInput(self: *const Self, display: *x11.Display, mask: c_long) Error!void {
    const result = x11.XSelectInput(
        display,
        self.handle,
        mask,
    );
    if (result == x11.False) return Error.SelectInputFailed;
}

pub fn map(self: *const Self, display: *x11.Display) Error!void {
    if (x11.XMapWindow(display, self.handle) == x11.False) return Error.MapFailed;
}

pub fn unmap(self: *const Self, display: *x11.Display) Error!void {
    if (x11.XUnmapWindow(display, self.handle) == x11.False) return Error.UnmapFailed;
}

pub fn arrange(self: *const Self, display: *x11.Display) Error!void {
    const result = x11.XMoveResizeWindow(display, self.handle, self.alignment.pos.x, self.alignment.pos.y, self.alignment.width, self.alignment.height);
    if (result == x11.False) return Error.ArrangeFailed;
}

pub fn focus(self: *const Self, display: *x11.Display) Error!void {
    if (x11.XSetInputFocus(display, self.handle, x11.RevertToPointerRoot, x11.CurrentTime) == x11.False) return Error.FocusFailed;
    if (x11.XRaiseWindow(display, self.handle) == x11.False) return Error.FocusFailed;
    if (x11.XSetWindowBorderWidth(display, self.handle, Border.width) == x11.False) return Error.FocusFailed;
    if (x11.XSetWindowBorder(display, self.handle, Border.focused_color) == x11.False) return Error.FocusFailed;
}

pub fn unfocus(self: *const Self, display: *x11.Display) Error!void {
    if (x11.XSetWindowBorderWidth(display, self.handle, Border.width) == x11.False) return Error.FocusFailed;
    if (x11.XSetWindowBorder(display, self.handle, Border.unfocused_color) == x11.False) return Error.FocusFailed;
}

pub fn updateAlignment(self: *Self, display: *x11.Display) Error!void {
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
pub fn destroy(self: *Self, display: *x11.Display) Error!void {
    if (x11.XDestroyWindow(display, self.handle) == x11.False) return Error.DestroyFailed;
}

pub fn setMode(self: *Self, new_mode: Mode) void {
    self.mode = new_mode;
}

pub fn setAlignment(self: *Self, alignment: Alignment) void {
    self.alignment = alignment;
}
