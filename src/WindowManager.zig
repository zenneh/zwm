const x = @import("X11.zig");
const Config = @import("Config.zig");
const window = @import("Window.zig");
const layout = @import("layout.zig");
const plugin = @import("plugin.zig");

const std = @import("std");
const Alloc = std.heap.GeneralPurposeAllocator(.{}){};

// Singleton instance for the error handler,
// should not be fucked around with manually
var CURRENT: ?*WM = null;

const EVENT_MASK = x.SubstructureRedirectMask | x.SubstructureNotifyMask | x.ButtonPressMask | x.KeyPressMask | x.EnterWindowMask | x.FocusChangeMask | x.EnterWindowMask;

const NUM_CURSORS = 3;

// The amount of bits reserved for the mask
const BITMASK = u9;

pub const Error = error{
    AlreadyRunningWM,
    DisplayConnectionFailed,
    CursorInitFailed,
    AllocationFailed,
};

// Global error handler for x11 reported errors
fn xErrorHandler(_: ?*x.Display, event: [*c]x.XErrorEvent) callconv(.C) c_int {
    if (CURRENT) |wm| {
        wm.handleError(event);
    }

    return 0;
}

pub fn wima(comptime config: *const Config) type {
    return struct {
        pm: plugin.PluginManager(config.plugins) = .{},
        a: i32 = 0,
    };
}

const WM = @This();

root: x.Window,
// alloc: std.mem.Allocator,
display: *x.Display,
config: *const Config,
running: bool,
screen: c_int,
windows: std.SinglyLinkedList(window.Window(BITMASK)),

pub fn init(comptime config: *const Config) WM {
    return .{
        .root = undefined,
        // .alloc = Alloc.allocator(),
        .running = false,
        .display = undefined,
        .screen = undefined,
        .config = config,
        .windows = .{},
        // .plugins = plugin.PluginManager(config.plugins),
    };
}

pub fn deinit(_: *WM) void {
    CURRENT = null;
}

pub fn start(self: *WM) Error!void {
    try self.openDisplay();
    defer self.closeDisplay();

    self.initScreen();
    self.deinitScreen();

    try self.initInputs();

    self.initError();
    defer self.deinitError();

    self.running = true;
    CURRENT = self;

    var event: x.XEvent = undefined;
    while (self.running) {
        _ = x.XNextEvent(self.display, &event);
        self.handleEvent(&event);
    }
}

// Display
fn openDisplay(self: *WM) Error!void {
    self.display = x.XOpenDisplay(null) orelse {
        return Error.DisplayConnectionFailed;
    };
}

fn closeDisplay(self: *WM) void {
    _ = x.XCloseDisplay(self.display);
}

// Screen
fn initScreen(self: *WM) void {
    self.screen = x.XDefaultScreen(self.display);
    self.root = x.XRootWindow(self.display, self.screen);
}

fn deinitScreen(_: *WM) void {}

// Inputs
fn initInputs(self: *WM) Error!void {
    const result = x.XSelectInput(self.display, self.root, EVENT_MASK);

    if (result == 0) {
        std.log.err("Failed to become window manager (another WM running?)\n", .{});
        return Error.AlreadyRunningWM;
    }
}

// Error handling
fn initError(_: *WM) void {
    _ = x.XSetErrorHandler(xErrorHandler);
}

fn deinitError(_: *WM) void {
    _ = x.XSetErrorHandler(null);
}

fn handleError(_: *WM, err: *x.XErrorEvent) void {
    std.log.err("X11 Error: {d}", .{err.error_code});
    unreachable;
}

fn handleEvent(_: *WM, event: [*c]x.XEvent) void {
    const debug = std.debug;

    switch (event.*.type) {
        // MapRequest is sent when a client attempts to map a window.
        x.MapRequest => {
            const map_event = @as(*x.XMapRequestEvent, @ptrCast(event));
            debug.print("MapRequest: window={X}, parent={X}\n", .{ map_event.window, map_event.parent });
        },

        // MapNotify is sent when a window is actually mapped (becomes visible)
        x.MapNotify => {
            const notify_event = @as(*x.XMapEvent, @ptrCast(event));
            debug.print("MapNotify: window={X}, event={X}, override_redirect={}\n", .{ notify_event.window, notify_event.event, notify_event.override_redirect });
        },

        // EnterNotify is sent when the pointer enters a window
        x.EnterNotify => {
            const enter_event = @as(*x.XEnterWindowEvent, @ptrCast(event));
            debug.print("EnterNotify: window={X}, root={X}, x={}, y={}\n", .{ enter_event.window, enter_event.root, enter_event.x, enter_event.y });
        },

        // LeaveNotify is sent when the pointer leaves a window
        x.LeaveNotify => {
            const leave_event = @as(*x.XLeaveWindowEvent, @ptrCast(event));
            debug.print("LeaveNotify: window={X}, root={X}, x={}, y={}\n", .{ leave_event.window, leave_event.root, leave_event.x, leave_event.y });
        },

        // ButtonPress is sent when a mouse button is pressed
        x.ButtonPress => {
            const button_event = @as(*x.XButtonEvent, @ptrCast(event));
            debug.print("ButtonPress: window={X}, button={}, state={b}, x={}, y={}\n", .{ button_event.window, button_event.button, button_event.state, button_event.x, button_event.y });
        },

        // FocusIn is sent when a window gains input focus
        x.FocusIn => {
            const focus_event = @as(*x.XFocusChangeEvent, @ptrCast(event));
            debug.print("FocusIn: window={X}, mode={}, detail={}\n", .{ focus_event.window, focus_event.mode, focus_event.detail });
        },

        // FocusOut is sent when a window loses input focus
        x.FocusOut => {
            const focus_event = @as(*x.XFocusChangeEvent, @ptrCast(event));
            debug.print("FocusOut: window={X}, mode={}, detail={}\n", .{ focus_event.window, focus_event.mode, focus_event.detail });
        },

        // KeyPress is sent when a key is pressed
        x.KeyPress => {
            const key_event = @as(*x.XKeyEvent, @ptrCast(event));
            debug.print("KeyPress: window={X}, keycode={}, state={b}\n", .{ key_event.window, key_event.keycode, key_event.state });
        },

        // Handle any other events
        else => {
            debug.print("Unhandled event type: {}\n", .{event.*.type});
        },
    }
}
