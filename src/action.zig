const std = @import("std");
const Layout = @import("layout.zig");
const WM = @import("WindowManager.zig");

fn Action(comptime F: type) type {
    return struct {
        func: F,
        args: std.meta.ArgsTuple(F),
    };
}

// Helper to create an action entry with type checking
// The handler method must contain a *WS reference as the first argument
pub fn ActionEntry(
    comptime modifier: u8,
    comptime key: u8,
    comptime func: anytype,
    comptime args: anytype,
) type {
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

    return struct {
        pub const mod = modifier;
        pub const keycode = key;

        pub fn invoke(wm: *WM) void {
            @call(.auto, func, .{wm} ++ args);
        }
    };
}

pub fn view(wm: *WM, index: u8) void {
    wm.workspaces[wm.current_workspace].unmapAll(wm.display);
    wm.workspaces[index].mapAll(wm.display);
    wm.workspaces[index].arrange(wm.display);
    wm.current_workspace = index;
}

pub fn tag(wm: *WM, index: u8) void {
    std.debug.print("Trying to tag window: {}", .{wm.current_window.?.window});
    if (wm.current_window == null) return;

    wm.workspaces[wm.current_workspace].unmapAll(wm.display);

    // Untag window from previous workspaces
    for (&wm.workspaces) |*workspace| {
        workspace.untag(wm.current_window.?);
    }

    // Clear the current mask
    wm.current_window.?.mask.clear();

    // Tag the correct mask
    wm.current_window.?.mask.tag(index) catch return;

    // insert window in the correct workspace
    wm.workspaces[index].tag(wm.current_window.?);

    //TODO redraw layout
    wm.workspaces[wm.current_workspace].mapAll(wm.display);
    wm.workspaces[wm.current_workspace].arrange(wm.display);
    std.debug.print("Tagged window: {}", .{wm.current_window.?.window});
}

pub fn toggletag(_: *WM) void {}

pub fn check(wm: *WM) void {
    wm.check();
}

pub fn setLayout(wm: *WM, layout: Layout.Layouts) void {
    wm.workspaces[wm.current_workspace].layout = layout.asLayout();
}
