const WM = @import("WindowManager.zig");
const x = @import("X11.zig");

const std = @import("std");
const debug = std.debug;

pub fn getWindow(windows: *WM.WindowList, window_id: c_ulong) ?*WM.Window {
    var current = windows.first;
    while (current) |node| {
        if (node.data.window == window_id) return &node.data;
        current = node.next;
    }

    return null;
}

pub fn mapRequest(wm: *WM, event: *const x.XEvent) void {
    const e = @as(*const x.XMapRequestEvent, @ptrCast(event));
    debug.print("MapRequest: window={X}, parent={X}\n", .{ e.window, e.parent });

    if (getWindow(&wm.windows, e.window)) |window| {
        window.map(wm.display);
        return;
    }

    const w = WM.Window{
        .window = e.window,
    };

    const node = wm.alloc.create(WM.WindowList.Node) catch unreachable;
    node.* = WM.WindowList.Node{
        .data = w,
    };

    wm.windows.prepend(node);

    node.data.map(wm.display);
    node.data.selectInput(wm.display);
}

pub fn mapNotify(_: *WM, event: *const x.XMapEvent) void {
    debug.print("MapNotify: window={X}, event={X}, override_redirect={}\n", .{ event.window, event.event, event.override_redirect });
}

pub fn enterNotify(_: *WM, event: *const x.XEnterWindowEvent) void {
    debug.print("EnterNotify: window={X}, root={X}, x={}, y={}\n", .{ event.window, event.root, event.x, event.y });
}

pub fn keyPress(wm: *WM, event: *const x.XEvent) void {
    const casted = @as(*const x.XKeyPressedEvent, @ptrCast(event));
    debug.print("KeyPress: window={X}, keycode={}, state={b}\n", .{ casted.window, casted.keycode, casted.state });
    // const keysym = x.XKeycodeToKeysym(wm.display, @as(x.KeyCode, @truncate(casted.keycode)), 0);
    wm.shortcut_dispatcher(wm, casted);
}

pub fn buttonPress(_: *WM, _: *const x.XButtonEvent) void {
    // const casted = @as(*const x.button, @ptrCast(event));
    // debug.print("ButtonPress: window={X}, button={}, state={b}, x={}, y={}\n", .{ event.window, event.button, event.state, event.x, event.y });
}
