# ~/.zshrc -- a symlink to the versioned file in the dotfiles repo.
# Machine-local state goes in ~/.zshrc.d/, not here. No `source /etc/zshrc`,
# unlike the Linux side: zsh sources the system files itself, before this one.

# Resolve this file's own location so the repo can be cloned anywhere. BSD
# readlink only grew -f in macOS 12.3, hence the perl fallback.
_self="${(%):-%N}"
if _resolved=$(readlink -f "$_self" 2>/dev/null) && [ -n "$_resolved" ]; then
    _self="$_resolved"
elif _resolved=$(perl -MCwd -e 'print Cwd::abs_path shift' "$_self" 2>/dev/null) && [ -n "$_resolved" ]; then
    _self="$_resolved"
fi
DOTFILES_OS_DIR="$(cd "$(dirname "$_self")" && pwd)"
export DOTFILES="$(dirname "$DOTFILES_OS_DIR")"

# Numeric prefixes are ONE load order across both script directories:
# shared/scripts/ for what is OS-neutral, macos/scripts/ for what is not. The
# number decides, not the directory -- shared/scripts/90-tmux.sh has to sort
# after macos/scripts/80-sdkman.sh, because it ends in `tmux attach && exit` and
# nothing after it runs in the outer shell. Sourcing one tree and then the other
# cannot produce that order, so the two are merged by basename.
#
# Only basenames go through the split, and those are repo-controlled
# `NN-name.sh`, so a clone path with a space in it stays safe.
for _name in ${(f)"$(
    for _f in "$DOTFILES/shared/scripts"/*.sh(N) "$DOTFILES_OS_DIR/scripts"/*.sh(N); do
        printf '%s\n' "${_f##*/}"
    done | sort -u
)"}; do
    for _dir in "$DOTFILES/shared/scripts" "$DOTFILES_OS_DIR/scripts"; do
        [ -r "$_dir/$_name" ] && . "$_dir/$_name"
    done
done

unset _self _resolved _name _dir DOTFILES_OS_DIR

# Last, so a one-off on one box can override anything above.
if [ -d ~/.zshrc.d ]; then
    for _rc in ~/.zshrc.d/*(N); do
        [ -f "$_rc" ] && . "$_rc"
    done
    unset _rc
fi
