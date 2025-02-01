const Config = @import("Config.zig");
const WindowManager = @import("WindowManager.zig");

const x = @import("X11.zig");
const std = @import("std");

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

pub fn main() !void {
    const config = comptime Config{};

    var wm = WindowManager.wima(&config){};
    wm.a = 30;

    // var wm = WindowManager.init(&config);
    // defer wm.deinit();

    // wm.start() catch {
    //     std.log.err("Hey we got some issues man\n", .{});
    // };
}
