const WM = @import("WindowManager.zig");
const Window = WM.Window;
const std = @import("std");
const x = @import("X11.zig");

pub const Pos = struct {
    x: u16 = 0,
    y: u16 = 0,
};

pub const Alignment = struct {
    pos: Pos = Pos{},
    width: u16 = 0,
    height: u16 = 0,
};

pub const Layout = struct {
    vtable: *const VTable,

    const VTable = struct {
        arrange: *const fn (windows: []*Window, display: *x.Display) void,
        center: ?*const fn () void = null,
    };

    pub fn arrange(self: Layout, windows: []*Window, display: *x.Display) void {
        self.vtable.arrange(windows, display);
    }

    pub fn center(self: Layout) void {
        if (self.vtable.center) |centerFn| centerFn();
    }
};

pub const Monocle = struct {
    pub fn init() Layout {
        return .{
            .vtable = &.{
                .arrange = arrange,
                .center = center,
            },
        };
    }

    fn arrange(windows: []*Window, display: *x.Display) void {
        for (windows) |window| {
            window.*.alignment = Alignment{
                .pos = .{ .x = 0, .y = 0 },
                .width = 1000,
                .height = 1000,
            };
            window.arrange(display);
        }
    }

    fn center() void {
        // Implement centering
    }
};

pub const Layouts = enum {
    monocle,
    // tile,

    pub fn asLayout(self: Layouts) Layout {
        return switch (self) {
            .monocle => Monocle.init(),
            // .tile => TileLayout.init(),
        };
    }
};
