#!/usr/bin/env bash

# This script can run from a curl one-liner, will clone the rest of
# the repo into a proper location

# Settings
HOSTNAME="mb-pro"
GITHUB_USERNAME="vanderoost"
BOOTSTRAP_REPO_NAME="bootstrap"

GIT_NAME="Richard van der Oost"
GIT_EMAIL="richard@vanderoost.com"

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

# Registering a key twice is not an error, so re-runs stay safe
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
  abort "Bash is required to interpret this script."
fi

green_echo "STARTING MAC BOOTSTRAP SCRIPT"
echo "This script will set up command line tools, ssh, git, install all Homebrew"
echo "packages from the Brewfile, set up the Mac preferences and App preferences."

# Ask for the password upfront and hold on to it for the whole run
echo
sudo -v

CAFFEINATE_PID=""
SUDO_KEEPALIVE_PID=""
SUDOERS_INSTALLED=""

# A refreshed sudo ticket is not enough: Homebrew still prompts partway
# through the Brewfile, so grant this user passwordless sudo instead
install_passwordless_sudo() {
    local tmp
    tmp="$(mktemp)"
    printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$(id -un)" > "$tmp"

    # An unparseable drop-in breaks every sudo on the machine, so only
    # ever install one that visudo has already accepted
    if ! visudo -c -q -f "$tmp"; then
        rm -f "$tmp"
        abort "Refusing to install an unparseable sudoers rule"
    fi

    # Claim it before creating it, so a half-written file still gets
    # cleaned up if `install` fails partway through
    SUDOERS_INSTALLED="yes"
    sudo install -m 0440 -o root -g wheel "$tmp" "$SUDOERS_FILE"
    rm -f "$tmp"
}

# The rule is meant to outlive nothing: give it back however we exit
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
# Without these, a Ctrl-C would leave the sudoers rule behind
trap 'exit 1' INT TERM

if [ -f "$SUDOERS_FILE" ]; then
    echo "Replacing the rule an interrupted run left behind"
fi
install_passwordless_sudo

# A drop-in is silently ignored unless /etc/sudoers includes the
# directory, and dropping the ticket is the only way to tell it took
sudo -k
if ! sudo -n true 2> /dev/null; then
    echo "WARNING: /etc/sudoers.d is not read, expect password prompts" >&2
    sudo rm -f "$SUDOERS_FILE"
    SUDOERS_INSTALLED=""
    sudo -v
fi

# One assertion for the entire script: `caffeinate -u` only lasts five
# seconds, so the Mac could idle sleep and let the sudo ticket lapse
caffeinate -dims -w "$$" &
CAFFEINATE_PID=$!

# Only a backstop for the warning above, but a cheap one. `sudo -n -v`
# refreshes the ticket and can never re-authenticate, so one failed
# refresh must not take the loop down with it, as `set -e` would
(
    trap - EXIT INT TERM
    set +e
    while kill -0 "$$" 2> /dev/null; do
        sudo -n -v 2> /dev/null
        sleep 30
    done
) &
SUDO_KEEPALIVE_PID=$!

# green_echo "INSTALL ALL AVAILABLE UPDATES"
# sudo softwareupdate -ia --verbose

# Install Xcode command line tools
if ! $(xcode-select -p &>/dev/null); then
    xcode-select --install &>/dev/null
    # Wait until the Xcode command line tools are installed
    until $(xcode-select -p &>/dev/null); do
        sleep 5
    done

    # Enable command line tools
    sudo xcode-select --switch /Library/Developer/CommandLineTools
fi

# Set the computer hostname
sudo scutil --set HostName $HOSTNAME

# Turn on SSH into this machine
sudo systemsetup -setremotelogin on

green_echo "CHECK HOMEBREW STATUS"
if ! command -v brew &> /dev/null; then
	echo "Installing Homebrew..."
	NONINTERACTIVE=1 /bin/bash -c \
        "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

	# Add Brew to the path
	if ! command -v brew &> /dev/null; then
		eval "$(/opt/homebrew/bin/brew shellenv)"
	fi
else
	echo "All good"
fi

green_echo "UPDATE HOMEBREW"
brew update
brew upgrade

# The GitHub CLI sets up SSH access below, long before the Brewfile is available
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
    # Ask for the key scopes up front so a fresh Mac needs one login, not two
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
# Probe this specific key: an older key may still work while this one is unknown
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

# Without this, `git log --show-signature` cannot verify our own commits
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
brew trust --formula koekeishiya/formulae/skhd
brew bundle --no-upgrade --file "$BOOTSTRAP_DIR/Brewfile"
brew cleanup

# Pin Neovim so it doesn't randomly break
brew pin neovim

# Install Python tools with pipx
pipx ensurepath
pipx install poetry
pipx install pynvim

green_echo "SET PREFERENCES"
"$BOOTSTRAP_DIR/preferences.sh"

green_echo "SETUP THE DOCK"
cd "$BOOTSTRAP_DIR"
./dock-setup.sh
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

green_echo "DOWNLOADING AND INSTALLING DOTFILE CONFIGS"
cd "$GIT_DIR/home"
./install.sh
cd "$HOME"

green_echo "ALL DONE"
