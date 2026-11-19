pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Synced lyrics for what's playing, with the line that's being sung now. Looked up when the track
// changes: a lyrics file you picked for this song before (pickFile), else an .lrc next to the
// playing file, else LRCLIB (lrclib.net).
Singleton {
    id: ly
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || (Mpris.players.values.length > 0 ? Mpris.players.values[0] : null)
    readonly property string key: player ? (player.trackArtist + "\u0001" + player.trackTitle) : ""
    property var lines: []          // [{ t: seconds, text }]
    property string plain: ""
    property string state: "none"   // none | loading | ok | missing
    // Where the song is, for the lines: counted on ten times a second from the last time the
    // player was asked, and the player is asked itself (its Position, over D-Bus) every few
    // seconds while lyrics show. It was player.position, which is only worked out again when
    // something asks for it (a progress bar somewhere, once a second), so a line could come up
    // to a second late, and it's counted on from the last seek or track change, so it drifted
    // from the music when a song started a moment late or stalled.
    property real base: 0       // seconds, at `baseAt`
    property real baseAt: 0
    property real now: 0
    property real seenPos: 0    // the player's own position the last time it said, and when
    property real seenAt: 0
    readonly property bool timing: !!player && lines.length > 0
    function fromPlayer() {
        if (!player) { now = 0; return; }
        player.positionChanged();
        base = player.position; baseAt = Date.now(); now = base;
        seenPos = base; seenAt = baseAt;
    }
    function ask() {
        if (!player || !player.dbusName || truth.running) return;
        truth.t0 = Date.now();
        truth.command = ["sh", "-c", "busctl --user get-property \"$1\" /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player Position 2>/dev/null"
            + " || gdbus call --session --dest \"$1\" --object-path /org/mpris/MediaPlayer2 --method org.freedesktop.DBus.Properties.Get org.mpris.MediaPlayer2.Player Position 2>/dev/null", "_", player.dbusName];
        truth.running = true;
    }
    Process {
        id: truth
        property real t0: 0
        stdout: StdioCollector {
            onStreamFinished: {
                // "x 249620000" (busctl) or "(<int64 249620000>,)" (gdbus): microseconds
                const m = text.match(/(-?\d+)\D*$/);
                if (!m || !ly.player) return;
                const p = Number(m[1]) / 1e6;
                if (!(p >= 0)) return;
                // (asked a moment ago: the answer is from about the middle of the wait)
                ly.base = p; ly.baseAt = (truth.t0 + Date.now()) / 2;
                ly.now = ly.player.isPlaying ? p + (Date.now() - ly.baseAt) / 1000 * (ly.player.rate || 1) : p;
            }
        }
    }
    onPlayerChanged: { fromPlayer(); askSoon.restart(); }
    onTimingChanged: if (timing) { fromPlayer(); ask(); }
    Connections {
        target: ly.player
        ignoreUnknownSignals: true
        function onPostTrackChanged() { ly.fromPlayer(); askSoon.restart(); }
        function onIsPlayingChanged() { ly.fromPlayer(); askSoon.restart(); }
        // (a seek: the player's own position jumps from where it would have got to by itself.
        // Not compared with ours: the two can differ by more than that, which is the point)
        function onPositionChanged() {
            const p = ly.player.position, t = Date.now();
            const due = ly.seenPos + (ly.player.isPlaying ? (t - ly.seenAt) / 1000 * (ly.player.rate || 1) : 0);
            const jumped = ly.seenAt > 0 && Math.abs(p - due) > 1.5;
            ly.seenPos = p; ly.seenAt = t;
            if (jumped) { ly.base = p; ly.baseAt = t; ly.now = p; askSoon.restart(); }
        }
    }
    // (a track that just changed still answers with the last one's place for a moment)
    Timer { id: askSoon; interval: 700; onTriggered: if (ly.timing) ly.ask() }
    Timer { interval: 4000; repeat: true; running: ly.timing && ly.player.isPlaying; onTriggered: ly.ask() }
    Timer {
        interval: 100; repeat: true
        running: ly.timing && ly.player.isPlaying
        onTriggered: ly.now = ly.base + (Date.now() - ly.baseAt) / 1000 * (ly.player.rate || 1)
    }
    readonly property int currentIndex: {
        if (!player || lines.length === 0) return -1;
        const p = now;
        let i = -1;
        for (let k = 0; k < lines.length; k++) { if (lines[k].t <= p + 0.25) i = k; else break; }
        return i;
    }

    onKeyChanged: fetchLater.restart()
    Timer { id: fetchLater; interval: 400; onTriggered: ly.fetch() }

    // the song's own lyrics file: remembered per song (artist + title)
    function hash(t) { let h = 5381; for (let i = 0; i < t.length; i++) h = ((h * 33) ^ t.charCodeAt(i)) >>> 0; return h.toString(16); }
    readonly property string fileKey: "lyrics.files.k" + hash(key)
    readonly property string pickedFile: key !== "" ? Store.get(fileKey, "") : ""
    readonly property string trackFile: {
        const u = player && player.metadata ? String(player.metadata["xesam:url"] || "") : "";
        return u.startsWith("file://") ? decodeURIComponent(u.slice(7)) : "";
    }
    property bool fromFile: false
    function pickFile() {
        if (key === "") return;
        picker.running = true;
    }
    function forgetFile() { Store.unset(fileKey); fetch(); }
    Process {
        id: picker
        command: ["sh", "-c", "if command -v zenity >/dev/null; then zenity --file-selection --title='Lyrics for this song' --file-filter='Lyrics (.lrc, .txt) | *.lrc *.LRC *.txt' --file-filter='All files | *'; " +
            "elif command -v kdialog >/dev/null; then kdialog --title 'Lyrics for this song' --getopenfilename \"$HOME\" 'Lyrics (*.lrc *.txt)'; " +
            "else notify-send -a Monolith 'No file chooser' 'Install zenity or kdialog to pick a lyrics file'; fi"]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim(); if (p !== "") { Store.set(ly.fileKey, p); ly.fetch(); } } }
    }
    // reads the picked file, else the .lrc beside the song; prints nothing when there's neither
    Process {
        id: local
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") { ly.online(); return; }
                ly.fromFile = true;
                ly.lines = ly.parse(text);
                ly.plain = ly.lines.length > 0 ? "" : text.trim();
                ly.state = "ok";
            }
        }
    }

    function fetch() {
        lines = []; plain = ""; fromFile = false;
        if (!player || !player.trackTitle) { state = "none"; return; }
        state = "loading";
        local.command = ["sh", "-c", "for f in \"$1\" \"${2%.*}.lrc\"; do [ -n \"$f\" ] && [ \"$f\" != .lrc ] && [ -f \"$f\" ] && exec cat \"$f\"; done; true", "_", pickedFile, trackFile];
        local.running = true;
    }
    function online() {
        if (!player) { state = "none"; return; }
        let u = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(player.trackArtist || "")
            + "&track_name=" + encodeURIComponent(player.trackTitle);
        if (player.trackAlbum) u += "&album_name=" + encodeURIComponent(player.trackAlbum);
        if (player.lengthSupported && player.length > 0) u += "&duration=" + Math.round(player.length);
        req.command = ["curl", "-sf", "--max-time", "12", "-A", "monolith (https://github.com/apolloKapa/monolith)", u];
        req.running = true;
    }
    function parse(lrc) {
        const out = [];
        // a line can carry several times ([00:12.00][01:30.00] chorus)
        for (const l of lrc.split("\n")) {
            const times = [];
            let rest = l.trim(), m;
            while ((m = rest.match(/^\[(\d+):(\d+(?:[.:]\d+)?)\]/))) {
                times.push(Number(m[1]) * 60 + Number(m[2].replace(":", ".")));
                rest = rest.slice(m[0].length);
            }
            for (const t of times) out.push({ t: t, text: rest.trim() });
        }
        return out.sort((a, b) => a.t - b.t);
    }
    Process {
        id: req
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    ly.lines = d.syncedLyrics ? ly.parse(d.syncedLyrics) : [];
                    ly.plain = d.plainLyrics || "";
                    ly.state = (ly.lines.length > 0 || ly.plain !== "") ? "ok" : "missing";
                } catch (e) { ly.state = "missing"; }
            }
        }
        onExited: code => { if (code !== 0) ly.state = "missing"; }
    }
}
