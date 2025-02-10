const layouts = @import("layout.zig").layouts;
const shortcut = @import("shortcut.zig");

const Layout = @import("layout.zig").Layout;
const SC = shortcut.createShortCut;

const key = @import("Key.zig");
const action = @import("action.zig");
const cmd = @import("util.zig").cmd;

const std = @import("std");
const x11 = @import("X11.zig");

const handler = @import("handler.zig");
const WM = @import("WindowManager.zig");

const Config = @This();

// const ModLayer0 = x11.Mod4Mask;
// const ModLayer1 = x11.Mod4Mask | x11.ShiftMask;
// const ModLayer2 = x11.Mod4Mask | x11.ControlMask;
// const ModLayer3 = x11.Mod4Mask | x11.ControlMask | x11.ShiftMask;
const ModLayer0 = 0;
const ModLayer1 = x11.ShiftMask;
const ModLayer2 = x11.ControlMask;
const ModLayer3 = x11.ControlMask | x11.ShiftMask;

// Default Layout
layout: Layout,

// X11 Event Handlers
handlers: []const handler.HandlerEntry,

// User defined keyboard shortcuts
shortcuts: []const shortcut.Shortcut,

pub const Default = Config{
    .layout = layouts.monocle,
    .handlers = &[_]handler.HandlerEntry{
        .{ .event = x11.MapRequest, .handlers = &[_]handler.Handler{
            handler.mapRequest,
        } },
        .{ .event = x11.MappingNotify, .handlers = &[_]handler.Handler{
            handler.mapNotify,
        } },
        .{ .event = x11.KeyPress, .handlers = &[_]handler.Handler{
            handler.keyPress,
        } },
        .{ .event = x11.DestroyNotify, .handlers = &[_]handler.Handler{
            handler.keyPress,
        } },
        .{ .event = x11.MotionNotify, .handlers = &[_]handler.Handler{
            handler.motionNotify,
        } },
        .{ .event = x11.EnterNotify, .handlers = &[_]handler.Handler{
            handler.enterNotify,
        } },
        .{ .event = x11.ButtonPress, .handlers = &[_]handler.Handler{
            handler.buttonPress,
        } },
        .{ .event = x11.ButtonRelease, .handlers = &[_]handler.Handler{
            handler.buttonRelease,
        } },
    },
    .shortcuts = &[_]shortcut.Shortcut{
        // Tag window
        SC(ModLayer1, x11.XK_1, action.tag, .{@as(u8, 0)}),
        SC(ModLayer1, x11.XK_2, action.tag, .{@as(u8, 1)}),
        SC(ModLayer1, x11.XK_3, action.tag, .{@as(u8, 2)}),
        SC(ModLayer1, x11.XK_4, action.tag, .{@as(u8, 3)}),
        SC(ModLayer3, x11.XK_1, action.toggleTag, .{@as(u8, 0)}),
        SC(ModLayer3, x11.XK_2, action.toggleTag, .{@as(u8, 1)}),
        SC(ModLayer3, x11.XK_3, action.toggleTag, .{@as(u8, 2)}),
        SC(ModLayer3, x11.XK_4, action.toggleTag, .{@as(u8, 3)}),

        // View workspace
        SC(ModLayer0, x11.XK_1, action.view, .{@as(u8, 0)}),
        SC(ModLayer0, x11.XK_2, action.view, .{@as(u8, 1)}),
        SC(ModLayer0, x11.XK_3, action.view, .{@as(u8, 2)}),
        SC(ModLayer0, x11.XK_4, action.view, .{@as(u8, 3)}),
        SC(ModLayer0, x11.XK_c, action.check, .{}),

        // Navigation
        SC(ModLayer0, x11.XK_n, action.focusNext, .{}),
        SC(ModLayer0, x11.XK_p, action.focusPrev, .{}),

        // Workspace configuration
        SC(ModLayer0, x11.XK_m, action.setLayout, .{layouts.monocle}),
        SC(ModLayer0, x11.XK_t, action.setLayout, .{layouts.tile}),
        SC(ModLayer1, x11.XK_i, action.incrementLayout, .{@as(usize, 1)}),
        SC(ModLayer1, x11.XK_o, action.decrementLayout, .{@as(usize, 1)}),

        // Window configuration
        SC(ModLayer1, x11.XK_p, action.toggleFloating, .{}),

        // Processes
        SC(ModLayer1, x11.XK_t, action.process, .{cmd("st")}),
        SC(ModLayer1, x11.XK_f, action.process, .{cmd("firefox")}),

        SC(ModLayer0, x11.XK_q, action.kill, .{}),
    },
};
