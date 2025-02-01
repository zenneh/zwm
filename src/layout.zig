const Layout = @This();

ptr: *anyopaque,
vtable: *const VTable,

const VTable = struct {
    // Virtual methods
    center: *const fn (void) void,
    resize: *const fn (void) void,
};

pub fn center(self: *Layout) void {
    self.vtable.center();
}

pub fn resize(self: *Layout) void {
    self.vtable.resize();
}

pub const Monocle = struct {
    const Self = @This();

    pub fn layout(self: *Self) Layout {
        return .{ .ptr = self, .vtable = .{
            .center = self.center,
            .resize = self.center,
        } };
    }

    pub fn center() void {}
};
