const Layout = @import("layout.zig").Layout;
const LayoutType = @import("layout.zig").Type;
const Shortcut = @import("action.zig").Shortcut;
const action = @import("action.zig");
const cmd = @import("util.zig").cmd;
const std = @import("std");
const x11 = @import("X11.zig");

const handler = @import("handler.zig");
const WM = @import("WindowManager.zig");

const Config = @This();

// Default Layout
layout: LayoutType,

// X11 Event Handlers
handlers: []const handler.HandlerEntry,

// User defined keyboard shortcuts
shortcuts: []const action.CallableShortcut,

pub const Default = Config{
    .layout = LayoutType.monocle,
    .handlers = &[_]handler.HandlerEntry{
        .{
            .event = x11.MapRequest,
            .handlers = &[_]handler.Handler{
                handler.mapRequest,
            },
        },
        .{
            .event = x11.MappingNotify,
            .handlers = &[_]handler.Handler{
                handler.mapNotify,
            },
        },
        .{
            .event = x11.KeyPress,
            .handlers = &[_]handler.Handler{
                handler.keyPress,
            },
        },
        .{
            .event = x11.DestroyNotify,
            .handlers = &[_]handler.Handler{
                handler.keyPress,
            },
        },
        .{
            .event = x11.MotionNotify,
            .handlers = &[_]handler.Handler{
                handler.motionNotify,
            },
        },
        .{
            .event = x11.ButtonPress,
            .handlers = &[_]handler.Handler{
                handler.buttonPress,
            },
        },
        .{
            .event = x11.ButtonRelease,
            .handlers = &[_]handler.Handler{
                handler.buttonRelease,
            },
        },
    },
    .shortcuts = &[_]action.CallableShortcut{
        // Tag window
        Shortcut(x11.ShiftMask, x11.XK_1, action.tag, .{@as(u8, 0)}),
        Shortcut(x11.ShiftMask, x11.XK_2, action.tag, .{@as(u8, 1)}),
        Shortcut(x11.ShiftMask, x11.XK_3, action.tag, .{@as(u8, 2)}),
        Shortcut(x11.ShiftMask, x11.XK_4, action.tag, .{@as(u8, 3)}),

        // View workspace
        Shortcut(0, x11.XK_1, action.view, .{@as(u8, 0)}),
        Shortcut(0, x11.XK_2, action.view, .{@as(u8, 1)}),
        Shortcut(0, x11.XK_3, action.view, .{@as(u8, 2)}),
        Shortcut(0, x11.XK_4, action.view, .{@as(u8, 3)}),
        Shortcut(0, x11.XK_t, action.check, .{}),

        // Navigation
        Shortcut(0, x11.XK_l, action.focusNext, .{}),
        Shortcut(0, x11.XK_h, action.focusPrev, .{}),

        // Change layout
        Shortcut(x11.ShiftMask, x11.XK_m, action.setLayout, .{LayoutType.monocle}),
        Shortcut(x11.ShiftMask, x11.XK_t, action.setLayout, .{LayoutType.tile}),
        // action.Shortcut(x.ShiftMask, x.XK_b, action.setLayout, .{Layouts.bugo}),
        Shortcut(x11.ShiftMask, x11.XK_i, action.incrementLayout, .{@as(usize, 1)}),
        Shortcut(x11.ShiftMask, x11.XK_o, action.decrementLayout, .{@as(usize, 1)}),

        // Processes
        Shortcut(x11.ShiftMask, x11.XK_g, action.process, .{cmd("st")}),
        Shortcut(x11.ShiftMask, x11.XK_f, action.process, .{cmd("firefox")}),

        Shortcut(x11.ShiftMask, x11.XK_q, action.kill, .{}),
    },
};
