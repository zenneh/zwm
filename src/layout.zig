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
    /// Arranges windows in a tiling layout with a master area and stack area
    /// master_count determines how many windows appear in the master area
    pub fn arrange(ctx: *const Context, alignments: []*Alignment) void {
        // Early returns for empty or single window cases
        if (alignments.len == 0) return;
        if (alignments.len == 1) {
            alignments[0].* = ctx.root.*;
            return;
        }

        // Calculate master area properties
        const master_count: u32 = @intCast(@min(ctx.index + 1, alignments.len));
        const use_split_layout = alignments.len > master_count;

        // Calculate basic dimensions
        const total_width = ctx.root.width;
        const total_height = ctx.root.height;
        const master_width = if (use_split_layout) total_width / 2 else total_width;

        // Prevent division by zero for height calculations
        const master_height: u32 = if (master_count > 0)
            @intCast(total_height / master_count)
        else
            total_height;

        const stack_count: u32 = @intCast(alignments.len - master_count);
        const stack_height: u32 = if (stack_count > 0) total_height / stack_count else total_height;

        // Arrange windows in master area
        var i: usize = 0;
        while (i < master_count) : (i += 1) {
            alignments[i].* = .{
                .pos = .{
                    .x = 0,
                    .y = @intCast(i * master_height),
                },
                .width = @intCast(master_width),
                .height = @intCast(master_height),
            };
        }

        // Arrange windows in stack area
        while (i < alignments.len) : (i += 1) {
            const stack_index = i - master_count;
            alignments[i].* = .{
                .pos = .{
                    .x = @intCast(master_width),
                    .y = @intCast(stack_index * stack_height),
                },
                .width = @intCast(master_width),
                .height = @intCast(stack_height),
            };
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
