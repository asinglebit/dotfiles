#!/usr/bin/env bash
# Symlink this repo into $HOME. The repo holds the real files; $HOME only
# references them.
#
# Deploys shared/ plus the directory matching this OS (linux/ or macos/), so a
# machine only ever gets config it can use.
#
# Layout -> target:
#   <os>/.bashrc          -> ~/.bashrc          (dotfiles at an OS root go to $HOME)
#   shared/config/**      -> ~/.config/**       (config/ trees go to $XDG_CONFIG_HOME)
#   <os>/config/**        -> ~/.config/**
#   shared/share/**       -> ~/.local/share/**  (share/ trees go to $XDG_DATA_HOME)
#   <os>/share/**         -> ~/.local/share/**
#   <os>/ssh/**           -> ~/.ssh/**          (ssh/ trees go to ~/.ssh -- see below)
#
# Links are made per FILE, never per directory, so a tree like ~/.config/tmux
# can hold both our tmux.conf and TPM's plugins/ without one clobbering the
# other. This mirrors `just link-dotfiles` in the bazzite repo, which shares
# the backup convention (<name>.bak-<timestamp>).

set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
stamp="$(date +%Y%m%d-%H%M%S)"

case "$(uname -s)" in
    Linux)  os=linux  ;;
    Darwin) os=macos  ;;
    *) echo "install.sh: unsupported OS $(uname -s)" >&2; exit 1 ;;
esac

echo "repo: $repo"
echo "os:   $os"
[ "$DRY_RUN" = 1 ] && echo "(dry run -- nothing will be written)"
echo

link() {
    local src="$1" target="$2" rel="$3"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$src" ]; then
        printf '  ok         %s\n' "$rel"
        return
    fi

    if [ "$DRY_RUN" = 1 ]; then
        if [ -e "$target" ] || [ -L "$target" ]; then
            printf '  would back up + link  %s\n' "$rel"
        else
            printf '  would link  %s\n' "$rel"
        fi
        return
    fi

    mkdir -p "$(dirname "$target")"
    if [ -e "$target" ] || [ -L "$target" ]; then
        mv -- "$target" "$target.bak-$stamp"
        printf '  backed up  %s -> %s.bak-%s\n' "$rel" "$rel" "$stamp"
    fi
    ln -s "$src" "$target"
    printf '  linked     %s\n' "$rel"
}

# config/ trees -> $XDG_CONFIG_HOME, preserving the path below config/.
link_config_tree() {
    local base="$1"
    [ -d "$base/config" ] || return 0
    while IFS= read -r -d '' file; do
        local rel="${file#"$base/config"/}"
        link "$file" "$config_home/$rel" ".config/$rel"
    done < <(find "$base/config" -type f -print0 | sort -z)
}

# share/ trees -> $XDG_DATA_HOME. Desktop entries and their icons live here: an
# XDG data path, not a config one, and per-user so nothing depends on the image.
link_data_tree() {
    local base="$1"
    [ -d "$base/share" ] || return 0
    while IFS= read -r -d '' file; do
        local rel="${file#"$base/share"/}"
        link "$file" "$data_home/$rel" ".local/share/$rel"
    done < <(find "$base/share" -type f -print0 | sort -z)
}

# ssh/ trees -> ~/.ssh. Not an XDG path and not $HOME either: OpenSSH looks in
# exactly one place, honours no XDG variable, and cannot include a directory of
# drop-ins the way sway or environment.d can. It also refuses a config file that
# is group- or world-writable, so the modes the repo carries are what land here
# -- 0644 for the config, 0755 for the askpass helper ssh-add has to exec. ~/.ssh
# itself is forced back to 0700: link()'s mkdir -p would otherwise create it at
# the umask on a fresh machine.
link_ssh_tree() {
    local base="$1"
    [ -d "$base/ssh" ] || return 0
    if [ "$DRY_RUN" = 0 ]; then
        mkdir -p "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
    fi
    while IFS= read -r -d '' file; do
        local rel="${file#"$base/ssh"/}"
        link "$file" "$HOME/.ssh/$rel" ".ssh/$rel"
    done < <(find "$base/ssh" -type f -print0 | sort -z)
}

