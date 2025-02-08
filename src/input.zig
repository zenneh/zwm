const State = struct { cursor: Cursor };

pub const Cursor = struct {
    x: u16,
    y: u16,
    pressed: bool,
};
