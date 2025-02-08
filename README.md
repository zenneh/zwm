# Zigga

A based window manager made using zig.

> This project is still in very early stages and is worked on actively.
> Please submit an issue for any cool feature requests idea's.

## Project goals

- Highly hackable codebase


## Features

* User can define keyboard shortcuts in the config
* Easy way to implement layouts and window arrangment

### Architecture

- Window: Managing application windows
- Workspace: Managing the layouts and constraints per workspace
- WM: Main window manager class that will do the work
- EventHandler: Sends events to the correct handlers

### BUGS
- Focussing window bug

### TODO
- Handle action errors
- Floating windows + layout
- Custom logging
- Make keyboard shortcuts better by updating the Key.zig file.
- Restack windows

### Future
- Support for legacy applications using X11 Atoms
- Support for extended Window Management Protocol.
