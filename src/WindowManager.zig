const x11 = @import("X11.zig");
const Config = @import("Config.zig");
const Window = @import("Window.zig");
const layout = @import("layout.zig");
const plugin = @import("plugin.zig");
const util = @import("util.zig");
const Workspace = @import("Workspace.zig");

const handler = @import("handler.zig");

const std = @import("std");
const debug = std.debug;

// Singleton instance for the error handler,
// should not be fucked around with manually
const Self = @This();

var CURRENT: ?*Self = null;

pub const WM_EVENT_MASK = x11.SubstructureRedirectMask | x11.SubstructureNotifyMask | x11.ButtonPressMask | x11.ButtonReleaseMask | x11.KeyPressMask | x11.EnterWindowMask | x11.LeaveWindowMask | x11.FocusChangeMask | x11.PropertyChangeMask | x11.StructureNotifyMask | x11.PointerMotionMask;
pub const WINDOW_EVENT_MASK = x11.EnterWindowMask | x11.LeaveWindowMask;
pub const BITMASK = u9;
pub const NUM_WORKSPACES = @typeInfo(BITMASK).int.bits;
pub const NUM_CURSORS = 3;

pub const WindowList = std.DoublyLinkedList(Window);

pub const Error = error{
    AlreadyRunningWM,
    DisplayConnectionFailed,
    CursorInitFailed,
    AllocationFailed,
};

// Global error handler for x11 reported errors
fn xErrorHandler(_: ?*x11.Display, event: [*c]x11.XErrorEvent) callconv(.C) c_int {
    if (CURRENT) |wm| {
        wm.handleError(event);
    }

    return 0;
}

root: Window,
allocator: std.mem.Allocator,
display: *x11.Display,
config: *const Config,
running: bool,
screen: c_int,
windows: WindowList,
handlers: [x11.LASTEvent][]const *const fn (*Self, *const x11.XEvent) void,
shortcut_handler: *const fn (*Self, *const x11.XKeyEvent) void,
workspaces: [NUM_WORKSPACES]Workspace,
current_workspace: u8 = 0,

pub fn init(allocator: std.mem.Allocator, comptime config: *const Config) Self {
    return .{
        .root = undefined,
        .allocator = allocator,
        .running = false,
        .display = undefined,
        .screen = undefined,
        .config = config,
        .windows = .{},
        .handlers = comptime util.createHandlers(config.handlers),
        .shortcut_handler = comptime util.createShortcutHandler(config.shortcuts),
        .workspaces = init: {
            var ws: [NUM_WORKSPACES]Workspace = undefined;
            for (0..NUM_WORKSPACES) |i| {
                ws[i] = Workspace.init(allocator);
            }
            break :init ws;
        },
    };
}

pub fn deinit(self: *Self) void {
    for (&self.workspaces) |*workspace| {
        workspace.deinit();
    }
}

pub fn start(self: *Self) Error!void {
    CURRENT = self;
    try self.openDisplay();
    defer self.closeDisplay();

    self.initScreen();
    self.deinitScreen();

    try self.initInputs();

    self.initError();
    defer self.deinitError();

    self.grabKeys();

    self.running = true;

    _ = x11.XSync(self.display, x11.False);

    var event: x11.XEvent = undefined;
    while (self.running) {
        _ = x11.XNextEvent(self.display, &event);
        self.handleEvent(&event);
    }
}

// Display
fn openDisplay(self: *Self) Error!void {
    self.display = x11.XOpenDisplay(null) orelse {
        return Error.DisplayConnectionFailed;
    };
}

fn closeDisplay(self: *Self) void {
    _ = x11.XCloseDisplay(self.display);
}

// Screen
fn initScreen(self: *Self) void {
    self.screen = x11.XDefaultScreen(self.display);
    const x11_window = x11.XRootWindow(self.display, self.screen);
    self.root = Window.init(x11_window);
    self.root.updateAlignment(self.display) catch return;
}

fn deinitScreen(_: *Self) void {}

// Inputs
fn initInputs(self: *Self) Error!void {
    const result = x11.XSelectInput(self.display, self.root.handle, WM_EVENT_MASK);

    if (result == 0) {
        std.log.err("Failed to become window manager (another WM running?)\n", .{});
        return Error.AlreadyRunningWM;
    }
}

pub fn grabKeys(wm: *Self) void {
    var s: c_int = 0;
    var e: c_int = 0;
    var skip: c_int = 0;

    var syms: ?[*c]x11.KeySym = undefined;

    _ = x11.XUngrabKey(wm.display, x11.AnyKey, x11.AnyModifier, wm.root.handle);
    _ = x11.XDisplayKeycodes(wm.display, &s, &e);

    syms = x11.XGetKeyboardMapping(wm.display, @intCast(s), e - s + 1, &skip);

    var k: c_int = s;
    if (syms == null) return;

    while (k <= e) : (k += 1) {
        for (wm.config.shortcuts) |shortcut| {
            if (shortcut.key == syms.?[@intCast((k - s) * skip)]) {
                _ = x11.XGrabKey(wm.display, k, shortcut.mod, wm.root.handle, x11.True, x11.GrabModeAsync, x11.GrabModeAsync);
            }
        }
    }

    _ = x11.XFree(@ptrCast(syms));
}

// Error handling
fn initError(_: *Self) void {
    _ = x11.XSetErrorHandler(xErrorHandler);
}

fn deinitError(_: *Self) void {
    _ = x11.XSetErrorHandler(null);
}

fn handleError(self: *Self, event: *x11.XErrorEvent) void {
    var buffer: [256]u8 = .{0} ** 256;
    _ = x11.XGetErrorText(self.display, event.*.error_code, @ptrCast(&buffer), 256);

    std.log.err("X11 Error: {s} (code: {d})", .{ buffer, event.error_code });
    unreachable;
}

fn handleEvent(self: *Self, event: [*c]x11.XEvent) void {
    const event_index: usize = @intCast(event.*.type);
    for (self.handlers[event_index]) |f| {
        f(self, @ptrCast(event));
    }
}

pub fn currentWorkspace(self: *Self) *Workspace {
    return &self.workspaces[self.current_workspace];
}

fn getNodeByHandle(self: *Self, x11_window: x11.Window) ?*WindowList.Node {
    var it = self.windows.first;
    while (it) |node| : (it = node.next) {
        if (node.data.handle == x11_window) return node;
    }
    return null;
}

pub fn createWindow(self: *Self, x11_window: x11.Window) !void {
    if (self.getNodeByHandle(x11_window) != null) return;

    const node = try self.allocator.create(WindowList.Node);
    errdefer self.allocator.destroy(node);

    const window = Window.init(x11_window);
    try window.selectInput(self.display, WINDOW_EVENT_MASK);

    node.* = WindowList.Node{
        .data = window,
        .next = null,
        .prev = null,
    };

    node.data.selectInput(self.display, WINDOW_EVENT_MASK) catch unreachable;
    node.data.map(self.display) catch unreachable;

    self.windows.append(node);

    try self.currentWorkspace().tagWindow(&node.data);
    self.currentWorkspace().arrangeWindows(&self.root.alignment, self.display) catch unreachable;
}

pub fn destroyWindow(self: *Self, x11_window: x11.Window) !void {
    if (self.getNodeByHandle(x11_window)) |node| {
        for (&self.workspaces) |*workspace| {
            workspace.untagWindow(&node.data) catch continue;
        }

        self.windows.remove(node);
        try node.data.destroy(self.display);
        self.allocator.destroy(node);
    }
}