# Dotfiles sitting directly in an OS root -> $HOME. Only real files, and never
# the scripts/ or config/ subtrees, which are handled separately.
link_home_dotfiles() {
    local base="$1"
    while IFS= read -r -d '' file; do
        local rel="${file#"$base"/}"
        link "$file" "$HOME/$rel" "$rel"
    done < <(find "$base" -maxdepth 1 -type f -name '.*' -print0 | sort -z)
}

# systemd user units. Two, both part of the ssh setup:
#
#   ssh-agent.socket    The socket-activated agent scripts/30-ssh-agent.sh and
#                       config/environment.d/10-ssh-agent.conf point at. Fedora
#                       ships it disabled and only Plasma wires it up, so on a
#                       sway session enabling it is on us.
#   ssh-add-key.service Loads the key into that agent at login, reading the
#                       passphrase from the keyring. See the unit's own header.
#
# Enabled, not merely started: environment.d hands every app in the session the
# socket path from the moment sway starts, and the first shell -- all the rc
# file can react to -- may come minutes later or never.
enable_user_units() {
    [ "$os" = linux ] || return 0
    command -v systemctl >/dev/null 2>&1 || return 0
    if ! systemctl --user show-environment >/dev/null 2>&1; then
        printf '  skipped    user units (no systemd user session here)\n'
        return 0
    fi

    # ssh-add-key.service arrives as a symlink this run may have just made;
    # without a reload systemctl still sees the directory as it was.
    if [ "$DRY_RUN" = 0 ]; then
        systemctl --user daemon-reload
    fi

    local unit
    for unit in ssh-agent.socket ssh-add-key.service; do
        if [ "$(systemctl --user is-enabled "$unit" 2>/dev/null)" = enabled ]; then
            printf '  ok         %s\n' "$unit"
        elif [ "$DRY_RUN" = 1 ]; then
            printf '  would enable  %s\n' "$unit"
        elif systemctl --user enable "$unit" >/dev/null 2>&1; then
            printf '  enabled    %s\n' "$unit"
        else
            printf '  FAILED     %s -- see `systemctl --user status %s`\n' "$unit" "$unit"
        fi
    done

    if [ "$DRY_RUN" = 1 ]; then
        return 0
    fi

    # Started as well as enabled, so an install takes effect without a
    # re-login. The socket unconditionally -- starting it only opens an idle
    # listener. The key loader only once there is a passphrase to find, because
    # without one it can do nothing but fail, and an installer that reports a
    # failure for a step the machine has not been given the input for yet is
    # just noise.
    systemctl --user start ssh-agent.socket >/dev/null 2>&1 || true

    if command -v secret-tool >/dev/null 2>&1 &&
            secret-tool lookup dotfiles ssh-passphrase key id_ed25519 >/dev/null 2>&1; then
        if systemctl --user start ssh-add-key.service >/dev/null 2>&1; then
            printf '  loaded     ssh key into the agent\n'
        else
            printf '  FAILED     ssh-add-key.service -- journalctl --user -b | grep askpass\n'
        fi
    else
        cat <<'HINT'
  todo       the key passphrase is not in the keyring yet. Once, per machine:
               secret-tool store --label='ssh key passphrase (id_ed25519)' \
                   dotfiles ssh-passphrase key id_ed25519
HINT
    fi
}

echo "shared:"
link_config_tree "$repo/shared"
link_data_tree   "$repo/shared"
link_ssh_tree    "$repo/shared"

echo
echo "$os:"
link_home_dotfiles "$repo/$os"
link_config_tree   "$repo/$os"
link_data_tree     "$repo/$os"
link_ssh_tree      "$repo/$os"

echo
echo "systemd:"
enable_user_units

echo
echo "done."
