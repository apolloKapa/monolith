#!/usr/bin/env bash

source "$SCRIPT_DIR/../caching.sh"

quickshell -p "$MAIN_QML" ipc call theme reloadColors >/dev/null 2>&1 &

# kitty re-reads its config (and the new colors.conf) on SIGUSR1. Its process is "kitty" on
# Arch and Gentoo, ".kitty-wrapped" on NixOS.
pkill -USR1 -x kitty 2>/dev/null
pkill -USR1 -x .kitty-wrapped 2>/dev/null

wait
