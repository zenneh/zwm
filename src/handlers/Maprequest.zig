const WM = @import("../WindowManager.zig");
const x = @import("../X11.zig");
const std = @import("std");

pub fn maprequest(_: *WM, event: [*c]x.XEvent) void {
    const casted = @as(*x.XMapEvent, @ptrCast(event));
    std.debug.print("Window request for window: {d}\n", .{casted.window});
}
