# ~/.bashrc -- a symlink to the versioned file in the dotfiles repo.
# Machine-local state goes in ~/.bashrc.d/, not here.

# First: Fedora's /etc/profile.d/*.sh loop is what appends brew to PATH.
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Resolve this file's own location so the repo can be cloned anywhere. GNU
# readlink -f is a given here; only the macOS side needs a fallback.
_self="${BASH_SOURCE[0]}"
if _resolved=$(readlink -f "$_self" 2>/dev/null) && [ -n "$_resolved" ]; then
    _self="$_resolved"
fi
DOTFILES_OS_DIR="$(cd "$(dirname "$_self")" && pwd)"
export DOTFILES="$(dirname "$DOTFILES_OS_DIR")"

# Numeric prefixes are ONE load order across both script directories:
# shared/scripts/ for what is OS-neutral, linux/scripts/ for what is not. The
# number decides, not the directory -- shared/scripts/90-tmux.sh has to sort
# last, because it ends in `tmux attach && exit` and nothing after it runs in
# the outer shell, and on the Mac that means after macos/scripts/80-sdkman.sh.
# Sourcing one tree and then the other cannot produce that, so the two are
# merged by basename.
#
# Only basenames go through the split, and those are repo-controlled
# `NN-name.sh`, so a clone path with a space in it stays safe.
for _name in $(
    for _f in "$DOTFILES/shared/scripts"/*.sh "$DOTFILES_OS_DIR/scripts"/*.sh; do
        [ -r "$_f" ] && printf '%s\n' "${_f##*/}"
    done | sort -u
); do
    for _dir in "$DOTFILES/shared/scripts" "$DOTFILES_OS_DIR/scripts"; do
        [ -r "$_dir/$_name" ] && . "$_dir/$_name"
    done
done

unset _self _resolved _name _dir DOTFILES_OS_DIR

# Last, so a one-off on a single box can override anything above it.
if [ -d ~/.bashrc.d ]; then
    for _rc in ~/.bashrc.d/*; do
        [ -f "$_rc" ] && . "$_rc"
    done
    unset _rc
fi
