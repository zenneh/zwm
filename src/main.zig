const Config = @import("Config.zig");
const WindowManager = @import("WindowManager.zig");

const x = @import("X11.zig");
const std = @import("std");

pub fn main() !void {
    var alloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (alloc.deinit() == .leak) {
            @panic("memory leak!");
        }
    }

    var wm = WindowManager.init(alloc.allocator(), &Config.Default);
    defer wm.deinit();

    wm.start() catch {
        std.log.err("Hey we got some issues man\n", .{});
    };
}
