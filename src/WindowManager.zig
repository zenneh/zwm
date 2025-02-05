const x = @import("X11.zig");
const Config = @import("Config.zig");
const window = @import("Window.zig");
const layout = @import("layout.zig");
const plugin = @import("plugin.zig");
const util = @import("util.zig");
const Workspace = @import("Workspace.zig");

const std = @import("std");
const Alloc = std.mem.Allocator;
const debug = std.debug;

// Singleton instance for the error handler,
// should not be fucked around with manually
const WM = @This();

var CURRENT: ?*WM = null;

pub const EVENT_MASK = x.SubstructureRedirectMask | x.SubstructureNotifyMask | x.ButtonPressMask | x.KeyPressMask | x.EnterWindowMask | x.FocusChangeMask | x.EnterWindowMask;
pub const BITMASK = u9;
pub const NUM_WORKSPACES = @typeInfo(BITMASK).Int.bits;
pub const NUM_CURSORS = 3;

pub const Window = window.Window(BITMASK);
pub const WindowList = std.SinglyLinkedList(Window);
pub const Handler = *const fn (wm: *WM, event: *const x.XEvent) void;
pub const HandlerEntry = struct {
    event: c_int,
    handlers: []const Handler,
};

pub const LocalHandler = *const fn (wm: *WM, event: *const x.XEvent) void;

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

root: x.Window,
alloc: Alloc,
display: *x.Display,
config: *const Config,
running: bool,
screen: c_int,
windows: WindowList,
handlers: [x.LASTEvent][]const LocalHandler,
shortcut_dispatcher: *const fn (*WM, *const x.XKeyEvent) void,
workspaces: [NUM_WORKSPACES]Workspace,
current_workspace: u8 = 0,
current_window: ?*Window = null,

pub fn init(alloc: Alloc, comptime config: *const Config) WM {
    return .{
        .root = undefined,
        .alloc = alloc,
        .running = false,
        .display = undefined,
        .screen = undefined,
        .config = config,
        .windows = .{},
        .handlers = comptime util.createHandlers(config.handlers),
        .shortcut_dispatcher = comptime util.handleKeyPress(config.shortcuts),
        .workspaces = init: {
            var ws: [NUM_WORKSPACES]Workspace = undefined;
            for (0..NUM_WORKSPACES) |i| {
                ws[i] = Workspace.init(alloc, config.default_layout);
            }
            break :init ws;
        },
    };
}

pub fn deinit(_: *WM) void {}

pub fn start(self: *WM) Error!void {
    try self.openDisplay();
    defer self.closeDisplay();

    self.initScreen();
    self.deinitScreen();

    try self.initInputs();

    self.initError();
    defer self.deinitError();

    self.running = true;

    _ = x.XSync(self.display, x.False);

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

fn handleEvent(self: *WM, event: [*c]x.XEvent) void {
    const event_index: usize = @intCast(event.*.type);
    for (self.handlers[event_index]) |handler| {
        handler(self, @ptrCast(event));
    }
}

pub fn check(self: *WM) void {
    std.debug.print("Called from keyboard shortcut\n", .{});
    for (&self.workspaces, 0..) |*workspace, i| {
        std.debug.print("Workspace {}: \n", .{i});
        for (workspace.windows.items) |w| {
            std.debug.print("\twindow {}:{b}\n", .{ w.window, w.mask.mask });
        }
    }
}
