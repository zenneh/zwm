# Window moving
- Keep a state of an optional node which should be swapped with inside the .move state.
- on release, swap the nodes

# Window Resizing
- A resize should update the window's preferences for that workspace layout
- a layout can use the preferences to adjust arrangement but is not obligated to do so. The monocle layout will ignore any user specified preferences.
- implement hotkeys to reset the preferences of a current window or all the windows in the workspace

# Current list of tasks
- [x] Implement keyboard button handlers
- [x] Implement floating windows
- [x] Implement window movement
- [x] Implement restacking
- [x] Fix arrange and restack bugs
- [x] Implement size preferences
- [x] Implement window resizing

# Bugs
- [x] Windows don't get unmapped when changing workspaces

# Nextup
- [x] Implement window gaps
- [ ] x11 atoms
- [ ] Cursors
- [ ] Top bar :3
- [ ] Fonts
- [ ] Theme
- [ ] Workspace overview
- [ ] Improve zig build file
- [ ] Configure project build inside flake.nix

