#!/usr/bin/env bash
# macOS preference domains, set with `defaults write`. Run by hand:
#
#   ./macos/defaults.sh
#
# Deliberately NOT called by ../install.sh, and not folded into ./bootstrap.sh.
# install.sh is a linker: every effect it has is a symlink, so the repo stays
# the one real copy, --dry-run can name everything it is about to do, and
# undoing it is deleting a link. `defaults write` is the other shape entirely --
# a one-way push into cfprefsd's store, which caches values in memory and
# rewrites the backing plist on its own schedule. There is no link back, nothing
# to preview, and re-running silently reverts whatever you last changed in the
# app's own UI. That is a different promise from the one the first line of the
# README makes, so it gets a different file.
#
# This is also why a preference cannot simply be symlinked like everything else
# here: linking ~/Library/Preferences/<domain>.plist would be overwritten out
# from under us the first time the daemon flushes.
#
# Idempotent -- `defaults write` sets rather than appends -- so re-running is free.

set -euo pipefail

uid="$(id -u)"

# DiscreteScroll -- https://github.com/emreyolcu/discrete-scroll
#
# How many lines one notch of the wheel scrolls. 3 is upstream's own default and
# what the app uses when the key is absent; it is written explicitly so the
# value is visible and versioned rather than implied. Raise it if the jump feels
# short. A negative value inverts the direction.
defaults write com.emreyolcu.DiscreteScroll lines -int 3
echo "com.emreyolcu.DiscreteScroll  lines = $(defaults read com.emreyolcu.DiscreteScroll lines)"

# The agent reads its preferences once, at launch, so the write above changes
# nothing until it restarts. kickstart -k kills and respawns it in place.
# Guarded because the agent may not be bootstrapped yet -- see ./bootstrap.sh.
#
# Do NOT reach for `killall cfprefsd`: the write already went through cfprefsd,
# and killing it costs every other running app its cached preferences for
# nothing.
if launchctl print "gui/$uid/com.emreyolcu.DiscreteScroll" >/dev/null 2>&1; then
    launchctl kickstart -k "gui/$uid/com.emreyolcu.DiscreteScroll"
    echo "  restarted the agent so it picks the value up"
else
    echo "  agent not loaded; run ./macos/bootstrap.sh"
fi

echo
echo "done."
