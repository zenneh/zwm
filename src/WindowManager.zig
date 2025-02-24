const x11 = @import("X11.zig");
const Config = @import("Config.zig");
const _window = @import("window.zig");
const _layout = @import("layout.zig");
const plugin = @import("plugin.zig");
const util = @import("util.zig");
const bitmask = @import("bitmask.zig");
const _workspace = @import("workspace.zig");

const handler = @import("handler.zig");

const std = @import("std");
const debug = std.debug;

const Allocator = std.mem.Allocator;

const ROOT_MASK = x11.SubstructureRedirectMask | x11.SubstructureNotifyMask | x11.ButtonPressMask | x11.ButtonReleaseMask | x11.EnterWindowMask;
pub const WINDOW_MASK = x11.EnterWindowMask | x11.LeaveWindowMask;
const KEY_MASK = x11.KeyPressMask | x11.KeyReleaseMask;
const BUTTON_MASK = x11.ButtonPressMask | x11.ButtonReleaseMask;
const POINTER_MASK = x11.PointerMotionMask | BUTTON_MASK;
const NUM_EVENTS = x11.LASTEvent;

pub const Error = error{
    AlreadyRunningWM,
    DisplayConnectionFailed,
    CursorInitFailed,
    AllocationFailed,
} || std.mem.Allocator.Error || _window.Error || std.io.AnyWriter.Error;

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

const Input = union(enum) {
    default,
    pointer: _layout.Pos,
};

const Action = union(enum) {
    arrange,
    move,
    resize,
};

