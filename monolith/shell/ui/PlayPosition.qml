import QtQuick

// A playing track's position that moves every frame: the player only reports it when asked
// (about once a second here), so in between it's counted on from the last report. `shown` is
// what to draw; seek with the player as usual.
Item {
    id: pp
    property var player: null
    property bool active: true
    property real pos: 0
    property real at: 0
    property real shown: 0
    readonly property real len: player && player.lengthSupported ? player.length : 0
    function sync() { if (player) { player.positionChanged(); pos = player.position; at = Date.now(); shown = pos; } else shown = 0; }
    onPlayerChanged: sync()
    Connections { target: pp.player; ignoreUnknownSignals: true; function onPostTrackChanged() { pp.sync(); } function onIsPlayingChanged() { pp.sync(); } function onPositionChanged() { if (Math.abs(pp.player.position - pp.shown) > 1.5) { pp.pos = pp.player.position; pp.at = Date.now(); } } }
    Timer { interval: 1000; repeat: true; running: pp.active && !!pp.player; triggeredOnStart: true; onTriggered: pp.sync() }
    FrameAnimation {
        running: pp.active && !!pp.player && pp.player.isPlaying
        onTriggered: pp.shown = Math.min(pp.len > 0 ? pp.len : 1e9, pp.pos + (Date.now() - pp.at) / 1000)
    }
}
