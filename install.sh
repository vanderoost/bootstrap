#!/usr/bin/env bash

# This script can run from a curl one-liner, will clone the rest of
# the repo into a proper location

# Settings
GITHUB_USERNAME="vanderoost"
BOOTSTRAP_REPO_NAME="bootstrap"

GIT_NAME="Richard van der Oost"
GIT_EMAIL="richard@vanderoost.com"

USE_SSH=1
SSH_DIR="$HOME/.ssh"
SSH_KEY_FILE="$SSH_DIR/id_ed25519"
ALLOWED_SIGNERS_FILE="$SSH_DIR/allowed_signers"
GH_KEY_SCOPES="admin:public_key,admin:ssh_signing_key"
GIT_DIR="$HOME/git"
BOOTSTRAP_DIR="$GIT_DIR/$BOOTSTRAP_REPO_NAME"
SUDOERS_FILE="/etc/sudoers.d/bootstrap-nopasswd"

set -eu

# Utils
GREEN='\033[0;32m'
NC='\033[0m' # No Color
green_echo()(echo; echo -e "==> ${GREEN}$1${NC}")

abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

add_github_key() {
    local key_type="$1" output
    if output=$(gh ssh-key add "$SSH_KEY_FILE.pub" --title "$HOSTNAME" \
        --type "$key_type" 2>&1); then
        echo "Added the $key_type key"
    elif echo "$output" | grep -qi 'already'; then
        echo "The $key_type key is already registered"
    else
        abort "$output"
    fi
}

# Fail when not using bash
if [ -z "${BASH_VERSION:-}" ]
then
  abort "Bash is required to run this script."
fi

green_echo "STARTING MAC BOOTSTRAP SCRIPT"
echo "This script will set up command line tools, ssh, git, install all Homebrew"
echo "packages from the Brewfile, set up the Mac preferences and App preferences."

CURRENT_HOSTNAME="$(scutil --get ComputerName 2> /dev/null || hostname -s)"
read -r -p "Enter this Mac's hostname [$CURRENT_HOSTNAME]: " HOSTNAME < /dev/tty
HOSTNAME="${HOSTNAME:-$CURRENT_HOSTNAME}"

# Ask for the password upfront
echo "Your password is required for some admin work"
sudo -v

CAFFEINATE_PID=""
SUDO_KEEPALIVE_PID=""
SUDOERS_INSTALLED=""

install_passwordless_sudo() {
    local tmp
    tmp="$(mktemp)"
    printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$(id -un)" > "$tmp"

    if ! visudo -c -q -f "$tmp"; then
        rm -f "$tmp"
        abort "Refusing to install an unparseable sudoers rule"
    fi

    SUDOERS_INSTALLED="yes"
    sudo install -m 0440 -o root -g wheel "$tmp" "$SUDOERS_FILE"
    rm -f "$tmp"
}

release_privileges() {
    if [ -n "$SUDOERS_INSTALLED" ]; then
        SUDOERS_INSTALLED=""
        sudo -n rm -f "$SUDOERS_FILE" 2> /dev/null \
            || echo "WARNING: please remove $SUDOERS_FILE by hand" >&2
    fi
    [ -n "$SUDO_KEEPALIVE_PID" ] && kill "$SUDO_KEEPALIVE_PID" 2> /dev/null
    [ -n "$CAFFEINATE_PID" ] && kill "$CAFFEINATE_PID" 2> /dev/null
    return 0
}
trap release_privileges EXIT
trap 'exit 1' INT TERM

if [ -f "$SUDOERS_FILE" ]; then
    echo "Replacing the rule an interrupted run left behind"
fi
install_passwordless_sudo

sudo -k
if ! sudo -n true 2> /dev/null; then
    echo "WARNING: /etc/sudoers.d is not read, expect password prompts" >&2
    sudo rm -f "$SUDOERS_FILE"
    SUDOERS_INSTALLED=""
    sudo -v
fi

# Stay awake the whole run
caffeinate -dims -w "$$" &
CAFFEINATE_PID=$!

# Keep sudo privileges alive
(
    trap - EXIT INT TERM
    set +e
    while kill -0 "$$" 2> /dev/null; do
        sudo -n -v 2> /dev/null
        sleep 30
    done
) &
SUDO_KEEPALIVE_PID=$!

green_echo "INSTALL ALL AVAILABLE UPDATES"
sudo softwareupdate -ia --verbose

