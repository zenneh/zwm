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
    debug.print("MapRequest: window={X}, parent={X}\n", .{ casted.window, casted.parent });

    action.createWindow(wm, casted.window);
    action.focusPrev(wm);
    action.view(wm, wm.current_workspace);
}

pub fn mapNotify(wm: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XMappingEvent, @ptrCast(event));
    debug.print("MapNotify: window={X}\n", .{casted.window});

    _ = x.XRefreshKeyboardMapping(@constCast(casted));
    if (casted.request == x.MappingKeyboard) {
        wm.grabKeys();
    }
}

pub fn enterNotify(_: *WM, event: *const x.XEnterWindowEvent) void {
    debug.print("EnterNotify: window={X}, root={X}, x={}, y={}\n", .{ event.window, event.root, event.x, event.y });
}

pub fn motionNotify(_: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XMotionEvent, @ptrCast(event));
    debug.print("MotionNotify: window={X}, root={X}, x={}, y={}\n", .{ casted.window, casted.root, casted.x, casted.y });
}

pub fn keyPress(wm: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XKeyPressedEvent, @ptrCast(event));
    debug.print("KeyPress: window={X}, keycode={}, state={b}\n", .{ casted.window, casted.keycode, casted.state });
    wm.shortcut_dispatcher(wm, casted);
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
