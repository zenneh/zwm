const WM = @import("WindowManager.zig");
const Window = @import("window.zig");
const std = @import("std");
const x11 = @import("X11.zig");
const Alloc = std.mem.Allocator;

pub const Pos = struct {
    x: c_int = 0,
    y: c_int = 0,
};

pub const Alignment = struct {
    pos: Pos = Pos{},
    width: u32 = 0,
    height: u32 = 0,
};

// TODO, for window sizing
pub const Constraint = struct {};

// Data necessary for arrangement
pub const Context = struct {
    index: usize,
    root: *const Alignment,
};

pub const ArrangeFn = *const fn (ctx: *const Context, alignments: []*Alignment) void;

pub const Layout = struct {
    arrange: ArrangeFn,
};

pub const layouts = struct {
    pub const monocle = Layout{
        .arrange = Monocle.arrange,
    };

    pub const tile = Layout{
        .arrange = Tile.arrange,
    };
};

const Monocle = struct {
    pub fn arrange(ctx: *const Context, alignments: []*Alignment) void {
        for (alignments) |al| {
            al.* = ctx.root.*;
        }
    }
};

const Tile = struct {
    pub fn arrange(ctx: *const Context, alignments: []*Alignment) void {
        if (alignments.len == 0) return;
        if (alignments.len == 1) {
            alignments[0].* = ctx.root.*;
        }

        var x: i32 = 0;
        // var y: i32 = 0;
        const width: u32 = if (alignments.len <= ctx.index) ctx.root.width else ctx.root.width / 2;
        var height: u32 = undefined;
        const ctxi = @as(u32, @intCast(ctx.index + 1));

        for (alignments, 0..) |al, index| {
            if (index <= ctx.index) {
                height = ctx.root.height / ctxi;
                al.* = Alignment{
                    .pos = Pos{ .x = x, .y = @intCast(height * index) },
                    .width = width,
                    .height = ctx.root.height / ctxi,
                };
            } else {
                x = @intCast(ctx.root.width / 2);
                height = @intCast(ctx.root.height / (alignments.len - ctx.index));
                al.* = Alignment{
                    .pos = Pos{ .x = x, .y = @intCast((ctx.index - index) * height) },
                    .width = width,
                    .height = @intCast(ctx.root.height / ctx.index),
                };
            }
        }
    }
};

const Grid = struct {};

// const Tile = struct {
//     fn arrange(ctx: *const Context, windows: []*Window, alignment: *const Alignment, display: *x.Display) void {
//         if (windows.len == 0) return;

//         // Master window takes up left portion
//         if (windows.len == 1) {
//             windows[0].*.alignment = alignment.*;
//             windows[0].arrange(display) catch unreachable;
//             return;
//         }

//         const master_amount = ctx.index % windows.len;
//         const child_amount = windows.len - master_amount;

//         if (child_amount == 0 or master_amount == 0) {
//             const height = alignment.height / windows.len;
//             for (windows, 0..) |window, index| {
//                 window.alignment = .{
//                     .pos = .{
//                         .x = alignment.pos.x,
//                         .y = alignment.pos.y + @as(c_int, @intCast(height * index)),
//                     },
//                     .width = alignment.width,
//                     .height = @intCast(height),
//                 };
//                 window.arrange(display) catch unreachable;
//             }
//             return;
//         }

//         const master_height: usize = alignment.height / master_amount;
//         const child_height: usize = alignment.height / child_amount;

//         const width: usize = alignment.width / 2;

//         // Master window
//         for (windows[0..master_amount], 0..) |window, index| {
//             window.alignment = .{
//                 .pos = .{
//                     .x = alignment.pos.x,
//                     .y = alignment.pos.y + @as(c_int, @intCast(master_height * index)),
//                 },
//                 .width = @intCast(width),
//                 .height = @intCast(master_height),
//             };
//             window.arrange(display) catch unreachable;
//         }

//         // Child window
//         for (windows[master_amount..], 0..) |window, index| {
//             window.alignment = .{
//                 .pos = .{
//                     .x = alignment.pos.x + @as(c_int, @intCast(width)),
//                     .y = alignment.pos.y + @as(c_int, @intCast(child_height * index)),
//                 },
//                 .width = @intCast(width),
//                 .height = @intCast(child_height),
//             };
//             window.arrange(display) catch unreachable;
//         }
//     }
// };
