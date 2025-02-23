const std = @import("std");
const _layout = @import("layout.zig");
const x11 = @import("X11.zig");
const _window = @import("window.zig");
const _window_manager = @import("WindowManager.zig");

const Alignment = _layout.Alignment;
const Layout = _layout.Layout;
const Allocator = std.mem.Allocator;

const WINDOW_MASK = _window_manager.WINDOW_MASK;

pub const Error = error{
    WindowAlreadyInWorkspace,
    WindowNotInWorkspace,
    NoCurrentWindow,
} || std.mem.Allocator.Error || _window.Error;

pub fn WindowData(comptime T: type) type {
    return struct {
        ptr: *T,
        preferred: ?Alignment, // Preferred alignment
    };
}

// A workspace owns a window node for the time being active in here
// Ownership can be transfered to other workspaces
pub fn Workspace(comptime Mask: type) type {
    const Window = _window.Window(Mask);
    const Windows = std.DoublyLinkedList(WindowData(Window));

    return struct {
        layout: *const Layout,

        windows: Windows,

        master: usize,

        allocator: Allocator,

        current_window: ?*Windows.Node,

        const Self = @This();

        pub fn init(allocator: Allocator, layout: *const Layout) Self {
            return Self{
                .layout = layout,
                .windows = .{},
                .master = 0,
                .allocator = allocator,
                .current_window = null,
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
            self.current_window = node;

            try self.focus(display);
        }

        pub fn focus(self: *Self, display: *x11.Display) Error!void {
            if (self.current_window == null) {
                self.current_window = self.windows.first;
            }
            var it = self.windows.first;
            while (it) |node| : (it = node.next) {
                if (node == self.current_window) {
                    try node.data.ptr.focus(display);
                } else {
                    try node.data.ptr.unfocus(display);
                }
            }
        }

        pub fn arrange(self: *Self, alignment: Alignment, display: *x11.Display) Error!void {
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
            while (it) |node| : ({
                it = node.next;
                index += 1;
            }) {
                if (node.data.ptr.mode == .default) {
                    windows[index] = node.data.ptr;
                    alignments[index] = &node.data.ptr.alignment;
                    if (node.data.ptr.preferences) |*p| {
                        preferences[index] = p;
                    } else {
                        preferences[index] = null;
                    }
                }
            }

            self.layout.arrange(&.{
                .root = &alignment,
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
            self.allocator.destroy(node);

            self.current_window = null;
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
