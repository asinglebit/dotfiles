# ~/.zshrc -- a symlink to macos/.zshrc in the dotfiles repo.
#
# The real file is versioned; the OS only references it. Machine state that
# should not be committed goes in ~/.zshrc.d/ (sourced at the bottom) or in
# ~/.config/mise/config.local.toml for tool versions.
#
# There is no `source /etc/zshrc` here, unlike the Linux side's /etc/bashrc:
# zsh sources the system files itself, before this one.

# Resolve this file's own location so the repo can be cloned anywhere.
# ${(%):-%N} is zsh's "path of the file currently being sourced". BSD readlink
# only grew -f in macOS 12.3, hence the perl fallback.
_self="${(%):-%N}"
if _resolved=$(readlink -f "$_self" 2>/dev/null) && [ -n "$_resolved" ]; then
    _self="$_resolved"
elif _resolved=$(perl -MCwd -e 'print Cwd::abs_path shift' "$_self" 2>/dev/null) && [ -n "$_resolved" ]; then
    _self="$_resolved"
fi
DOTFILES_OS_DIR="$(cd "$(dirname "$_self")" && pwd)"
export DOTFILES="$(dirname "$DOTFILES_OS_DIR")"

# Numeric prefixes are the load order. 90-tmux.sh is last on purpose: it ends
# in `tmux attach && exit`, so nothing after it runs in the outer shell. The
# shell tmux then starts re-sources this file with $TMUX set, the autostart
# block skips, and the earlier scripts -- dib() included -- get defined there.
for _script in "$DOTFILES_OS_DIR"/scripts/*.sh; do
    [ -r "$_script" ] && . "$_script"
done

unset _self _resolved _script DOTFILES_OS_DIR

# Machine-local drop-ins, deliberately outside the repo. Kept last so a
# one-off on a single box can override anything above it.
if [ -d ~/.zshrc.d ]; then
    for _rc in ~/.zshrc.d/*(N); do
        [ -f "$_rc" ] && . "$_rc"
    done
    unset _rc
fi
