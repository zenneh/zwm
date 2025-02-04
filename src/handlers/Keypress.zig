const WM = @import("../WindowManager.zig");
const x = @import("../X11.zig");
const std = @import("std");

pub fn keypress(_: *WM, _: [*c]x.XEvent) void {
    std.debug.print("inside keypress handler\n", .{});
}
