const std = @import("std");
const x = @cImport(@cInclude("X11/Xlib.h")); // X11 library

const print = std.debug.print;

fn error_handler(display: ?*x.Display, event: [*c]x.XErrorEvent) callconv(.C) c_int {
    _ = display;
    print("X11 error: {}\n", .{event.*});
    return 0;
}

fn handle_keypress(event: *x.XEvent) void {
    const c = @as(*x.XKeyEvent, @ptrCast(event));
    print("Key pressed: {d}, x:{d} y: {d}, {d}, {b:0>8}\n", .{ c.keycode, c.x, c.y, c.time, c.state });

    switch (c.state) {
        x.ShiftMask | x.Mod1Mask => {
            print("mod key pressed\n", .{});
            var env_map = std.process.EnvMap.init(std.heap.c_allocator);
            defer env_map.deinit();

            env_map.put("DISPLAY", ":1") catch |err| {
                print("Error setting display: {s}", .{@errorName(err)});
            };

            const args = &[_][]const u8{"st"};

            var child = std.process.Child.init(args, std.heap.c_allocator);
            child.env_map = &env_map;

            child.spawn() catch |err| {
                print("error spawning terminal {s}\n", .{@errorName(err)});
                return;
            };

            print("spawned terminal\n", .{});
        },
        else => {},
    }
}

fn handle_button(event: *x.XButtonPressedEvent) void {
    print("button pressed {} {}", .{ event.button, event.state });
}

const Arg = union(enum) {
    s: *const []u8,
    f: f32,
};

const Shortcut = struct {
    modifier: i8,
    key: i8,
    handler: *void,
    args: []Arg,
};

const shortcuts: []Shortcut = .{.{ .modifier = 10 }};

pub fn main() !void {
    const display: *x.Display = x.XOpenDisplay(null) orelse {
        print("Cannot open display\n", .{});
        return error.CannotOpenDisplay;
    };

    defer _ = x.XCloseDisplay(display);

    print("Opened display {p}\n", .{display});

    const screen = x.XDefaultScreen(display);
    print("Default screen {}\n", .{screen});

    const root = x.XRootWindow(display, screen);
    print("Root window {d}\n", .{root});

    _ = x.XSetErrorHandler(error_handler);

    // Try to become the window manager by selecting SubstructureRedirectMask
    // This will fail if another window manager is running
    const result = x.XSelectInput(display, root, x.SubstructureRedirectMask | x.SubstructureNotifyMask | x.ButtonPressMask | x.KeyPressMask);

    if (result == 0) {
        const stderr = std.io.getStdErr().writer();
        try stderr.print("Failed to become window manager (another WM running?)\n", .{});
        return error.FailedToBecome;
    }

    var event: x.XEvent = undefined;
    const running = true;
    while (running) {
        _ = x.XSync(display, 0);
        _ = x.XNextEvent(display, &event);

        switch (event.type) {
            x.ButtonPress => {
                handle_button(@as(*x.XButtonPressedEvent, @ptrCast(&event)));
            },
            x.KeyPress => {
                handle_keypress(&event);
            },
            x.CreateNotify => {
                const create_event = @as(*x.XCreateWindowEvent, @ptrCast(&event));
                print("Window created: {}\n", .{create_event.window});
            },
            x.MapRequest => {
                const map_request = @as(*x.XMapRequestEvent, @ptrCast(&event));
                print("Map request for window: {}\n", .{map_request.window});
                // Actually map (show) the window
                _ = x.XMapWindow(display, map_request.window);
                _ = x.XSync(display, 0);
            },
            else => {},
        }
    }
}

// Handle keyboard shortcuts the cool way :)
//

// 1) Registering a method with args like dwm

// 2) Creating a plugin system
//
// listen for events and get a reference to the wm context
