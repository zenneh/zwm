const std = @import("std");
const x = @import("X11.zig");
const stderr = std.io.getStdErr().writer();

const Cursor = @import("Cursor.zig");
const Window = @import("Window.zig");
const Workspace = @import("Workspace.zig");

const Alloc = std.mem.Allocator;

const ErrorClosure = struct {
    var wm: ?*WM = null;

    fn handle(_: ?*x.Display, event: [*c]x.XErrorEvent) callconv(.C) c_int {
        if (wm != null) wm.?.handle_error(event);
        return 0;
    }
};

pub const WM = struct {
    const event_mask = x.SubstructureRedirectMask | x.SubstructureNotifyMask | x.ButtonPressMask | x.KeyPressMask | x.EnterWindowMask;
    const Self = @This();

    const Error = error{ FailedBecome, CannotOpenDisplay, Cursor };

    display: *x.Display,
    screen: c_int,
    root: x.Window,
    allocator: *const Alloc,
    running: bool = true,
    cursors: [3]*const Cursor,

    // All the Application windows
    windows: std.SinglyLinkedList(Window),

    pub fn init(allocator: *const Alloc) WM {
        return WM{
            .display = undefined,
            .screen = undefined,
            .root = undefined,
            .cursors = undefined,
            .allocator = allocator,
            .windows = .{},
        };
    }

    pub fn deinit(_: *Self) void {} // TODO: Free allocated resources

    pub fn start(self: *Self) Error!void {
        try self.open_display();
        defer self.close_display();

        self.setup_screen();

        self.init_error();
        defer self.deinit_error();

        var event: x.XEvent = undefined;

        try self.setup_inputs();

        self.init_cursors() catch return Error.Cursor;
        defer self.deinit_cursors();

        while (self.running) {
            _ = x.XNextEvent(self.display, &event);
            _ = x.XSync(self.display, 0);

            self.handle_event(&event);
        }
    }

    fn open_display(self: *Self) Error!void {
        self.display = x.XOpenDisplay(null) orelse {
            return Error.CannotOpenDisplay;
        };
    }

    fn close_display(self: *Self) void {
        _ = x.XCloseDisplay(self.display);
    }

    fn setup_screen(self: *Self) void {
        self.screen = x.XDefaultScreen(self.display);
        self.root = x.XRootWindow(self.display, self.screen);
    }

    fn setup_inputs(self: *Self) Error!void {
        const result = x.XSelectInput(self.display, self.root, WM.event_mask);

        if (result == 0) {
            std.log.err("Failed to become window manager (another WM running?)\n", .{});
            return Error.FailedBecome;
        }
    }

    fn init_error(self: *Self) void {
        ErrorClosure.wm = self;
        _ = x.XSetErrorHandler(ErrorClosure.handle);
        // I want this
    }

    fn deinit_error(_: *Self) void {
        ErrorClosure.wm = undefined;
    }

    fn init_cursors(self: *Self) !void {
        var hover = try Cursor.createHover(self.allocator);
        var resize = try Cursor.createResize(self.allocator);
        var move = try Cursor.createMove(self.allocator);

        hover.init(self.display);
        resize.init(self.display);
        move.init(self.display);

        self.cursors[0] = hover;
        self.cursors[1] = resize;
        self.cursors[2] = move;

        _ = x.XDefineCursor(self.display, self.root, move.cursor);
    }

    fn deinit_cursors(self: *Self) void {
        for (self.cursors) |cursor| {
            self.allocator.destroy(cursor);
        }
    }

    fn handle_error(self: *Self, event: [*c]x.XErrorEvent) void {
        // I have no idea how we should handle errors
        self.running = false;
        std.log.err("X11 error: {}\n", .{event.*});
    }

    fn list_windows(self: *Self) void {
        var window = self.windows.first;
        while (window) |w| {
            std.debug.print("Window {d}\n", .{w.data.window});
            window = w.next;
        }
    }

    fn handle_event(self: *Self, event: [*c]x.XEvent) void {
        switch (event.*.type) {
            x.ButtonPress => {
                const casted = @as(*x.XButtonPressedEvent, @ptrCast(event));
                std.log.info("Button Pressed: {b:0>8}", .{casted.button});

                // try toggle window
            },
            x.KeyPress => {
                const casted = @as(*x.XKeyPressedEvent, @ptrCast(event));
                std.log.info("Key Pressed: {d} options: {d} {d}", .{ casted.keycode, x.XK_i, x.XK_o });

                const i_keycode = x.XKeysymToKeycode(self.display, x.XK_i);
                const o_keycode = x.XKeysymToKeycode(self.display, x.XK_o);
                const l_keycode = x.XKeysymToKeycode(self.display, x.XK_l);

                if (casted.keycode == i_keycode) {
                    std.log.info("unmap window", .{});

                    if (self.windows.first) |node| {
                        _ = x.XUnmapWindow(self.display, node.data.window);
                    }
                }
                if (casted.keycode == o_keycode) {
                    std.log.info("map window", .{});
                    if (self.windows.first) |node| {
                        _ = x.XMapWindow(self.display, node.data.window);
                    }
                }
                if (casted.keycode == o_keycode) {
                    std.log.info("map window", .{});
                    if (self.windows.first) |node| {
                        _ = x.XMapWindow(self.display, node.data.window);
                    }
                }
                if (casted.keycode == l_keycode) {
                    self.list_windows();
                }
            },
            x.MapRequest => {
                std.log.info("maprequst", .{});
                const casted = @as(*x.XMapRequestEvent, @ptrCast(event));
                _ = x.XMapWindow(self.display, self.root);
                _ = x.XMapWindow(self.display, casted.window);
                _ = x.XSetWindowBorderWidth(self.display, casted.window, 10);

                var attr: x.XWindowAttributes = .{};

                _ = x.XGetWindowAttributes(self.display, self.root, &attr);

                const window = Window{
                    .window = casted.window,
                    .x = 0,
                    .y = 0,
                    .width = @intCast(attr.width),
                    .height = @intCast(attr.height),
                };

                const T = std.SinglyLinkedList(Window);

                const node: *T.Node = self.allocator.create(T.Node) catch unreachable;
                node.* = .{ .data = window };
                self.windows.prepend(node);
                // _ = x.XMoveResizeWindow(self.display, casted.window, 0, 0, @intCast(attr.width), @intCast(attr.height));
            },
            x.MapNotify => {
                const casted = @as(*x.XKeyPressedEvent, @ptrCast(event));
                std.log.info("window created {d}", .{casted.keycode});
            },
            x.EnterNotify => {
                std.log.info("window entered", .{});
            },
            else => {
                // TODO: unhandled cases
            },
        }
    }

    fn ballz() void {
        std.debug.print("niggertrrrr\n", .{});
    }
};
