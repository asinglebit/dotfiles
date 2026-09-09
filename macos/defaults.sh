#!/usr/bin/env bash
# macOS preference domains, set with `defaults write`. Run by hand:
#
#   ./macos/defaults.sh
#
# Deliberately not called by ../install.sh and not folded into ./bootstrap.sh: a
# `defaults write` is a one-way push into cfprefsd's store rather than a symlink,
# so there is nothing to preview and nothing to undo by deleting a link. The
# README's "defaults is a push, not a link" note has the rest, including why a
# preference cannot be symlinked at all.
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
# nothing until it restarts. Guarded because it may not be bootstrapped yet --
# see ./bootstrap.sh. Not `killall cfprefsd`: the write already went through it,
# and killing it would cost every other running app its cached preferences.
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
# Chrome is deliberately not in that table, and the line it would have does
# nothing: it sits at ~10pt with the key set in its own domain and having
# launched after the write. Chromium draws its own window frame rather than
# taking AppKit's, so the read never happens in that process. The README carries
# the measurements -- do not re-add it.
#
# Undocumented: in none of Apple's headers, so nothing obliges a future system
# update to keep honouring it. If the corners go round again after one, this is
# the first line to re-check. `-float` is the type the key is read as.
#
# No `kickstart` pairs with this the way DiscreteScroll's does above -- there is
# no one agent to restart, so each app takes the value at its next launch and
# logging out is how to catch all of them at once.
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