sudo scutil --set ComputerName "$HOSTNAME"
sudo scutil --set HostName "$HOSTNAME"
sudo scutil --set LocalHostName "$(echo "$HOSTNAME" \
    | sed -e 's/[^A-Za-z0-9-]/-/g' -e 's/--*/-/g' -e 's/^-//' -e 's/-$//')"

if [ "$USE_SSH" = "1" ]; then
    sudo launchctl enable system/com.openssh.sshd
    if ! sudo launchctl print system/com.openssh.sshd &> /dev/null; then
        sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist
    fi
fi

green_echo "CHECK HOMEBREW STATUS"
if [ ! -x /opt/homebrew/bin/brew ]; then
	echo "Installing Homebrew..."
	NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
	echo "All good"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

green_echo "UPDATE HOMEBREW"
brew update
brew upgrade --yes

green_echo "CHECK GITHUB CLI STATUS"
if ! command -v gh &> /dev/null; then
	echo "Installing the GitHub CLI..."
	brew install gh
else
	echo "All good"
fi

mkdir -p "$SSH_DIR"

green_echo "CHECKING SSH KEY PAIR"
if [ ! -f "$SSH_KEY_FILE" ]; then
    echo "Creating a new Ed25519 SSH key pair"
    ssh-keygen -t ed25519 -f "$SSH_KEY_FILE" -q -N "" -C "$USER@$HOSTNAME"
else
    echo "All good"
fi

green_echo "CHECKING GITHUB CLI AUTHENTICATION"
if ! gh auth status --hostname github.com &> /dev/null; then
    # Ask for the key scopes up front so a fresh Mac needs only one login
    echo "Logging in to GitHub"
    gh auth login --hostname github.com --git-protocol ssh --web \
        --skip-ssh-key --scopes "$GH_KEY_SCOPES"
else
    echo "All good"
fi

green_echo "CHECKING GITHUB SSH HOST KEYS"
if ! ssh-keygen -F "github.com" -f "$SSH_DIR/known_hosts" &> /dev/null; then
    echo "Adding GitHub's host keys to $SSH_DIR/known_hosts"
    gh api meta --jq '.ssh_keys[]' \
        | sed 's/^/github.com /' >> "$SSH_DIR/known_hosts"
else
    echo "All good"
fi

green_echo "CHECKING GITHUB SSH ACCESS"
if ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$SSH_KEY_FILE" \
    -T git@github.com 2>&1 | grep -q 'success'; then
    echo "All good"
else
    echo "Registering this machine's public key with GitHub"

    # Only needed when we were already logged in with the default scopes
    if ! gh auth status --hostname github.com 2>&1 | grep -q "'admin:public_key'"
    then
        gh auth refresh --hostname github.com --scopes "$GH_KEY_SCOPES"
    fi

    add_github_key authentication
    add_github_key signing

    # Key management is a privilege escalation, keep it off the daily token
    echo "Dropping the key-management scopes again"
    gh auth refresh --hostname github.com --remove-scopes "$GH_KEY_SCOPES"

    ssh -o BatchMode=yes -o IdentitiesOnly=yes -i "$SSH_KEY_FILE" \
        -T git@github.com 2>&1 | grep -q 'success' \
        || abort "SSH access to github.com is still not working."
fi

green_echo "CONFIGURING GIT SIGNING"
if ! git config --global --get user.email > /dev/null; then
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
fi
git config --global gpg.format ssh
git config --global user.signingkey "$SSH_KEY_FILE.pub"
git config --global commit.gpgsign true
git config --global gpg.ssh.allowedSignersFile "$ALLOWED_SIGNERS_FILE"

SIGNER_LINE="$GIT_EMAIL namespaces=\"git\" $(cat "$SSH_KEY_FILE.pub")"
if ! grep -qxF "$SIGNER_LINE" "$ALLOWED_SIGNERS_FILE" 2> /dev/null; then
    echo "$SIGNER_LINE" >> "$ALLOWED_SIGNERS_FILE"
fi
echo "All good"

green_echo "ENSURE BOOTSTRAP REPOSITORY IS PULLED AND UPDATED"
mkdir -p "$GIT_DIR"
if [ -d "$BOOTSTRAP_DIR" ]
then
	echo "Refreshing the Bootstrap repository"
	cd "$BOOTSTRAP_DIR"
	git pull
	cd "$HOME"
