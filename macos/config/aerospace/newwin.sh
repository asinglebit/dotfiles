#!/usr/bin/env bash
# Open a NEW window of an app, even when that app is already running.
#
# macOS has no generic "give me another window" verb. Launching an app that is
# already up -- Spotlight, the Dock, plain `open -a` -- sends it a "reopen"
# Apple Event, and every app here answers that by raising the windows it
# already owns. Under a tiling WM that is actively wrong: instead of a fresh
# window on the workspace you are looking at, you get yanked to whichever
# workspace the old window happens to live on. So each app needs its own poke.
#
# Two mechanisms, chosen per app by what was actually observed to work:
#
#   open -a <app> <dir>   A LaunchServices "open document" event. Needs no
#                         Automation permission, costs ~2s. Terminal.app reads
#                         a folder as "new window, cd'd here". iTerm2 does not
#                         -- it silently no-ops -- so this is Terminal-only.
#
#   osascript             A direct Apple Event, ~0.2s. Needs a one-time
#                         Automation grant for whatever runs this script (that
#                         is AeroSpace, once these are bound to keys, NOT the
#                         terminal you are testing from). Used for iTerm2,
#                         Finder and Chrome, where speed is worth the grant.
#
# Cold start is deliberately never AppleScript. Sending an Apple Event to a
# non-running app launches it and then blocks on delivering the event, and that
# block sits behind the Automation consent dialog -- which is modal, easy to
# miss under a tiling WM, and will hang this script until someone answers it.
# `open -a` launches without any of that, and an app opens its own first window
# on launch anyway, which is exactly what we wanted.

set -eu

app=${1:?usage: newwin.sh <iterm|terminal|finder|chrome> [dir]}
dir=${2:-$HOME}

# -x so the many "Google Chrome Helper" processes do not count as Chrome.
running() { pgrep -x "$1" >/dev/null; }

case "$app" in

    iterm)
        # iTerm2 ignores `open -a iTerm <dir>` (verified: window count does not
        # move), so once it is running AppleScript is the only way in.
        if running iTerm2; then
            osascript -e 'tell application "iTerm" to create window with default profile' \
                      -e 'tell application "iTerm" to activate' >/dev/null
        else
            open -a iTerm
        fi
        ;;

    terminal)
        # Terminal.app opens a folder as a brand new window cd'd into it whether
        # or not it is already running, so one branch covers both -- and it needs
        # no Automation grant at all.
        open -a Terminal "$dir"
        ;;

    finder)
        # `activate` is not cosmetic here. Without it Finder's AppleScript layer
        # reports a stale, empty window list: the new window really is created,
        # but `count`/`close` in the same script cannot see it and silently do
        # nothing. Finder is always running, so there is no cold-start branch.
        osascript - "$dir" >/dev/null <<'OSA'
on run argv
    set p to POSIX file (item 1 of argv) as alias
    tell application "Finder"
        activate
        make new Finder window to p
    end tell
end run
OSA
        ;;

    chrome)
        # AppleScript is ~10x faster than the `open -n` handoff (0.2s vs 2s),
        # which is what you want on a key you hit all day. The fallback covers a
        # missing or denied Automation grant: `open -n` starts a second Chrome
        # process, which finds the existing singleton, hands it --new-window and
        # exits -- so you still end up with exactly one Chrome, just slower.
        if running "Google Chrome"; then
            osascript -e 'tell application "Google Chrome" to make new window' \
                      -e 'tell application "Google Chrome" to activate' >/dev/null 2>&1 \
                || open -na "Google Chrome" --args --new-window
        else
            open -a "Google Chrome"
        fi
        ;;

    *)
        echo "unknown app: $app (want iterm|terminal|finder|chrome)" >&2
        exit 2
        ;;
esac
