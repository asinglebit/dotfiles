#!/usr/bin/env bash
# Symlink this repo into $HOME, per FILE so a tree like ~/.config/tmux can hold
# both our tmux.conf and TPM's plugins/. Anything overwritten is backed up.
#
#   <os>/.bashrc             -> ~/.bashrc
#   {shared,<os>}/config/**  -> ~/.config/**
#   {shared,<os>}/share/**   -> ~/.local/share/**
#   {shared,<os>}/ssh/**     -> ~/.ssh/**
#   <os>/library/**          -> ~/Library/**

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
    # The `ln -s` below is only safe because of this move: with a directory --
    # or a symlink to one -- already at target, `ln -s` creates
    # target/basename(src) instead of replacing it. `[ -e ] || [ -L ]` is
    # exhaustive (-L catches the dangling symlink -e misses), so ln always runs
    # against a name that does not exist. If this backup ever goes away, the
    # replacement is `ln -sfn`, never `ln -sf` -- see the README for why.
    if [ -e "$target" ] || [ -L "$target" ]; then
        mv -- "$target" "$target.bak-$stamp"
        printf '  backed up  %s -> %s.bak-%s\n' "$rel" "$rel" "$stamp"
    fi
    ln -s "$src" "$target"
    printf '  linked     %s\n' "$rel"
}

# Config directories linked WHOLE, in defiance of the per-file rule above.
#
# Karabiner-Elements is the only entry, and it has to be: its writer unlink()s
# karabiner.json before rewriting it, so a symlinked file survives exactly until
# the first save from the GUI, and is ignored entirely until then. Upstream
# closed the fix as "not planned" (issue #3248) and documents linking the
# directory instead. The README has the trade that buys, and its cost.
#
# Entries are top-level directory names under config/. Keep this array
# non-empty: bash 3.2 errors on "${arr[@]}" for an empty array under `set -u`.
config_dir_links=(karabiner)

# True when a path relative to config/ falls inside one of those directories.
# Anchored at the top level deliberately -- a nested config/foo/karabiner/ is a
# different directory and keeps getting ordinary per-file links. The trailing /
# in the pattern is what requires a directory component, so a plain FILE named
# karabiner is still linked normally; the name is quoted so it matches
# literally rather than as a glob.
under_dir_link() {
    local rel="$1" name
    for name in "${config_dir_links[@]}"; do
        case "$rel" in "$name"/*) return 0 ;; esac
    done
    return 1
}

# config/ trees -> $XDG_CONFIG_HOME, preserving the path below config/.
#
# The skip is a safety interlock, not tidiness. Once ~/.config/karabiner is a
# symlink into this repo, find still walks the repo's real files, and the
# target computed for macos/config/karabiner/karabiner.json resolves back
# THROUGH that symlink onto the source itself -- so link() would rename the
# repo's own config to .bak-<stamp> and leave a self-referential symlink, with
# .gitignore's *.bak-* hiding the evidence.
link_config_tree() {
    local base="$1"
    [ -d "$base/config" ] || return 0
    while IFS= read -r -d '' file; do
        local rel="${file#"$base/config"/}"
        under_dir_link "$rel" && continue
        link "$file" "$config_home/$rel" ".config/$rel"
    done < <(find "$base/config" -type f -print0 | sort -z)
}

# The exceptions above, linked as directories. Guarded on the source existing so
# a name that only applies to one OS costs nothing on the other.
link_config_dirs() {
    local base="$1" name
    for name in "${config_dir_links[@]}"; do
        [ -d "$base/config/$name" ] || continue
        link "$base/config/$name" "$config_home/$name" ".config/$name"
    done
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

# library/ trees -> ~/Library. LaunchAgents live here: launchd is the only
# reader, so these are ordinary per-file links with no directory exception.
# Not XDG and not overridable, hence the literal path rather than a *_home
# variable beside config_home and data_home -- its absence from that block is
# the point.
link_library_tree() {
    local base="$1"
    [ -d "$base/library" ] || return 0
    while IFS= read -r -d '' file; do
        local rel="${file#"$base/library"/}"
        link "$file" "$HOME/Library/$rel" "Library/$rel"
    done < <(find "$base/library" -type f -print0 | sort -z)
}

# Dotfiles sitting directly in an OS root -> $HOME. Only real files, and never
# the scripts/ or config/ subtrees, which are handled separately.
#
# .DS_Store is excluded by name: one Finder visit to macos/ creates it, and
# without this the next run happily links ~/.DS_Store to it. .gitignore stops
# it being committed, not linked.
link_home_dotfiles() {
    local base="$1"
    while IFS= read -r -d '' file; do
        local rel="${file#"$base"/}"
        link "$file" "$HOME/$rel" "$rel"
    done < <(find "$base" -maxdepth 1 -type f -name '.*' ! -name '.DS_Store' -print0 | sort -z)
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

# Tree before dirs, and the order is load-bearing. With a correct skip it makes
# no difference, so this is defence in depth against the skip and
# config_dir_links drifting apart: tree-first, a stale per-file link lands in
# the REAL ~/.config and the dir walker then backs that whole directory up --
# noisy, recoverable, outside the repo. Dirs-first, it writes through the fresh
# symlink into the working tree, which is the failure link_config_tree's
# comment describes.
echo "shared:"
link_config_tree "$repo/shared"
link_config_dirs "$repo/shared"
link_data_tree   "$repo/shared"
link_ssh_tree    "$repo/shared"

echo
echo "$os:"
link_home_dotfiles "$repo/$os"
link_config_tree   "$repo/$os"
link_config_dirs   "$repo/$os"
link_data_tree     "$repo/$os"
link_ssh_tree      "$repo/$os"
link_library_tree  "$repo/$os"

echo
echo "systemd:"
enable_user_units

echo
echo "done."
