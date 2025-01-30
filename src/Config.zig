const Key = @import("Key.zig");

const Config = @This();

tags: u8 = 9, // Amount of tags DEFAULT 9
shortcuts: []Key.Shortcut,

pub fn default() Config {
    return Config{
        .tags = 9,
        .shortcuts = [_].{
            .{
                .modifier = Key.Modifier.shift(),
                .key = 20,
                .action = &void,
            },
        },
    };
}
