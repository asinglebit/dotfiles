# SDKMAN -- the JVM toolchain: java, gradle, maven.
#
# Not redundant with mise, which is the obvious question to ask. mise owns go,
# node, pnpm, rust and godot (see shared/config/mise/config.toml) and no JVM
# tool at all, so nothing here overlaps. If a JVM ever moves to mise, this file
# is what gets deleted.
#
# Numbered 80, and the number matters in both directions. The old monolithic
# .zshrc carried the line "THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO
# WORK": sdkman-init.sh PREPENDS its candidates to PATH, so anything that
# rebuilds PATH afterwards takes java away from it. Hence as late as possible.
# But not last: 90-tmux.sh ends in `tmux attach && exit`, so nothing sorted
# after it runs in the outer shell at all.
#
# There is no macOS/Linux divergence here yet -- SDKMAN is only installed on
# this Mac, so the Linux side has no counterpart rather than a different one.
export SDKMAN_DIR="$HOME/.sdkman"
[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ] && . "$SDKMAN_DIR/bin/sdkman-init.sh"
