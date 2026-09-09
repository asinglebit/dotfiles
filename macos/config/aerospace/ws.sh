#!/usr/bin/env bash
# Per-monitor 1-9 workspaces, i3/sway style.
#
# AeroSpace workspace names are global -- there can only ever be one workspace
# called "1" -- so "workspace 1 on monitor 2" needs a distinct real name.
# Scheme: monitor M owns the block (M-1)*10 + 1..9
#
#     monitor 1  ->   1 ..  9
#     monitor 2  ->  11 .. 19
#     monitor 3  ->  21 .. 29
#
# workspace-to-monitor-force-assignment in the aerospace.toml beside this file
# pins each block to its monitor, so Alt+N never drags focus onto another screen
# -- it only ever changes the monitor you are already looking at.
#
# Undocked, only monitor 1 exists, so Alt+N lands on 1..9 on the laptop and the
# 11..29 blocks fall back onto it (reachable via Alt+Tab / workspace next|prev).

set -eu
action=${1:?usage: ws.sh <switch|move> <1-9>}
digit=${2:?usage: ws.sh <switch|move> <1-9>}

mon=$(aerospace list-monitors --focused --format '%{monitor-id}')
ws=$(( (mon - 1) * 10 + digit ))

case "$action" in
    switch) exec aerospace workspace "$ws" ;;
    move)   exec aerospace move-node-to-workspace --focus-follows-window "$ws" ;;
    *)      echo "unknown action: $action" >&2; exit 2 ;;
esac
