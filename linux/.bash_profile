# ~/.bash_profile -- login shells.

if [ -f ~/.bashrc ]; then
    . ~/.bashrc
fi

# Shims are the half GUI applications and editors inherit: they get the login
# environment and never source an interactive rc, so the hook in
# scripts/10-mise.sh never runs for them.
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate bash --shims)"
fi
