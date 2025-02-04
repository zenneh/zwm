// Transforms the handlers into an indexable array at compile time
// since zig doesn't support a nice syntax for this like in C.
const WM = @import("WindowManager.zig");
const x = @import("X11.zig");

pub fn createHandlers(comptime handlers: []const WM.HandlerEntry) [x.LASTEvent][]const WM.LocalHandler {
    return comptime blk: {
        var result: [x.LASTEvent][]const WM.LocalHandler = undefined;
        // Initialize array with empty slices
        for (&result, 0..) |*slot, i| {
            // Count how many handlers we have for this event
            var total_handlers: usize = 0;
            for (handlers) |handler| {
                if (@as(usize, @intCast(handler.event)) == i) {
                    total_handlers += handler.handlers.len;
                }
            }
            if (total_handlers == 0) {
                slot.* = &[_]WM.LocalHandler{};
                continue;
            }

            // Create the handlers array directly in the slot
            const static_handlers = blk2: {
                var arr: [total_handlers]WM.LocalHandler = undefined;
                var pos: usize = 0;
                for (handlers) |handler| {
                    if (@as(usize, @intCast(handler.event)) == i) {
                        for (handler.handlers) |h| {
                            arr[pos] = h;
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

pub fn handleKeyPress(comptime shortcuts: []const type) fn (*WM, *const x.XKeyEvent) void {
    return struct {
        pub fn handle(_: *WM, casted: *const x.XKeyEvent) void {
            inline for (shortcuts) |shortcut| {
                if (casted.state == shortcut.mod and casted.keycode == shortcut.keycode) {
                    shortcut.invoke();
                }
            }
        }
    }.handle;
}
