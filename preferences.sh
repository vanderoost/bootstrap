#!/usr/bin/env bash

# Set up preferences

# Prerequisites:
# $XDG_CONFIG_HOME set
# Dotfiles installed

GIT_DIR="$HOME/git"
BOOTSTRAP_REPO_NAME="bootstrap"

# MAC PREFERENCES

# Keyboard remapping
mkdir -p "$HOME/Library/LaunchAgents"
cp "$GIT_DIR/$BOOTSTRAP_REPO_NAME/com.local.KeyRemapping.plist" \
    "$HOME/Library/LaunchAgents/com.local.KeyRemapping.plist"

# Disable the Character Accent Menu and Enable Key Repeat
defaults write -globalDomain ApplePressAndHoldEnabled -bool false

# Expand save panel by default
defaults write NSGlobalDomain NSNavPanelExpandedStateForSaveMode -bool true

# Expand print panel by default
defaults write NSGlobalDomain PMPrintingExpandedStateForPrint -bool true

# Show all file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false 

# Disable auto switching Workspaces?
defaults write com.apple.dock workspaces-auto-swoosh -bool true

# Set a blazingly fast keyboard repeat rate
defaults write NSGlobalDomain InitialKeyRepeat -int 10
defaults write NSGlobalDomain KeyRepeat -int 1

# Full Keyboard Access
# In windows and dialogs, press Tab to move keyboard focus between:
# 1 : Text boxes and lists only
# 3 : All controls
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Don't use smart quotes
defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false

# Disable automatic period substitution
defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false

# Disable automatic capitalization
defaults write NSGlobalDomain NSAutomaticCapitalizationEnabled -bool false

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Enable tap to click for the trackpad
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Open notification center with the trackpad (3 = yes, 0 = no)
defaults write com.apple.AppleMultitouchTrackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadTwoFingerFromRightEdgeSwipeGesture -int 3

# Trackpad haptic feedback
# 0: Light
# 1: Medium
# 2: Firm
defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0
defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 0

# Increase trackpad speed (0.0 - 3.0 is the normal range)
defaults write -globalDomain com.apple.trackpad.scaling -float 5.0

# Move spaces when opening an App
defaults write -g AppleSpacesSwitchOnActivate -bool true

# Set 'home' as the default location for new Finder windows
# For other paths, use `PfLo` and `file:///full/path/here/`
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://$HOME"

# Remove items from the trash after 30 days
defaults write com.apple.finder FXRemoveOldTrashItems -bool true

# Save screenshots to Downloads to keep the Desktop clean
defaults write com.apple.screencapture location -string "$HOME/Downloads"

# When doing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Show the status bar in Finder
defaults write com.apple.finder ShowStatusBar -bool true

# Show folders at the top
defaults write com.apple.finder _FXSortFoldersFirst -bool true


# APP PREFERENCES

# Use plain text for TextEdit app
defaults write com.apple.TextEdit RichText -bool false
