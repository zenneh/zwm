const x = @import("X11.zig");
const bitmask = @import("bitmask.zig");

pub fn Window(comptime T: type) type {
    return struct {
        mask: bitmask.Mask(T),
        window: x.Window,
        x: i16,
        y: i16,
        width: u16,
        height: u16,
    };
}
