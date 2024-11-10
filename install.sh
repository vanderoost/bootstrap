#!/bin/bash

# This script can run from a curl one-liner, will clone the rest of
# the repo into a proper location

# Settings
HOSTNAME="mb-pro"
GITHUB_USERNAME="vanderoost"
BOOTSTRAP_REPO_NAME="bootstrap"

SSH_DIR="$HOME/.ssh"
GIT_DIR="$HOME/git"
BOOTSTRAP_DIR="$GIT_DIR/$BOOTSTRAP_REPO_NAME"

set -eu

# Utils
GREEN='\033[0;32m'
NC='\033[0m' # No Color
green_echo()(echo; echo -e "==> ${GREEN}$1${NC}")

abort() {
  printf "%s\n" "$@" >&2
  exit 1
}

# Fail when not using bash
if [ -z "${BASH_VERSION:-}" ]
then
  abort "Bash is required to interpret this script."
fi

green_echo "STARTING MAC BOOTSTRAP SCRIPT"
echo "This script will set up command line tools, ssh, git, install all Homebrew"
echo "packages from the Brewfile, set up the Mac preferences and App preferences."

# Ask password upfront and keep alive
# https://github.com/joshukraine/mac-bootstrap/blob/master/bootstrap#L88
echo
sudo -v
while :; do
    sudo -n true
    caffeinate -u sleep 60
    kill -0 "$$" || exit
done 2>/dev/null &

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

mkdir -p "$SSH_DIR"

green_echo "CHECKING SSH KEY PAIR"
ID_RSA_FILE="$SSH_DIR/id_rsa"
if [ ! -f "$ID_RSA_FILE" ]; then
    echo "Creating a new SSH key pair"
	ssh-keygen -t rsa -b 4096 -f "$ID_RSA_FILE" -q -N ""
else
    echo "All good"
fi

# Turn on SSH into this machine
sudo systemsetup -setremotelogin on

green_echo "CHECKING GITHUB SSH HOST"
if ! grep 'github.com ssh-rsa' "$SSH_DIR/known_hosts" &> /dev/null; then
    echo "Adding github.com rsa fingerprint to $SSH_DIR/known_hosts"
    ssh-keyscan -t rsa "github.com" >> "$SSH_DIR/known_hosts"
else
    echo "All good"
fi

green_echo "CHECKING GITHUB SSH ACCESS"
if ! ssh -T git@github.com 2>&1 | grep 'success' &> /dev/null; then
	GITHUB_SSH=false
	echo "No access, SSH key needs to be set up at github.com"
	pbcopy < "$ID_RSA_FILE.pub"
	open "https://github.com/settings/ssh/new"
	say "Log into Github and paste the public SSH key please"
else
	GITHUB_SSH=true
	echo "All good"
fi

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

# Install Homebrew Bundle
green_echo "INSTALL HOMEBREW BUNDLE"
brew tap Homebrew/bundle
brew update
brew upgrade

# Wait until Github SSH is working
if ! $GITHUB_SSH; then
	green_echo "VERIFYING GITHUB SSH ACCESS"
	while :; do
		ssh -T git@github.com 2>&1 | grep 'success' &> /dev/null && break
		echo -n .
		sleep 10
	done
	echo
fi

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
