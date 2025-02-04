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

fn Action(comptime F: type) type {
    return struct {
        func: F,
        args: std.meta.ArgsTuple(F),
    };
}

// Helper to create an action entry with type checking
pub fn ActionEntry(
    comptime modifier: u8,
    comptime key: u8,
    comptime func: anytype,
    comptime args: anytype,
) type {
    const F = @TypeOf(func);
    const ArgsTuple = std.meta.ArgsTuple(F);
    const ProvidedArgs = @TypeOf(args);
    comptime {
        const expected_fields = @typeInfo(ArgsTuple).Struct.fields;
        const provided_fields = @typeInfo(ProvidedArgs).Struct.fields;

        if (expected_fields.len != provided_fields.len) {
            @compileError(std.fmt.comptimePrint("Wrong number of arguments. Expected {d} arguments, got {d}", .{ expected_fields, provided_fields }));
        }
        for (expected_fields, provided_fields) |exp, prov| {
            if (exp.type != prov.type) {
                @compileError(std.fmt.comptimePrint("Type mismatch for argument {s}. Expected {}, got {}", .{ exp.name, exp.type, prov.type }));
            }
        }
    }

    return struct {
        pub const mod = modifier;
        pub const keycode = key;

        pub fn invoke() void {
            @call(.auto, func, args);
        }
    };
}

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
