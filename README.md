# Bootstrap

Automatically configure a new Mac from scratch.

## TL;DR Run the installer

Before running this command, make sure the terminal program has **Full Disk Access** in
System Settings -> Privacy & Security.

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/vanderoost/bootstrap/main/install.sh)"
```

The installer opens a browser twice for a GitHub device-code prompt: once to log in
and upload this machine's SSH key, and once to hand the key-management scopes back
afterwards so the everyday token keeps only the default permissions. Re-running the
installer on an already configured Mac prompts for neither.

The installer asks for your password once at the start, then installs a
`/etc/sudoers.d/bootstrap-nopasswd` rule so the rest of the run — Homebrew casks
especially — never prompts again. The rule is removed when the script exits,
including on Ctrl-C. While it is in place, anything running as your user can use
`sudo` without a password, so don't leave the run unattended on a shared machine.
If a run is killed outright (`kill -9`, a panic), the rule survives; the next run
replaces and then removes it, or delete it by hand.

## Customization

I recommend customizing the following files to your own needs:

- Brewfile
