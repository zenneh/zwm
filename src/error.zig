const WindowManager = @import("WindowManager.zig");
const x11 = @import("X11.zig");

fn createErrorHandlers(wm: *WindowManager) type {
    return struct {

        // A mock error handler that does nothing
        const mock = struct {
            pub fn handle(_: ?*x11.Display, _: [*c]x11.XErrorEvent) callconv(.C) c_int {}
        }.handle;

        const default = struct {
            pub fn handle(display: ?*x11.Display, event: [*c]x11.XErrorEvent) callconv(.C) c_int {
                // wm.handleError(event);
                const buffer: [256]u8 = .{0} ** 256;
                x11.XGetErrorText(display, event.*.error_code, &buffer, 256);
            }
        }.handle;

        const local = struct {
            pub fn handle(_: ?*x11.Display, event: [*c]x11.XErrorEvent) callconv(.C) c_int {
                wm.handleError(event);
            }
        }.handle;
    };
}
// fn xErrorHandler(_: ?*x11.Display, event: [*c]x11.XErrorEvent) callconv(.C) c_int {
//     if (CURRENT) |wm| {
//         wm.handleError(event);
//     }

//     return 0;
// }
