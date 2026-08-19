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

# Aliases
alias g='~/projects/personal/guitar/target/release/guitar'
alias n='nvim'
alias l="ls -a"
alias claude-work='CLAUDE_CONFIG_DIR=$HOME/.claude-work claude'
alias claude-personal='CLAUDE_CONFIG_DIR=$HOME/.claude-personal claude'

# Auto setup tmux in main projects
dib() {
  root="$HOME/projects/work/customer-portal"
  types="$root/packages/types"
  store="$root/packages/store"
  localize="$root/packages/localize"
  api="$root/packages/api"
  posthog="$root/packages/posthog"
  ui="$root/packages/ui"
  cli="$HOME/projects/dib-cli"

  win=$(tmux new-window -P -F "#{window_id}" -n work -c "$root")

  # Gate file: the reset pane writes its exit status here when it finishes.
  # Derived from the window id so two `dib` runs can't share a gate.
  gate="${TMPDIR:-/tmp}/dib-gate-${win#@}"
  rm -f "$gate"

  # Left 90% becomes a 3x2 grid; right 10% is the 11-row stack.
  p_guitar=$(tmux list-panes -t "$win" -F "#{pane_id}" | head -n1)

  # A 3x2 grid plus an 11-row stack needs room. tmux will happily make 1-line panes,
  # so this is about legibility, not failure. `display-message -t` wants a
  # target-PANE, so ask via $p_guitar — a @window id silently reports the wrong window.
  read -r wh ww <<<"$(tmux display-message -p -t "$p_guitar" '#{window_height} #{window_width}')"
  if [ "$wh" -lt 33 ] || [ "$ww" -lt 240 ]; then
    echo "dib: window is ${ww}x${wh}; wants 240x33+ — panes will be cramped." >&2
  fi

  # Split off the right-hand stack (10% wide), then give row 1 only 10% of the height.
  p_w_types=$(tmux split-window -P -F "#{pane_id}" -h -l 10% -t "$p_guitar" -c "$types")
  p_nvim=$(tmux    split-window -P -F "#{pane_id}" -v -l 90% -t "$p_guitar" -c "$root")

  # ROW 1 → guitar | dib-cli shell | reset, in equal thirds
  p_cli=$(tmux   split-window -P -F "#{pane_id}" -h -l 67% -t "$p_guitar" -c "$cli")
  p_reset=$(tmux split-window -P -F "#{pane_id}" -h -l 50% -t "$p_cli"    -c "$root")

  # ROW 2 → nvim | claude-work | claude-work, in equal thirds
  p_claude1=$(tmux split-window -P -F "#{pane_id}" -h -l 67% -t "$p_nvim"    -c "$root")
  p_claude2=$(tmux split-window -P -F "#{pane_id}" -h -l 50% -t "$p_claude1" -c "$root")

  # RIGHT column → 11 equal rows. Each -l is (rows_left - 1)/rows_left, so the new
  # pane takes all but one row's worth and the target keeps that one row.
  p_w_store=$(tmux     split-window -P -F "#{pane_id}" -v -l 91% -t "$p_w_types"     -c "$store")
  p_w_localize=$(tmux  split-window -P -F "#{pane_id}" -v -l 90% -t "$p_w_store"     -c "$localize")
  p_w_api=$(tmux       split-window -P -F "#{pane_id}" -v -l 89% -t "$p_w_localize"  -c "$api")
  p_w_posthog=$(tmux   split-window -P -F "#{pane_id}" -v -l 88% -t "$p_w_api"       -c "$posthog")
  p_w_ui=$(tmux        split-window -P -F "#{pane_id}" -v -l 86% -t "$p_w_posthog"   -c "$ui")
  p_test_remote=$(tmux split-window -P -F "#{pane_id}" -v -l 83% -t "$p_w_ui"        -c "$root")
  p_test_api=$(tmux    split-window -P -F "#{pane_id}" -v -l 80% -t "$p_test_remote" -c "$root")
  p_uiapp=$(tmux       split-window -P -F "#{pane_id}" -v -l 75% -t "$p_test_api"    -c "$ui")
  p_host=$(tmux        split-window -P -F "#{pane_id}" -v -l 67% -t "$p_uiapp"       -c "$root")
  p_remote=$(tmux      split-window -P -F "#{pane_id}" -v -l 50% -t "$p_host"        -c "$root")

  # Parallel arrays — portable across bash/zsh (no associative arrays,
  # no ${!arr[@]} key-expansion which means "indirect" in zsh).
  # The five immediate panes are NOT here; they are dispatched directly below.
  panes=(
    "$p_w_types" "$p_w_store" "$p_w_localize" "$p_w_api" "$p_w_posthog" "$p_w_ui"
    "$p_test_remote" "$p_test_api" "$p_uiapp" "$p_host" "$p_remote"
  )
  cmds=(
    "pnpm watch" "pnpm watch" "pnpm watch" "pnpm watch" "pnpm watch" "pnpm watch:lib"
    "pnpm test:remote" "pnpm test:api" "pnpm start:app" "pnpm start:host" "pnpm start:remote"
  )
  # Offsets are relative to `pnpm reset` EXITING, not to wall-clock t=0.
  delays=(
    0 0 0 0 0 0
    15 15 10 10 10
  )

  sleep 0.5

  # Phase 0: the destructive step runs alone. reset.sh does `git clean -fdx`, which
  # would delete node_modules/dist out from under anything else running.
  # `;` before writing $? so the gate still opens when reset fails.
  tmux send-keys -t "$p_reset" "pnpm reset && pnpm i; echo \$? > '$gate'" C-m

  # Interactive tools: nothing to wait for. `git clean -fdx` doesn't touch .git,
  # so guitar is safe to open against the repo immediately.
  # $p_cli gets no command — it stays a shell parked in the dib-cli folder.
  tmux send-keys -t "$p_guitar"  "g" C-m
  tmux send-keys -t "$p_nvim"    "n" C-m
  tmux send-keys -t "$p_claude1" "claude-work" C-m
  tmux send-keys -t "$p_claude2" "claude-work" C-m

  # Detect array base (zsh = 1, bash = 0) so this works in both shells.
  if [ -n "${ZSH_VERSION:-}" ]; then
    _start=1; _end=${#panes[@]}
  else
    _start=0; _end=$((${#panes[@]} - 1))
  fi

  # Phase 1: everything that needs node_modules waits on the gate.
  for ((i=_start; i<=_end; i++)); do
    (
      # A failed split leaves an empty pane id, and `send-keys -t ""` fires into
      # the *active* pane — skip rather than misfire.
      [ -n "${panes[$i]}" ] || exit 0

      waited=0
      while [ ! -f "$gate" ] && [ "$waited" -lt 1800 ]; do
        sleep 2
        waited=$((waited + 2))
      done

      # NB: not `status` — that name is read-only in zsh (an alias for $?).
      rc=$([ -f "$gate" ] && cat "$gate" || echo timeout)
      if [ "$rc" != "0" ]; then
        tmux send-keys -t "${panes[$i]}" \
          "echo 'dib: pnpm reset did not succeed ($rc) — not auto-starting'" C-m
        exit 0
      fi

      sleep "${delays[$i]}"
      tmux send-keys -t "${panes[$i]}" "${cmds[$i]}" C-m
    ) &
  done
}