pub const Context = struct {
    ptr: *anyopaque,

    vtable: struct {
        createWindow: *const fn (ptr: *anyopaque, x11_window: x11.Window) Error!void,
        destroyWindow: *const fn (ptr: *anyopaque, x11_window: x11.Window) Error!void,
        handleKeyEvent: *const fn (ptr: *anyopaque, event: *const x11.XKeyEvent) Error!void,
        handleButtonEvent: *const fn (ptr: *anyopaque, event: *const x11.XButtonEvent) Error!void,
        viewWorkspace: *const fn (ptr: *anyopaque, index: usize) Error!void,
        tagWindow: *const fn (ptr: *anyopaque, index: usize) Error!void,
        toggleTagWindow: *const fn (ptr: *anyopaque, index: usize) Error!void,
        toggleMode: *const fn (ptr: *anyopaque, mode: _window.Mode) Error!void,

        moveWindow: *const fn (ptr: *anyopaque, pos: _layout.Pos) Error!void,
        resizeWindow: *const fn (ptr: *anyopaque, pos: _layout.Pos) Error!void,

        setInput: *const fn (ptr: *anyopaque, mode: Input) Error!void,
        setAction: *const fn (ptr: *anyopaque, mode: Action) Error!void,

        check: *const fn (ptr: *anyopaque) Error!void,
        focusWindow: *const fn (ptr: *anyopaque, x11_window: x11.Window) Error!void,
        focusNextWindow: *const fn (ptr: *anyopaque) Error!void,
        focusPrevWindow: *const fn (ptr: *anyopaque) Error!void,
        setLayout: *const fn (ptr: *anyopaque, l: *const _layout.Layout) Error!void,
        incrementMaster: *const fn (ptr: *anyopaque, amount: i8) Error!void,
        incrementGapsize: *const fn (ptr: *anyopaque, amount: i8) Error!void,

        process: *const fn (ptr: *anyopaque, args: []const []const u8) Error!void,
        kill: *const fn (ptr: *anyopaque) Error!void,
    },

    display: *Display,

    root: c_ulong,

    input: Input,

    action: Action,

    pub fn toggleMode(self: Context, mode: _window.Mode) Error!void {
        try self.vtable.toggleMode(self.ptr, mode);
    }

    pub fn moveWindow(self: Context, pos: _layout.Pos) Error!void {
        try self.vtable.moveWindow(self.ptr, pos);
    }
    pub fn resizeWindow(self: Context, pos: _layout.Pos) Error!void {
        try self.vtable.resizeWindow(self.ptr, pos);
    }

    pub fn setInput(self: Context, mode: Input) Error!void {
        try self.vtable.setInput(self.ptr, mode);
    }

    pub fn setAction(self: Context, mode: Action) Error!void {
        try self.vtable.setAction(self.ptr, mode);
    }

    pub fn createWindow(self: Context, x11_window: x11.Window) Error!void {
        try self.vtable.createWindow(self.ptr, x11_window);
    }

    pub fn destroyWindow(self: Context, x11_window: x11.Window) Error!void {
        try self.vtable.destroyWindow(self.ptr, x11_window);
    }

    pub fn focusWindow(self: Context, x11_window: x11.Window) Error!void {
        try self.vtable.focusWindow(self.ptr, x11_window);
    }

    pub fn handleKeyEvent(self: Context, event: *const x11.XKeyEvent) Error!void {
        try self.vtable.handleKeyEvent(self.ptr, event);
    }

    pub fn handleButtonEvent(self: Context, event: *const x11.XButtonEvent) Error!void {
        try self.vtable.handleButtonEvent(self.ptr, event);
    }

    pub fn viewWorkspace(self: Context, index: usize) Error!void {
        try self.vtable.viewWorkspace(self.ptr, index);
    }

    pub fn tagWindow(self: Context, index: usize) Error!void {
        try self.vtable.tagWindow(self.ptr, index);
    }

    pub fn toggleTagWindow(self: Context, index: usize) Error!void {
        try self.vtable.toggleTagWindow(self.ptr, index);
    }

    pub fn check(self: Context) Error!void {
        try self.vtable.check(self.ptr);
    }

    pub fn focusNextWindow(self: Context) Error!void {
        try self.vtable.focusNextWindow(self.ptr);
    }

    pub fn focusPrevWindow(self: Context) Error!void {
        try self.vtable.focusPrevWindow(self.ptr);
    }

    pub fn setLayout(self: Context, l: *const _layout.Layout) Error!void {
        try self.vtable.setLayout(self.ptr, l);
    }

    pub fn incrementMaster(self: *Context, amount: i8) Error!void {
        try self.vtable.incrementMaster(self.ptr, amount);
    }
    pub fn incrementGapsize(self: *Context, amount: i8) Error!void {
        try self.vtable.incrementGapsize(self.ptr, amount);
    }
    pub fn process(self: *Context, args: []const []const u8) Error!void {
        try self.vtable.process(self.ptr, args);
    }
    pub fn kill(self: *Context) Error!void {
        try self.vtable.kill(self.ptr);
    }
};

