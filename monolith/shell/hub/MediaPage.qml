import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../core"
import "../ui"

// Media: the current player (art, title, seek, controls) and the other players as chips.
Page {
    id: page
    pageId: "media"
    property string view: "player"
    readonly property real bodyH: view === "player" ? 236 : (view === "lyrics" ? 400 : 330)
    implicitHeight: 48 + bodyH

    readonly property var players: Mpris.players.values
    property int chosen: -1
    readonly property var player: players.length === 0 ? null
        : (chosen >= 0 && chosen < players.length ? players[chosen] : (players.find(p => p.isPlaying) || players[0]))

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

    // Player · Lyrics · Equaliser
    Rectangle {
        id: views
        width: 360
        height: 40
        radius: Theme.corner(height)
        color: Theme.container
        readonly property var opts: [["player", "Player", "play_circle"], ["lyrics", "Lyrics", "lyrics"], ["eq", "Equaliser", "equalizer"]]
        Rectangle {
            y: 4
            x: 4 + views.opts.findIndex(o => o[0] === page.view) * ((views.width - 8) / 3)
            width: (views.width - 8) / 3
            height: views.height - 8
            radius: Theme.corner(height)
            color: Theme.selected
            Behavior on x { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        }
        Row {
            anchors.fill: parent
            anchors.margins: 4
            Repeater {
                model: views.opts
                Pressable {
                    required property var modelData
                    width: parent.width / 3
                    height: parent.height
                    color: "transparent"
                    onClicked: page.view = modelData[0]
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { name: modelData[2]; size: 18; filled: page.view === modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: modelData[1]; font.pixelSize: Theme.sizeSmall; strong: page.view === modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }

    Label {
        anchors.horizontalCenter: parent.horizontalCenter
        y: 48 + 90
        visible: !page.player && page.view !== "eq"
        text: "Nothing is playing"
        muted: true
    }

    // ── lyrics: the current line big and bright, the rest fading out ──
    ListView {
        id: lyricList
        visible: page.view === "lyrics" && !!page.player
        y: 48
        width: parent.width
        height: page.bodyH
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
        visible: page.view === "lyrics" && !!page.player && Lyrics.lines.length === 0
        y: 48
        width: parent.width
        height: page.bodyH
        contentHeight: plainText.implicitHeight
        clip: true
        Label {
            id: plainText
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: Lyrics.state === "loading" ? "Looking for lyrics…" : (Lyrics.plain !== "" ? Lyrics.plain : "No lyrics found for this song")
            muted: Lyrics.plain === ""
            topPadding: 40
        }
    }

    // ── equaliser: ten vertical sliders, presets, on/off ──
    Item {
        visible: page.view === "eq"
        y: 48
        width: parent.width
        height: page.bodyH
        RowLayout {
            id: eqHead
            width: parent.width
            height: 40
            Toggle { checked: Eq.enabled; onToggled: on => Eq.setEnabled(on) }
            Label { text: Eq.enabled ? "On (EasyEffects)" : "Off"; muted: !Eq.enabled; Layout.leftMargin: 6 }
            Item { Layout.fillWidth: true }
            Repeater {
                model: Object.keys(Eq.presets)
                Pressable {
                    required property string modelData
                    Layout.preferredHeight: 32
                    Layout.preferredWidth: pl.implicitWidth + 20
                    color: Eq.preset === modelData ? Theme.selected : Theme.containerHigh
                    onClicked: Eq.usePreset(modelData)
                    Label { id: pl; anchors.centerIn: parent; text: modelData; font.pixelSize: Theme.sizeSmall; strong: Eq.preset === modelData }
                }
            }
        }
        Row {
            y: eqHead.height + 12
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
                        y: 0
                        width: 34
                        height: parent.height - 50
                        radius: Theme.corner(width)
                        color: Theme.control
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
                    Label { anchors.horizontalCenter: parent.horizontalCenter; y: track.height + 6; text: (bandItem.g > 0 ? "+" : "") + bandItem.g; font.pixelSize: Theme.sizeSmall; strong: true }
                    Label { anchors.horizontalCenter: parent.horizontalCenter; y: track.height + 24; text: Eq.freqs[bandItem.index] >= 1000 ? (Eq.freqs[bandItem.index] / 1000) + "k" : Eq.freqs[bandItem.index]; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                }
            }
        }
    }

    RowLayout {
        visible: !!page.player && page.view === "player"
        y: 48
        width: parent.width
        height: page.bodyH
        spacing: 16

        // the art, or a tonal square with a note
        Rectangle {
            Layout.preferredWidth: page.bodyH
            Layout.preferredHeight: page.bodyH
            radius: Theme.corner(page.bodyH, 6)
            color: Theme.container
            clip: true
            Icon { anchors.centerIn: parent; name: "music_note"; size: 56; color: Theme.faint; visible: art.status !== Image.Ready }
            Image {
                id: art
                anchors.fill: parent
                source: page.player ? (page.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: status === Image.Ready
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6

            Row {
                spacing: 6
                Repeater {
                    model: page.players
                    Pressable {
                        required property var modelData
                        required property int index
                        height: 28
                        width: chipLabel.implicitWidth + 24
                        color: modelData === page.player ? Theme.selected : Theme.containerHigh
                        onClicked: page.chosen = index
                        Label { id: chipLabel; anchors.centerIn: parent; text: modelData.identity || "Player"; font.pixelSize: Theme.sizeSmall }
                    }
                }
            }
            Item { Layout.fillHeight: true }
            Label {
                Layout.fillWidth: true
                text: page.player ? (page.player.trackTitle || "Unknown track") : ""
                font.pixelSize: Theme.sizeTitle + 4
                strong: true
            }
            Label {
                Layout.fillWidth: true
                text: page.player ? [page.player.trackArtist, page.player.trackAlbum].filter(s => s).join("  ·  ") : ""
                muted: true
            }
            Item { Layout.preferredHeight: 6 }

            // seek: a thin track with an accent fill
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                visible: !!page.player && page.player.lengthSupported && page.player.length > 0
                Rectangle {
                    id: seekTrack
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: Theme.control
                    Rectangle {
                        width: page.player && page.player.length > 0 ? parent.width * Math.min(1, page.player.position / page.player.length) : 0
                        height: parent.height
                        radius: 3
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
                Label { text: page.player ? page.fmt(page.player.position) : ""; muted: true; font.pixelSize: Theme.sizeSmall }
                Item { Layout.fillWidth: true }
                Label { text: page.player ? page.fmt(page.player.length) : ""; muted: true; font.pixelSize: Theme.sizeSmall }
            }

            RowLayout {
                spacing: 8
                Pressable {
                    Layout.preferredWidth: 48; Layout.preferredHeight: 48
                    enabledInput: !!page.player && page.player.canGoPrevious
                    onClicked: page.player.previous()
                    Icon { anchors.centerIn: parent; name: "skip_previous"; size: 24; filled: true }
                }
                Pressable {
                    Layout.preferredWidth: 72; Layout.preferredHeight: 48
                    color: Theme.accent
                    ink: Theme.onAccent
                    onClicked: page.player.togglePlaying()
                    Icon { anchors.centerIn: parent; name: page.player && page.player.isPlaying ? "pause" : "play_arrow"; size: 28; filled: true; color: Theme.onAccent }
                }
                Pressable {
                    Layout.preferredWidth: 48; Layout.preferredHeight: 48
                    enabledInput: !!page.player && page.player.canGoNext
                    onClicked: page.player.next()
                    Icon { anchors.centerIn: parent; name: "skip_next"; size: 24; filled: true }
                }
            }
        }
    }
}
