const x11 = @import("X11.zig");
const Config = @import("Config.zig");
const window = @import("window.zig");
const layout = @import("layout.zig");
const plugin = @import("plugin.zig");
const util = @import("util.zig");
const Workspace = @import("Workspace.zig");
const bitmask = @import("bitmask.zig");

const handler = @import("handler.zig");

const std = @import("std");
const debug = std.debug;

const Allocator = std.mem.Allocator;

const ROOT_MASK = x11.SubstructureRedirectMask | x11.SubstructureNotifyMask;
const KEY_MASK = x11.KeyPressMask | x11.KeyReleaseMask;
const BUTTON_MASK = x11.ButtonPressMask | x11.KeyReleaseMask;
const NUM_EVENTS = x11.LASTEvent;
// pub const WM_EVENT_MASK = x11.SubstructureRedirectMask | x11.SubstructureNotifyMask | x11.ButtonPressMask | x11.ButtonReleaseMask | x11.KeyPressMask | x11.EnterWindowMask | x11.LeaveWindowMask | x11.FocusChangeMask | x11.PropertyChangeMask | x11.StructureNotifyMask;
// pub const WINDOW_EVENT_MASK = x11.EnterWindowMask | x11.LeaveWindowMask;

pub const Error = error{
    AlreadyRunningWM,
    DisplayConnectionFailed,
    CursorInitFailed,
    AllocationFailed,
};

// X11 style error handler
pub const ErrorHandler = fn (_: ?*x11.Display, _: [*c]x11.XErrorEvent) callconv(.C) c_int;

// TODO: refactor to a display struct
const Display = x11.Display;

const Screen = c_int;

// Describe the current wm state
const State = enum {
    initial,
    running,
    recover,
    stopping,
};

pub const Context = struct {
    ptr: *anyopaque,
    vtable: struct {
        createWindow: *const fn (ptr: *anyopaque, x11_window: x11.Window) Error!void,
        destroyWindow: *const fn (ptr: *anyopaque, x11_window: x11.Window) Error!void,
    },

    pub fn createWindow(self: Context, x11_window: x11.Window) Error!void {
        try self.vtable.createWindow(self.ptr, x11_window);
    }

    pub fn destroyWindow(self: Context, x11_window: x11.Window) Error!void {
        try self.vtable.destroyWindow(self.ptr, x11_window);
    }
};

pub fn WindowManager(comptime config: Config) type {
    const Mask = util.requireUnsignedInt(config.workspaces);
    const WorkspaceMask = bitmask.Mask(Mask);
    const Window = window.Window(Mask);
    const WindowList = std.DoublyLinkedList(Window);

    return struct {
        allocator: std.mem.Allocator,

        // Root window on the current screen
        root: Window,

        // Current x11 display
        display: *Display,

        // Current x11 screen
        screen: Screen,

        // List of active windows
        windows: WindowList,

        // A bitmask representing all the active workspaces
        workspace_mask: WorkspaceMask,

        // Error handler
        // error_handler: comptime
        state: State,

        // For each XEvent we allocate space for the handlers
        const event_handlers = util.createEventHandlers(config.handlers);

        // A shortcut handler which will execute the actions associated to the shortcuts
        const shortcut_handler = util.createShortcutHandler(config.shortcuts);

        // Global reference to the current window manager for error handling
        var global: ?*Self = null;

        const Self = @This();

        pub fn init(allocator: Allocator) !Self {
            // Open connection to the x11 server
            const display = try x11.openDisplay(null);

            // Get the default screen
            const screen = x11.XDefaultScreen(display);

            // Get the root window
            const x11_window = x11.XRootWindow(display, screen);
            const root = Window.init(x11_window);

            return Self{
                .allocator = allocator,
                .root = root,
                .display = display,
                .screen = screen,
                .windows = .{},
                .workspace_mask = WorkspaceMask.init(0),
                .state = .initial,
            };
        }

        pub fn deinit(self: *Self) void {
            _ = x11.XCloseDisplay(self.display);
            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                self.allocator.destroy(node);
            }
        }

        // Start the window manager and listen for events
        pub fn start(self: *Self) !void {

            // Setup singleton
            Self.global = self;
            defer Self.global = null;

            // TODO: Configure error handler
            _ = x11.XSetErrorHandler(Self.x11ErrorHandler);

            // Select input
            try self.root.selectInput(self.display, ROOT_MASK);
            _ = x11.XSync(self.display, x11.False);

            var event: x11.XEvent = undefined;
            while (self.state == .running) {
                _ = x11.XNextEvent(self.display, &event);
                try self.handleEvent(&event);
            }

            if (self.state == .recover) self.recover();
        }

        fn recover(_: *Self) void {
            //TODO: Recover from error and restart
        }

        fn handleError(self: *Self, _: ?*x11.Display, _: [*c]x11.XErrorEvent) void {
            std.log.err("in error handler", .{});
            switch (self.state) {
                .initial => {
                    self.state = .stopping;
                    std.log.err("Another wm is running", .{});
                },
                .running => unreachable,
                .recover => unreachable,
                .stopping => {},
            }
        }

        fn handleEvent(self: *Self, event: *x11.XEvent) Error!void {
            const event_index: usize = @intCast(event.*.type);
            for (Self.event_handlers[event_index]) |f| {
                try f(&self.context(), @ptrCast(event));
            }
        }

        pub fn context(self: *Self) Context {
            return Context{
                .ptr = self,
                .vtable = .{
                    .createWindow = createWindow,
                    .destroyWindow = destroyWindow,
                },
            };
        }

        fn createWindow(ptr: *anyopaque, _: x11.Window) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            _ = self;
        }

        fn destroyWindow(_: *anyopaque, _: x11.Window) Error!void {}

        fn x11ErrorHandler(display: ?*x11.Display, event: [*c]x11.XErrorEvent) callconv(.C) c_int {
            if (Self.global) |wm| {
                wm.handleError(display, event);
            }
            return 0;
        }
    };
}

