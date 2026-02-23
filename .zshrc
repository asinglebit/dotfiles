export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm

# Load Angular CLI autocompletion.
# source <(ng completion script)

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

# Aliases
alias g='~/projects/personal/guitar/target/release/guitar'
alias n='/opt/homebrew/bin/nvim'
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

  # LEFT column - 3 rows
  left=$(tmux list-panes -t "$win" -F "#{pane_id}" | head -n 1)
  tmux split-window -v -l 33% -t "$left" -c "$ui"
  tmux split-window -v -l 50% -t "$left" -c "$root"

  # RIGHT column - 4 rows
  right=$(tmux list-panes -t "$win" -F "#{pane_left} #{pane_id}" | sort -nr | head -n1 | awk '{print $2}')
  tmux split-window -v -l 25% -t "$right" -c "$root"
  tmux split-window -v -l 33% -t "$right" -c "$ui"
  tmux split-window -v -l 50% -t "$right" -c "$api"

  # CENTER column - 3 rows
  center=$(tmux list-panes -t "$win" -F "#{pane_id}" | awk 'NR==4{print $1}')
  tmux split-window -v -l 50% -t "$center" -c "$root"
  tmux split-window -v -l 50% -t "$center" -c "$root"

  # ----------------------------
  # Send commands to each pane
  # ----------------------------

  cmds=(
    "sleep 30 && pnpm start:host" 
    "sleep 30 && pnpm start:remote"
    "sleep 30 && pnpm start:app"
    "sleep 40 && pnpm test:remote"
    "sleep 40 && pnpm test:api"
    "pnpm reset && pnpm i"
    "sleep 20 && pnpm watch"
    "sleep 20 && pnpm watch"
    "sleep 20 && pnpm watch:lib"
    "g"
  )

panes=("${(@f)$(tmux list-panes -t "$win" -F "#{pane_id}")}")

i=1
for pane in "${panes[@]}"; do
  tmux send-keys -t "$pane" "${cmds[$i]}" Enter
  ((i++))
done

}

eval "$(/Users/ali/.local/bin/mise activate zsh)"
