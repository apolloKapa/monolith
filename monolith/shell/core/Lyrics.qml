pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Synced lyrics for what's playing, from LRCLIB (lrclib.net): looked up when the track changes,
// with the line that's being sung now.
Singleton {
    id: ly
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || (Mpris.players.values.length > 0 ? Mpris.players.values[0] : null)
    readonly property string key: player ? (player.trackArtist + "\u0001" + player.trackTitle) : ""
    property var lines: []          // [{ t: seconds, text }]
    property string plain: ""
    property string state: "none"   // none | loading | ok | missing
    readonly property int currentIndex: {
        if (!player || lines.length === 0) return -1;
        const p = player.position;
        let i = -1;
        for (let k = 0; k < lines.length; k++) { if (lines[k].t <= p + 0.25) i = k; else break; }
        return i;
    }

    onKeyChanged: fetchLater.restart()
    Timer { id: fetchLater; interval: 400; onTriggered: ly.fetch() }

    function fetch() {
        lines = []; plain = "";
        if (!player || !player.trackTitle) { state = "none"; return; }
        state = "loading";
        let u = "https://lrclib.net/api/get?artist_name=" + encodeURIComponent(player.trackArtist || "")
            + "&track_name=" + encodeURIComponent(player.trackTitle);
        if (player.trackAlbum) u += "&album_name=" + encodeURIComponent(player.trackAlbum);
        if (player.lengthSupported && player.length > 0) u += "&duration=" + Math.round(player.length);
        req.command = ["curl", "-sf", "--max-time", "12", "-A", "monolith (https://github.com/apolloKapa/monolith)", u];
        req.running = true;
    }
    function parse(lrc) {
        const out = [];
        for (const l of lrc.split("\n")) {
            const m = l.match(/^\[(\d+):(\d+(?:\.\d+)?)\]\s*(.*)$/);
            if (m) out.push({ t: Number(m[1]) * 60 + Number(m[2]), text: m[3] });
        }
        return out;
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
