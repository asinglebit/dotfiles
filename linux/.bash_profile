# ~/.bash_profile -- login shells.

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# Shims activation, in addition to the interactive `mise activate bash` in
# scripts/10-mise.sh. This is the half GUI applications and editors get: they
# inherit the login environment and never source an interactive rc, so without
# it they see no mise-managed tools. Shims are a directory of stub executables,
# so they keep working in a process that never re-runs a shell hook.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash --shims)"
fi
