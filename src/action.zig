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
    if (wm.current_workspace == index) return;

    wm.workspaces[wm.current_workspace].unmapAll(wm.display);
    wm.workspaces[index].mapAll(wm.display);
    wm.workspaces[index].arrange(&wm.root.alignment, wm.display);
    wm.current_workspace = index;
}

pub fn tag(wm: *WM, index: u8) void {
    const workspace = &wm.workspaces[wm.current_workspace];
    const workspace_window = workspace.active_window;

    if (workspace_window) |node| {
        std.debug.print("Trying to tag window: {d}", .{node.data.window});
        workspace.unmapAll(wm.display);

        for (&wm.workspaces) |*other| {
            other.untag(node.data);
        }

        node.data.mask.clear();
        node.data.mask.tag(index) catch unreachable; // TODO
        workspace.tag(node.data);

        workspace.arrange(&wm.root.alignment, wm.display);
        workspace.mapAll(wm.display);

        std.debug.print("Tagged window: {}", .{node.data.window});
    }
}

pub fn toggletag(_: *WM) void {}

pub fn check(wm: *WM) void {
    wm.check();
}

pub fn setLayout(wm: *WM, layout: Layout.Layouts) void {
    wm.workspaces[wm.current_workspace].layout = layout.asLayout();
}

pub fn focusNext(wm: *WM) void {
    wm.workspaces[wm.current_workspace].focusNext();
}

pub fn focusPrev(wm: *WM) void {
    wm.workspaces[wm.current_workspace].focusPrev();
}

pub fn createWindow(wm: *WM, x11_window: x11.Window) void {
    var w = WM.Window.fromX11Window(x11_window);
    w.updateAlignment(wm.display);

    const node = wm.alloc.create(WM.WindowList.Node) catch return;
    node.* = WM.WindowList.Node{
        .data = w,
    };

    wm.windows.append(node);
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
