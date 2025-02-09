# ZWM

A modern, hackable window manager written in Zig.

## Overview

ZWM is a lightweight window manager designed with hackability and customization in mind. Built using the Zig programming language, it aims to provide a flexible and efficient window management solution for Linux desktop environments.

> **Note**: This project is in active development. Features and APIs may change significantly.

## Features

- **Customizable Keyboard Shortcuts**: Define and modify keyboard shortcuts through an intuitive configuration system
- **Flexible Layout System**: Easy-to-implement window layouts and arrangements
- **Modular Architecture**: Clean separation of concerns for better maintainability and extensibility
- **Native Zig Implementation**: Built from the ground up in Zig for optimal performance

## Architecture

ZWM follows a modular design with these core components:

- **Window Manager (WM)**: Central component orchestrating all window management operations
- **Window**: Handles individual application window management and state
- **Workspace**: Manages layouts and workspace-specific constraints
- **EventHandler**: Routes system events to appropriate handlers

## Getting Started

### Prerequisites

- Zig compiler (latest version recommended)
- X11 development libraries
- Linux operating system

### Installation

```bash
# Installation instructions coming soon
```

## Configuration

Configuration is handled through a simple configuration file in Config.zig.

```zig
// Example configuration coming soon
```

## Development Status

### Current Focus

- Core window management functionality
- Basic layout implementations
- Event handling system

### Known Issues

- Window focus handling needs improvement
- Some keyboard shortcuts may not register correctly

### Roadmap

#### Short-term Goals

- [ ] Error handling improvements
- [ ] Floating window support
- [ ] Enhanced logging system
- [ ] Keyboard shortcut system refinement
- [ ] Window restacking implementation
- [ ] Codebase refactoring

#### Long-term Goals

- [ ] X11 Atoms support for legacy applications
- [ ] Extended Window Management Protocol support
- [ ] Additional layout implementations
- [ ] Plugin system

## Contributing

Contributions are welcome! Please feel free to:

- Submit feature requests and bug reports through issues
- Fork the repository and submit pull requests

## License

No licence for now, do whatever you want.

---

Made with ❤️ using [Zig](https://ziglang.org/)
