const Alignment = @import("layout.zig").Alignment;
const Window = @import("window.zig");
// const Layout = @import("layout.zig").Layout;
const layouts = @import("layout.zig").layouts;
const LayoutType = @import("layout.zig").Type;

const std = @import("std");
const util = @import("util.zig");
const x11 = @import("X11.zig");

const WindowList = std.DoublyLinkedList(*Window);

pub const Error = error{
    OutOfMemory,
    WindowNotFound,
    InvalidIndex,
};

const Self = @This();

allocator: std.mem.Allocator,

// How many windows allowed on the root
index: usize,

// layout: Layout,

// List of window pointers active in this workspace
windows: WindowList,

active_window: ?*WindowList.Node,

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .index = 1,
        .allocator = allocator,
        .layout = layouts.monocle,
        .windows = WindowList{},
        .active_window = null,
    };
}

pub fn deinit(self: *Self) void {
    var current = self.windows.first;
    while (current) |node| {
        current = node.next;
        self.allocator.destroy(node);
    }
}

pub fn toggleTagWindow(self: *Self, window: *Window) Error!void {
    if (self.findWindowNode(window)) |node| {
        try self.untagWindow(node.data);
    } else {
        try self.tagWindow(window);
    }
}

pub fn tagWindow(self: *Self, window: *Window) Error!void {
    if (self.findWindowNode(window)) |_| return;

    const node = try self.allocator.create(std.DoublyLinkedList(*Window).Node);
    errdefer self.allocator.destroy(node);

    node.* = .{
        .data = window,
        .next = null,
        .prev = null,
    };

    self.windows.append(node);
    self.active_window = node;
}

pub fn untagWindow(self: *Self, window: *Window) Error!void {
    const node = self.findWindowNode(window) orelse return;
    self.windows.remove(node);

    if (node == self.active_window) {
        self.active_window = if (node.next) |next| next else self.windows.first;
    }

    self.allocator.destroy(node);
}

pub fn mapAllWindows(self: *Self, display: *x11.Display) void {
    var it = self.windows.first;
    while (it) |node| : (it = node.next) {
        node.data.map(display) catch continue;
    }
}

pub fn unmapAllWindows(self: *Self, display: *x11.Display) void {
    var it = self.windows.first;
    while (it) |node| : (it = node.next) {
        node.data.unmap(display) catch continue;
    }
}

// pub fn setLayout(self: *Self, layout: Layout) void {
//     self.layout = layout;
// }

pub fn arrangeWindows(self: *Self, alignment: *const Alignment, display: *x11.Display) Error!void {
    var windows = try self.allocator.alloc(*Window, self.windows.len);
    defer self.allocator.free(windows);

    var i: usize = 0;
    var it = self.windows.first;
    while (it) |node| : ({
        it = node.next;
        i += 1;
    }) {
        windows[i] = node.data;
    }

    self.layout.arrange(&.{
        .index = self.index,
    }, windows, alignment, display);

    if (self.active_window) |node| {
        node.data.focus(display) catch return;
    }
}

pub fn focusWindow(self: *Self, window: *Window, display: *x11.Display) void {
    const found = self.findWindowNode(window) orelse return;

    if (self.active_window) |current| {
        current.data.unfocus(display);
    }

    self.active_window = found;
    found.data.focus(display);
}

pub fn focusNextWindow(self: *Self) void {
    if (self.active_window) |current| {
        self.active_window = if (current.next) |next| next else self.windows.first;
    } else {
        self.active_window = self.windows.first;
    }
}

/// Focus the previous window in sequence
pub fn focusPrevWindow(self: *Self) void {
    if (self.active_window) |current| {
        self.active_window = if (current.prev) |prev| prev else self.windows.last;
    } else {
        self.active_window = self.windows.last;
    }
}

pub fn incrementIndex(self: *Self, amount: usize) void {
    self.index = @intCast((self.index +% amount) % self.windows.len);
}

pub fn decrementIndex(self: *Self, amount: usize) void {
    if (self.index == 0) {
        self.index = self.windows.len;
        return;
    }
    self.index = @intCast((self.index -% amount) % self.windows.len);
}
pub fn findWindowNode(self: *Self, window: *Window) ?*std.DoublyLinkedList(*Window).Node {
    var it = self.windows.first;
    while (it) |node| : (it = node.next) {
        if (node.data == window) return node;
    }
    return null;
}
