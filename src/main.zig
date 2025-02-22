const Config = @import("Config.zig");
const WindowManager = @import("WindowManager.zig").WindowManager;

const x = @import("X11.zig");
const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak) {
            @panic("memory leak!");
        }
    }

    const WM = WindowManager(Config.Default);

    var wm = try WM.init(gpa.allocator());
    defer wm.deinit();

    wm.start() catch |err| {
        std.log.err("Hey we got some issues man: {s}\n", .{@errorName(err)});
    };
}
