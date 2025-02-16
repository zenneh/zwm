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

    pub fn diff(a: Alignment, b: Alignment) Alignment {
        return Alignment{
            .pos = Pos{
                .x = a.pos.x - b.pos.x,
                .y = a.pos.y - b.pos.y,
            },
            .width = a.width - b.width,
            .height = a.height - b.height,
        };
    }
};

// TODO, for window sizing
pub const Constraint = struct {};

// Data necessary for arrangement
pub const Context = struct {
    index: usize,
    root: *const Alignment,
};

pub const ArrangeFn = *const fn (ctx: *const Context, alignments: []*Alignment, preferences: []?*Alignment) void;

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

    pub const bugo = Layout{
        .arrange = BugoJanssen.arrange,
    };
};

const Monocle = struct {
    pub fn arrange(ctx: *const Context, alignments: []*Alignment, _: []?*Alignment) void {
        for (alignments) |al| {
            al.* = ctx.root.*;
        }
    }
};

const BugoJanssen = struct {
    pub fn arrange(ctx: *const Context, alignments: []*Alignment, preferences: []?*Alignment) void {
        // Early returns for empty or single window cases
        if (alignments.len == 0) return;
        if (alignments.len == 1) {
            alignments[0].* = ctx.root.*;
            return;
        }

        // Find master preference
        var master_preference: ?*Alignment = null;
        for (0..alignments.len) |i| {
            if (preferences[i]) |p| {
                if (std.meta.eql(Alignment.diff(alignments[i].*, p.*), Alignment{})) {
                    master_preference = preferences[i];
                    std.log.debug("Found master preferences", .{});
                    break;
                }
            }
        }

        // Calculate predefined widths and heights

    }
};

const Tile = struct {
    /// Arranges windows in a tiling layout with a master area and stack area
    /// master_count determines how many windows appear in the master area
    pub fn arrange(ctx: *const Context, alignments: []*Alignment, _: []?*Alignment) void {
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
