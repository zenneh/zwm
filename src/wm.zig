const std = @import("std");
const x = @cImport(@cInclude("X11/Xlib.h")); // X11 library
const stderr = std.io.getStdErr().writer();

const Cursor = @import("Cursor.zig");

const Alloc = std.mem.Allocator;

fn x_error_handler(_: ?*x.Display, event: [*c]x.XErrorEvent) callconv(.C) c_int {
    WM.error_ctx.wm.handle_error(event);
    WM.error_ctx.last_error = event.*;
    return 0;
}

pub const WM = struct {
    const event_mask = x.SubstructureRedirectMask | x.SubstructureNotifyMask | x.ButtonPressMask | x.KeyPressMask | x.EnterWindowMask;
    const Self = @This();

    const Error = error{ FailedBecome, CannotOpenDisplay };

    const ErrorContext = struct {
        wm: *WM,
        last_error: ?x.XErrorEvent = null,
    };

    var error_ctx: ErrorContext = undefined;

    display: *x.Display,
    screen: c_int,
    root: x.Window,
    allocator: *const Alloc,
    running: bool = true,
    cursors: [3]Cursor,

    pub fn init(allocator: *const Alloc) WM {
        return WM{
            .display = undefined,
            .screen = undefined,
            .root = undefined,
            .cursors = undefined,
            .allocator = allocator,
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

        // const cursor = x.XCreateFontCursor(self.display, 68);
        // _ = x.XDefineCursor(self.display, self.root, cursor);
        //
        try self.init_cursors();
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
        error_ctx = .{
            .wm = self,
            .last_error = null,
        };

        _ = x.XSetErrorHandler(x_error_handler);
    }

    fn deinit_error(_: *Self) void {
        WM.error_ctx = .{
            .wm = undefined,
            .last_error = null,
        };
    }

    fn init_cursors(self: *Self) !void {
        self.cursors[0] = Cursor.createHover().init(self.display);
        self.cursors[1] = Cursor.createResize().init(self.display);
        self.cursors[2] = Cursor.createMove().init(self.display);

        x.XDefineCursor(self.display, self.root, self.cursors[2].cursor);
    }

    fn deinit_cursors(self: *Self) void {
        for (self.cursors) |*cursor| {
            cursor.deinit();
        }
    }

    fn handle_error(self: *Self, event: [*c]x.XErrorEvent) void {
        // I have no idea how we should handle errors
        self.running = false;
        std.log.err("X11 error: {}\n", .{event.*});
    }

    fn handle_event(self: *Self, event: [*c]x.XEvent) void {
        switch (event.*.type) {
            x.ButtonPress => {
                const casted = @as(*x.XButtonPressedEvent, @ptrCast(event));
                std.log.info("Button Pressed: {b:0>8}", .{casted.button});
            },
            x.KeyPress => {
                const casted = @as(*x.XKeyPressedEvent, @ptrCast(event));
                std.log.info("Key Pressed: {b:0>8}", .{casted.keycode});
            },
            x.MapRequest => {
                std.log.info("maprequst", .{});
                const casted = @as(*x.XMapRequestEvent, @ptrCast(event));
                _ = x.XMapWindow(self.display, self.root);
                _ = x.XMapWindow(self.display, casted.window);
                _ = x.XSetWindowBorderWidth(self.display, casted.window, 10);
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
};
