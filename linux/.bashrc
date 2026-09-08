# ~/.bashrc -- a symlink to the versioned file in the dotfiles repo.
# Machine-local state goes in ~/.bashrc.d/, not here.

# First: Fedora's /etc/profile.d/*.sh loop is what appends brew to PATH.
if [ -f /etc/bashrc ]; then
    . /etc/bashrc
fi

# Resolve this file's own location so the repo can be cloned anywhere. BSD
# readlink only grew -f in macOS 12.3, hence the perl fallback.
_self="${BASH_SOURCE[0]}"
if _resolved=$(readlink -f "$_self" 2>/dev/null) && [ -n "$_resolved" ]; then
    _self="$_resolved"
elif _resolved=$(perl -MCwd -e 'print Cwd::abs_path shift' "$_self" 2>/dev/null) && [ -n "$_resolved" ]; then
    _self="$_resolved"
fi
DOTFILES_OS_DIR="$(cd "$(dirname "$_self")" && pwd)"
export DOTFILES="$(dirname "$DOTFILES_OS_DIR")"

# Numeric prefixes are the load order, and 90-tmux.sh has to sort last: it ends
# in `tmux attach && exit`, so nothing after it runs in the outer shell.
for _script in "$DOTFILES_OS_DIR"/scripts/*.sh; do
    [ -r "$_script" ] && . "$_script"
done

unset _self _resolved _script DOTFILES_OS_DIR

# Last, so a one-off on a single box can override anything above it.
if [ -d ~/.bashrc.d ]; then
    for _rc in ~/.bashrc.d/*; do
        [ -f "$_rc" ] && . "$_rc"
    done
    unset _rc
fi
