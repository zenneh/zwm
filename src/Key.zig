const x = @import("X11.zig");

pub const Shift = Modifier{
    .shift = true,
};

pub const Control = Modifier{
    .control = true,
};

pub const ShiftMod = Modifier{
    .shift = true,
    .mod4 = true,
};

pub const ControlShift = Modifier{
    .shift = true,
    .mod4 = true,
};

pub const ControlShiftMod = Modifier{
    .shift = true,
    .control = true,
    .mod4 = true,
};

pub const Modifier = packed struct(u8) {
    shift: bool = false,
    lock: bool = false,
    control: bool = false,
    mod1: bool = false, // Usually mapped to Alt
    mod2: bool = false, // Usually mapped to NumLock
    mod3: bool = false, // Rarely used
    mod4: bool = false, // Usually mapped to Super/Windows key
    mod5: bool = false, // Usually mapped to ScrollLock/Mode_switch
};

pub const Action = fn (void) void;

pub const Shortcut = struct {
    modifier: u8 = .{},
    key: u8,
    action: Action,
};