// // Inputs
// fn initInputs(self: *Self) Error!void {
//     const result = x11.XSelectInput(self.display, self.root.handle, WM_EVENT_MASK);

//     if (result == 0) {
//         std.log.err("Failed to become window manager (another WM running?)\n", .{});
//         return Error.AlreadyRunningWM;
//     }
// }

// pub fn grabButtons(_: *Self) void {}

// pub fn grabKeys(wm: *Self) void {
//     var s: c_int = 0;
//     var e: c_int = 0;
//     var skip: c_int = 0;

//     var syms: ?[*c]x11.KeySym = undefined;

//     _ = x11.XUngrabKey(wm.display, x11.AnyKey, x11.AnyModifier, wm.root.handle);
//     _ = x11.XDisplayKeycodes(wm.display, &s, &e);

//     syms = x11.XGetKeyboardMapping(wm.display, @intCast(s), e - s + 1, &skip);

//     var k: c_int = s;
//     if (syms == null) return;

//     while (k <= e) : (k += 1) {
//         for (wm.config.shortcuts) |shortcut| {
//             if (shortcut.key == syms.?[@intCast((k - s) * skip)]) {
//                 _ = x11.XGrabKey(wm.display, k, shortcut.mod, wm.root.handle, x11.True, x11.GrabModeAsync, x11.GrabModeAsync);
//             }
//         }
//     }

//     _ = x11.XFree(@ptrCast(syms));
// }

// // Error handling
// fn initError(_: *Self) void {
//     _ = x11.XSetErrorHandler(xErrorHandler);
// }

// fn deinitError(_: *Self) void {
//     _ = x11.XSetErrorHandler(null);
// }

// fn handleError(self: *Self, event: *x11.XErrorEvent) void {
//     var buffer: [256]u8 = .{0} ** 256;
//     _ = x11.XGetErrorText(self.display, event.*.error_code, @ptrCast(&buffer), 256);

//     std.log.err("X11 Error: {s} (code: {d})", .{ buffer, event.error_code });
//     unreachable;
// }

// fn handleEvent(self: *Self, event: [*c]x11.XEvent) void {
//     const event_index: usize = @intCast(event.*.type);
//     for (self.handlers[event_index]) |f| {
//         f(self, @ptrCast(event));
//     }
// }

// pub fn currentWorkspace(self: *Self) *Workspace {
//     return &self.workspaces[self.current_workspace];
// }

// fn getNodeByHandle(self: *Self, x11_window: x11.Window) ?*WindowList.Node {
//     var it = self.windows.first;
//     while (it) |node| : (it = node.next) {
//         if (node.data.handle == x11_window) return node;
//     }
//     return null;
// }

// pub fn createWindow(self: *Self, x11_window: x11.Window) !void {
//     if (self.getNodeByHandle(x11_window) != null) return;

//     const node = try self.allocator.create(WindowList.Node);
//     errdefer self.allocator.destroy(node);

//     const window = Window.init(x11_window);
//     try window.selectInput(self.display, WINDOW_EVENT_MASK);

//     node.* = WindowList.Node{
//         .data = window,
//         .next = null,
//         .prev = null,
//     };

//     node.data.selectInput(self.display, WINDOW_EVENT_MASK) catch unreachable;
//     node.data.map(self.display) catch unreachable;

//     self.windows.append(node);

//     try self.currentWorkspace().tagWindow(&node.data);
//     self.currentWorkspace().arrangeWindows(&self.root.alignment, self.display) catch unreachable;
// }

// pub fn destroyWindow(self: *Self, x11_window: x11.Window) !void {
//     if (self.getNodeByHandle(x11_window)) |node| {
//         for (&self.workspaces) |*workspace| {
//             workspace.untagWindow(&node.data) catch continue;
//         }

//         self.windows.remove(node);
//         try node.data.destroy(self.display);
//         self.allocator.destroy(node);
//     }
// }
