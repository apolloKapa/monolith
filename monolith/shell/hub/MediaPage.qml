import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../core"
import "../ui"
import "../wall/faces" as Faces

// Media, laid out like the old Monolith's player and coloured by what's playing: the cover
// blurred behind everything and its own colour (picked from the art) on the play button, the
// progress, the tabs and the equaliser. On top the cover, the track, where it plays (output
// and player), a progress bar you can drag, and the controls; under it three tabs: the
// equaliser, audio (output, volume, balance) and lyrics. Tab switches between them.
Page {
    id: page
    pageId: "media"
    property string view: "eq"
    readonly property real topH: 210
    readonly property real tabH: 290          // the same for every tab: switching never moves the card
    implicitHeight: player ? topH + 18 + 40 + 14 + tabH : 380

    readonly property var players: Mpris.players.values
    property int chosen: -1
    readonly property var player: players.length === 0 ? null
        : (chosen >= 0 && chosen < players.length ? players[chosen] : (players.find(p => p.isPlaying) || players[0]))
    readonly property string art: player ? (player.trackArtUrl || "") : ""

    // ── the cover's colour: the most colourful of its main colours, made readable ──
    ColorQuantizer { id: cq; source: page.art; depth: 3 }
    readonly property color picked: {
        const cs = cq.colors || [];
        let best = null, score = -1;
        for (const c of cs) {
            const s = c.hsvSaturation * (0.35 + c.hsvValue);
            if (c.hsvValue > 0.25 && s > score) { score = s; best = c; }
        }
        if (!best || best.hsvSaturation < 0.18) return Theme.accent;
        // light enough to stand out on the dark card (dark enough on a light one)
        return Theme.dark ? Qt.hsva(best.hsvHue, Math.min(0.75, best.hsvSaturation), Math.max(0.78, best.hsvValue), 1)
                            : Qt.hsva(best.hsvHue, Math.min(0.85, best.hsvSaturation + 0.1), Math.min(0.5, best.hsvValue), 1);
    }
    // eases into the next track's colour
    property color tone: picked
    Behavior on tone { ColorAnimation { duration: Theme.ms(600); easing.type: Easing.OutCubic } }
    readonly property color onTone: tone.hslLightness > 0.6 ? "#15161a" : "#ffffff"

    // the default output, for the Audio tab and the output chip
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var outputs: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
    PwObjectTracker { objects: page.sink ? [page.sink] : [] }

    function fmt(s) {
        if (!isFinite(s) || s < 0) return "0:00";
        s = Math.floor(s);
        const h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), sec = String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + sec : m + ":" + sec;
    }
    // the position, moving smoothly between the player's (once a second) updates
    property real pos: 0
    property real posAt: 0
    readonly property real len: player && player.lengthSupported ? player.length : 0
    function syncPos() { if (player) { player.positionChanged(); pos = player.position; posAt = Date.now(); } }
    onPlayerChanged: syncPos()
    Connections { target: page.player; function onPostTrackChanged() { page.syncPos(); } function onIsPlayingChanged() { page.syncPos(); } }
    Timer { interval: 1000; repeat: true; running: page.current && HubState.open && !!page.player; triggeredOnStart: true; onTriggered: page.syncPos() }
    property real shownPos: 0
    FrameAnimation {
        running: page.current && HubState.open && !!page.player && page.player.isPlaying && !seek.dragging
        onTriggered: page.shownPos = Math.min(page.len || 1e9, page.pos + (Date.now() - page.posAt) / 1000)
    }
    onPosChanged: if (!(player && player.isPlaying)) shownPos = pos

    readonly property var viewIds: ["eq", "audio", "lyrics"]
    Keys.onTabPressed: event => { view = viewIds[(viewIds.indexOf(view) + 1) % 3]; event.accepted = true; }
    Keys.onBacktabPressed: view = viewIds[(viewIds.indexOf(view) + 2) % 3]

    // ── the cover, blurred, behind everything, tinted with its colour ──
    Item {
        id: backdrop
        anchors.fill: parent
        anchors.margins: -4
        Image { id: blurSrc; anchors.fill: parent; source: page.art; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(160, 160); visible: false }
        MultiEffect {
            anchors.fill: parent
            source: blurSrc
            visible: blurSrc.status === Image.Ready
            blurEnabled: true; blur: 1.0; blurMax: 64
            saturation: 0.3
            opacity: 0.42
            maskEnabled: true
            maskSource: bdMask
        }
        Rectangle { id: bdMask; anchors.fill: parent; radius: Theme.corner(80, 14); visible: false; layer.enabled: true }
        Rectangle {
            anchors.fill: parent
            radius: Theme.corner(80, 14)
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.alpha(page.tone, 0.10) }
                GradientStop { position: 0.55; color: "transparent" }
            }
        }
    }

    // ── nothing playing ──
    Column {
        visible: !page.player
        anchors.centerIn: parent
        spacing: 12
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 96; height: 96; radius: Theme.corner(96, 12)
            color: Theme.container
            Icon { anchors.centerIn: parent; name: "music_off"; size: 46; color: Theme.subtext }
        }
        Label { anchors.horizontalCenter: parent.horizontalCenter; text: "Nothing is playing"; strong: true; font.pixelSize: Theme.sizeTitle + 4 }
        Label { anchors.horizontalCenter: parent.horizontalCenter; width: Math.min(implicitWidth, page.width - 64); wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; text: "Play something in any app (a music player, a browser, a video) and it shows up here"; muted: true }
    }

    // ── top: the cover and the track ──
    Item {
        id: top
        visible: !!page.player
        x: 8; y: 8
        width: parent.width - 16
        height: page.topH - 8

        // the cover, with a soft shadow in its colour; crossfades when the track changes
        Item {
            id: cover
            width: top.height; height: top.height
            Rectangle {
                anchors.fill: parent
                radius: Theme.corner(top.height, 10)
                color: Theme.control
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Qt.alpha(page.tone, 0.55); shadowBlur: 1; blurMax: 40; shadowVerticalOffset: 6 }
            }
            Icon { anchors.centerIn: parent; name: "music_note"; size: 64; color: Theme.faint; visible: coverImg.status !== Image.Ready }
            Image {
                id: coverImg
                anchors.fill: parent
                source: page.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                visible: false
                onSourceChanged: fadeIn.restart()
            }
            MultiEffect {
                id: coverFx
                anchors.fill: parent
                source: coverImg
                visible: coverImg.status === Image.Ready
                maskEnabled: true
                maskSource: coverMask
                NumberAnimation on opacity { id: fadeIn; from: 0.2; to: 1; duration: Theme.ms(450); easing.type: Easing.OutCubic }
            }
            Rectangle { id: coverMask; visible: false; width: cover.width; height: cover.height; radius: Theme.corner(top.height, 10); layer.enabled: true }
        }

        ColumnLayout {
            anchors.left: cover.right; anchors.leftMargin: 22
            anchors.right: parent.right
            height: parent.height
            spacing: 2

            // the title: slides along slowly when it's too long to fit
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: titleText.implicitHeight
                clip: true
                Text {
                    id: titleText
                    text: page.player ? (page.player.trackTitle || "Unknown track") : ""
                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 26; font.weight: Font.Black
                    readonly property real over: Math.max(0, implicitWidth - parent.width)
                    x: 0
                    SequentialAnimation on x {
                        running: titleText.over > 0 && page.current && HubState.open
                        loops: Animation.Infinite
                        PauseAnimation { duration: 2500 }
                        NumberAnimation { to: -titleText.over; duration: Math.max(1200, titleText.over * 28); easing.type: Easing.InOutSine }
                        PauseAnimation { duration: 2000 }
                        NumberAnimation { to: 0; duration: Math.max(1200, titleText.over * 28); easing.type: Easing.InOutSine }
                    }
                    onTextChanged: x = 0
                }
            }
            Text {
                Layout.fillWidth: true
                elide: Text.ElideRight
                text: page.player ? ([page.player.trackArtist, page.player.trackAlbum].filter(s => s).join("  ·  ") || "Unknown artist") : ""
                color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 15; font.weight: Font.Medium
            }
            // where it plays: the output (click: the Audio tab) and the player (click: the next one)
            Row {
                Layout.topMargin: 8
                spacing: 6
                component Chip: Pressable {
                    property string icon
                    property string text
                    property bool more: false
                    height: 28; width: chipRow.implicitWidth + 20
                    color: hovered ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.06)
                    Row { id: chipRow; anchors.centerIn: parent; spacing: 6
                        Icon { name: parent.parent.icon; size: 15; color: page.tone; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: parent.parent.text; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; elide: Text.ElideRight; width: Math.min(implicitWidth, 190); anchors.verticalCenter: parent.verticalCenter }
                        Icon { visible: parent.parent.more; name: "unfold_more"; size: 14; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter } }
                }
                Chip {
                    icon: "speaker"
                    text: page.sink ? (page.sink.description || page.sink.nickname || page.sink.name) : "No output"
                    onClicked: page.view = "audio"
                }
                Chip {
                    icon: "graphic_eq"
                    text: page.player ? (page.player.identity || "A player") : ""
                    more: page.players.length > 1
                    onClicked: if (page.players.length > 1) page.chosen = (page.players.indexOf(page.player) + 1) % page.players.length
                }
            }
            Item { Layout.fillHeight: true }

            // the progress: drag it, or click anywhere on it
            Item {
                id: seek
                Layout.fillWidth: true
                Layout.preferredHeight: 18
                property bool dragging: false
                property real dragFrac: 0
                readonly property bool can: !!page.player && page.player.canSeek && page.len > 0
                readonly property real frac: dragging ? dragFrac : (page.len > 0 ? Math.min(1, page.shownPos / page.len) : 0)
                readonly property bool big: seekArea.containsMouse || dragging
                opacity: page.len > 0 ? 1 : 0.4
                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width; height: seek.big ? 8 : 5; radius: height / 2
                    color: Qt.alpha(Theme.text, 0.14)
                    Behavior on height { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }
                    Rectangle { width: Math.max(height, parent.width * seek.frac); height: parent.height; radius: height / 2; color: page.tone }
                }
                Rectangle {
                    visible: seek.can
                    x: parent.width * seek.frac - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: seek.big ? 16 : 0; height: width; radius: width / 2
                    color: page.tone
                    border.width: 3; border.color: Theme.frame
                    Behavior on width { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    id: seekArea
                    anchors.fill: parent; anchors.topMargin: -6; anchors.bottomMargin: -6
                    hoverEnabled: true
                    enabled: seek.can
                    cursorShape: Qt.PointingHandCursor
                    function at(x) { return Math.max(0, Math.min(1, x / width)); }
                    onPressed: mouse => { seek.dragging = true; seek.dragFrac = at(mouse.x); }
                    onPositionChanged: mouse => { if (pressed) seek.dragFrac = at(mouse.x); }
                    onReleased: mouse => {
                        const t = page.len * at(mouse.x);
                        page.player.position = t;
                        page.pos = t; page.posAt = Date.now(); page.shownPos = t;
                        seek.dragging = false;
                    }
                    onCanceled: seek.dragging = false
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: page.fmt(seek.dragging ? seek.dragFrac * page.len : page.shownPos); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 12; font.features: { "tnum": 1 } }
                Item { Layout.fillWidth: true }
                Text { text: page.len > 0 ? "-" + page.fmt(page.len - (seek.dragging ? seek.dragFrac * page.len : page.shownPos)) : ""; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 12; font.features: { "tnum": 1 } }
            }

            // controls: shuffle · previous · play · next · repeat
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 2
                spacing: 10
                component Ctl: Pressable {
                    property string icon
                    property bool on: false
                    property bool side: false          // shuffle / repeat: small, with a dot when on
                    width: side ? 40 : 46; height: width
                    anchors.verticalCenter: parent.verticalCenter
                    color: hovered ? Qt.alpha(Theme.text, 0.1) : "transparent"
                    Icon { anchors.centerIn: parent; name: parent.icon; filled: !parent.side; size: parent.side ? 20 : 28; color: parent.on ? page.tone : (parent.enabledInput ? Theme.text : Theme.faint) }
                    Rectangle { visible: parent.side && parent.on; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 3; width: 4; height: 4; radius: 2; color: page.tone }
                }
                Ctl {
                    side: true; icon: "shuffle"
                    on: !!page.player && page.player.shuffle
                    enabledInput: !!page.player && page.player.shuffleSupported
                    onClicked: page.player.shuffle = !page.player.shuffle
                }
                Ctl { icon: "skip_previous"; enabledInput: !!page.player && page.player.canGoPrevious; onClicked: page.player.previous() }
                Pressable {
                    width: 64; height: 64
                    anchors.verticalCenter: parent.verticalCenter
                    radius: Theme.square ? 0 : 32
                    color: page.tone; ink: page.onTone
                    enabledInput: !!page.player && (page.player.canPause || page.player.canPlay)
                    onClicked: page.player.togglePlaying()
                    scale: pressed ? 0.94 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(120); easing.type: Easing.OutCubic } }
                    Icon { anchors.centerIn: parent; name: page.player && page.player.isPlaying ? "pause" : "play_arrow"; size: 34; filled: true; color: page.onTone }
                }
                Ctl { icon: "skip_next"; enabledInput: !!page.player && page.player.canGoNext; onClicked: page.player.next() }
                Ctl {
                    side: true
                    icon: page.player && page.player.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    on: !!page.player && page.player.loopState !== MprisLoopState.None
                    enabledInput: !!page.player && page.player.loopSupported
                    onClicked: page.player.loopState = page.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist
                        : (page.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None)
                }
            }
        }
    }

    // ── the tabs ──
    Rectangle {
        id: tabs
        visible: !!page.player
        x: 8; y: page.topH + 18
        width: parent.width - 16; height: 40
        radius: Theme.corner(40)
        color: Qt.alpha(Theme.text, 0.06)
        readonly property var opts: [["eq", "Equaliser", "equalizer"], ["audio", "Audio", "tune"], ["lyrics", "Lyrics", "lyrics"]]
        Rectangle {
            y: 4
            x: 4 + tabs.opts.findIndex(o => o[0] === page.view) * ((tabs.width - 8) / 3)
            width: (tabs.width - 8) / 3; height: tabs.height - 8
            radius: Theme.corner(height)
            color: Qt.alpha(page.tone, 0.22)
            border.width: 1; border.color: Qt.alpha(page.tone, 0.45)
            Behavior on x { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        }
        Row {
            anchors.fill: parent; anchors.margins: 4
            Repeater {
                model: tabs.opts
                Pressable {
                    required property var modelData
                    readonly property bool on: page.view === modelData[0]
                    width: parent.width / 3; height: parent.height
                    color: "transparent"
                    onClicked: page.view = modelData[0]
                    Row {
                        anchors.centerIn: parent; spacing: 7
                        Icon { name: parent.parent.modelData[2]; size: 17; filled: parent.parent.on; color: parent.parent.on ? page.tone : Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: parent.parent.modelData[1]; color: parent.parent.on ? Theme.text : Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: parent.parent.on ? Font.Bold : Font.Normal; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
    Item {
        id: body
        visible: !!page.player
        x: 10; y: tabs.y + tabs.height + 14
        width: parent.width - 20
        height: page.tabH - 18

        // ── equaliser: on/off, presets, ten bands ──
        Item {
            anchors.fill: parent
            visible: page.view === "eq"
            RowLayout {
                id: eqHead
                width: parent.width
                height: 34
                spacing: 8
                Toggle { checked: Eq.enabled; onToggled: on => Eq.setEnabled(on) }
                Text { text: Eq.enabled ? "On" : "Off"; color: Eq.enabled ? Theme.text : Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; Layout.rightMargin: 6 }
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 30
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
                                readonly property bool on: Eq.preset === modelData
                                height: 30; width: pl.implicitWidth + 24
                                color: on ? Qt.alpha(page.tone, 0.22) : (hovered ? Qt.alpha(Theme.text, 0.12) : Qt.alpha(Theme.text, 0.06))
                                border.width: on ? 1 : 0; border.color: Qt.alpha(page.tone, 0.5)
                                onClicked: Eq.usePreset(modelData)
                                Text { id: pl; anchors.centerIn: parent; text: parent.modelData; color: parent.on ? Theme.text : Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: parent.on ? Font.Bold : Font.Normal }
                            }
                        }
                    }
                }
            }
            // the sound itself behind the bands: you see what each one is shaping
            Faces.CavaBars {
                y: eqHead.height + 16
                width: parent.width
                height: parent.height - y - 42
                count: 40; spacing: 4; minLen: 0
                live: page.view === "eq" && page.current && !!page.player && page.player.isPlaying
                visible: live
                opacity: 0.22
                color: page.tone
            }
            Row {
                y: eqHead.height + 16
                width: parent.width
                height: parent.height - y
                opacity: Eq.enabled ? 1 : 0.45
                Behavior on opacity { NumberAnimation { duration: Theme.ms(200); easing.type: Easing.OutCubic } }
                Repeater {
                    model: 10
                    Item {
                        id: bandItem
                        required property int index
                        width: parent.width / 10
                        height: parent.height
                        readonly property real g: Eq.gains[index] || 0
                        Rectangle {
                            id: track
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 8
                            height: parent.height - 42
                            radius: 4
                            color: Qt.alpha(Theme.text, 0.12)
                            readonly property real mid: height / 2
                            // the fill, from the middle (0 dB) up or down
                            Rectangle {
                                width: parent.width; radius: 4
                                color: page.tone
                                readonly property real off: Math.abs(bandItem.g) / 12 * track.mid
                                y: bandItem.g >= 0 ? track.mid - off : track.mid
                                height: Math.max(2, off)
                                Behavior on y { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
                                Behavior on height { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
                            }
                        }
                        // 0 dB
                        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: track.mid - 0.5; width: 20; height: 1; color: Qt.alpha(Theme.text, 0.25) }
                        // the knob
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: track.mid - bandItem.g / 12 * track.mid - height / 2
                            width: bandArea.containsMouse || bandArea.pressed ? 24 : 20; height: width; radius: width / 2
                            color: Theme.frame
                            border.width: 3; border.color: page.tone
                            Behavior on y { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
                            Behavior on width { NumberAnimation { duration: Theme.ms(120); easing.type: Easing.OutCubic } }
                        }
                        MouseArea {
                            id: bandArea
                            x: 0; width: parent.width; height: track.height
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            function set(y) { Eq.setBand(bandItem.index, Math.round((track.mid - y) / track.mid * 12 * 2) / 2); }
                            onPressed: mouse => set(mouse.y)
                            onPositionChanged: mouse => { if (pressed) set(mouse.y); }
                            onDoubleClicked: Eq.setBand(bandItem.index, 0)
                            onWheel: wheel => Eq.setBand(bandItem.index, Math.max(-12, Math.min(12, bandItem.g + (wheel.angleDelta.y > 0 ? 0.5 : -0.5))))
                        }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: track.height + 8; text: (bandItem.g > 0 ? "+" : "") + bandItem.g; color: bandItem.g === 0 ? Theme.subtext : Theme.text; font.family: Theme.fontFamily; font.pixelSize: 12; font.weight: Font.Bold }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; y: track.height + 25; text: Eq.freqs[bandItem.index] >= 1000 ? (Eq.freqs[bandItem.index] / 1000) + "k" : Eq.freqs[bandItem.index]; color: Theme.faint; font.family: Theme.fontFamily; font.pixelSize: 11 }
                    }
                }
            }
        }

        // ── audio: output, volume, balance, the player's own volume ──
        Column {
            id: audioTab
            anchors.fill: parent
            visible: page.view === "audio"
            spacing: 16
            readonly property var vols: page.sink && page.sink.audio ? page.sink.audio.volumes : []
            // balance from the two channels' volumes: -1 all left .. 1 all right
            readonly property real balance: vols.length >= 2 && Math.max(vols[0], vols[1]) > 0 ? (vols[1] - vols[0]) / Math.max(vols[0], vols[1]) : 0
            function setBalance(b) {
                if (!page.sink || !page.sink.audio || vols.length < 2) return;
                const v = page.sink.audio.volume;
                const l = v * (b > 0 ? 1 - b : 1), r = v * (b < 0 ? 1 + b : 1);
                page.sink.audio.volumes = vols.map((x, i) => i % 2 === 0 ? l : r);
            }
            component Line: Row {
                property string label
                spacing: 12
                Text { text: parent.label; width: 96; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter }
            }
            Line {
                label: "Output"
                Dropdown {
                    width: body.width - 108
                    opts: page.outputs.map(n => [n.name, n.description || n.nickname || n.name])
                    value: page.sink ? page.sink.name : ""
                    onPicked: v => { const n = page.outputs.find(x => x.name === v); if (n) Pipewire.preferredDefaultAudioSink = n; }
                }
            }
            Line {
                label: "Volume"
                Slider {
                    width: body.width - 108; implicitHeight: 34
                    icon: page.sink && page.sink.audio && page.sink.audio.muted ? "volume_off" : "volume_up"
                    muted: !!page.sink && !!page.sink.audio && page.sink.audio.muted
                    value: page.sink && page.sink.audio ? page.sink.audio.volume : 0
                    onMoved: v => { if (page.sink && page.sink.audio) { page.sink.audio.muted = false; page.sink.audio.volume = v; } }
                    onIconClicked: if (page.sink && page.sink.audio) page.sink.audio.muted = !page.sink.audio.muted
                }
            }
            Line {
                label: "Balance"
                Column {
                    width: body.width - 108
                    spacing: 3
                    Slider {
                        width: parent.width; implicitHeight: 34
                        icon: "balance"
                        value: (audioTab.balance + 1) / 2
                        onMoved: v => audioTab.setBalance(Math.abs(v - 0.5) < 0.03 ? 0 : v * 2 - 1)
                        onIconClicked: audioTab.setBalance(0)
                    }
                    Item {
                        width: parent.width; height: 16
                        Text { text: "Left"; color: Theme.faint; font.family: Theme.fontFamily; font.pixelSize: 11 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: Math.abs(audioTab.balance) < 0.02 ? "Centre" : Math.round(Math.abs(audioTab.balance) * 100) + "% " + (audioTab.balance < 0 ? "left" : "right"); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11; font.weight: Font.Bold }
                        Text { anchors.right: parent.right; text: "Right"; color: Theme.faint; font.family: Theme.fontFamily; font.pixelSize: 11 }
                    }
                }
            }
            Line {
                visible: !!page.player && page.player.volumeSupported
                label: page.player ? (page.player.identity || "Player") : ""
                Slider {
                    width: body.width - 108; implicitHeight: 34
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
            visible: page.view === "lyrics" && Lyrics.lines.length > 0
            clip: true
            model: Lyrics.lines.length > 0 ? Lyrics.lines : []
            currentIndex: Lyrics.currentIndex
            highlightRangeMode: ListView.ApplyRange
            preferredHighlightBegin: height * 0.38
            preferredHighlightEnd: height * 0.5
            highlightMoveDuration: 500
            interactive: false
            delegate: Text {
                required property var modelData
                required property int index
                readonly property int dist: Math.abs(index - Lyrics.currentIndex)
                width: lyricList.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: modelData.text === "" ? "♪" : modelData.text
                font.family: Theme.fontFamily
                font.pixelSize: dist === 0 ? 23 : 16
                font.weight: dist === 0 ? Font.Black : Font.Medium
                color: dist === 0 ? Theme.text : Theme.subtext
                opacity: Math.max(0.22, 1 - dist * 0.2)
                topPadding: 6; bottomPadding: 6
                Behavior on font.pixelSize { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
            }
        }
        Column {
            visible: page.view === "lyrics" && Lyrics.lines.length === 0
            anchors.centerIn: parent
            width: parent.width
            spacing: 10
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Lyrics.state === "loading" ? "progress_activity" : "lyrics"; size: 40; color: Theme.faint
                RotationAnimation on rotation { running: Lyrics.state === "loading"; from: 0; to: 360; duration: 900; loops: Animation.Infinite } }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: Lyrics.state === "loading" ? "Looking for lyrics…" : (Lyrics.plain !== "" ? Lyrics.plain : "No lyrics found for this song")
                color: Lyrics.plain !== "" ? Theme.text : Theme.subtext
                font.family: Theme.fontFamily; font.pixelSize: Lyrics.plain !== "" ? 14 : 15
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: Lyrics.state !== "loading" && Lyrics.state !== "none"
                text: Lyrics.fromFile ? "Use online lyrics" : "Pick a lyrics file"
                icon: Lyrics.fromFile ? "cloud" : "folder_open"
                onClicked: Lyrics.fromFile ? Lyrics.forgetFile() : Lyrics.pickFile()
            }
        }
    }
}
