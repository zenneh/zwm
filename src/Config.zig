// const Key = @import("Key.zig");
const x = @import("X11.zig");
const std = @import("std");
const WM = @import("WindowManager.zig");
const action = @import("action.zig");
const Layout = @import("layout.zig").Layout;
const Layouts = @import("layout.zig").Layouts;

// Handlers
const handlers = @import("handlers.zig");

default_layout: Layouts,
handlers: []const WM.HandlerEntry,
shortcuts: []const action.CallableShortcut,

pub const Default = @This(){
    .default_layout = Layouts.monocle,
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
        .{
            .event = x.DestroyNotify,
            .handlers = &[_]WM.Handler{
                handlers.keyPress,
            },
        },
    },
    .shortcuts = &[_]action.CallableShortcut{
        // Tag window
        action.Shortcut(x.ShiftMask, x.XK_1, action.tag, .{@as(u8, 0)}),
        action.Shortcut(x.ShiftMask, x.XK_2, action.tag, .{@as(u8, 1)}),
        action.Shortcut(x.ShiftMask, x.XK_3, action.tag, .{@as(u8, 2)}),
        action.Shortcut(x.ShiftMask, x.XK_4, action.tag, .{@as(u8, 3)}),

        // View workspace
        action.Shortcut(0, x.XK_1, action.view, .{@as(u8, 0)}),
        action.Shortcut(0, x.XK_2, action.view, .{@as(u8, 1)}),
        action.Shortcut(0, x.XK_3, action.view, .{@as(u8, 2)}),
        action.Shortcut(0, x.XK_4, action.view, .{@as(u8, 3)}),
        action.Shortcut(0, x.XK_t, action.check, .{}),

        // Navigation
        action.Shortcut(0, x.XK_l, action.focusNext, .{}),
        action.Shortcut(0, x.XK_h, action.focusPrev, .{}),

        // Change layout
        action.Shortcut(0, x.XK_t, action.setLayout, .{Layouts.monocle}),
    },
};
