#!/usr/bin/env bash
# Symlink this repo into $HOME, per FILE so a tree like ~/.config/tmux can hold
# both our tmux.conf and TPM's plugins/. Anything overwritten is backed up.
#
#   <os>/.bashrc             -> ~/.bashrc
#   {shared,<os>}/config/**  -> ~/.config/**
#   {shared,<os>}/share/**   -> ~/.local/share/**
#   {shared,<os>}/ssh/**     -> ~/.ssh/**

set -euo pipefail

DRY_RUN=0
[ "${1:-}" = "--dry-run" ] && DRY_RUN=1

# pwd -P: /home is a symlink to var/home here, and the two spellings never
# compare equal, which turns the idempotence check below into a relink.
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

link_config_tree() {
    local base="$1"
    [ -d "$base/config" ] || return 0
    while IFS= read -r -d '' file; do
        local rel="${file#"$base/config"/}"
        link "$file" "$config_home/$rel" ".config/$rel"
    done < <(find "$base/config" -type f -print0 | sort -z)
}

link_data_tree() {
    local base="$1"
    [ -d "$base/share" ] || return 0
    while IFS= read -r -d '' file; do
        local rel="${file#"$base/share"/}"
        link "$file" "$data_home/$rel" ".local/share/$rel"
    done < <(find "$base/share" -type f -print0 | sort -z)
}

# OpenSSH honours no XDG path, and ignores ~/.ssh unless it is 0700.
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

link_home_dotfiles() {
    local base="$1"
    while IFS= read -r -d '' file; do
        local rel="${file#"$base"/}"
        link "$file" "$HOME/$rel" "$rel"
    done < <(find "$base" -maxdepth 1 -type f -name '.*' -print0 | sort -z)
}

# ssh-agent.socket is the agent; ssh-add-key.service loads the key into it at
# login. Fedora ships both disabled. Enabled rather than just started, because
# apps get the socket path at session start, long before any shell runs.
enable_user_units() {
    [ "$os" = linux ] || return 0
    command -v systemctl >/dev/null 2>&1 || return 0
    if ! systemctl --user show-environment >/dev/null 2>&1; then
        printf '  skipped    user units (no systemd user session here)\n'
        return 0
    fi

    # The service arrives as a symlink this run may have just made.
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

    # Started too, so an install takes effect without a re-login -- the key
    # loader only once the keyring has a passphrase for it to find.
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
