#!/usr/bin/env bash
# One-time macOS setup that cannot be expressed as a symlink.
#
#   ./macos/bootstrap.sh
#
# Run it AFTER ../install.sh, which is what puts the LaunchAgent plist in
# ~/Library/LaunchAgents. install.sh is only a linker: every effect it has is a
# symlink, so the repo stays the one real copy, --dry-run can name everything
# it is about to do, and undoing it is deleting a link. Installing an app into
# /Applications and bootstrapping a launchd job are neither of those shapes, so
# they live here instead of being smuggled into the linker.
#
# Idempotent. Re-running replaces the app and reloads the job.
#
# See also ./defaults.sh, which pushes preference-domain values and is likewise
# deliberately separate.

set -euo pipefail

os_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
uid="$(id -u)"

# ---------------------------------------------------------------- DiscreteScroll
#
# macOS applies smooth, accelerated scrolling to every wheel event, which is
# right for a trackpad and wrong for a notched wheel. DiscreteScroll intercepts
# the events and turns each notch back into a fixed jump.
#
# The app is vendored in macos/apps/ rather than fetched, because Homebrew's
# `discretescroll` cask is disabled upstream and the only other source is a
# GitHub release zip that may not outlive the project. It is 172K and MIT.
#
# COPIED into /Applications, not symlinked, and this is the whole point of the
# exercise: an app run from ~/Downloads with the quarantine flag still set gets
# App Translocation, so macOS executes it from a randomised read-only path under
# /private/var/folders. The Accessibility (TCC) grant is keyed to the path it
# resolves to, so it breaks every time that randomised path changes and the app
# has to be re-approved by hand. A de-quarantined copy at a stable path in
# /Applications is what stops that.
app_src="$os_dir/apps/DiscreteScroll.app"
app_dst="/Applications/DiscreteScroll.app"

if [ -d "$app_src" ]; then
    echo "DiscreteScroll:"
    if [ -e "$app_dst" ]; then
        rm -rf -- "$app_dst"
        echo "  removed    previous $app_dst"
    fi
    # /Applications is group-writable by admin, so this needs no sudo.
    cp -R "$app_src" "$app_dst"
    echo "  installed  $app_dst"

    # Strip the quarantine flag, the thing that triggers translocation. The app
    # is ad-hoc signed with no Developer ID and is not notarized, so Gatekeeper
    # would otherwise refuse or translocate it.
    xattr -dr com.apple.quarantine "$app_dst" 2>/dev/null || true
    echo "  cleared    com.apple.quarantine"
else
    echo "DiscreteScroll: $app_src missing -- skipping" >&2
fi

# ------------------------------------------------------------------ LaunchAgent
#
# launchd reads the plist once, at bootstrap, so the symlink install.sh made is
# not by itself a deployment: this is the step that actually loads it, and the
# step to repeat after editing the plist.
label="com.emreyolcu.DiscreteScroll"
plist="$HOME/Library/LaunchAgents/$label.plist"

echo "launchd:"
if [ ! -e "$plist" ]; then
    echo "  $plist missing -- run ./install.sh first" >&2
    exit 1
fi

# bootout first so re-running reloads rather than failing on "service already
# loaded". It fails when nothing is loaded, which is the normal first-run case,
# hence the guard.
launchctl bootout "gui/$uid/$label" 2>/dev/null || true
launchctl bootstrap "gui/$uid" "$plist"
echo "  bootstrapped  $label"

echo
echo "done."
echo
echo "Two things still need you, and cannot be scripted:"
echo "  1. System Settings > Privacy & Security > Accessibility -- allow DiscreteScroll."
echo "     The TCC database is SIP-protected; nothing can grant this for you."
echo "  2. System Settings > General > Login Items & Extensions -- allow the agent"
echo "     in the background. macOS 13+ requires this one-time approval before a"
echo "     LaunchAgent will start at login."
