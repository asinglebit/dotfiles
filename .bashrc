# Auto-start tmux sessions with shared windows
if [[ -z "$TMUX" && -z "$NVIM" && -t 1 ]]; then
  # Ensure the main session exists
  if ! tmux has-session -t main 2>/dev/null; then
    tmux new-session -d -s main
  fi

  # Create a new session sharing main's windows
  new_name="dev_$(date +%Y%m%d_%H%M%S)"
  tmux new-session -d -t main -s "$new_name"

  # Add a new window to the new session
  tmux new-window -t "$new_name" -n "work"

  # Attach to the new session
  exec tmux attach -t "$new_name"
fi

# SSH Agent setup
if [ ! -S ~/.ssh/ssh_auth_sock ]; then
    eval "$(ssh-agent -s)"
    ln -sf "$SSH_AUTH_SOCK" ~/.ssh/ssh_auth_sock
fi
export SSH_AUTH_SOCK=~/.ssh/ssh_auth_sock

# Add your default key
ssh-add -l > /dev/null || ssh-add ~/.ssh/keyfile 2>/dev/null
