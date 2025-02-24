const std = @import("std");
const _layout = @import("layout.zig");
const x11 = @import("X11.zig");
const _window = @import("window.zig");

const Alignment = _layout.Alignment;
const Layout = _layout.Layout;
const Allocator = std.mem.Allocator;

pub const Error = error{
    WindowAlreadyInWorkspace,
    WindowNotInWorkspace,
    NoCurrentWindow,
} || std.mem.Allocator.Error || _window.Error;

pub fn WindowData(comptime T: type) type {
    return struct {
        ptr: *T,
        alignment: Alignment,
        preferred: ?Alignment, // Preferred alignment
    };
}

// A workspace owns a window node for the time being active in here
// Ownership can be transfered to other workspaces
pub fn Workspace(comptime Mask: type) type {
    const Window = _window.Window(Mask);
    const Windows = std.DoublyLinkedList(WindowData(Window));

    const State = union(enum) {
        default,
        moving: *Windows.Node,
        resizing,
    };

    return struct {
        layout: *const Layout,

        windows: Windows,

        master: usize,

        allocator: Allocator,

        current_window: ?*Windows.Node,

        state: State,

        const Self = @This();

        pub fn init(allocator: Allocator, layout: *const Layout) Self {
            return Self{
                .layout = layout,
                .windows = .{},
                .master = 0,
                .allocator = allocator,
                .current_window = null,
                .state = .default,
            };
        }

        pub fn deinit(self: *Self) void {
            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                self.windows.remove(node);
                self.allocator.destroy(node);
            }

            self.current_window = null;
        }
        pub fn setState(self: *Self, state: State) Error!void {
            switch (self.state) {
                .default => {},
                .moving => |s| {
                    const cw = self.current_window orelse return;
                    try self.swapNodes(cw, s);
                    std.log.info("Swapping nodes", .{});
                },
                .resizing => {},
            }
            self.state = state;
        }

        pub fn getCurrentWindow(self: *Self) ?*const Window {
            if (self.current_window) |window| {
                return window.data.ptr;
            }

            return null;
        }

        pub fn focusNextWindow(self: *Self, display: *x11.Display) Error!void {
            const node = self.current_window orelse return;
            if (node.next) |next| {
                self.current_window = next;
            }

            try self.focus(display);
        }

        pub fn focusPrevWindow(self: *Self, display: *x11.Display) Error!void {
            const node = self.current_window orelse return;
            if (node.prev) |prev| {
                self.current_window = prev;
            }

            try self.focus(display);
        }

        pub fn setLayout(self: *Self, layout: *const Layout) void {
            self.layout = layout;
        }

        pub fn incrementMaster(self: *Self, amount: i8) void {
            if (self.windows.len == 0) return;

            var new_master: i32 = @as(i32, @intCast(self.master)) + amount;

            if (new_master < 0) {
                new_master = 0;
            } else if (new_master > @as(i32, @intCast(self.windows.len - 1))) {
                new_master = @intCast(self.windows.len - 1);
            }

            self.master = @intCast(new_master);
        }

        fn getWindowNodeByReference(self: *Self, window: *const Window) ?*Windows.Node {
            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                if (node.data.ptr == window) return node;
            }
            return null;
        }

        pub fn addWindow(self: *Self, window: *Window) Error!void {
            if (self.getWindowNodeByReference(window) != null) return Error.WindowAlreadyInWorkspace;

            const node = try self.allocator.create(Windows.Node);
            errdefer self.allocator.destroy(node);

            node.*.data = WindowData(Window){
                .ptr = window,
                .alignment = window.alignment,
                .preferred = Alignment{},
            };

            self.windows.prepend(node);

            self.current_window = node;
        }

        fn findWindowNodeByHandle(self: *Self, x11_window: x11.Window) ?*Windows.Node {
            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                if (node.data.ptr.handle == x11_window) return node;
            }
            return null;
        }

        pub fn focusWindow(self: *Self, x11_window: x11.Window, display: *x11.Display) Error!void {
            const node = self.findWindowNodeByHandle(x11_window) orelse return;
            if (self.current_window == node) return;

            self.current_window = node;

            std.log.info("focusWindow called", .{});
            try self.focus(display);
        }

        pub fn focus(self: *Self, display: *x11.Display) Error!void {
            std.log.info("focus called", .{});
            if (self.current_window == null) {
                self.current_window = self.windows.first;
            }
            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                if (node == self.current_window) {
                    std.log.info("focus", .{});
                    try node.data.ptr.focus(display);
                } else {
                    std.log.info("unfocus", .{});
                    try node.data.ptr.unfocus(display);
                }
            }
        }

        pub fn moveWindow(self: *Self, pos: _layout.Pos) Error!void {
            if (self.state != .moving) return;
            const window = self.current_window orelse return;
            var it = self.windows.first;

            while (it) |node| : (it = node.next) {
                if (node.data.ptr.mode != .default) continue;

                if (node.data.ptr.alignment.within(pos) and node != window) {
                    std.log.info("Swapping nodes", .{});
                    self.state = .{ .moving = node };
                    break;
                }
            }
        }

        pub fn swapNodes(self: *Self, node1: *Windows.Node, node2: *Windows.Node) Error!void {
            if (node1 == node2) return;

            // Store temporary references
            const node1_prev = node1.prev;
            const node1_next = node1.next;
            const node2_prev = node2.prev;
            const node2_next = node2.next;

            // Update adjacent nodes' references
            if (node1_prev) |prev| prev.next = node2;
            if (node1_next) |next| {
                if (next != node2) next.prev = node2;
            }

            if (node2_prev) |prev| {
                if (prev != node1) prev.next = node1;
            }
            if (node2_next) |next| next.prev = node1;

            // Update the swapped nodes' references
            node1.prev = if (node2_prev == node1) node2 else node2_prev;
            node1.next = if (node2_next == node1) node2 else node2_next;
            node2.prev = if (node1_prev == node2) node1 else node1_prev;
            node2.next = if (node1_next == node2) node1 else node1_next;

            // Update list head and tail if necessary
            if (self.windows.first == node1) {
                self.windows.first = node2;
            } else if (self.windows.first == node2) {
                self.windows.first = node1;
            }

            if (self.windows.last == node1) {
                self.windows.last = node2;
            } else if (self.windows.last == node2) {
                self.windows.last = node1;
            }
        }

        pub fn arrange(self: *Self, gapsize: u32, alignment: Alignment, display: *x11.Display) Error!void {
            // Count windows
            var count: usize = 0;
            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                if (node.data.ptr.mode == .default) count += 1;
            }

            // allocate slices
            const windows = try self.allocator.alloc(*Window, count);
            defer self.allocator.free(windows);

            const alignments = try self.allocator.alloc(*Alignment, count);
            defer self.allocator.free(alignments);

            const preferences = try self.allocator.alloc(?*Alignment, count);
            defer self.allocator.free(preferences);

            // get data
            it = self.windows.first;
            var index: usize = 0;
            while (it) |node| : (it = node.next) {
                if (node.data.ptr.mode == .default) {
                    windows[index] = node.data.ptr;
                    alignments[index] = &node.data.ptr.alignment;
                    if (node.data.ptr.preferences) |*p| {
                        preferences[index] = p;
                    } else {
                        preferences[index] = null;
                    }

                    index += 1;
                }
            }

            self.layout.arrange(&.{
                .root = &alignment,
                .gapsize = gapsize,
                .index = self.master,
            }, alignments, preferences);

            for (windows, 0..) |window, i| {
                try window.moveResize(
                    display,
                    alignments[i].pos.x,
                    alignments[i].pos.y,
                    alignments[i].width,
                    alignments[i].height,
                );
            }
        }

        pub fn restack(self: *Self, root: c_ulong, display: *x11.Display) Error!void {
            var sibling: x11.Window = root;
            const cw = self.current_window orelse return;

            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                const window = node.data.ptr;
                if (window.mode != .default or node == cw) continue;
                var changes = x11.XWindowChanges{
                    .sibling = sibling,
                    .stack_mode = x11.Above,
                };

                try window.configure(display, x11.CWSibling | x11.CWStackMode, &changes);
                sibling = window.handle;
            }

            var changes = x11.XWindowChanges{
                .sibling = sibling,
                .stack_mode = x11.Above,
            };
            try cw.data.ptr.configure(display, x11.CWSibling | x11.CWStackMode, &changes);
        }

        pub fn removeWindow(self: *Self, window: *const Window) Error!void {
            const node = self.getWindowNodeByReference(window) orelse return Error.WindowNotInWorkspace;
            self.windows.remove(node);
            defer self.allocator.destroy(node);

            if (self.current_window == node) {
                if (node.next) |next| {
                    self.current_window = next;
                }
                if (node.prev) |prev| {
                    self.current_window = prev;
                } else {
                    self.current_window = self.windows.first;
                }
            }
        }

        // pub fn mapAllWindows(self: *Self, display: *x11.Display) void {
        //     var it = self.windows.first;
        //     while (it) |node| : (it = node.next) {
        //         node.data.map(display);
        //     }
        // }

        // pub fn unmapAllWindows(self: *Self, display: *x11.Display) void {
        //     var it = self.windows.first;
        //     while (it) |node| : (it = node.next) {
        //         node.data.unmap(display);
        //     }
        // }
    };
}
