const x = @cImport({
    @cInclude("X11/Xlib.h");
});

const Self = @This();

pub const Modifier = packed struct(u8) {
    shift: bool = false,
    lock: bool = false,
    control: bool = false,
    mod1: bool = false, // Usually mapped to Alt
    mod2: bool = false, // Usually mapped to NumLock
    mod3: bool = false, // Rarely used
    mod4: bool = false, // Usually mapped to Super/Windows key
    mod5: bool = false, // Usually mapped to ScrollLock/Mode_switch

    pub fn shift() Modifier {
        return Modifier{
            .shift = true,
        };
    }

    pub fn control() Modifier {
        return Modifier{
            .control = true,
        };
    }

    pub fn mod4() Modifier {
        return Modifier{
            .mod4 = true,
        };
    }
};

pub const Action = fn (void) void;

pub const Shortcut = struct {
    modifier: Modifier = .{},
    key: u8,
    action: Action,
};
