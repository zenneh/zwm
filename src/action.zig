const Layout = @import("layout.zig");
const WM = @import("WindowManager.zig");
const std = @import("std");
const util = @import("util.zig");
const x11 = @import("X11.zig");

fn Action(comptime F: type) type {
    return struct {
        func: F,
        args: std.meta.ArgsTuple(F),
    };
}

// Helper to create an action entry with type checking
// The handler method must contain a *WS reference as the first argument
pub const CallableShortcut = struct {
    mod: u8,
    keycode: u8,
    invoke: *const fn (wm: *WM) void,
};

pub fn Shortcut(
    comptime modifier: u8,
    comptime key: u8,
    comptime func: anytype,
    comptime args: anytype,
) CallableShortcut {
    const F = @TypeOf(func);
    const ArgsTuple = std.meta.ArgsTuple(F);
    const ProvidedArgs = @TypeOf(args);
    const WindowType = @TypeOf(*WM);

    comptime {
        const expected_fields = @typeInfo(ArgsTuple).Struct.fields;
        const provided_fields = @typeInfo(ProvidedArgs).Struct.fields;

        // Check if handler method has the correct parameters
        if (expected_fields.len == 0 or @TypeOf(expected_fields[0].type) != WindowType) {
            @compileError(std.fmt.comptimePrint("The action method should have a *WM as the first param", .{}));
        }

        if (expected_fields.len - 1 != provided_fields.len) {
            @compileError(std.fmt.comptimePrint("Wrong number of arguments. Expected {d} arguments, got {d}", .{ expected_fields - 1, provided_fields }));
        }

        for (expected_fields[1..], provided_fields) |exp, prov| {
            if (exp.type != prov.type) {
                @compileError(std.fmt.comptimePrint("Type mismatch for argument {s}. Expected {}, got {}", .{ exp.name, exp.type, prov.type }));
            }
        }
    }

    return .{
        .mod = modifier,
        .keycode = key,
        .invoke = comptime blk: {
            break :blk struct {
                pub fn invoke(wm: *WM) void {
                    @call(.auto, func, .{wm} ++ args);
                }
            }.invoke;
        },
    };
}

pub fn view(wm: *WM, index: u8) void {
    const prev = &wm.workspaces[wm.current_workspace];
    prev.unmapAll(wm.display);

    const current = &wm.workspaces[index];
    current.mapAll(wm.display);
    current.arrange(&wm.root.alignment, wm.display);

    wm.current_workspace = index;
}

pub fn tag(wm: *WM, index: u8) void {
    const prev = &wm.workspaces[wm.current_workspace];
    const workspace_window = prev.active_window;

    if (workspace_window) |node| {
        const window_ptr = node.data;

        std.debug.print("Trying to tag window: {d} to {d}\n", .{ node.data.window, index });
        std.debug.print("Node: {*}\n", .{node});
        prev.unmapAll(wm.display);

        for (&wm.workspaces) |*other| {
            other.untag(window_ptr);
        }

        const current = &wm.workspaces[index];
        current.tag(window_ptr);
    }
}

pub fn toggletag(_: *WM) void {}

pub fn check(wm: *WM) void {
    wm.check();
}

pub fn setLayout(wm: *WM, layout: Layout.Layouts) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    workspace.layout = layout.asLayout();
}

pub fn focusNext(wm: *WM) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    workspace.focusNext();

    if (workspace.active_window) |node| {
        node.data.focus(wm.display);
    }
}

pub fn focusPrev(wm: *WM) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    workspace.focusPrev();

    if (workspace.active_window) |node| {
        node.data.focus(wm.display);
    }
}

pub fn createWindow(wm: *WM, x11_window: x11.Window) void {
    var w = WM.Window.fromX11Window(x11_window);
    w.updateAlignment(wm.display);

    const node = wm.alloc.create(WM.WindowList.Node) catch return;
    node.* = WM.WindowList.Node{
        .data = w,
    };

    wm.windows.append(node);

    const workspace = &wm.workspaces[wm.current_workspace];
    workspace.tag(&node.data);
}

pub fn destroyWindow(wm: *WM, x11_window: x11.Window) void {
    var node = wm.windows.first;
    while (node) |item| : (node = item.next) {
        if (item.data.window != x11_window) continue;

        for (&wm.workspaces) |*workspace| {
            workspace.untag(&item.data);
        }
        wm.windows.remove(item);
        wm.alloc.destroy(item);
        break;
    }
}

pub fn process(wm: *WM, comptime args: []const []const u8) void {
    const display = std.mem.span(x11.DisplayString(wm.display));

    var env_map = std.process.EnvMap.init(std.heap.c_allocator);
    defer env_map.deinit();

    env_map.put("DISPLAY", display) catch return;

    util.spawn_process(&env_map, args, wm.alloc) catch return;
}
