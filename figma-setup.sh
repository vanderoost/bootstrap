#!/usr/bin/env bash

# Stop Figma from adding FigmaAgent to the login items on every update
# Figma copies the agent out of its app bundle, so we put an immutable dummy
# file in its place that Figma can't overwrite
# Undo with: sudo chflags noschg "$AGENT_APP" && rm "$AGENT_APP"

AGENT_APP="$HOME/Library/Application Support/Figma/FigmaAgent.app"

set -eu

# Already a dummy file with the system immutable flag
if [ -f "$AGENT_APP" ] && ls -lO "$AGENT_APP" | grep -q schg; then
    echo "All good"
    exit 0
fi

pkill -x figma_agent 2> /dev/null || true

osascript -e 'tell application "System Events" to delete (every login item whose name is "FigmaAgent")' \
    > /dev/null 2>&1 || echo "Remove FigmaAgent from the Login Items by hand"

mkdir -p "$(dirname "$AGENT_APP")"
rm -rf "$AGENT_APP"
touch "$AGENT_APP"
sudo chflags schg "$AGENT_APP"
echo "Replaced FigmaAgent.app with an undeletable dummy file"
