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

## Customization

I recommend customizing the following files to your own needs:

- Brewfile
