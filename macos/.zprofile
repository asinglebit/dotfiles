# ~/.zprofile -- login shells. zsh reads this for login shells and .zshrc for
# interactive ones, and does not chain them the way bash has to.

# Shims are the half GUI applications inherit: they never source an
# interactive rc, so the hook in scripts/10-mise.sh never runs for them.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh --shims)"
fi
