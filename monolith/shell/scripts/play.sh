#!/bin/sh
# Plays a sound when Qt's own audio (core/Sounds.qml) can't: the first player this system has.
#   play.sh VOLUME FILE [FALLBACK]   VOLUME 0..1; FALLBACK is played when FILE isn't there
#                                    (the freedesktop sound theme isn't installed everywhere)
#   play.sh which                    prints the player it would use, or nothing
v="$1"; f="$2"
pick() {
    for p in pw-play paplay ffplay aplay; do command -v "$p" >/dev/null 2>&1 && { echo "$p"; return; }; done
}
[ "$1" = which ] && { pick; exit 0; }
[ -f "$f" ] || f="$3"
[ -n "$f" ] && [ -f "$f" ] || exit 1
case "$(pick)" in
    pw-play) exec pw-play --media-role Notification --volume "$v" -P '{ "application.name": "Monolith sounds", "media.role": "event" }' "$f" ;;
    paplay)  exec paplay --volume="$(awk -v v="$v" 'BEGIN{printf "%d", v * 65536}')" --property=media.role=event --client-name="Monolith sounds" "$f" ;;
    ffplay)  exec ffplay -nodisp -autoexit -loglevel quiet -volume "$(awk -v v="$v" 'BEGIN{printf "%d", v * 100}')" "$f" ;;
    aplay)   exec aplay -q "$f" ;;
esac
exit 1
