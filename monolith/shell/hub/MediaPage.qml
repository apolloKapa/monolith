import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../core"
import "../ui"

// Media, laid out like the old Monolith's player: the album cover blurred behind everything;
// on top the cover, the track, where it plays (output and player), the seek bar and the
// controls; under it three tabs: the equaliser, audio (output, volume, balance) and lyrics.
// Tab switches between them.
Page {
    id: page
    pageId: "media"
    property string view: "eq"
    readonly property real topH: 196
    readonly property real tabH: view === "lyrics" ? 300 : 270
    implicitHeight: topH + 16 + 40 + 12 + tabH

    readonly property var players: Mpris.players.values
    property int chosen: -1
    readonly property var player: players.length === 0 ? null
        : (chosen >= 0 && chosen < players.length ? players[chosen] : (players.find(p => p.isPlaying) || players[0]))
    readonly property string art: player ? (player.trackArtUrl || "") : ""

    // the default output, for the Audio tab and the output chip
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    PwObjectTracker { objects: page.sink ? [page.sink] : [] }

    function fmt(s) {
        if (!isFinite(s) || s < 0) return "0:00";
        s = Math.floor(s);
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }
    // position only updates when asked: tick while shown and playing
    Timer {
        interval: 1000; repeat: true
        running: page.current && HubState.open && !!page.player && page.player.isPlaying
        onTriggered: if (page.player) page.player.positionChanged()
    }
    readonly property var viewIds: ["eq", "audio", "lyrics"]
    Keys.onTabPressed: event => { view = viewIds[(viewIds.indexOf(view) + 1) % 3]; event.accepted = true; }
    Keys.onBacktabPressed: view = viewIds[(viewIds.indexOf(view) + 2) % 3]

    // ── the cover, blurred, behind everything ──
    Rectangle {
        id: backdrop
        anchors.fill: parent
        radius: Theme.corner(80, 12)
        color: Theme.container
        clip: true
        Image {
            id: blurSrc
            anchors.fill: parent
            source: page.art
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(256, 256)
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: blurSrc
            visible: blurSrc.status === Image.Ready
            blurEnabled: true; blur: 1.0; blurMax: 64
            saturation: 0.2
            opacity: 0.55
        }
        Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.frame, 0.45) }
    }

    // ── top: the cover and the track ──
    Item {
        id: top
        x: 16; y: 16
        width: parent.width - 32
        height: page.topH - 16

        Rectangle {
            id: cover
            width: top.height; height: top.height
            radius: Theme.corner(top.height, 8)
            color: Theme.control
            clip: true
            Icon { anchors.centerIn: parent; name: "music_note"; size: 64; color: Theme.faint; visible: coverImg.status !== Image.Ready }
            Image {
                id: coverImg
                anchors.fill: parent
                source: page.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
                layer.enabled: true
                layer.effect: MultiEffect { maskEnabled: true; maskSource: coverMask }
            }
            Rectangle { id: coverMask; visible: false; width: cover.width; height: cover.height; radius: cover.radius; layer.enabled: true }
        }

        ColumnLayout {
            anchors.left: cover.right; anchors.leftMargin: 18
            anchors.right: parent.right
            height: parent.height
            spacing: 4

            Label {
                Layout.fillWidth: true
                text: page.player ? (page.player.trackTitle || "Unknown track") : "Nothing playing"
                font.pixelSize: Theme.sizeTitle + 6
                strong: true
            }
            Label {
                Layout.fillWidth: true
                text: page.player ? "by " + ([page.player.trackArtist, page.player.trackAlbum].filter(s => s).join("  ·  ") || "unknown artist") : "Play something and it shows here"
                muted: true
            }
            // where it plays: the output (click: the Audio tab) and the player (click: the next one)
            Row {
                Layout.topMargin: 6
                spacing: 6
                Pressable {
                    height: 30; width: outRow.implicitWidth + 22
                    color: Qt.alpha(Theme.containerHigh, 0.85)
                    onClicked: page.view = "audio"
                    Row { id: outRow; anchors.centerIn: parent; spacing: 6
                        Icon { name: "speaker"; size: 16; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: page.sink ? (page.sink.description || page.sink.nickname || page.sink.name) : "No output"; font.pixelSize: Theme.sizeSmall; width: Math.min(implicitWidth, 200); anchors.verticalCenter: parent.verticalCenter } }
                }
                Pressable {
                    visible: !!page.player
                    height: 30; width: srcRow.implicitWidth + 22
                    color: Qt.alpha(Theme.containerHigh, 0.85)
                    onClicked: if (page.players.length > 1) page.chosen = (page.players.indexOf(page.player) + 1) % page.players.length
                    Row { id: srcRow; anchors.centerIn: parent; spacing: 6
                        Icon { name: "apps"; size: 16; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: "via " + (page.player ? (page.player.identity || "a player") : ""); font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                        Icon { visible: page.players.length > 1; name: "swap_horiz"; size: 15; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter } }
                }
            }
            Item { Layout.fillHeight: true }

            // seek
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 16
                opacity: !!page.player && page.player.lengthSupported && page.player.length > 0 ? 1 : 0.35
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: 6; radius: 3
                    color: Qt.alpha(Theme.control, 0.9)
                    Rectangle {
                        width: page.player && page.player.length > 0 ? parent.width * Math.min(1, page.player.position / page.player.length) : 0
                        height: parent.height; radius: 3
                        color: Theme.accent
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => { if (page.player && page.player.canSeek) page.player.position = page.player.length * (mouse.x / width); }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Label { text: page.player ? page.fmt(page.player.position) : "0:00"; muted: true; font.pixelSize: Theme.sizeSmall }
                Item { Layout.fillWidth: true }
                Label { text: page.player ? page.fmt(page.player.length) : "0:00"; muted: true; font.pixelSize: Theme.sizeSmall }
            }

            // controls: shuffle · previous · play · next · repeat
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 8
                Pressable {
                    width: 40; height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    enabledInput: !!page.player && page.player.shuffleSupported
                    color: page.player && page.player.shuffle ? Theme.accentContainer : "transparent"
                    onClicked: page.player.shuffle = !page.player.shuffle
                    Icon { anchors.centerIn: parent; name: "shuffle"; size: 20; color: page.player && page.player.shuffle ? Theme.onAccentContainer : Theme.subtext }
                }
                Pressable {
                    width: 46; height: 46
                    anchors.verticalCenter: parent.verticalCenter
                    enabledInput: !!page.player && page.player.canGoPrevious
                    onClicked: page.player.previous()
                    Icon { anchors.centerIn: parent; name: "skip_previous"; size: 26; filled: true }
                }
                Pressable {
                    width: 76; height: 50
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent; ink: Theme.onAccent
                    enabledInput: !!page.player
                    onClicked: page.player.togglePlaying()
                    Icon { anchors.centerIn: parent; name: page.player && page.player.isPlaying ? "pause" : "play_arrow"; size: 30; filled: true; color: Theme.onAccent }
                }
                Pressable {
                    width: 46; height: 46
                    anchors.verticalCenter: parent.verticalCenter
                    enabledInput: !!page.player && page.player.canGoNext
                    onClicked: page.player.next()
                    Icon { anchors.centerIn: parent; name: "skip_next"; size: 26; filled: true }
                }
                Pressable {
                    readonly property bool on: !!page.player && page.player.loopState !== MprisLoopState.None
                    width: 40; height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    enabledInput: !!page.player && page.player.loopSupported
                    color: on ? Theme.accentContainer : "transparent"
                    onClicked: page.player.loopState = page.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                        : (page.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
                    Icon { anchors.centerIn: parent; name: page.player && page.player.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"; size: 20; color: parent.on ? Theme.onAccentContainer : Theme.subtext }
                }
            }
        }
    }

    // ── the tabs ──
    Segmented {
        id: tabs
        x: 16; y: page.topH + 16
        width: parent.width - 32; height: 40
        opts: [["eq", "Equaliser"], ["audio", "Audio"], ["lyrics", "Lyrics"]]
        value: page.view
        onPicked: v => page.view = v
    }
    Item {
        id: body
        x: 16; y: tabs.y + tabs.height + 12
        width: parent.width - 32
        height: page.tabH - 16

        // ── equaliser: on/off, presets, ten bands ──
        Item {
            anchors.fill: parent
            visible: page.view === "eq"
            RowLayout {
                id: eqHead
                width: parent.width
                height: 34
                spacing: 6
                Toggle { checked: Eq.enabled; onToggled: on => Eq.setEnabled(on) }
                Label { text: Eq.enabled ? "On" : "Off"; muted: !Eq.enabled; Layout.leftMargin: 4; Layout.rightMargin: 8 }
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 32
                    contentWidth: presetRow.implicitWidth
                    clip: true
                    SmoothWheel { horizontal: true }
                    Row {
                        id: presetRow
                        spacing: 6
                        Repeater {
                            model: Object.keys(Eq.presets)
                            Pressable {
                                required property string modelData
                                height: 32
                                width: pl.implicitWidth + 22
                                color: Eq.preset === modelData ? Theme.accentContainer : Qt.alpha(Theme.containerHigh, 0.85)
                                onClicked: Eq.usePreset(modelData)
                                Label { id: pl; anchors.centerIn: parent; text: modelData; font.pixelSize: Theme.sizeSmall; strong: Eq.preset === modelData; color: Eq.preset === modelData ? Theme.onAccentContainer : Theme.text }
                            }
                        }
                    }
                }
            }
            Row {
                y: eqHead.height + 14
                width: parent.width
                height: parent.height - y
                Repeater {
                    model: 10
                    Item {
                        id: bandItem
                        required property int index
                        width: parent.width / 10
                        height: parent.height
                        readonly property real g: Eq.gains[index] || 0
                        opacity: Eq.enabled ? 1 : 0.5
                        Rectangle {
                            id: track
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 32
                            height: parent.height - 44
                            radius: Theme.corner(width)
                            color: Qt.alpha(Theme.control, 0.9)
                            // the fill grows from the middle (0 dB) up or down
                            Rectangle {
                                width: parent.width
                                radius: parent.radius
                                color: Theme.accent
                                readonly property real mid: track.height / 2
                                readonly property real off: Math.abs(bandItem.g) / 12 * mid
                                y: bandItem.g >= 0 ? mid - off : mid
                                height: Math.max(4, off)
                                Behavior on y { NumberAnimation { duration: 160 } }
                                Behavior on height { NumberAnimation { duration: 160 } }
                            }
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 1; color: Theme.faint }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                function set(y) { Eq.setBand(bandItem.index, (track.height / 2 - y) / (track.height / 2) * 12); }
                                onPressed: mouse => set(mouse.y)
                                onPositionChanged: mouse => { if (pressed) set(mouse.y); }
                                onWheel: wheel => Eq.setBand(bandItem.index, bandItem.g + (wheel.angleDelta.y > 0 ? 0.5 : -0.5))
                            }
                        }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; y: track.height + 4; text: (bandItem.g > 0 ? "+" : "") + bandItem.g; font.pixelSize: Theme.sizeSmall; strong: true }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; y: track.height + 22; text: Eq.freqs[bandItem.index] >= 1000 ? (Eq.freqs[bandItem.index] / 1000) + "k" : Eq.freqs[bandItem.index]; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                    }
                }
            }
        }

        // ── audio: output, volume, balance, the player's own volume ──
        Column {
            anchors.fill: parent
            visible: page.view === "audio"
            spacing: 14
            readonly property var vols: page.sink && page.sink.audio ? page.sink.audio.volumes : []
            // balance from the two channels' volumes: -1 all left .. 1 all right
            readonly property real balance: vols.length >= 2 && Math.max(vols[0], vols[1]) > 0 ? (vols[1] - vols[0]) / Math.max(vols[0], vols[1]) : 0
            function setBalance(b) {
                if (!page.sink || !page.sink.audio || vols.length < 2) return;
                const v = page.sink.audio.volume;
                const l = v * (b > 0 ? 1 - b : 1), r = v * (b < 0 ? 1 + b : 1);
                page.sink.audio.volumes = vols.map((x, i) => i % 2 === 0 ? l : r);
            }
            Row {
                spacing: 10
                Label { text: "Output"; strong: true; width: 90; anchors.verticalCenter: parent.verticalCenter }
                Dropdown {
                    width: body.width - 100
                    opts: page.outputs.map(n => [n.name, n.description || n.nickname || n.name])
                    value: page.sink ? page.sink.name : ""
                    onPicked: v => { const n = page.outputs.find(x => x.name === v); if (n) Pipewire.preferredDefaultAudioSink = n; }
                }
            }
            Row {
                spacing: 10
                Label { text: "Volume"; strong: true; width: 90; anchors.verticalCenter: parent.verticalCenter }
                Slider {
                    width: body.width - 100; implicitHeight: 34
                    icon: page.sink && page.sink.audio && page.sink.audio.muted ? "volume_off" : "volume_up"
                    muted: !!page.sink && !!page.sink.audio && page.sink.audio.muted
                    value: page.sink && page.sink.audio ? page.sink.audio.volume : 0
                    onMoved: v => { if (page.sink && page.sink.audio) { page.sink.audio.muted = false; page.sink.audio.volume = v; } }
                    onIconClicked: if (page.sink && page.sink.audio) page.sink.audio.muted = !page.sink.audio.muted
                }
            }
            Row {
                spacing: 10
                Label { text: "Balance"; strong: true; width: 90; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    width: body.width - 100
                    spacing: 2
                    Slider {
                        width: parent.width; implicitHeight: 34
                        icon: "balance"
                        value: (parent.parent.parent.balance + 1) / 2
                        onMoved: v => parent.parent.parent.setBalance(Math.abs(v - 0.5) < 0.03 ? 0 : v * 2 - 1)
                        onIconClicked: parent.parent.parent.setBalance(0)
                    }
                    Item {
                        width: parent.width; height: 16
                        Label { text: "Left"; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: Math.abs(parent.parent.parent.parent.balance) < 0.02 ? "Centre" : Math.round(Math.abs(parent.parent.parent.parent.balance) * 100) + "% " + (parent.parent.parent.parent.balance < 0 ? "left" : "right"); font.pixelSize: Theme.sizeSmall - 1; strong: true }
                        Label { anchors.right: parent.right; text: "Right"; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                    }
                }
            }
            Row {
                visible: !!page.player && page.player.volumeSupported
                spacing: 10
                Label { text: page.player ? (page.player.identity || "Player") : ""; strong: true; width: 90; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
                Slider {
                    width: body.width - 100; implicitHeight: 34
                    icon: "music_note"
                    value: page.player ? page.player.volume : 0
                    onMoved: v => { if (page.player) page.player.volume = v; }
                }
            }
        }

        // ── lyrics: the current line big and bright, the rest fading out ──
        ListView {
            id: lyricList
            SmoothWheel {}
            anchors.fill: parent
            visible: page.view === "lyrics" && !!page.player && Lyrics.lines.length > 0
            clip: true
            model: Lyrics.lines.length > 0 ? Lyrics.lines : []
            currentIndex: Lyrics.currentIndex
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: height * 0.38
            preferredHighlightEnd: height * 0.5
            highlightMoveDuration: 500
            interactive: false
            delegate: Label {
                required property var modelData
                required property int index
                readonly property int dist: Math.abs(index - Lyrics.currentIndex)
                width: lyricList.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: modelData.text === "" ? "♪" : modelData.text
                font.pixelSize: dist === 0 ? 22 : 16
                strong: dist === 0
                color: dist === 0 ? Theme.text : Theme.subtext
                opacity: Math.max(0.25, 1 - dist * 0.18)
                topPadding: 6
                bottomPadding: 6
                Behavior on font.pixelSize { NumberAnimation { duration: 260 } }
                Behavior on opacity { NumberAnimation { duration: 260 } }
            }
        }
        Flickable {
            SmoothWheel {}
            anchors.fill: parent
            visible: page.view === "lyrics" && (!page.player || Lyrics.lines.length === 0)
            contentHeight: plainText.implicitHeight
            clip: true
            Label {
                id: plainText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: !page.player ? "Play something to see its lyrics" : (Lyrics.state === "loading" ? "Looking for lyrics…" : (Lyrics.plain !== "" ? Lyrics.plain : "No lyrics found for this song"))
                muted: Lyrics.plain === ""
                topPadding: 40
            }
        }
    }
}
