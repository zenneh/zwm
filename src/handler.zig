const window_manager = @import("WindowManager.zig");
const Context = window_manager.Context;
const Error = window_manager.Error;
const x11 = @import("X11.zig");

const std = @import("std");
const debug = std.debug;
const action = @import("action.zig");
const util = @import("util.zig");

pub const Handler = *const fn (ctx: *const Context, event: *const x11.XEvent) Error!void;

pub const HandlerEntry = struct {
    event: c_int,
    handlers: []const Handler,
};

pub const Default = &[_]HandlerEntry{
    .{ .event = x11.MapRequest, .handlers = &[_]Handler{
        mapRequest,
    } },
    // .{ .event = x11.MappingNotify, .handlers = &[_]Handler{
    //     mapNotify,
    // } },
    .{ .event = x11.KeyPress, .handlers = &[_]Handler{
        keyPress,
    } },
    // .{ .event = x11.DestroyNotify, .handlers = &[_]Handler{
    //     keyPress,
    // } },
    // .{ .event = x11.MotionNotify, .handlers = &[_]Handler{
    //     motionNotify,
    // } },
    // .{ .event = x11.EnterNotify, .handlers = &[_]Handler{
    //     enterNotify,
    // } },
    // .{ .event = x11.ButtonPress, .handlers = &[_]Handler{
    //     buttonPress,
    // } },
    // .{ .event = x11.ButtonRelease, .handlers = &[_]Handler{
    //     buttonRelease,
    // } },
};

pub fn mapRequest(ctx: *const Context, event: *const x11.XEvent) Error!void {
    const casted = @as(*const x11.XMapRequestEvent, @ptrCast(event));
    std.log.info("Maprequest: window - {}", .{casted.window});
    try ctx.createWindow(casted.window);
}

// pub fn mapNotify(wm: *WM, event: *const x11.XEvent) void {
//     // const casted = @as(*const x11.XMappingEvent, @ptrCast(event));
// }

pub fn keyPress(ctx: *const Context, event: *const x11.XEvent) Error!void {
    const casted = @as(*const x11.XKeyPressedEvent, @ptrCast(event));
    try ctx.handleKeyEvent(casted);
}
//
// pub fn enterNotify(wm: *WM, event: *const x11.XEvent) void {
//     // const casted = @as(*const x11.XEnterWindowEvent, @ptrCast(event));
// }

// pub fn motionNotify(wm: *WM, event: *const x11.XEvent) void {
//     // const casted = @as(*const x11.XMotionEvent, @ptrCast(event));
// }

// pub fn buttonPress(wm: *WM, event: *const x11.XEvent) void {
//     // const casted = @as(*const x11.XButtonPressedEvent, @ptrCast(event));
// }

// pub fn buttonRelease(wm: *WM, event: *const x11.XEvent) void {
//     // const casted = @as(*const x11.XButtonReleasedEvent, @ptrCast(event));
// }

// pub fn destroyNotify(wm: *WM, event: *const x11.XEvent) void {
//     // const casted = @as(*const x11.XDestroyWindowEvent, @ptrCast(event));
// }
