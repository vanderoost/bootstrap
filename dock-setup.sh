#!/usr/bin/env bash

# Set up the Dock with apps from 'dock-items.txt'

# Full reset to default
defaults delete com.apple.dock
killall Dock
echo -n "Restarting dock "
while ! defaults read com.apple.dock "persistent-apps" &> /dev/null; do
    echo -n .
    sleep 0.2
done
echo

# Add all persistent apps
defaults write com.apple.dock "persistent-apps" -array $(
    while read -r dock_item; do
      echo -n "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>$dock_item</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict> " 
    done < dock-items.txt
)

# Reset recent apps
defaults delete com.apple.dock "recent-apps"

# Display translucent Dock icons for hidden apps
defaults write com.apple.dock "showhidden" -bool "true"

# Lock the Dock size
defaults write com.apple.dock "size-immutable" -bool "true"

# Automatically hide/show the Dock
defaults write com.apple.dock "autohide" -bool "true"

# Time the cursor has to stay still for the Dock to show up
defaults write com.apple.dock "autohide-delay" -float "0.05"

# Time of the auto hide/show animation
defaults write com.apple.dock "autohide-time-modifier" -float "0.4"

# Don't auto-rearrange spaces (also a dock option for some reason)
defaults write com.apple.dock "mru-spaces" -bool "false"

killall Dock
