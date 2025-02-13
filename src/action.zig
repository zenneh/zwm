const std = @import("std");
const util = @import("util.zig");
const x11 = @import("X11.zig");
const layout = @import("layout.zig");

const window_manager = @import("WindowManager.zig");

const Layout = @import("layout.zig").Layout;
const Window = @import("window.zig");
const Context = window_manager.Context;
const Error = window_manager.Error;

// View A workspace
pub fn view(ctx: *Context, index: usize) Error!void {
    std.log.info("view workspace {}", .{index});
    try ctx.viewWorkspace(index);
}

// Tag a window to a workspace
pub fn tag(ctx: *Context, index: usize) Error!void {
    std.log.info("Tag window to {d}", .{index});
    try ctx.tagWindow(index);
}

// Toggle the tag of a window to a workspace
pub fn toggleTag(ctx: *Context, index: usize) Error!void {
    std.log.info("Toggle window tag {d}", .{index});
    try ctx.toggleTagWindow(index);
}

pub fn check(ctx: *Context) Error!void {
    try ctx.check();
}

pub fn focusNext(ctx: *Context) Error!void {
    try ctx.focusNextWindow();
}

pub fn focusPrev(ctx: *Context) Error!void {
    try ctx.focusPrevWindow();
}

pub fn setLayout(ctx: *Context, l: *const layout.Layout) Error!void {
    std.log.info("Setting layout to {s}", .{@typeName(@TypeOf(l.*))});
    try ctx.setLayout(l);
}

pub fn incrementMaster(ctx: *Context, amount: i8) Error!void {
    try ctx.incrementMaster(amount);
}

pub fn process(ctx: *Context, args: []const []const u8) Error!void {
    try ctx.process(args);
}

pub fn kill(ctx: *Context) Error!void {
    try ctx.kill();
}

pub fn move(_: *Context) Error!void {}
// fn rearrangeWorkspace(wm: *WindowManager) void {
//     const workspace = &wm.workspaces[wm.current_workspace];
//     workspace.arrangeWindows(&wm.root.alignment, wm.display) catch return;
// }

// pub fn setMode(wm: *WindowManager, mode: Window.Mode) void {
//     const workspace = &wm.workspaces[wm.current_workspace];
//     if (workspace.active_window) |node| {
//         node.data.setMode(mode);
//         rearrangeWorkspace(wm);
//     }
// }

// pub fn toggleFloating(wm: *WindowManager) void {
//     const workspace = &wm.workspaces[wm.current_workspace];
//     if (workspace.active_window) |node| {
//         if (node.data.mode == .floating) {
//             setMode(wm, .default);
//         } else {
//             setMode(wm, .floating);
//         }
//     }
// }

// // TODO: Unmapping all windows is not always necessary since a window can be in multiple workspaces
// pub fn view(wm: *WindowManager, index: u8) void {
//     std.debug.print("Viewing workspace {d}\n", .{index});
//     const prev = &wm.workspaces[wm.current_workspace];
//     prev.unmapAllWindows(wm.display);

//     const current = &wm.workspaces[index];
//     current.mapAllWindows(wm.display);
//     current.arrangeWindows(&wm.root.alignment, wm.display) catch return;

//     wm.current_workspace = index;
// }

// pub fn tag(wm: *WindowManager, index: u8) void {
//     const prev = &wm.workspaces[wm.current_workspace];
//     const workspace_window = prev.active_window;

//     if (workspace_window) |node| {
//         const window_ptr = node.data;

//         std.debug.print("Trying to tag window: {d} to {d}\n", .{ node.data.handle, index });
//         std.debug.print("Node: {*}\n", .{node});
//         prev.unmapAllWindows(wm.display);

//         for (&wm.workspaces) |*other| {
//             other.untagWindow(window_ptr) catch return;
//         }

//         const current = &wm.workspaces[index];
//         current.tagWindow(window_ptr) catch return;
//     }
// }

// // Toggle a tag of a given window,
// // only if window is tagged in at least 1 other workspace
// pub fn toggleTag(wm: *WindowManager, index: u8) void {
//     if (index == wm.current_workspace) return;

//     const workspace = &wm.workspaces[wm.current_workspace];

//     if (workspace.active_window) |node| {
//         var window_count: usize = 0;
//         for (&wm.workspaces) |*other| {
//             if (other.findWindowNode(node.data) != null) window_count += 1;
//         }

//         if (window_count > 1) wm.workspaces[index].toggleTagWindow(node.data) catch unreachable;
//     }
// }

// pub fn focus(wm: *WindowManager, x11_window: x11.Window) void {
//     const workspace = &wm.workspaces[wm.current_workspace];
//     if (workspace.active_window) |node| {
//         if (node.data.handle == x11_window) return;
//     }

//     var current = workspace.windows.first;
//     while (current) |node| : (current = node.next) {
//         if (node.data.handle == x11_window) {
//             node.data.focus(wm.display) catch return;
//         } else node.data.unfocus(wm.display) catch return;
//     }
// }

// pub fn focusNext(wm: *WindowManager) void {
//     const workspace = &wm.workspaces[wm.current_workspace];

//     if (workspace.active_window) |node| {
//         node.data.unfocus(wm.display) catch return;
//     }
//     workspace.focusNextWindow();

//     if (workspace.active_window) |node| {
//         node.data.focus(wm.display) catch return;
//     }
// }

