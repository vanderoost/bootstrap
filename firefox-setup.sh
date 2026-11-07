#!/usr/bin/env bash

# Link 'firefox/user.js' and 'firefox/userChrome.css' into every Firefox profile
# Profiles added later need a re-run of this script

PROFILES_DIR="$HOME/Library/Application Support/Firefox/Profiles"
FIREFOX_DIR="$(cd "$(dirname "$0")" && pwd)/firefox"

# Every profile has its own folder here, including ones about:profiles hides
shopt -s nullglob
profiles=("$PROFILES_DIR"/*/)

# Firefox only creates its profiles on first launch
if [ "${#profiles[@]}" -eq 0 ]; then
    open -a Firefox
    echo "Waiting for Firefox to create a profile (press enter to skip)"
    until [ "${#profiles[@]}" -gt 0 ]; do
        if read -r -t 2 _ < /dev/tty; then
            echo "Skipping, re-run this script once Firefox has started"
            exit 0
        fi
        profiles=("$PROFILES_DIR"/*/)
    done

    # The first launch creates more than one profile, give it a moment
    sleep 2
    profiles=("$PROFILES_DIR"/*/)
    RESTART_NEEDED="yes"
fi

for profile in "${profiles[@]}"; do
    echo "Linking user.js and userChrome.css into $(basename "$profile")"
    ln -sf "$FIREFOX_DIR/user.js" "$profile/user.js"
    mkdir -p "$profile/chrome"
    ln -sf "$FIREFOX_DIR/userChrome.css" "$profile/chrome/userChrome.css"
done

# Firefox reads user.js and userChrome.css only at startup
if [ -n "${RESTART_NEEDED:-}" ]; then
    echo "Restart Firefox to load user.js and userChrome.css"
fi
