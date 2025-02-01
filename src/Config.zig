// const Key = @import("Key.zig");
const plugin = @import("plugin.zig");

pub const CONFIG = @This(){};

tags: u8 = 9, // Amount of tags DEFAULT 9
// shortcuts: []const Key.Shortcut = &[_]Key.Shortcut{},
plugins: []const plugin.EventHandler = &[_]plugin.EventHandler{},
