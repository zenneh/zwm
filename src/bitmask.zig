const std = @import("std");
const print = std.debug.print;

pub fn Mask(comptime T: type) type {
    // Only allow unsigned integers for a bitmask
    if (@typeInfo(T) != .Int or @typeInfo(T).Int.signedness != .unsigned) {
        @compileError("Mask type must be an unsigned integer");
    }

    return struct {
        mask: T,
        const bits = @typeInfo(T).Int.bits;

        pub fn init(value: T) @This() {
            return .{
                .mask = value,
            };
        }

        pub fn tag(self: *@This(), position: T) !void {
            self.mask ^= (@as(T, 1) << @truncate(position));
        }

        pub fn next(self: *@This(), position: T) T {
            if (self.mask == 0) return position;
            const shifted: T = self.mask >> @truncate(position + 1);
            return if (shifted == 0) @ctz(self.mask) else position + 1 + @ctz(shifted);
        }

        pub fn prev(self: *@This(), position: T) T {
            if (self.mask == 0) return position;
            const amount = bits - position;
            const shifted: T = self.mask << @truncate(amount);
            return if (shifted == 0)
                @as(T, @intCast(bits)) - 1 - @clz(self.mask)
            else
                position - 1 - @clz(shifted);
        }

        pub fn clear(self: *@This()) void {
            self.mask = 0;
        }
    };
}

test "Different bitsizes" {
    _ = Mask(u1);
    _ = Mask(u2);
    _ = Mask(u3);
    _ = Mask(u4);
    _ = Mask(u8);
    _ = Mask(u12);
    _ = Mask(u13);
}

test "Tag index" {
    var mask = Mask(u8).init(0);
    try mask.tag(0);

    try std.testing.expectEqual(mask.mask, 0b0000_0001);
}

test "Tag out of range" {
    var mask = Mask(u8).init(0);
    try mask.tag(8);
}

test "Find next tag" {
    var mask = Mask(u8).init(0);
    try mask.tag(0);
    try mask.tag(2);

    const pos = mask.next(0);

    try std.testing.expect(pos == 2);
}

test "Find previous tag" {
    var mask = Mask(u8).init(0);
    try mask.tag(0);
    try mask.tag(2);
    try mask.tag(5);

    const pos = mask.prev(5);

    try std.testing.expect(pos == 2);
}

test "Find next tag with overflow" {
    var mask = Mask(u8).init(0);
    try mask.tag(1);
    try mask.tag(3);
    try mask.tag(2);

    const pos = mask.next(3);

    try std.testing.expect(pos == 1);
}

test "Find previous tag with overflow" {
    var mask = Mask(u8).init(0);
    try mask.tag(5);
    try mask.tag(6);
    try mask.tag(7);

    const pos = mask.prev(5);

    try std.testing.expectEqual(pos, 7);
}

test "Find next tag with no active tags" {
    var mask = Mask(u8).init(0);

    const pos = mask.next(5);

    try std.testing.expectEqual(pos, 5);
}

test "Clear bitmask" {
    var mask = Mask(u8).init(1);
    mask.clear();

    try std.testing.expectEqual(mask.mask, 0);
}
