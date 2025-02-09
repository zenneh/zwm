const WindowManager = @import("WindowManager.zig");

const std = @import("std");

// TODO: add predicates

pub const Shortcut = struct {
    mod: c_uint,
    key: c_int,
    invoke: *const fn (*WindowManager) void,
};

pub fn createShortCut(
    comptime mod: c_uint,
    comptime key: c_int,
    comptime action: anytype,
    comptime args: anytype,
) Shortcut {
    const F = @TypeOf(action);
    const ArgsTuple = std.meta.ArgsTuple(F);
    const ProvidedArgs = @TypeOf(args);
    const WindowType = @TypeOf(*WindowManager);

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
        .mod = mod,
        .key = key,
        .invoke = comptime blk: {
            break :blk struct {
                pub fn invoke(wm: *WindowManager) void {
                    @call(.auto, action, .{wm} ++ args);
                }
            }.invoke;
        },
    };
}
