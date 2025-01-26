const std = @import("std");
const x = @cImport(@cInclude("X11/Xlib.h")); // X11 library

const wm = @import("wm.zig");

const print = std.debug.print;

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
    i: i32,
};

const Shortcut = struct {
    modifier: i8,
    key: i8,
    handler: *fn (...) void,
    args: []Arg,
};

const shortcuts: []Shortcut = .{.{
    .modifier = 10,
}};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    var manager = wm.WM.init(&gpa.allocator());
    defer manager.deinit();

    manager.start() catch {
        std.log.err("Hey we got some issues man\n", .{});
    };
}
