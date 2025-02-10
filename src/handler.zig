const WM = @import("WindowManager.zig");
const x11 = @import("X11.zig");

const std = @import("std");
const debug = std.debug;
const action = @import("action.zig");
const util = @import("util.zig");

pub const Handler = *const fn (wm: *WM, event: *const x11.XEvent) void;

pub const HandlerEntry = struct {
    event: c_int,
    handlers: []const Handler,
};

pub fn mapRequest(wm: *WM, event: *const x11.XEvent) void {
    const casted = @as(*const x11.XMapRequestEvent, @ptrCast(event));
    wm.createWindow(casted.window) catch return;
}

pub fn mapNotify(wm: *WM, event: *const x11.XEvent) void {
    const casted = @as(*const x11.XMappingEvent, @ptrCast(event));
    _ = x11.XRefreshKeyboardMapping(@constCast(casted));
    if (casted.request == x11.MappingKeyboard) {
        wm.grabKeys();
    }
}

pub fn enterNotify(wm: *WM, event: *const x11.XEvent) void {
    const casted = @as(*const x11.XEnterWindowEvent, @ptrCast(event));
    action.focus(wm, casted.window);
}

pub fn motionNotify(wm: *WM, event: *const x11.XEvent) void {
    const casted = @as(*const x11.XMotionEvent, @ptrCast(event));
    debug.print("MotionNotify: window={X}, root={X}, x={}, y={}\n", .{ casted.window, casted.root, casted.x, casted.y });
    action.moveWindow(wm, casted.x, casted.y);
}

pub fn keyPress(wm: *WM, event: *const x11.XEvent) void {
    const casted = @as(*const x11.XKeyPressedEvent, @ptrCast(event));
    wm.shortcut_handler(wm, casted);
}

pub fn buttonPress(wm: *WM, event: *const x11.XEvent) void {
    const casted = @as(*const x11.XButtonPressedEvent, @ptrCast(event));
    debug.print("ButtonPress: window={X}, button={}, state={b}, x={}, y={}\n", .{ casted.window, casted.button, casted.state, casted.x, casted.y });
    wm.input_state = .{ .x = casted.x, .y = casted.y };
    std.log.info("input state set {any}", .{wm.input_state});
    // 	if (XGrabPointer(dpy, root, False, MOUSEMASK, GrabModeAsync, GrabModeAsync,
    // None, cursor[CurMove]->cursor, CurrentTime) != GrabSuccess)

    const mask = x11.ButtonPressMask | x11.ButtonReleaseMask | x11.PointerMotionMask;
    _ = x11.XGrabPointer(wm.display, wm.root.handle, x11.False, mask, x11.GrabModeAsync, x11.GrabModeAsync, x11.None, x11.None, x11.CurrentTime);
}

pub fn buttonRelease(wm: *WM, event: *const x11.XEvent) void {
    const casted = @as(*const x11.XButtonReleasedEvent, @ptrCast(event));
    debug.print("ButtonRelease: window={X}, button={}, state={b}, x={}, y={}\n", .{ casted.window, casted.button, casted.state, casted.x, casted.y });
    wm.input_state = null;
    _ = x11.XUngrabPointer(wm.display, x11.CurrentTime);
}

pub fn destroyNotify(wm: *WM, event: *const x11.XEvent) void {
    const casted = @as(*const x11.XDestroyWindowEvent, @ptrCast(event));
    action.destroyWindow(wm, casted.window);
}
