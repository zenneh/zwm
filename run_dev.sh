#!/bin/sh
set -e

# Start Xephyr
Xephyr :1 -ac -screen 1024x768 &
XEPHYR_PID=$!

# Wait for Xephyr to start
sleep 1

# Run the window manager
DISPLAY=:1 zig build run

# Cleanup
kill $XEPHYR_PID

