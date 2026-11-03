#!/usr/bin/env bash

# Set up the Mail accounts from the logins in a Bitwarden folder, the repo is
# public so the addresses and servers stay in the vault as well.
#
# Each login needs its email address as the username, and a custom field called
# 'host' with the mail server. cPanel uses the same server and ports for all.
#
# To pick up changed logins, remove the profile first:
# profiles remove -identifier com.vanderoost.bootstrap.mail

BITWARDEN_FOLDER="bootstrap-mail"
PROFILE_IDENTIFIER="com.vanderoost.bootstrap.mail"
PROFILES_SETTINGS="x-apple.systempreferences:com.apple.Profiles-Settings.extension"
ACCOUNTS_SETTINGS="x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension"

set -eu
set -o pipefail
umask 077

profile_installed() {
    profiles list 2> /dev/null | grep -qF "$PROFILE_IDENTIFIER"
}

if profile_installed; then
    echo "The Mail accounts profile is already installed, to pick up changed logins:"
    echo "profiles remove -identifier $PROFILE_IDENTIFIER"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
BW_UNLOCKED_HERE=""

clean_up() {
    # The generated profile has the passwords in plain text
    rm -rf "$TMP_DIR"
    [ -n "$BW_UNLOCKED_HERE" ] && bw lock > /dev/null
    return 0
}
trap clean_up EXIT
trap 'exit 1' INT TERM

case "$(bw status | jq -r '.status')" in
    unauthenticated)
        echo "Log in to Bitwarden to read the Mail accounts from your vault"
        BW_SESSION="$(bw login --raw)"
        BW_UNLOCKED_HERE="yes"
        ;;
    locked)
        echo "Unlock Bitwarden to read the Mail accounts from your vault"
        BW_SESSION="$(bw unlock --raw)"
        BW_UNLOCKED_HERE="yes"
        ;;
esac
export BW_SESSION="${BW_SESSION:-}"

bw sync > /dev/null

folder_id="$(bw list folders | jq -r --arg name "$BITWARDEN_FOLDER" \
    'first(.[] | select(.name == $name) | .id) // empty')"
if [ -z "$folder_id" ]; then
    echo "Create a '$BITWARDEN_FOLDER' folder in Bitwarden first" >&2
    exit 1
fi

items="$(bw list items --folderid "$folder_id" | jq '
    map(select(.type == 1) | {
        name,
        address: (.login.username // ""),
        password: (.login.password // ""),
        host: (first(.fields[]? | select(.name == "host") | .value) // "")
    })')"

incomplete="$(printf '%s' "$items" | jq -r \
    '.[] | select(.address == "" or .password == "" or .host == "") | .name')"
if [ -n "$incomplete" ]; then
    echo "These logins need a username, password and 'host' field:" >&2
    echo "$incomplete" >&2
    exit 1
fi

count="$(printf '%s' "$items" | jq 'length')"
if [ "$count" = "0" ]; then
    echo "There are no logins in the '$BITWARDEN_FOLDER' folder" >&2
    exit 1
fi

# One for each account and one for the profile itself
uuids="$(for _ in $(seq 0 "$count"); do uuidgen; done | jq -R . | jq -s .)"
profile="$TMP_DIR/mail.mobileconfig"

printf '%s' "$items" | jq \
    --arg full_name "$(git config --global user.name)" \
    --arg identifier "$PROFILE_IDENTIFIER" \
    --argjson uuids "$uuids" '{
    PayloadContent: (to_entries | map(.key as $index | .value | {
        EmailAccountDescription: .name,
        EmailAccountName: $full_name,
        EmailAccountType: "EmailTypeIMAP",
        EmailAddress: .address,
        IncomingMailServerAuthentication: "EmailAuthPassword",
        IncomingMailServerHostName: .host,
        IncomingMailServerPortNumber: 993,
        IncomingMailServerUseSSL: true,
        IncomingMailServerUsername: .address,
        IncomingPassword: .password,
        OutgoingMailServerAuthentication: "EmailAuthPassword",
        OutgoingMailServerHostName: .host,
        OutgoingMailServerPortNumber: 465,
        OutgoingMailServerUseSSL: true,
        OutgoingMailServerUsername: .address,
        OutgoingPassword: .password,
        OutgoingPasswordSameAsIncomingPassword: false,
        PayloadIdentifier: "\($identifier).\(.address)",
        PayloadType: "com.apple.mail.managed",
        PayloadUUID: $uuids[$index],
        PayloadVersion: 1
    })),
    PayloadDisplayName: "Mail accounts",
    PayloadIdentifier: $identifier,
    PayloadType: "Configuration",
    PayloadUUID: $uuids[-1],
    PayloadVersion: 1
}' | plutil -convert xml1 -o "$profile" -

# Scripts can't install profiles since Big Sur, only the user can approve them
open "$profile"
open "$PROFILES_SETTINGS"
echo "Approve the 'Mail accounts' profile (press enter to skip)"
until profile_installed; do
    if read -r -t 5 _ < /dev/tty; then
        echo "Skipping, the Mail accounts won't be set up"
        exit 0
    fi
done
echo "Added $count Mail account(s)"

# macOS has no profile for Google accounts, and it signs in through the browser
echo "Add your Google Workspace account: click 'Add Account...', choose Google,"
echo "sign in through the browser and keep Mail enabled"
open "$ACCOUNTS_SETTINGS"
read -r -p "Press enter once it's added... " _ < /dev/tty
