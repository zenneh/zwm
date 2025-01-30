pub const x = @cImport({
    @cInclude("X11/Xlib.h");
    @cInclude("X11/cursorfont.h");
    @cInclude("X11/keysym.h");
});
