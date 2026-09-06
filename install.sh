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

# Dotfiles sitting directly in an OS root -> $HOME. Only real files, and never
# the scripts/ or config/ subtrees, which are handled separately.
link_home_dotfiles() {
    local base="$1"
    while IFS= read -r -d '' file; do
        local rel="${file#"$base"/}"
        link "$file" "$HOME/$rel" "$rel"
    done < <(find "$base" -maxdepth 1 -type f -name '.*' -print0 | sort -z)
}

echo "shared:"
link_config_tree "$repo/shared"
link_data_tree   "$repo/shared"

echo
echo "$os:"
link_home_dotfiles "$repo/$os"
link_config_tree   "$repo/$os"
link_data_tree     "$repo/$os"

echo
echo "done."
