const Alignment = @import("layout.zig").Alignment;
const Alloc = std.mem.Allocator;
const Layout = @import("layout.zig").Layout;
const Layouts = @import("layout.zig").Layouts;
const Window = @import("WindowManager.zig").Window;

const std = @import("std");
const util = @import("util.zig");
const x = @import("X11.zig");

const Self = @This();
const WindowList = std.DoublyLinkedList(*Window);

alloc: Alloc,
layout: Layout,
windows: WindowList,
active_window: ?*WindowList.Node,

pub fn init(alloc: Alloc, comptime layout: Layouts) Self {
    return .{
        .alloc = alloc,
        .layout = layout.asLayout(),
        .windows = WindowList{},
        .active_window = null,
    };
}

pub fn deinit(self: *Self) void {
    var current = self.windows.first;
    while (current) |node| {
        current = node.next;
        self.alloc.destroy(node);
    }
}

pub fn tag(self: *Self, window_node: *Window) void {
    var it = self.windows.first;
    while (it) |node| : (it = node.next) {
        if (node.data == window_node) return;
    }

    const node = self.alloc.create(WindowList.Node) catch unreachable;
    node.* = .{
        .data = window_node,
        .next = null,
        .prev = null,
    };

    self.windows.append(node);
    self.active_window = node;
}

pub fn untag(self: *Self, window_node: *Window) void {
    var current = self.windows.first;
    while (current) |node| : (current = node.next) {
        if (node.data != window_node) continue;
        self.windows.remove(node);

        if (node == self.active_window) {
            self.active_window = if (node.next) |next| next else self.windows.first;
        }

        self.alloc.destroy(node);

        break;
    }
}

pub fn mapAll(self: *Self, display: *x.Display) void {
    var it = self.windows.first;
    while (it) |node| : (it = node.next) {
        node.data.map(display);
    }
}

pub fn unmapAll(self: *Self, display: *x.Display) void {
    var it = self.windows.first;
    while (it) |node| : (it = node.next) {
        node.data.unmap(display);
    }
}

pub fn arrange(self: *Self, alignment: *const Alignment, display: *x.Display) void {
    var window_count: usize = 0;
    var it = self.windows.first;
    while (it) |_| : (it = it.?.next) {
        window_count += 1;
    }

    var windows = self.alloc.alloc(*Window, window_count) catch return;
    defer self.alloc.free(windows);

    var i: usize = 0;
    it = self.windows.first;
    while (it) |node| : ({
        it = node.next;
        i += 1;
    }) {
        windows[i] = node.data;
    }

    self.layout.arrange(windows, alignment, display);

    if (self.active_window) |node| {
        node.data.focus(display);
    }
}

pub fn focusNext(self: *Self) void {
    if (self.active_window) |current| {
        self.active_window = if (current.next) |next| next else self.windows.first;
    } else {
        self.active_window = self.windows.first;
    }
}

pub fn focusPrev(self: *Self) void {
    if (self.active_window) |current| {
        self.active_window = if (current.prev) |prev| prev else self.windows.last;
    } else {
        self.active_window = self.windows.last;
    }
}
