# ~/.zprofile -- login shells.
#
# zsh sources .zprofile for login shells and .zshrc for interactive ones, and
# does NOT chain them the way bash's .bash_profile has to source .bashrc. So
# this file only carries what a login environment needs on its own.

# Shims activation, the counterpart to the interactive `mise activate zsh` in
# scripts/10-mise.sh. This is the half GUI applications inherit: they get the
# login environment and never source an interactive rc, so without it they see
# no mise-managed tools. Shims are a directory of stub executables, so they keep
# working in a process that never re-runs a shell hook.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh --shims)"
fi
