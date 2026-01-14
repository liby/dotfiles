#!/bin/bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Chrome (Debug)
# @raycast.mode silent

# Optional parameters:
# @raycast.icon /Applications/Google Chrome.app/Contents/Resources/app.icns
# @raycast.packageName Browser

# Check if debug Chrome is already running
if pgrep -f "remote-debugging-port=9222" > /dev/null; then
  exit 0
fi

/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/.chrome-debug-profile" &