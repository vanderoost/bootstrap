# Bootstrap

Automatically set up a new Mac from scratch.

## TL;DR Run the installer

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/vanderoost/bootstrap/main/install.sh)"
```

The installer opens a browser twice for a GitHub device-code prompt: once to log in
and upload this machine's SSH key, and once to hand the key-management scopes back
afterwards so the everyday token keeps only the default permissions.

The script is idempotent so you can re-run it as often as you want once it's installed.

The installer asks for your password once at the start, then installs a temporary
`/etc/sudoers.d/bootstrap-nopasswd` rule so the rest of the run you never have to enter
your password again.

## Customization

I recommend customizing the following files to your own needs:

- Brewfile
- `install.sh`'s settings at the top of the file
- `spaces-items.txt`, which app goes on which Desktop (Desktop number, bundle ID)