else
	echo "Cloning the entire Bootstrap repository"
	cd "$GIT_DIR"
	git clone "git@github.com:$GITHUB_USERNAME/$BOOTSTRAP_REPO_NAME"
	cd "$HOME"
fi

green_echo "INSTALLING ALL HOMEBREW PACKAGES"
brew trust --formula asmvik/formulae/skhd
brew trust --formula stripe/stripe-cli/stripe

# mas can no longer sign in by itself, the App Store app has to do it
if brew bundle check --verbose --file "$BOOTSTRAP_DIR/Brewfile" 2> /dev/null \
    | grep -q '→ App '; then
    open -a "App Store"
    read -r -p "Press enter once you've signed in to the App Store... " _ < /dev/tty
fi

BUNDLE_FAILED=""
if ! brew bundle --no-upgrade --file "$BOOTSTRAP_DIR/Brewfile"; then
    BUNDLE_FAILED="yes"
fi
brew cleanup

# Pin Neovim so it doesn't randomly break
brew pin neovim

green_echo "SET PREFERENCES"
"$BOOTSTRAP_DIR/preferences.sh"

green_echo "SETUP THE DOCK"
cd "$BOOTSTRAP_DIR"
./dock-setup.sh
cd "$HOME"

green_echo "ASSIGN APPS TO DESKTOPS"
cd "$BOOTSTRAP_DIR"
./spaces-setup.sh
cd "$HOME"

green_echo "INSTALLING GITHUB REPOSITORIES"
while read -r repo; do
    if [ -d "$GIT_DIR/$repo" ]
    then
        echo "Refreshing the $repo repository"
        cd "$GIT_DIR/$repo"
        git pull
        cd "$HOME"
    else
        echo "Cloning the entire $repo repository"
        cd "$GIT_DIR"
        git clone "git@github.com:$GITHUB_USERNAME/$repo"
        cd $HOME
    fi
done < "$BOOTSTRAP_DIR/github-repos.txt"

green_echo "INITIALIZING DROPBOX"
DROPBOX_INFO="$HOME/.dropbox/info.json"

# Signed in once Dropbox wrote its info file and the synced folders exist
dropbox_ready() {
    local path
    [ -f "$DROPBOX_INFO" ] || return 1
    while read -r path; do
        [ -d "$path" ] || return 1
    done < <(jq -r '.[].path' "$DROPBOX_INFO" 2> /dev/null)
}

if dropbox_ready; then
    echo "All good"
else
    open -a Dropbox
    echo "Waiting for the Dropbox sign-in (press enter to skip)"
    until dropbox_ready; do
        if read -r -t 5 _ < /dev/tty; then
            echo "Skipping, Dropbox folders won't be linked"
            break
        fi
    done
fi

green_echo "DOWNLOADING AND INSTALLING DOTFILE CONFIGS"
cd "$GIT_DIR/home"
./install.sh
cd "$HOME"

green_echo "STARTING SKHD"
SKHD_PLIST="$HOME/Library/LaunchAgents/com.koekeishiya.skhd.plist"

# --restart-service only works on a loaded service, --start-service loads it
skhd_start() {
    if launchctl print "gui/$(id -u)/com.koekeishiya.skhd" &> /dev/null; then
        skhd --restart-service
    else
        skhd --start-service
    fi
}

[ -f "$SKHD_PLIST" ] || skhd --install-service
skhd_start

# skhd needs Accessibility access, which only the user can grant
sleep 2
if ! pgrep -x skhd &> /dev/null; then
    echo "Allow skhd under Accessibility (use + and Cmd+Shift+G to add"
    echo "$(readlink -f "$(command -v skhd)") if it's not listed)"
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    read -r -p "Press enter once skhd is allowed... " _ < /dev/tty
    skhd_start
fi

green_echo "ALL DONE"
if [ -n "$BUNDLE_FAILED" ]; then
    echo "WARNING: some Brewfile entries failed to install, see the output above," >&2
    echo "then run: brew bundle --file $BOOTSTRAP_DIR/Brewfile" >&2
fi

echo "Restart the Mac to load the audio driver and the key remapping"

# Hand the terminal over to a fresh shell that has the new PATH and dotfiles.
# exec skips the EXIT trap, so release everything by hand first
if [ -t 1 ] && [ -x /bin/zsh ]; then
    release_privileges
    trap - EXIT INT TERM
    exec /bin/zsh -l < /dev/tty
fi
