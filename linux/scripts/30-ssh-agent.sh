# ssh-agent with a stable socket path.
#
# Each new shell would otherwise start its own agent and leak it. Pointing
# SSH_AUTH_SOCK at a fixed symlink means every shell -- and every tmux pane,
# which does not inherit the launching terminal's environment -- reuses one
# agent and one unlocked key.
if [ ! -S "$HOME/.ssh/ssh_auth_sock" ]; then
    eval "$(ssh-agent -s)" >/dev/null
    ln -sf "$SSH_AUTH_SOCK" "$HOME/.ssh/ssh_auth_sock"
fi
export SSH_AUTH_SOCK="$HOME/.ssh/ssh_auth_sock"

# Add the default key only if the agent is empty, so this is silent on every
# shell after the first.
ssh-add -l >/dev/null 2>&1 || ssh-add "$HOME/.ssh/id_ed25519" 2>/dev/null
