// const Key = @import("Key.zig");
const x = @import("X11.zig");
const std = @import("std");
const WM = @import("WindowManager.zig");

// Handlers
const handlers = @import("handlers.zig");

handlers: []const WM.HandlerEntry,
shortcuts: []const type,

fn ballz() void {
    std.debug.print("Ballzzz\n", .{});
}

pub const Default = @This(){
    .handlers = &[_]WM.HandlerEntry{
        .{
            .event = x.MapRequest,
            .handlers = &[_]WM.Handler{
                handlers.mapRequest,
            },
        },
        .{
            .event = x.KeyPress,
            .handlers = &[_]WM.Handler{
                handlers.keyPress,
            },
        },
    },
    .shortcuts = &[_]type{
        WM.ActionEntry(0, x.XK_t, ballz, .{}),
    },
};
