const WM = @import("WindowManager.zig");
const x = @import("X11.zig");

const std = @import("std");
const debug = std.debug;
const action = @import("action.zig");
const util = @import("util.zig");

pub const Handler = *const fn (wm: *WM, event: *const x.XEvent) void;

pub const HandlerEntry = struct {
    event: c_int,
    handlers: []const Handler,
};

pub fn mapRequest(wm: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XMapRequestEvent, @ptrCast(event));
    wm.createWindow(casted.window) catch return;
}

pub fn mapNotify(wm: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XMappingEvent, @ptrCast(event));
    _ = x.XRefreshKeyboardMapping(@constCast(casted));
    if (casted.request == x.MappingKeyboard) {
        wm.grabKeys();
    }
}

pub fn enterNotify(wm: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XEnterWindowEvent, @ptrCast(event));
    action.focus(wm, casted.window);
}

pub fn motionNotify(wm: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XMotionEvent, @ptrCast(event));
    // debug.print("MotionNotify: window={X}, root={X}, x={}, y={}\n", .{ casted.window, casted.root, casted.x, casted.y });
    action.moveWindow(wm, @intCast(casted.x), @intCast(casted.y));
    if ((casted.state & x.Button1MotionMask) > 0) {}
}

pub fn keyPress(wm: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XKeyPressedEvent, @ptrCast(event));
    wm.shortcut_handler(wm, casted);
}

pub fn buttonPress(_: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XButtonPressedEvent, @ptrCast(event));
    debug.print("ButtonPress: window={X}, button={}, state={b}, x={}, y={}\n", .{ casted.window, casted.button, casted.state, casted.x, casted.y });
}

pub fn buttonRelease(_: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XButtonReleasedEvent, @ptrCast(event));
    debug.print("ButtonRelease: window={X}, button={}, state={b}, x={}, y={}\n", .{ casted.window, casted.button, casted.state, casted.x, casted.y });
}

pub fn destroyNotify(wm: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XDestroyWindowEvent, @ptrCast(event));
    action.destroyWindow(wm, casted.window);
}
