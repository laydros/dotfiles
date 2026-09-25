# Dotfiles

This repository contains my personal dotfiles managed with `yadm`.
It is intentionally minimal to avoid over-engineering. Configuration
files live directly in the repo so they can be symlinked into `$HOME`
by `yadm`.

## Structure

- `bin/` – personal helper scripts
- `.config/` – application configuration (nvim, sway, tmux, etc.)
- `.vim/` – Vim configuration shared with Neovim

Feel free to adapt pieces for your own setup.

## Per-OS setup notes

These steps live outside the tracked dotfiles because they touch
system state, not config files. Run them once on each new install.

### macOS: system settings

Run `~/bin/macos-defaults.sh` on a new Mac. It sets hot corners, Dock, Finder, trackpad (tap to click, Look Up on Force Click), Ctrl+1..5 to switch desktops, and Caps Lock -> Control. It is safe to re-run and exits on other OSes.

- Keyboard remaps are stored per keyboard, so run it again after plugging in a new one. It remaps every attached keyboard. Keyboards listed in `PC_KEYBOARDS` also get Option and Command swapped and are set up even when unplugged.
- Create desktops 1-5 in Mission Control first. The script only binds the keys.
- Log out once afterward so keyboard and trackpad changes take effect everywhere.

### Ubuntu / GNOME: use plain ssh-agent instead of gnome-keyring

GNOME's `gcr-ssh-agent` lists passphrased keys via `ssh-add -l` but
sometimes refuses to sign with them (`sign_and_send_pubkey: signing
failed... agent refused operation`). Switch to OpenSSH's plain
`ssh-agent.service`:

```bash
# Mask the GNOME and gpg-agent SSH wrappers
systemctl --user mask --now \
  gcr-ssh-agent.socket gcr-ssh-agent.service gpg-agent-ssh.socket

# ssh-agent.service ships static (graphical-session-pre.target.wants only).
# Wire it into default.target so it also starts for SSH-only logins.
mkdir -p ~/.config/systemd/user/default.target.wants
ln -sf /usr/lib/systemd/user/ssh-agent.service \
       ~/.config/systemd/user/default.target.wants/ssh-agent.service

# Prevent gnome-keyring from autostarting its own ssh-agent on GUI login.
# Drop a user-level XDG autostart override with Hidden=true:
install -D /dev/null ~/.config/autostart/gnome-keyring-ssh.desktop
cat > ~/.config/autostart/gnome-keyring-ssh.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=SSH Key Agent
Exec=/usr/bin/gnome-keyring-daemon --start --components=ssh
OnlyShowIn=GNOME;Unity;MATE;
Hidden=true
EOF
```

Log out and back in (or reboot) for masked sockets to fully clear.

The shell side (`SSH_AUTH_SOCK` selection in `.zshenv` and the
`ssh-agent` fallback in `.config/zsh/.zshrc`) is portable and lives in
the tracked dotfiles. `AddKeysToAgent yes` in `.ssh/config` adds the
key (after a one-time passphrase prompt) on first SSH use per session.
