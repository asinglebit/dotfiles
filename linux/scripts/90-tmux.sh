# Auto-start tmux: attach a fresh session that shares the `main` session's
# windows, so every terminal is a different view of one workspace.
#
# Guards: tmux installed, not already inside tmux, not nvim's :terminal, and
# stdout is a tty. The tty check is what keeps non-interactive tooling -- which
# sources this file but has a piped stdout -- from being exec'd into tmux.
if command -v tmux >/dev/null 2>&1 && [[ -z "$TMUX" && -z "$NVIM" && -t 1 ]]; then
    if ! tmux has-session -t main 2>/dev/null; then
        tmux new-session -d -s main
    fi

    new_name="dev_$(date +%Y%m%d_%H%M%S)"
    tmux new-session -d -t main -s "$new_name"
    tmux new-window -t "$new_name" -n "work"

    # Reap this session when its terminal closes, so opening and closing
    # terminals does not pile up detached dev_* sessions.
    #
    # Set from a client-attached hook rather than directly: `destroy-unattached
    # on` takes effect the moment it is set, so setting it here -- while the
    # session is still detached -- destroys the session before the attach below
    # can reach it, and a failed `exec` closes the terminal. The hook defers it
    # to the instant a client is actually attached.
    #
    # `main` never gets the option, so it survives as the anchor that holds the
    # shared windows.
    tmux set-hook -t "$new_name" client-attached \
        "set-option -t '$new_name' destroy-unattached on"

    # `&& exit` rather than `exec`: if tmux cannot start -- an unusable $TERM is
    # the common case -- exec has already replaced the shell, so the terminal
    # dies with no prompt to recover from. This falls through to a plain shell
    # instead, and still closes the terminal on a normal detach.
    tmux attach -t "$new_name" && exit
fi
