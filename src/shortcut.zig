const window_manager = @import("WindowManager.zig");
const Context = window_manager.Context;
const Error = window_manager.Error;

const std = @import("std");

// TODO: add predicates

pub const Shortcut = struct {
    mod: c_uint,
    key: c_int,
    invoke: *const fn (ctx: *Context) Error!void,
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
    const WindowType = @TypeOf(*Context);

    comptime {
        const expected_fields = @typeInfo(ArgsTuple).Struct.fields;
        const provided_fields = @typeInfo(ProvidedArgs).Struct.fields;

        // Check if handler method has the correct parameters
        if (expected_fields.len == 0 or @TypeOf(expected_fields[0].type) != WindowType) {
            @compileError(std.fmt.comptimePrint("The action method should have a *Context as the first param", .{}));
        }

        if (expected_fields.len - 1 != provided_fields.len) {
            @compileError(std.fmt.comptimePrint("Wrong number of arguments. Expected {d} arguments, got {d}", .{ expected_fields.len - 1, provided_fields.len }));
        }

        // for (expected_fields[1..], provided_fields) |exp, prov| {
        //     if (exp.type != prov.type) {
        //         @compileError(std.fmt.comptimePrint("Type mismatch for argument {s}. Expected {}, got {}", .{ exp.name, exp.type, prov.type }));
        //     }
        // }
    }

    return .{
        .mod = mod,
        .key = key,
        .invoke = comptime blk: {
            break :blk struct {
                pub fn invoke(ctx: *Context) Error!void {
                    const ArgFields = std.meta.fields(ArgsTuple);

                    if (ArgFields.len > 1) {
                        const ArgumentTypes = std.meta.Tuple(&[_]type{
                            ArgFields[1].type, // Skip the first field (Context)
                        });
                        var casted_args: ArgumentTypes = undefined;

                        inline for (std.meta.fields(ProvidedArgs), 0..) |field, i| {
                            casted_args[i] = @as(ArgFields[i + 1].type, @field(args, field.name));
                        }
                        try @call(.auto, action, .{ctx} ++ casted_args);
                        return;
                    }

                    try @call(.auto, action, .{ctx});
                }
            }.invoke;
        },
    };
}
