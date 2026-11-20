pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Smooth sailing (Settings → Animations): when the shell first starts in a session, the bar
// glides in from its edge, the desktop's widgets rise in one after another and the dock comes up
// last, instead of everything being there in the first frame. Only the first start after logging
// in (a mark in the runtime folder, which logging out clears): a reload or a restart of the
// shell doesn't play it again.
// `k` 0 … 1 drives it (linear); piece(a, b) is one part's own eased 0 … 1 over [a, b] of it.
Singleton {
    id: intro
    readonly property bool wanted: Store.get("theme.smoothSailing", false) === true
    readonly property string mark: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/monolith-sailed"
    // (read at once, so nothing shows for a frame before it's known whether to play)
    FileView { id: markFile; path: intro.mark; blockLoading: true; printErrors: false }
    // (worked out once, as it starts: tied to the file, writing the mark undid it on the spot)
    property bool first: false
    property real k: 1
    readonly property bool playing: k < 1
    function piece(a, b) {
        const t = Math.max(0, Math.min(1, (k - a) / (b - a)));
        return 1 - Math.pow(1 - t, 3);
    }
    // the parts: the bar, then the widgets (each a little after the last), then the dock
    readonly property real barK: piece(0, 0.45)
    function widgetK(i) { const j = Math.min(6, Math.max(0, i)); return piece(0.25 + j * 0.07, 0.7 + j * 0.05); }
    readonly property real dockK: piece(0.5, 1)

    NumberAnimation { id: sail; target: intro; property: "k"; from: 0; to: 1; duration: Math.max(600, Theme.ms(1800)); easing.type: Easing.Linear }
    // (a moment after starting: the wallpaper is up first, and the first frames are slow)
    Timer { id: wait; interval: 450; onTriggered: sail.start() }
    function decide() {
        if (!first || k >= 1 || sail.running || wait.running) return;
        markFile.setText(String(Date.now()));
        if (wanted && Theme.animOn && !GameMode.lean) wait.start(); else k = 1;
    }
    Component.onCompleted: {
        first = markFile.text() === "";
        if (first) k = 0;
        if (Store.loaded) decide();
    }
    Connections { target: Store; function onLoadedChanged() { if (Store.loaded) intro.decide(); } }
    // never stuck hidden
    Timer { interval: 6000; running: intro.first; onTriggered: intro.k = 1 }
}
