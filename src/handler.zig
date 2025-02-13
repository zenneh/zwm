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
    .{ .event = x11.MotionNotify, .handlers = &[_]Handler{
        motionNotify,
    } },
    .{ .event = x11.EnterNotify, .handlers = &[_]Handler{
        enterNotify,
    } },
    .{ .event = x11.ButtonPress, .handlers = &[_]Handler{
        buttonPress,
    } },
    .{ .event = x11.ButtonRelease, .handlers = &[_]Handler{
        buttonRelease,
    } },
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
pub fn enterNotify(ctx: *const Context, event: *const x11.XEvent) Error!void {
    const casted = @as(*const x11.XEnterWindowEvent, @ptrCast(event));
    std.log.info("Enter notify {}", .{casted.window});
    try ctx.focusWindow(casted.window);
}

pub fn motionNotify(ctx: *const Context, event: *const x11.XEvent) Error!void {
    const casted = @as(*const x11.XMotionEvent, @ptrCast(event));
    std.log.info("motion: {}:{} - {}:{}", .{ casted.x, casted.y, casted.x_root, casted.y_root });
    std.log.info("{any}", .{ctx.action});
    switch (ctx.action) {
        .arrange => {},
        .resize => {
            @panic("Resize not implemented");
        },
        .move => {
            std.log.info("moving window: {}:{}", .{ casted.x, casted.y });
            try ctx.moveWindow(.{ .x = casted.x, .y = casted.y });
        },
    }
}

pub fn buttonPress(ctx: *const Context, event: *const x11.XEvent) Error!void {
    const casted = @as(*const x11.XButtonPressedEvent, @ptrCast(event));
    std.log.info("Button press", .{});
    try ctx.setInput(.{ .pointer = .{ .x = casted.x, .y = casted.y } });
    try ctx.handleButtonEvent(casted);
}

pub fn buttonRelease(ctx: *const Context, _: *const x11.XEvent) Error!void {
    // const casted = @as(*const x11.XButtonReleasedEvent, @ptrCast(event));
    std.log.info("Button release", .{});
    try ctx.setInput(.default);

    // restore action state
    try ctx.setAction(.arrange);
}

// pub fn destroyNotify(wm: *WM, event: *const x11.XEvent) void {
//     // const casted = @as(*const x11.XDestroyWindowEvent, @ptrCast(event));
// }
