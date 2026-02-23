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

# Alias ls
alias l="ls -a"

# Auto setup tmux in main projects
dib() {
  root="/Users/ali/projects/work/dib-customer-web"
  types="/Users/ali/projects/work/dib-customer-web/packages/types"
  api="/Users/ali/projects/work/dib-customer-web/packages/api"
  ui="/Users/ali/projects/work/dib-customer-web/packages/ui"

  # ----------------------------
  # Create window in desired directory
  # ----------------------------
  win=$(tmux new-window -P -F "#{window_id}" -n work -c "$root")

  # 3 columns
  tmux split-window -h -l 75% -t "$win" -c "$root"
  tmux split-window -h -l 33% -t "$win" -c "$types"

  # LEFT column → 3 rows
  left=$(tmux list-panes -t "$win" -F "#{pane_id}" | head -n 1)
  tmux split-window -v -l 33% -t "$left" -c "$ui"
  tmux split-window -v -l 50% -t "$left" -c "$root"

  # RIGHT column → 4 rows
  right=$(tmux list-panes -t "$win" -F "#{pane_left} #{pane_id}" | sort -nr | head -n1 | awk '{print $2}')
  tmux split-window -v -l 25% -t "$right" -c "$root"
  tmux split-window -v -l 33% -t "$right" -c "$api"
  tmux split-window -v -l 50% -t "$right" -c "$ui"

  # CENTER column → 3 rows
  center=$(tmux list-panes -t "$win" -F "#{pane_id}" | awk 'NR==4{print $1}')
  tmux split-window -v -l 50% -t "$center" -c "$workdir"
  tmux split-window -v -l 50% -t "$center" -c "$workdir"

  # ----------------------------
  # Send commands to each pane
  # ----------------------------
  panes=$(tmux list-panes -t "$win" -F "#{pane_id}")

  cmds=(
    "sleep 20s && pnpm start:host" 
    "sleep 20s && pnpm start:remote"
    "sleep 20s && pnpm start:app"
    "sleep 30s && pnpm test:remote"
    "sleep 30s && pnpm test:api"
    "pnpm reset && pnpm i"
    "sleep 10s && pnpm watch"
    "sleep 11s && pnpm watch"
    "sleep 10s && pnpm watch:lib"
    "g"
  )

  i=0
  for pane in $panes; do
    tmux send-keys -t "$pane" "${cmds[$i]}" Enter
    i=$((i+1))
  done
}

