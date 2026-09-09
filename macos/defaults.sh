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

# Window corner radius -- NSConvolutionOverride1, a radius in points
#
# macOS 26 draws window corners much rounder than 15 did, and this is the knob
# that pulls them back. Lower is squarer.
#
# NSGlobalDomain is the floor under every app, and a per-app domain beats it,
# because CFPreferences searches an app's own domain before the global one. So
# the table below reads as "the default, then the exceptions", and singling one
# app out is one more line -- `com.apple.Notes 4`, say.
#
# Chrome is deliberately not in that table, and the line it would have is not
# worth re-adding, because it does nothing. Measured on 26.6.2 by capturing each
# window with `screencapture -o -l <id>` and reading the alpha channel along the
# corner: Finder takes the global 8 and comes out at ~8pt, TextEdit with a
# per-app 2 comes out square, and Chrome sits at ~10pt with
# `com.google.Chrome NSConvolutionOverride1 = 8` set and having launched after
# the write. Chrome's binary references neither this key nor any corner radius
# switch of its own, which fits: Chromium draws its own window frame rather than
# taking AppKit's, so the AppKit read that consults this key never happens in
# that process and no preference domain can reach it.
#
# Undocumented, and that is the caveat worth carrying: the key is in none of
# Apple's headers or docs, so its behaviour is what observation says it is and
# nothing obliges a future system update to keep honouring it. If the corners go
# round again after one, this is the first line to re-check rather than the last.
# The `-float` is deliberate -- it is the type the key is read as.
#
# Nothing here pairs with a `kickstart` the way DiscreteScroll does above. There
# is no one agent to restart: the readers are the apps themselves, and each picks
# the value up the next time it launches. Already-open windows keep their old
# corners until that app is relaunched, so logging out and back in is how to
# catch all of them at once.
while read -r domain radius; do
    [ -n "$domain" ] || continue
    defaults write "$domain" NSConvolutionOverride1 -float "$radius"
    echo "$domain  NSConvolutionOverride1 = $(defaults read "$domain" NSConvolutionOverride1)"
done <<'RADII'
NSGlobalDomain  8
RADII
echo "  relaunch an app, or log out and back in, to see it"

echo
echo "done."
