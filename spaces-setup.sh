#!/usr/bin/env bash

# Assign apps to Desktops from 'spaces-items.txt' (Desktop number, bundle ID)
# The Desktops themselves have to be created by hand in Mission Control

SPACES="SpacesDisplayConfiguration.Management Data.Monitors.0.Spaces"

# Read the UUIDs of all Desktops in order, skipping full screen apps (type 4)
load_desktops() {
    local config type i=0
    config="$(defaults export com.apple.spaces -)"
    desktops=()
    while type="$(plutil -extract "$SPACES.$i.type" raw -o - - <<< "$config" 2> /dev/null)"; do
        if [ "$type" = "0" ]; then
            desktops+=("$(plutil -extract "$SPACES.$i.uuid" raw -o - - <<< "$config")")
        fi
        i=$((i + 1))
    done
}

needed="$(cut -d ' ' -f 1 spaces-items.txt | sort -n | tail -1)"
load_desktops
while [ "${#desktops[@]}" -lt "$needed" ]; do
    echo "Found ${#desktops[@]} Desktops, but $needed are needed"
    read -r -p "Make sure you have enough Desktops, then press enter... " _ < /dev/tty
    load_desktops
done

# The Dock stores bundle IDs in lowercase, the first Desktop has an empty UUID
bindings=()
while read -r desktop bundle_id; do
    bindings+=("$(echo "$bundle_id" | tr '[:upper:]' '[:lower:]')" "${desktops[$((desktop - 1))]}")
done < spaces-items.txt
defaults write com.apple.spaces "app-bindings" -dict "${bindings[@]}"

killall Dock
