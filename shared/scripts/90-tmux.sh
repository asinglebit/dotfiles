# Auto-start tmux: every terminal attaches a fresh session sharing `main`'s
# windows, so each is a different view of one workspace. The -t 1 guard keeps
# non-interactive tooling, which has a piped stdout, out of tmux.
if command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" && -z "$NVIM" && -t 1 ]]; then
    if ! tmux has-session -t main 2>/dev/null; then
        tmux new-session -d -s main
    fi

    new_name="dev_$(date +%Y%m%d_%H%M%S)"
    tmux new-session -d -t main -s "$new_name"
    tmux new-window -t "$new_name" -n "work"

    # Reap this session when its terminal closes. Set from a hook rather than
    # directly: `destroy-unattached on` applies at once and would kill this
    # still-detached session before the attach below reaches it. `main` never
    # gets it, so it survives as the anchor.
    tmux set-hook -t "$new_name" client-attached \
        "set-option -t '$new_name' destroy-unattached on"

    # `&& exit`, not `exec`: if tmux cannot start (usually a bad $TERM), exec
    # has already replaced the shell and the terminal dies with no prompt.
    tmux attach -t "$new_name" && exit
fi
