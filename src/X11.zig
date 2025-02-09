pub usingnamespace @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/cursorfont.h");
    @cInclude("X11/keysym.h");
    @cInclude("X11/Xatom.h");
});

const x11 = @This();

pub fn getModifierName(mod: c_int) []const u8 {
    return switch (mod) {
        x11.ShiftMask => "Shift",
        x11.ControlMask => "Control",
        x11.Mod1Mask => "Alt",
        x11.Mod2Mask => "Mod2",
        x11.Mod3Mask => "Mod3",
        x11.Mod4Mask => "Super",
        x11.Mod5Mask => "Mod5",
        else => "Unknown",
    };
}

// Helper to get readable key names
pub fn getKeyName(key: c_int) []const u8 {
    return switch (key) {
        x11.XK_space => "Space",
        x11.XK_Return => "Return",
        x11.XK_Tab => "Tab",
        x11.XK_q => "Q",
        x11.XK_w => "W",
        x11.XK_e => "E",
        x11.XK_r => "R",
        x11.XK_t => "T",
        x11.XK_y => "Y",
        x11.XK_u => "U",
        x11.XK_i => "I",
        x11.XK_o => "O",
        x11.XK_p => "P",
        x11.XK_a => "A",
        x11.XK_s => "S",
        x11.XK_d => "D",
        x11.XK_f => "F",
        x11.XK_g => "G",
        x11.XK_h => "H",
        x11.XK_j => "J",
        x11.XK_k => "K",
        x11.XK_l => "L",
        x11.XK_z => "Z",
        x11.XK_x => "X",
        x11.XK_c => "C",
        x11.XK_v => "V",
        x11.XK_b => "B",
        x11.XK_n => "N",
        x11.XK_m => "M",
        x11.XK_1 => "1",
        x11.XK_2 => "2",
        x11.XK_3 => "3",
        x11.XK_4 => "4",
        x11.XK_5 => "5",
        x11.XK_6 => "6",
        x11.XK_7 => "7",
        x11.XK_8 => "8",
        x11.XK_9 => "9",
        x11.XK_0 => "0",
        else => "Unknown",
    };
}
