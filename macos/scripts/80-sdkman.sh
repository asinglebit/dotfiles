# SDKMAN -- the JVM toolchain: java, gradle, maven. Not redundant with mise,
# which owns go, node, pnpm, rust and godot and no JVM tool at all. If a JVM
# ever moves to mise, this file is what gets deleted.
#
# Numbered 80 because sdkman-init.sh PREPENDS its candidates to PATH, so
# anything that rebuilds PATH afterwards takes java away from it -- as late as
# possible, but never after 90-tmux.sh. The README has both halves of that.
#
# macOS-only because SDKMAN is only installed here: the Linux side has no
# counterpart rather than a different one.
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
