const WM = @import("WindowManager.zig");
const Window = WM.Window;
const std = @import("std");
const x = @import("X11.zig");
const Alloc = std.mem.Allocator;

pub const Pos = struct {
    x: u16 = 0,
    y: u16 = 0,
};

pub const Alignment = struct {
    pos: Pos = Pos{},
    width: u16 = 0,
    height: u16 = 0,
};

// TODO, for window sizing
pub const Constraint = struct {};

// Data necessary for arrangement
pub const Context = struct {
    index: usize,
};

pub const ArrangeFn = *const fn (ctx: *const Context, windows: []*Window, alignment: *const Alignment, display: *x.Display) void;
pub const CenterFn = *const fn (ctx: *const Context, windows: []*Window, alignment: *const Alignment, display: *x.Display) void;

pub const Layout = struct {
    arrange: ArrangeFn,
    center: ?CenterFn,
};

pub const layouts = struct {
    pub const monocle = Layout{
        .arrange = Monocle.arrange,
        .center = null,
    };

    pub const tile = Layout{
        .arrange = Tile.arrange,
        .center = null,
    };
};

const Monocle = struct {
    fn arrange(ctx: *const Context, windows: []*Window, alignment: *const Alignment, display: *x.Display) void {
        _ = ctx;
        for (windows) |window| {
            window.*.alignment = alignment.*;
            window.arrange(display);
        }
    }
};

const Tile = struct {
    fn arrange(ctx: *const Context, windows: []*Window, alignment: *const Alignment, display: *x.Display) void {
        if (windows.len == 0) return;

        // Master window takes up left portion
        if (windows.len == 1) {
            windows[0].*.alignment = alignment.*;
            windows[0].arrange(display);
            return;
        }

        const master_amount = ctx.index % windows.len;
        const child_amount = windows.len - master_amount;

        if (child_amount == 0 or master_amount == 0) {
            const height = alignment.height / windows.len;
            for (windows, 0..) |window, index| {
                window.alignment = .{
                    .pos = .{
                        .x = alignment.pos.x,
                        .y = @intCast(alignment.pos.y + height * index),
                    },
                    .width = alignment.width,
                    .height = @intCast(height),
                };
                window.arrange(display);
            }
            return;
        }

        const master_height: usize = alignment.height / master_amount;
        const child_height: usize = alignment.height / child_amount;

        const width: usize = alignment.width / 2;

        // Master window
        for (windows[0..master_amount], 0..) |window, index| {
            window.alignment = .{
                .pos = .{
                    .x = alignment.pos.x,
                    .y = @intCast(alignment.pos.y + master_height * index),
                },
                .width = @intCast(width),
                .height = @intCast(master_height),
            };
            window.arrange(display);
        }

        // Child window
        for (windows[master_amount..], 0..) |window, index| {
            window.alignment = .{
                .pos = .{
                    .x = @intCast(alignment.pos.x + width),
                    .y = @intCast(alignment.pos.y + child_height * index),
                },
                .width = @intCast(width),
                .height = @intCast(child_height),
            };
            window.arrange(display);
        }
    }
};

pub const Type = enum {
    monocle,
    tile,

    pub fn getLayout(self: Type) Layout {
        return switch (self) {
            .monocle => layouts.monocle,
            .tile => layouts.tile,
        };
    }
};