pub fn WindowManager(comptime config: Config) type {
    const Mask = util.requireUnsignedInt(config.workspaces);
    const WorkspaceMask = bitmask.Mask(Mask);
    const Window = _window.Window(Mask);
    const WindowList = std.DoublyLinkedList(Window);
    const CurrentWorkspace = util.createCurrentWorkspaceType(Mask);
    const Workspace = _workspace.Workspace(Mask);

    const BITSIZE = @bitSizeOf(config.workspaces);

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

        // All the workspaces
        workspaces: [BITSIZE]Workspace,

        // Reference to the current workspace
        current_workspace: CurrentWorkspace,

        // Error handler
        // error_handler: comptime
        state: State,

        // Input state for handling resizing and moving
        input: Input,

        // Action state for handling tiling, resizing and moving
        action: Action,

        // Size of gaps to display in layouts
        gapsize: u8,

        // For each XEvent we allocate space for the handlers
        const event_handlers = util.createEventHandlers(config.handlers);

        // A shortcut handler which will execute the actions associated to the shortcuts
        const key_handler = util.createKeyShortcutHandler(config.keys);

        const button_handler = util.createButtonShortcutHandler(config.buttons);

        // How many events are being processed per second
        const event_fps: f64 = config.event_fps;

        // Layouts
        var layouts = util.createLayouts(Mask, config.layout);

        // Master counts
        var master_counts = util.createMasterCounts(Mask);

        // Global reference to the current window manager for error handling
        var global: ?*Self = null;

        const keys = config.keys;
        const buttons = config.buttons;

        const Self = @This();

        pub fn init(allocator: Allocator) !Self {
            // Open connection to the x11 server
            const display = try x11.openDisplay(null);

            // Get the default screen
            const screen = x11.XDefaultScreen(display);

            // Get the root window
            const x11_window = x11.XRootWindow(display, screen);
            var root = Window.init(x11_window);
            try root.updateAlignment(display);

            return Self{
                .allocator = allocator,
                .root = root,
                .display = display,
                .screen = screen,
                .windows = .{},
                .workspace_mask = WorkspaceMask.init(0),
                .current_workspace = 0,
                .state = .initial,
                .input = .default,
                .action = .arrange,
                .gapsize = config.gapsize,
                .workspaces = .{Workspace.init(allocator, config.layout)} ** BITSIZE,
            };
        }

        pub fn deinit(self: *Self) void {
            _ = x11.XCloseDisplay(self.display);
            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                self.allocator.destroy(node);
            }

            for (&self.workspaces) |*workspace| {
                workspace.deinit();
            }
        }

        // Start the window manager and listen for events
        pub fn start(self: *Self) !void {
            try self.setup();

            var event: x11.XEvent = undefined;
            while (self.state == .running) {
                _ = x11.XNextEvent(self.display, &event);
                try self.handleEvent(&event);
            }

            if (self.state == .recover) self.recover();
        }

        fn setup(self: *Self) Error!void {
            // Setup singleton
            Self.global = self;
            defer Self.global = null;

            // Configure error handler
            _ = x11.XSetErrorHandler(Self.x11ErrorHandler);

            // Select input
            try self.root.selectInput(self.display, ROOT_MASK);
            self.sync();

            self.grabKeys();

            self.state = .running;
        }

        fn recover(_: *Self) void {
            //TODO: Recover from error and restart
        }

        fn sync(self: *Self) void {
            _ = x11.XSync(self.display, x11.False);
        }

        fn handleError(self: *Self, _: ?*x11.Display, event: [*c]x11.XErrorEvent) void {
            var buff: [256]u8 = undefined;
            _ = x11.XGetErrorText(self.display, event.*.error_code, &buff, buff.len);

            std.log.err("{s}", .{buff});

            switch (self.state) {
                .initial => {
                    self.state = .stopping;
                    std.log.err("Failed to become window manager (another WM running?)\n", .{});
                },
                .running => self.state = .recover,
                else => return,
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
                .action = self.action,
                .input = self.input,
                .display = self.display,
                .root = self.root.handle,
                .ptr = self,
                .vtable = .{
                    .setInput = setInput,
                    .setAction = setAction,
                    .createWindow = createWindow,
                    .moveWindow = moveWindow,
                    .resizeWindow = resizeWindow,
                    .focusWindow = focusWindow,
                    .toggleMode = toggleMode,
                    .destroyWindow = destroyWindow,
                    .handleKeyEvent = handleKeyEvent,
                    .handleButtonEvent = handleButtonEvent,
                    .viewWorkspace = viewWorkspace,
                    .tagWindow = tagWindow,
                    .toggleTagWindow = toggleTagWindow,
                    .check = check,
                    .focusNextWindow = focusNextWindow,
                    .focusPrevWindow = focusPrevWindow,
                    .setLayout = setLayout,
                    .incrementMaster = incrementMaster,
                    .incrementGapsize = incrementGapsize,
                    .process = process,
                    .kill = kill,
                },
            };
        }

        fn arrange(self: *Self) Error!void {
            try self.getCurrentWorkspace().arrange(self.gapsize, self.root.alignment, self.display);
            try self.restack();

            self.sync();
        }

        fn restack(
            self: *Self,
        ) Error!void {
            try self.getCurrentWorkspace().restack(self.root.handle, self.display);
        }

        fn findWindowNodeByHandle(self: *Self, x11_window: x11.Window) ?*WindowList.Node {
            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                if (node.data.handle == x11_window) return node;
            }

            return null;
        }

        fn findFirstActiveNode(self: *Self) ?*WindowList.Node {
            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                if (node.data.mask.has(self.current_workspace)) return node;
            }

            return null;
        }

        fn toggleMode(ptr: *anyopaque, mode: _window.Mode) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            const node = self.getCurrentWorkspace().current_window orelse return;
            node.data.ptr.setMode(mode);
            try self.arrange();
        }

        fn focus(self: *Self) Error!void {
            const workspace = self.getCurrentWorkspace();

            try workspace.focus(self.display);
            if (workspace.getCurrentWindow()) |window| {
                self.grabButtons(window);
            }

            try self.restack();

            try self.arrange();
        }

        fn setAction(ptr: *anyopaque, mode: Action) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            switch (mode) {
                .arrange => {
                    try self.getCurrentWorkspace().setState(.default);
                    try self.arrange();
                },

                .move => {
                    const window = self.getCurrentWorkspace().current_window orelse return;
                    try self.getCurrentWorkspace().setState(.{ .moving = window });
                },

                else => {},
            }

            std.log.debug("action set to {any}", .{mode});

            self.action = mode;
        }

        fn setInput(ptr: *anyopaque, mode: Input) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            switch (mode) {
                .default => {
                    _ = x11.XUngrabPointer(self.display, x11.CurrentTime);
                    // if (self.current_window) |node| {
                    //     try node.data.updateAlignment(self.display);
                    // }
                },
                .pointer => {
                    _ = x11.XGrabPointer(self.display, self.root.handle, x11.False, POINTER_MASK, x11.GrabModeAsync, x11.GrabModeAsync, x11.None, x11.None, x11.CurrentTime);
                },
            }

            self.input = mode;
        }

        fn resizeWindow(ptr: *anyopaque, pos: _layout.Pos) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            var offset_x: c_int = 0;
            var offset_y: c_int = 0;
            switch (self.input) {
                .pointer => |p| {
                    offset_x = @intCast(pos.x - p.x);
                    offset_y = @intCast(pos.y - p.y);
                },
                .default => return,
            }

            if (self.getCurrentWindow()) |window| {
                const new_width: i32 = @as(i32, @intCast(window.alignment.width)) + @as(i32, @intCast(offset_x));
                const new_height: i32 = @as(i32, @intCast(window.alignment.height)) + @as(i32, @intCast(offset_y));

                const a: u32 = if (new_width > 100) @intCast(new_width) else window.alignment.width;
                const b: u32 = if (new_height > 100) @intCast(new_height) else window.alignment.height;

                try window.resize(self.display, a, b);
                try window.focus(self.display);
            }
        }

        fn moveWindow(ptr: *anyopaque, pos: _layout.Pos) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            switch (self.input) {
                .pointer => |p| {
                    const new_x = pos.x - p.x;
                    const new_y = pos.y - p.y;

                    if (self.getCurrentWindow()) |window| {
                        try window.move(self.display, new_x, new_y);
                    }
                    try self.getCurrentWorkspace().moveWindow(pos);
                    // if (self.getCurrentWindow()) |w| {
                    //     // try w.focus(self.display);
                    //     try w.move(self.display, new_x, new_y);
                    //     try

                    //     // Check if window is on another window's place
                    // }
                },
                .default => return,
            }
        }

        fn getCurrentWorkspace(self: *Self) *Workspace {
            return &self.workspaces[self.current_workspace];
        }

        fn getCurrentWindow(self: *Self) ?*Window {
            if (self.getCurrentWorkspace().current_window) |node| {
                return node.data.ptr;
            }

            return null;
        }

        // Create a window and adds it to the current workspace
        fn createWindow(ptr: *anyopaque, x11_window: x11.Window) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            if (self.findWindowNodeByHandle(x11_window) != null) return;

            const node = try self.allocator.create(WindowList.Node);
            node.data = Window.init(x11_window);
            node.data.mask.tag(self.current_workspace);

            try node.data.map(self.display);

            self.windows.prepend(node);

            try self.getCurrentWorkspace().addWindow(&node.data);

            try self.focus();

            try self.arrange();

            try node.data.selectInput(self.display, WINDOW_MASK);
        }

        fn destroyWindow(ptr: *anyopaque, x11_window: x11.Window) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            const node = self.findWindowNodeByHandle(x11_window) orelse return;

            // Remove nodes from all its active workspaces
            for (0..BITSIZE) |index| {
                if (node.data.mask.has(@truncate(index))) {
                    try self.workspaces[index].removeWindow(&node.data);
                }
            }

            try node.data.selectInput(self.display, 0);
            try node.data.destroy(self.display);
            self.windows.remove(node);

            self.allocator.destroy(node);

            try self.focus();

            try self.arrange();
        }

        fn viewWorkspace(ptr: *anyopaque, index: usize) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.current_workspace = @truncate(index);

            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                if (node.data.mask.has(self.current_workspace)) {
                    try node.data.map(self.display);
                    try node.data.selectInput(self.display, WINDOW_MASK);
                } else {
                    try node.data.unmap(self.display);
                    try node.data.selectInput(self.display, 0);
                }
            }

            try self.arrange();
            try self.focus();
        }

        // This will update the workspaces, only needed when changing the bitmask of a window
        fn updateWorkspaces(self: *Self, window: *Window) void {
            for (0..BITSIZE) |i| {
                if (window.mask.has(@truncate(i))) {
                    self.workspaces[i].addWindow(window) catch continue;
                } else {
                    self.workspaces[i].removeWindow(window) catch continue;
                }
            }
        }

        fn tagWindow(ptr: *anyopaque, index: usize) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            if (index == self.current_workspace) return;

            const current_node = self.getCurrentWorkspace().current_window orelse return;

            // Clean bitmask
            const window = current_node.data.ptr;

            // Adjust workspaces
            window.mask.clear();
            window.mask.tag(@intCast(index));

            self.updateWorkspaces(window);
            try window.unmap(self.display);
            try self.arrange();
        }

        fn toggleTagWindow(ptr: *anyopaque, index: usize) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            const current_node = self.getCurrentWorkspace().current_window orelse return;

            const window = current_node.data.ptr;
            window.mask.toggleTag(@intCast(index));

            // Node has no tags so retag current workspace
            if (window.mask.mask == 0) {
                try window.tag(@truncate(index));
                return;
            }

            if (self.current_workspace == index) {
                try window.unmap(self.display);
            }

            self.updateWorkspaces(window);

            try self.arrange();
        }

        fn focusWindow(ptr: *anyopaque, x11_window: x11.Window) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            try self.getCurrentWorkspace().focusWindow(x11_window, self.display);
            try self.restack();
        }

        fn focusNextWindow(ptr: *anyopaque) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            try self.getCurrentWorkspace().focusNextWindow(self.display);
            try self.restack();
        }

        fn focusPrevWindow(ptr: *anyopaque) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            try self.getCurrentWorkspace().focusPrevWindow(self.display);
            try self.restack();
        }

        fn setLayout(ptr: *anyopaque, layout: *const _layout.Layout) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            self.getCurrentWorkspace().setLayout(layout);

            try self.arrange();
        }

        fn incrementMaster(ptr: *anyopaque, amount: i8) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            self.getCurrentWorkspace().incrementMaster(amount);

            try self.arrange();
        }

        fn incrementGapsize(ptr: *anyopaque, amount: i8) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            const current = @as(i8, @intCast(self.gapsize));
            const new = std.math.add(i8, current, amount) catch return;

            if (new < 0) {
                self.gapsize = 0;
            } else {
                self.gapsize = @as(u8, @intCast(new));
            }

            std.log.info("Gapsize {}", .{self.gapsize});

            try self.arrange();
        }

        fn process(ptr: *anyopaque, args: []const []const u8) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            const display = std.mem.span(x11.DisplayString(self.display));

            var env_map = std.process.EnvMap.init(self.allocator);
            defer env_map.deinit();

            env_map.put("DISPLAY", display) catch return;

            util.spawn_process(&env_map, args, self.allocator) catch return;
        }

        fn kill(ptr: *anyopaque) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));

            const window = self.getCurrentWorkspace().getCurrentWindow() orelse return;
            for (0..BITSIZE) |i| {
                if (window.mask.has(@truncate(i))) {
                    self.workspaces[i].removeWindow(window) catch {
                        std.log.err("Window has no Workspace {}", .{i});
                    };
                }
            }

            const node = self.findWindowNodeByHandle(window.handle) orelse return;
            try node.data.destroy(self.display);
            self.windows.remove(node);
            self.allocator.destroy(node);

            try self.restack();
            try self.arrange();
            try self.focus();
        }

        fn handleKeyEvent(ptr: *anyopaque, event: *const x11.XKeyEvent) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            try Self.key_handler(@constCast(&self.context()), event);
        }

        fn handleButtonEvent(ptr: *anyopaque, event: *const x11.XButtonEvent) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            try Self.button_handler(@constCast(&self.context()), event);
        }

        fn x11ErrorHandler(display: ?*x11.Display, event: [*c]x11.XErrorEvent) callconv(.C) c_int {
            if (Self.global) |wm| {
                wm.handleError(display, event);
            }
            return 0;
        }

        fn grabButtons(self: *Self, window: *const Window) void {
            _ = x11.XUngrabButton(self.display, x11.AnyButton, x11.AnyModifier, self.root.handle);

            for (Self.buttons) |button| {
                std.log.debug("grabbing button {d}", .{button.key});
                _ = x11.XGrabButton(self.display, @intCast(button.key), button.mod, window.handle, x11.False, BUTTON_MASK, x11.GrabModeAsync, x11.GrabModeSync, x11.None, x11.None);
            }
        }

        fn grabKeys(self: *Self) void {
            var s: c_int = 0;
            var e: c_int = 0;
            var skip: c_int = 0;

            var syms: ?[*c]x11.KeySym = undefined;

            _ = x11.XUngrabKey(self.display, x11.AnyKey, x11.AnyModifier, self.root.handle);
            _ = x11.XDisplayKeycodes(self.display, &s, &e);

            syms = x11.XGetKeyboardMapping(self.display, @intCast(s), e - s + 1, &skip);

            var k: c_int = s;
            if (syms == null) return;

            while (k <= e) : (k += 1) {
                for (Self.keys) |shortcut| {
                    if (shortcut.key == syms.?[@intCast((k - s) * skip)]) {
                        std.log.debug("grabbing key {d}", .{shortcut.key});
                        _ = x11.XGrabKey(self.display, k, shortcut.mod, self.root.handle, x11.True, x11.GrabModeAsync, x11.GrabModeAsync);
                    }
                }
            }
        }

        fn check(ptr: *anyopaque) Error!void {
            const self: *Self = @ptrCast(@alignCast(ptr));
            const writer = std.io.getStdOut().writer();

            try writer.print("========= ZWM Debug Check =========\n", .{});
            try writer.print("State: {}\n", .{self.state});
            try writer.print("Screen: {}\n", .{self.screen});
            try writer.print("Root: {}\n", .{self.root});
            try writer.print("Current Workspace: {}\n", .{self.current_workspace});
            try writer.print("Windows ({d})\n", .{self.windows.len});

            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                try writer.print(" - handle: {}, mask: {b:9>}, mode: {any}\n", .{ node.data.handle, node.data.mask.mask, node.data.mode });
            }

            try writer.print("Workspaces({d})\n", .{self.workspaces.len});
            for (0..BITSIZE) |index| {
                try writer.print("{d}) Workspace\n", .{index});
                const workspace = &self.workspaces[index];
                try writer.print("Windows ({d})\n", .{workspace.windows.len});

                var jt = workspace.windows.first;
                while (jt) |n| : (jt = n.next) {
                    try writer.print(" - handle: {}, mask: {b:9>}, mode: {any}\n", .{
                        n.data.ptr.handle,
                        n.data.ptr.mask.mask,
                        n.data.ptr.mode,
                    });
                }
            }
        }
    };
}
