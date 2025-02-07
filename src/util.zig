// Transforms the handlers into an indexable array at compile time
// since zig doesn't support a nice syntax for this like in C.
const WM = @import("WindowManager.zig");
const x = @import("X11.zig");
const std = @import("std");
const action = @import("action.zig");
const Alloc = std.mem.Allocator;
const process = std.process;

pub fn createHandlers(comptime handlers: []const WM.HandlerEntry) [x.LASTEvent][]const WM.LocalHandler {
    return comptime blk: {
        var result: [x.LASTEvent][]const WM.LocalHandler = undefined;
        for (&result, 0..) |*slot, i| {
            var total_handlers: usize = 0;
            for (handlers) |handler| {
                if (@as(usize, @intCast(handler.event)) == i) {
                    total_handlers += handler.handlers.len;
                }
            }
            if (total_handlers == 0) {
                slot.* = &[_]WM.LocalHandler{};
                continue;
            }

            const static_handlers = blk2: {
                var arr: [total_handlers]WM.LocalHandler = undefined;
                var pos: usize = 0;
                for (handlers) |handler| {
                    if (@as(usize, @intCast(handler.event)) == i) {
                        for (handler.handlers) |h| {
                            arr[pos] = h;
                            pos += 1;
                        }
                    }
                }
                break :blk2 arr;
            };
            slot.* = &static_handlers;
        }
        break :blk result;
    };
}

pub fn handleKeyPress(comptime shortcuts: []const action.CallableShortcut) fn (*WM, *const x.XKeyEvent) void {
    return struct {
        pub fn handle(wm: *WM, casted: *const x.XKeyEvent) void {
            inline for (shortcuts) |shortcut| {
                const keysym = x.XKeycodeToKeysym(wm.display, @intCast(casted.keycode), 0);
                // std.debug.print("Shortcut mask: {} keycode: {} keysym: {} casted: {}\n", .{ shortcut.mod, shortcut.keycode, keysym, casted.keycode });

                if (casted.state == shortcut.mod and keysym == shortcut.keycode) {
                    shortcut.invoke(wm);
                }
            }
        }
    }.handle;
}

pub fn getWindow(windows: *WM.WindowList, window_id: c_ulong) ?*WM.Window {
    var current = windows.first;
    while (current) |node| {
        if (node.data.window == window_id) return &node.data;
        current = node.next;
    }

    return null;
}

pub fn getWindowNode(windows: *WM.WindowList, window_id: c_ulong) ?*WM.WindowList.Node {
    var current = windows.first;
    while (current) |node| {
        if (node.data.window == window_id) return &node;
        current = node.next;
    }

    return null;
}

pub fn spawn_process(env: ?*const process.EnvMap, argv: []const []const u8, allocator: Alloc) !void {
    var child = process.Child.init(argv, allocator);

    child.env_map = env;

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();
}

// Create a command string
pub fn cmd(comptime command: []const u8) []const []const u8 {
    return &[_][]const u8{command};
}
