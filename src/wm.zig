const std = @import("std");
const x = @cImport(@cInclude("X11/Xlib.h")); // X11 library
const stderr = std.io.getStdErr().writer();

const Alloc = std.mem.Allocator;

fn x_error_handler(_: ?*x.Display, event: [*c]x.XErrorEvent) callconv(.C) c_int {
    std.log.err("X11 error: {}\n", .{event.*});
    WM.error_ctx.wm.handle_error(event);
    WM.error_ctx.last_error = event.*;
    return 0;
}

pub const WM = struct {
    const event_mask = x.SubstructureRedirectMask | x.SubstructureNotifyMask | x.ButtonPressMask | x.KeyPressMask;
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

    pub fn init(allocator: *const Alloc) WM {
        return WM{
            .display = undefined,
            .screen = undefined,
            .root = undefined,
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

        while (self.running) {
            _ = x.XSync(self.display, 0);
            _ = x.XNextEvent(self.display, &event);

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

        std.log.info("I am your father\n", .{});
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

    fn handle_error(self: *Self, event: [*c]x.XErrorEvent) void {
        _ = self;
        _ = event;
    }

    fn handle_event(_: *Self, event: [*c]x.XEvent) void {
        switch (event.*.type) {
            x.ButtonPress => {
                const casted = @as(*x.XButtonPressedEvent, @ptrCast(event));
                std.log.info("Button Pressed: {b:0>8}", .{casted.button});
            },
            x.KeyPress => {
                const casted = @as(*x.XKeyPressedEvent, @ptrCast(event));
                std.log.info("Key Pressed: {b:0>8}", .{casted.keycode});
            },
            else => {
                // TODO: unhandled cases
            },
        }
    }
};
