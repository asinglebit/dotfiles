# dib -- one tmux window laid out for the customer-portal monorepo. Written to
# run under both bash and zsh, so the macOS side can source the same logic.

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

  # The reset pane writes its exit status here, keyed on the window id.
  gate="${TMPDIR:-/tmp}/dib-gate-${win#@}"
  rm -f "$gate"

  # Left 90% becomes a 3x2 grid; right 10% is the 11-row stack.
  p_guitar=$(tmux list-panes -t "$win" -F "#{pane_id}" | head -n1)

  # Legibility, not failure -- tmux will happily make 1-line panes. And -t
  # wants a pane id; a @window id reports another window.
  read -r wh ww <<<"$(tmux display-message -p -t "$p_guitar" '#{window_height} #{window_width}')"
  if [ "$wh" -lt 33 ] || [ "$ww" -lt 240 ]; then
    echo "dib: window is ${ww}x${wh}; wants 240x33+ — panes will be cramped." >&2
  fi

  # Right-hand stack first (10% wide), then row 1 keeps 10% of the height.
  p_w_types=$(tmux split-window -P -F "#{pane_id}" -h -l 10% -t "$p_guitar" -c "$types")
  p_nvim=$(tmux    split-window -P -F "#{pane_id}" -v -l 90% -t "$p_guitar" -c "$root")

  # ROW 1 → guitar | dib-cli shell | reset, in equal thirds
  p_cli=$(tmux   split-window -P -F "#{pane_id}" -h -l 67% -t "$p_guitar" -c "$cli")
  p_reset=$(tmux split-window -P -F "#{pane_id}" -h -l 50% -t "$p_cli"    -c "$root")

  # ROW 2 → nvim | claude-work | claude-work, in equal thirds
  p_claude1=$(tmux split-window -P -F "#{pane_id}" -h -l 67% -t "$p_nvim"    -c "$root")
  p_claude2=$(tmux split-window -P -F "#{pane_id}" -h -l 50% -t "$p_claude1" -c "$root")

  # RIGHT column → 11 equal rows: each -l is (rows_left - 1)/rows_left, so the
  # target keeps one row's worth.
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

  # Parallel arrays: in zsh ${!arr[@]} means indirection, not keys.
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

  # Phase 0 runs alone: reset.sh does `git clean -fdx`. `;` not `&&`, so the
  # gate still opens when reset fails.
  tmux send-keys -t "$p_reset" "pnpm reset && pnpm i; echo \$? > '$gate'" C-m

  # Nothing to wait for. $p_cli gets no command: it stays a shell in dib-cli.
  tmux send-keys -t "$p_guitar"  "g" C-m
  tmux send-keys -t "$p_nvim"    "n" C-m
  tmux send-keys -t "$p_claude1" "claude-work" C-m
  tmux send-keys -t "$p_claude2" "claude-work" C-m

  # zsh arrays are 1-based, bash's 0-based.
  if [ -n "${ZSH_VERSION:-}" ]; then
    _start=1; _end=${#panes[@]}
  else
    _start=0; _end=$((${#panes[@]} - 1))
  fi

  # Phase 1: everything that needs node_modules waits on the gate.
  for ((i=_start; i<=_end; i++)); do
    (
      # `send-keys -t ""` fires into the active pane, so skip a failed split.
      [ -n "${panes[$i]}" ] || exit 0

      waited=0
      while [ ! -f "$gate" ] && [ "$waited" -lt 1800 ]; do
        sleep 2
        waited=$((waited + 2))
      done

      # Not `status`: read-only in zsh.
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
