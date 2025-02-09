const Layout = @import("layout.zig").Layout;
const Window = @import("Window.zig");
const WindowManager = @import("WindowManager.zig");

const std = @import("std");
const util = @import("util.zig");
const x11 = @import("X11.zig");

pub fn rearrangeWorkspace(wm: *WindowManager) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    workspace.arrangeWindows(&wm.root.alignment, wm.display) catch return;
}

pub fn setMode(wm: *WindowManager, mode: Window.Mode) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    if (workspace.active_window) |node| {
        node.data.setMode(mode);
    }
}

pub fn toggleFloating(wm: *WindowManager) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    if (workspace.active_window) |node| {
        if (node.data.mode == .floating) {
            node.data.setMode(.default);
        } else {
            node.data.setMode(.floating);
        }
    }
}

// TODO: Unmapping all windows is not always necessary since a window can be in multiple workspaces
pub fn view(wm: *WindowManager, index: u8) void {
    std.debug.print("Viewing workspace {d}\n", .{index});
    const prev = &wm.workspaces[wm.current_workspace];
    prev.unmapAllWindows(wm.display);

    const current = &wm.workspaces[index];
    current.mapAllWindows(wm.display);
    current.arrangeWindows(&wm.root.alignment, wm.display) catch return;

    wm.current_workspace = index;
}

pub fn tag(wm: *WindowManager, index: u8) void {
    const prev = &wm.workspaces[wm.current_workspace];
    const workspace_window = prev.active_window;

    if (workspace_window) |node| {
        const window_ptr = node.data;

        std.debug.print("Trying to tag window: {d} to {d}\n", .{ node.data.handle, index });
        std.debug.print("Node: {*}\n", .{node});
        prev.unmapAllWindows(wm.display);

        for (&wm.workspaces) |*other| {
            other.untagWindow(window_ptr) catch return;
        }

        const current = &wm.workspaces[index];
        current.tagWindow(window_ptr) catch return;
    }
}

pub fn toggletag(_: *WindowManager) void {}

pub fn focus(wm: *WindowManager, x11_window: x11.Window) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    if (workspace.active_window) |node| {
        if (node.data.handle == x11_window) return;
    }

    var current = workspace.windows.first;
    while (current) |node| : (current = node.next) {
        if (node.data.handle == x11_window) {
            node.data.focus(wm.display) catch return;
        } else node.data.unfocus(wm.display) catch return;
    }
}

pub fn focusNext(wm: *WindowManager) void {
    const workspace = &wm.workspaces[wm.current_workspace];

    if (workspace.active_window) |node| {
        node.data.unfocus(wm.display) catch return;
    }
    workspace.focusNextWindow();

    if (workspace.active_window) |node| {
        node.data.focus(wm.display) catch return;
    }
}

pub fn focusPrev(wm: *WindowManager) void {
    const workspace = &wm.workspaces[wm.current_workspace];

    if (workspace.active_window) |node| {
        node.data.unfocus(wm.display) catch return;
    }
    workspace.focusPrevWindow();

    if (workspace.active_window) |node| {
        node.data.focus(wm.display) catch return;
    }
}

pub fn kill(wm: *WindowManager) void {
    const window_node = wm.currentWorkspace().active_window orelse return;
    wm.destroyWindow(window_node.data.handle) catch return;
}

pub fn setLayout(wm: *WindowManager, layout: Layout) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    workspace.layout = layout;
    workspace.arrangeWindows(&wm.root.alignment, wm.display) catch return;
}

pub fn process(wm: *WindowManager, comptime args: []const []const u8) void {
    const display = std.mem.span(x11.DisplayString(wm.display));

    var env_map = std.process.EnvMap.init(std.heap.c_allocator);
    defer env_map.deinit();

    env_map.put("DISPLAY", display) catch return;

    util.spawn_process(&env_map, args, wm.allocator) catch return;
}

pub fn incrementLayout(wm: *WindowManager, amount: usize) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    workspace.incrementIndex(amount);
    workspace.arrangeWindows(&wm.root.alignment, wm.display) catch return;
}

pub fn decrementLayout(wm: *WindowManager, amount: usize) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    workspace.decrementIndex(amount);
    workspace.arrangeWindows(&wm.root.alignment, wm.display) catch return;
}

pub fn moveWindow(wm: *WindowManager, x: u16, y: u16) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    std.log.info("Trying to move window to {} {}", .{ x, y });
    if (workspace.active_window) |node| {
        if (node.data.mode != .floating) return;
        node.data.alignment.pos = .{ .x = x, .y = y };
        node.data.arrange(wm.display) catch return;
    }
}

pub fn check(self: *WindowManager) void {
    const writer = std.io.getStdErr().writer();

    writer.print("\n=== Window Manager Status ===\n", .{}) catch return;
    writer.print("Running: {}\n", .{self.running}) catch return;
    writer.print("Current Workspace: {}\n", .{self.current_workspace}) catch return;
    writer.print("Total Windows Managed: {}\n", .{self.windows.len}) catch return;

    writer.print("\n=== Root Window ===\n", .{}) catch return;
    writer.print("Handle: {x}\n", .{self.root.handle}) catch return;
    writer.print("Alignment:\n", .{}) catch return;
    writer.print("  Position: ({}, {})\n", .{
        self.root.alignment.pos.x,
        self.root.alignment.pos.y,
    }) catch return;
    writer.print("  Size: {}x{}\n", .{
        self.root.alignment.width,
        self.root.alignment.height,
    }) catch return;

    writer.print("\n=== Workspaces ===\n", .{}) catch return;
    for (&self.workspaces, 0..) |*workspace, i| {
        const is_current = i == self.current_workspace;
        writer.print("\nWorkspace {}{s}\n", .{
            i,
            if (is_current) " (Current)" else "",
        }) catch return;
        writer.print("Window Count: {}\n", .{workspace.windows.len}) catch return;

        if (workspace.windows.len > 0) {
            writer.print("Windows:\n", .{}) catch return;
            var it = workspace.windows.first;
            var window_index: usize = 0;
            while (it) |node| : (it = node.next) {
                const window = node.data;
                window_index += 1;

                writer.print("  {}: Window {x}\n", .{ window_index, window.handle }) catch return;
                writer.print("    Alignment:\n", .{}) catch return;
                writer.print("      Position: ({}, {})\n", .{
                    window.alignment.pos.x,
                    window.alignment.pos.y,
                }) catch return;
                writer.print("      Size: {}x{}\n", .{
                    window.alignment.width,
                    window.alignment.height,
                }) catch return;

                var attrs: x11.XWindowAttributes = undefined;
                if (x11.XGetWindowAttributes(self.display, window.handle, &attrs) == 1) {
                    writer.print("    State:\n", .{}) catch return;
                    writer.print("      Mapped: {}\n", .{attrs.map_state == x11.IsViewable}) catch return;
                    writer.print("      Override Redirect: {}\n", .{attrs.override_redirect == x11.True}) catch return;
                    writer.print("      Border Width: {}\n", .{attrs.border_width}) catch return;
                }
            }
        }
    }

    writer.print("\n=== Global Window List ===\n", .{}) catch return;
    var global_it = self.windows.first;
    var global_index: usize = 0;
    while (global_it) |node| : (global_it = node.next) {
        global_index += 1;
        writer.print("Window {}: {x}\n", .{ global_index, node.data.handle }) catch return;
    }

    writer.print("\n=== End of Debug Info ===\n\n", .{}) catch return;
}