// pub fn focusPrev(wm: *WindowManager) void {
//     const workspace = &wm.workspaces[wm.current_workspace];

//     if (workspace.active_window) |node| {
//         node.data.unfocus(wm.display) catch return;
//     }
//     workspace.focusPrevWindow();

//     if (workspace.active_window) |node| {
//         node.data.focus(wm.display) catch return;
//     }
// }

// pub fn kill(wm: *WindowManager) void {
//     const window_node = wm.currentWorkspace().active_window orelse return;
//     wm.destroyWindow(window_node.data.handle) catch return;
// }

// pub fn setLayout(wm: *WindowManager, layout: Layout) void {
//     const workspace = &wm.workspaces[wm.current_workspace];
//     workspace.layout = layout;
//     workspace.arrangeWindows(&wm.root.alignment, wm.display) catch return;
// }

// pub fn incrementLayout(wm: *WindowManager, amount: usize) void {
//     const workspace = &wm.workspaces[wm.current_workspace];
//     workspace.incrementIndex(amount);
//     workspace.arrangeWindows(&wm.root.alignment, wm.display) catch return;
// }

// pub fn decrementLayout(wm: *WindowManager, amount: usize) void {
//     const workspace = &wm.workspaces[wm.current_workspace];
//     workspace.decrementIndex(amount);
//     workspace.arrangeWindows(&wm.root.alignment, wm.display) catch return;
// }

// pub fn moveWindow(wm: *WindowManager, x: c_int, y: c_int) void {
//     const state = &(wm.input_state orelse return);
//     const workspace = &wm.workspaces[wm.current_workspace];
//     if (workspace.active_window) |node| {
//         if (node.data.mode != .floating) return;
//         const dx = x - state.x;
//         const dy = y - state.y;
//         std.log.info("D: {} {}", .{ dx, dy });
//         const new_x = node.data.alignment.pos.x + dx;
//         const new_y = node.data.alignment.pos.y + dy;
//         std.log.info("Trying to move to: {} {}", .{ new_x, new_y });
//         node.data.alignment.pos.x = new_x;
//         node.data.alignment.pos.y = new_y;
//         node.data.arrange(wm.display) catch return;

//         state.x += dx;
//         state.y += dy;
//     }
// }

// pub fn check(self: *WindowManager) void {
//     const writer = std.io.getStdErr().writer();

//     writer.print("\n=== Window Manager Status ===\n", .{}) catch return;
//     writer.print("Running: {}\n", .{self.running}) catch return;
//     writer.print("Current Workspace: {}\n", .{self.current_workspace}) catch return;
//     writer.print("Total Windows Managed: {}\n", .{self.windows.len}) catch return;

//     writer.print("\n=== Root Window ===\n", .{}) catch return;
//     writer.print("Handle: {x}\n", .{self.root.handle}) catch return;
//     writer.print("Alignment:\n", .{}) catch return;
//     writer.print("  Position: ({}, {})\n", .{
//         self.root.alignment.pos.x,
//         self.root.alignment.pos.y,
//     }) catch return;
//     writer.print("  Size: {}x{}\n", .{
//         self.root.alignment.width,
//         self.root.alignment.height,
//     }) catch return;

//     writer.print("\n=== Workspaces ===\n", .{}) catch return;
//     for (&self.workspaces, 0..) |*workspace, i| {
//         const is_current = i == self.current_workspace;
//         writer.print("\nWorkspace {}{s}\n", .{
//             i,
//             if (is_current) " (Current)" else "",
//         }) catch return;
//         writer.print("Window Count: {}\n", .{workspace.windows.len}) catch return;

//         if (workspace.windows.len > 0) {
//             writer.print("Windows:\n", .{}) catch return;
//             var it = workspace.windows.first;
//             var window_index: usize = 0;
//             while (it) |node| : (it = node.next) {
//                 const window = node.data;
//                 window_index += 1;

//                 writer.print("  {}: Window {x}\n", .{ window_index, window.handle }) catch return;
//                 writer.print("    Alignment:\n", .{}) catch return;
//                 writer.print("      Position: ({}, {})\n", .{
//                     window.alignment.pos.x,
//                     window.alignment.pos.y,
//                 }) catch return;
//                 writer.print("      Size: {}x{}\n", .{
//                     window.alignment.width,
//                     window.alignment.height,
//                 }) catch return;

//                 var attrs: x11.XWindowAttributes = undefined;
//                 if (x11.XGetWindowAttributes(self.display, window.handle, &attrs) == 1) {
//                     writer.print("    State:\n", .{}) catch return;
//                     writer.print("      Mapped: {}\n", .{attrs.map_state == x11.IsViewable}) catch return;
//                     writer.print("      Override Redirect: {}\n", .{attrs.override_redirect == x11.True}) catch return;
//                     writer.print("      Border Width: {}\n", .{attrs.border_width}) catch return;
//                 }
//             }
//         }
//     }

//     writer.print("\n=== Global Window List ===\n", .{}) catch return;
//     var global_it = self.windows.first;
//     var global_index: usize = 0;
//     while (global_it) |node| : (global_it = node.next) {
//         global_index += 1;
//         writer.print("Window {}: {x}\n", .{ global_index, node.data.handle }) catch return;
//     }

//     writer.print("\n=== End of Debug Info ===\n\n", .{}) catch return;
// }
