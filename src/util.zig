const x11 = @import("X11.zig");
const std = @import("std");
const action = @import("action.zig");
const process = std.process;
const handler = @import("handler.zig");
const shortcut = @import("shortcut.zig");
const layout = @import("layout.zig");
const window_manager = @import("WindowManager.zig");

const Context = window_manager.Context;
const Error = window_manager.Error;
const Alloc = std.mem.Allocator;

pub fn createWorkspaces(comptime mask: type, comptime window: type) type {
    return @TypeOf([@bitSizeOf(mask)]std.DoublyLinkedList(*window));
}

pub fn createLayoutsType(comptime T: type) type {
    return @TypeOf([@bitSizeOf(T)]*const layout.Layout);
}

pub fn createLayouts(comptime T: type, default: *const layout.Layout) [@bitSizeOf(T)]*const layout.Layout {
    return .{default} ** @bitSizeOf(T);
}

pub fn createMasterCounts(comptime T: type) [@bitSizeOf(T)]usize {
    return .{0} ** @bitSizeOf(T);
}

pub fn createCurrentWorkspaceType(comptime T: type) type {
    const bits = @bitSizeOf(T);

    const log_bits = @as(comptime_int, @intFromFloat(@ceil(std.math.log2(@as(f64, @floatFromInt(bits))))));

    return @Type(.{ .Int = .{
        .signedness = .unsigned,
        .bits = log_bits,
    } });
}

pub fn requireUnsignedInt(comptime T: type) type {
    comptime {
        switch (@typeInfo(T)) {
            .Int => |int| {
                if (int.signedness == .unsigned) {
                    return T;
                }
                @compileError("Integer must be unsigned");
            },
            else => @compileError("Type must be an unsigned integer"),
        }
    }
}

pub fn createEventHandlers(comptime handlers: []const handler.HandlerEntry) [x11.LASTEvent][]const handler.Handler {
    return comptime blk: {
        var result: [x11.LASTEvent][]const handler.Handler = undefined;
        for (&result, 0..) |*slot, i| {
            var total_handlers: usize = 0;
            for (handlers) |h| {
                if (@as(usize, @intCast(h.event)) == i) {
                    total_handlers += h.handlers.len;
                }
            }
            if (total_handlers == 0) {
                slot.* = &[_]handler.Handler{};
                continue;
            }

            const static_handlers = blk2: {
                var arr: [total_handlers]handler.Handler = undefined;
                var pos: usize = 0;
                for (handlers) |h| {
                    if (@as(usize, @intCast(h.event)) == i) {
                        for (h.handlers) |k| {
                            arr[pos] = k;
                            pos += 1;
                        }
                    }
                }
                break :blk2 arr;
            };
            slot.* = &static_handlers;
        }
        break :blk result;
    };
}

pub fn createButtonShortcutHandler(comptime shortcuts: []const shortcut.Shortcut) fn (*Context, *const x11.XButtonEvent) Error!void {

    // Validate shortcuts
    comptime {
        for (shortcuts, 0..) |s, index| {
            for (shortcuts[index + 1 ..]) |other| {
                if (s.key == other.key and s.mod == other.mod) {
                    @compileError(std.fmt.comptimePrint("Duplicate shortcut: key {s} with modifier {s}", .{ x11.getKeyName(s.key), x11.getModifierName(s.mod) }));
                }
            }
        }
    }

    return struct {
        pub fn handle(ctx: *Context, casted: *const x11.XButtonEvent) Error!void {
            inline for (shortcuts) |s| {
                if (casted.state == s.mod and casted.button == s.key) {
                    try s.invoke(ctx);
                }
            }
        }
    }.handle;
}

pub fn createKeyShortcutHandler(comptime shortcuts: []const shortcut.Shortcut) fn (*Context, *const x11.XKeyEvent) Error!void {

    // Validate shortcuts
    comptime {
        for (shortcuts, 0..) |s, index| {
            for (shortcuts[index + 1 ..]) |other| {
                if (s.key == other.key and s.mod == other.mod) {
                    @compileError(std.fmt.comptimePrint("Duplicate shortcut: key {s} with modifier {s}", .{ x11.getKeyName(s.key), x11.getModifierName(s.mod) }));
                }
            }
        }
    }

    return struct {
        pub fn handle(ctx: *Context, casted: *const x11.XKeyEvent) Error!void {
            inline for (shortcuts) |s| {
                const keysym = x11.XKeycodeToKeysym(ctx.display, @intCast(casted.keycode), 0);

                if (casted.state == s.mod and keysym == s.key) {
                    try s.invoke(ctx);
                }
            }
        }
    }.handle;
}

pub fn spawn_process(env: ?*const process.EnvMap, argv: []const []const u8, allocator: Alloc) !void {
    var child = process.Child.init(argv, allocator);

    child.env_map = env;

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();
}

// Create a command string
pub fn cmd(comptime command: []const u8) []const []const u8 {
    return &[_][]const u8{command};
}
