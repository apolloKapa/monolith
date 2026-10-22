#!/usr/bin/env bash
# "What's this song?" (monolith msg recognize, or the button in the dashboard / island).
# Records ~8 s of what your speakers are playing (not the microphone) and asks Shazam through
# songrec. It sends an audio fingerprint over the internet, so it's off until you turn it on in
# Settings -> General -> Online.
SCRIPT_DIR="$(cd -- "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
source "$SCRIPT_DIR/caching.sh" 2>/dev/null || true
SETTINGS="${QS_SETTINGS:-$HOME/.config/monolith/settings.json}"
APP="Song recognition"

say() { notify-send -a "$APP" -i audio-x-generic "$@"; }

if [ "$(jq -r '.online.songRecognition // false' "$SETTINGS" 2>/dev/null)" != "true" ]; then
    say "Song recognition is off" "It sends an audio fingerprint to Shazam. Turn it on in Settings → General → Online."
    exit 1
fi
command -v songrec >/dev/null || { say "songrec isn't installed" "Install it with: sudo pacman -S songrec"; exit 1; }

tmp="$(mktemp --suffix=.wav)"
trap 'rm -f "$tmp"' EXIT
say -t 8000 "Listening…" "for 8 seconds"
timeout 8 parecord -d @DEFAULT_MONITOR@ --file-format=wav "$tmp" 2>/dev/null

json="$(songrec audio-file-to-recognized-song "$tmp" 2>/dev/null)"
title="$(jq -r '.track.title // empty' <<< "$json" 2>/dev/null)"
artist="$(jq -r '.track.subtitle // empty' <<< "$json" 2>/dev/null)"
if [ -n "$title" ]; then
    say "$title" "$artist"
    printf '%s\n' "$title — $artist"
else
    say "Couldn't recognise the song" "Try again while it's playing louder or clearer."
    exit 1
fi
