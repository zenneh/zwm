const std = @import("std");
const Map = std.AutoHashMap;
const WM = @import("WindowManager.zig");
const x = @import("X11.zig");
const EventPtr = [*c]x.XEvent;

// A plugin is a function that gets called on an specific x11 event
pub const Plugin: type = *const fn (*anyopaque, EventPtr) void;

// Define the plugin configuration struct type at module scope

pub const EventHandler = struct {
    event: c_int,
    handlers: []const Plugin,
};

pub fn PluginManager(comptime configs: []const EventHandler) type {
    return struct {
        const Self = @This();

        const handlers = blk: {
            var map: [32][]const Plugin = .{&[_]Plugin{}} ** 32; // Initialize with empty slices
            for (configs) |handler| {
                map[handler.event] = handler.handlers;
            }
            break :blk map;
        };

        pub fn send(_: *Self, wm: *anyopaque, event: EventPtr) void {
            const event_type: usize = @intCast(event.*.type);
            for (handlers[event_type]) |handler| {
                handler(wm, @ptrCast(event));
            }
        }
    };
}

test "Initialize plugin manager" {
    const configs = [_]EventHandler{
        .{
            .event = x.KeyPress,
            .handlers = &[_]Plugin{},
        },
    };
    _ = PluginManager(&configs);
}
