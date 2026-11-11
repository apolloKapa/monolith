import QtQuick
import QtQuick.Effects
import QtMultimedia
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../core"
import "../ui"

// The wallpaper picker: a panel in the middle of the screen. It opens as a bubble that drops
// out of the island and grows into the panel (and shrinks back up into it on close). Inside,
// a coverflow (or a grid) of your pictures: ←/→ or the wheel to browse, Enter or a click on
// the middle one to set it, right-click for this screen only, Esc to close.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property bool here: HubState.wallScreen === "" ? (Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]) : HubState.wallScreen === modelData.name
    readonly property bool shown: HubState.wallOpen && here

    // t: 0 closed … 1 open. The first part is the bubble's fall, the rest its growing into the panel.
    property real t: shown ? 1 : 0
    Behavior on t { NumberAnimation { duration: win.shown ? Theme.ms(720) : Theme.ms(380); easing.type: win.shown ? Easing.Linear : Easing.InQuad } }
    readonly property real fall: ease(Math.min(1, t / 0.42))
    readonly property real grow: ease(Math.max(0, (t - 0.42) / 0.58))
    function ease(x) { return 1 - Math.pow(1 - x, 3); }

    visible: shown || t > 0.001
    WlrLayershell.namespace: "monolith-wallpicker"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown && !HubState.authOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    readonly property string screenName: modelData.name
    readonly property string currentPath: Wall.pathFor(screenName)
    readonly property bool coverflow: Store.get("wallpaper.view", "flow") === "flow"
    // Pictures or Live (videos and GIFs); the tab you used last
    readonly property bool liveTab: Store.get("wallpaper.tab", "pictures") === "live"
    readonly property var list: liveTab ? Wall.live : Wall.pictures
    onShownChanged: if (shown) { Wall.rescan(); flow.currentIndex = Math.max(0, list.indexOf(currentPath)); keys.forceActiveFocus(); }

    // the room behind it dims; a click there closes it
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.38 * win.t
    }
    MouseArea { anchors.fill: parent; enabled: win.shown; onClicked: HubState.wallOpen = false }

    // ── the bubble that becomes the panel ──
    readonly property real bubble: 64
    readonly property real panelW: Math.min(width - 80, 1180)
    readonly property real panelH: Math.min(height - 120, 640)
    Rectangle {
        id: panel
        readonly property real w: win.bubble + (win.panelW - win.bubble) * win.grow
        readonly property real h: win.bubble + (win.panelH - win.bubble) * win.grow
        // the centre falls from the island to the middle of the screen
        readonly property real cy: Theme.islandH / 2 + (win.height / 2 - Theme.islandH / 2) * win.fall
        width: w
        height: h
        x: (win.width - w) / 2
        y: cy - h / 2
        radius: win.bubble / 2 + (Theme.corner(80, 14) - win.bubble / 2) * win.grow
        color: Theme.frame
        scale: 0.4 + 0.6 * Math.min(1, win.t / 0.2)
        opacity: Math.min(1, win.t * 4)
        CardShadow {}
        MouseArea { anchors.fill: parent }   // clicks on the panel stay on it

        // the bubble's icon, until it opens up
        Icon { anchors.centerIn: parent; name: "wallpaper"; size: 28; filled: true; color: Theme.accent; opacity: 1 - win.grow * 3 }

        Item {
            id: content
            anchors.fill: parent
            anchors.margins: 18
            opacity: Math.max(0, (win.grow - 0.55) / 0.45)
            visible: opacity > 0.01
            clip: true

            Item {
                id: keys
                focus: true
                Keys.onEscapePressed: HubState.wallOpen = false
                readonly property var g: win.liveTab ? liveGrid : grid
                readonly property bool f: win.coverflow && !win.liveTab
                Keys.onLeftPressed: if (f) flow.decrementCurrentIndex(); else g.moveCurrentIndexLeft()
                Keys.onRightPressed: if (f) flow.incrementCurrentIndex(); else g.moveCurrentIndexRight()
                Keys.onUpPressed: if (!f) g.moveCurrentIndexUp()
                Keys.onDownPressed: if (!f) g.moveCurrentIndexDown()
                Keys.onTabPressed: Store.set("wallpaper.tab", win.liveTab ? "pictures" : "live")
                Keys.onReturnPressed: { const i = f ? flow.currentIndex : g.currentIndex; if (win.list.length) Wall.set(win.list[i]); }
            }

            RowLayout {
                id: head
                width: parent.width
                height: 40
                Icon { name: "wallpaper"; size: 22; filled: true; color: Theme.accent }
                Label { text: "Wallpaper"; strong: true; font.pixelSize: Theme.sizeTitle + 2 }
                Segmented { Layout.leftMargin: 10; Layout.preferredWidth: 200; height: 36; opts: [["pictures", "Pictures"], ["live", "Live"]]; value: win.liveTab ? "live" : "pictures"; onPicked: v => Store.set("wallpaper.tab", v) }
                Label {
                    Layout.leftMargin: 8; Layout.fillWidth: true; elide: Text.ElideRight; muted: true; font.pixelSize: Theme.sizeSmall
                    text: win.liveTab ? Wall.live.length + (Wall.live.length === 1 ? " live wallpaper" : " live wallpapers") + "   ·   hover to preview"
                                      : Wall.dir.replace(Wall.home, "~") + "   ·   " + Wall.pictures.length + " pictures   ·   right-click: only this screen"
                }
                Segmented { visible: !win.liveTab; Layout.preferredWidth: 180; height: 36; opts: [["flow", "Coverflow"], ["grid", "Grid"]]; value: win.coverflow ? "flow" : "grid"; onPicked: v => Store.set("wallpaper.view", v) }
                Segmented { Layout.preferredWidth: 160; height: 36; opts: [["dark", "Dark"], ["light", "Light"]]; value: Theme.modeName; onPicked: v => Store.set("theme.mode", v) }
                Pressable {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    color: hovered ? Theme.containerHigh : "transparent"
                    onClicked: HubState.wallOpen = false
                    Icon { anchors.centerIn: parent; name: "close"; size: 20 }
                }
            }

            // a picture, clipped to its rounded card (the accent border when it's the one in use)
            component Card: ClippingRectangle {
                id: card
                property string path: ""
                property bool current: false
                radius: Theme.corner(height, 6)
                color: Theme.container
                border.width: current ? 3 : 0
                border.color: Theme.accent
                Icon { anchors.centerIn: parent; visible: Wall.isVideo(card.path); name: "movie"; size: 44; color: Theme.subtext }
                Image {
                    anchors.fill: parent
                    visible: !Wall.isVideo(card.path)
                    source: Wall.isVideo(card.path) || card.path === "" ? "" : Wall.url(card.path)
                    sourceSize: Qt.size(640, 400)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(240); easing.type: Easing.OutCubic } }
                }
            }

            // ── coverflow: the pictures turn away on both sides of the middle one ──
            PathView {
                id: flow
                visible: win.coverflow && !win.liveTab
                y: head.height + 12
                width: parent.width
                height: parent.height - y - 34
                model: win.list
                pathItemCount: Math.min(9, win.list.length)
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 380
                readonly property real cardW: Math.min(560, width * 0.46)
                readonly property real cardH: Math.min(cardW * 0.6, height - 20)
                path: Path {
                    startX: 0; startY: flow.height / 2
                    PathAttribute { name: "turn"; value: 62 }
                    PathAttribute { name: "size"; value: 0.6 }
                    PathAttribute { name: "depth"; value: 0 }
                    PathAttribute { name: "fade"; value: 0.3 }
                    PathLine { x: flow.width * 0.33; y: flow.height / 2 }
                    PathPercent { value: 0.38 }
                    PathAttribute { name: "turn"; value: 48 }
                    PathAttribute { name: "size"; value: 0.78 }
                    PathAttribute { name: "depth"; value: 5 }
                    PathAttribute { name: "fade"; value: 0.75 }
                    PathLine { x: flow.width * 0.5; y: flow.height / 2 }
                    PathPercent { value: 0.5 }
                    PathAttribute { name: "turn"; value: 0 }
                    PathAttribute { name: "size"; value: 1.0 }
                    PathAttribute { name: "depth"; value: 10 }
                    PathAttribute { name: "fade"; value: 1.0 }
                    PathLine { x: flow.width * 0.67; y: flow.height / 2 }
                    PathPercent { value: 0.62 }
                    PathAttribute { name: "turn"; value: -48 }
                    PathAttribute { name: "size"; value: 0.78 }
                    PathAttribute { name: "depth"; value: 5 }
                    PathAttribute { name: "fade"; value: 0.75 }
                    PathLine { x: flow.width; y: flow.height / 2 }
                    PathPercent { value: 1.0 }
                    PathAttribute { name: "turn"; value: -62 }
                    PathAttribute { name: "size"; value: 0.6 }
                    PathAttribute { name: "depth"; value: 0 }
                    PathAttribute { name: "fade"; value: 0.3 }
                }
                delegate: Item {
                    id: fc
                    required property string modelData
                    required property int index
                    readonly property bool middle: PathView.isCurrentItem
                    width: flow.cardW
                    height: flow.cardH
                    z: PathView.depth
                    scale: PathView.size
                    opacity: PathView.fade
                    transform: Rotation { origin.x: fc.width / 2; origin.y: fc.height / 2; axis { x: 0; y: 1; z: 0 } angle: fc.PathView.turn }
                    Card { anchors.fill: parent; path: fc.modelData; current: fc.modelData === win.currentPath }
                    Bubble { visible: fc.modelData === win.currentPath; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 12; size: 28; icon: "check"; on: true }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (!fc.middle) { flow.currentIndex = fc.index; return; }
                            if (mouse.button === Qt.RightButton) Wall.setFor(win.screenName, fc.modelData);
                            else Wall.set(fc.modelData);
                        }
                    }
                }
                WheelHandler { onWheel: event => { if (event.angleDelta.y > 0 || event.angleDelta.x > 0) flow.decrementCurrentIndex(); else flow.incrementCurrentIndex(); } }
            }
            Label {
                visible: win.coverflow && !win.liveTab && win.list.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: parent.width * 0.7
                horizontalAlignment: Text.AlignHCenter
                text: win.list.length ? (win.list[flow.currentIndex] || "").replace(/^.*\//, "") + "   ·   " + (flow.currentIndex + 1) + " / " + win.list.length : ""
                muted: true
                font.pixelSize: Theme.sizeSmall
            }

            // ── live: videos and GIFs, a still on each card that comes alive under the pointer ──
            component LiveCard: ClippingRectangle {
                id: lc
                property string path: ""
                property bool current: false
                property bool hot: false
                readonly property bool gif: Wall.isAnimated(path)
                radius: Theme.corner(height, 6)
                color: Theme.container
                border.width: current ? 3 : 0
                border.color: Theme.accent
                scale: hot ? 1.03 : 1
                Behavior on scale { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
                Icon { anchors.centerIn: parent; name: "movie"; size: 40; color: Theme.faint; visible: still.status !== Image.Ready && !lc.gif }
                // the still (a video's first second, made by Wall.makeThumbs)
                Image {
                    id: still
                    anchors.fill: parent
                    visible: !lc.gif
                    source: lc.gif || lc.path === "" ? "" : "file://" + Wall.thumb(lc.path) + "?" + Wall.thumbsMade
                    sourceSize: Qt.size(640, 400)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: false
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(240); easing.type: Easing.OutCubic } }
                }
                AnimatedImage {
                    anchors.fill: parent
                    visible: lc.gif
                    source: lc.gif ? Wall.url(lc.path) : ""
                    fillMode: Image.PreserveAspectCrop
                    playing: lc.hot
                    asynchronous: true
                }
                // the preview: plays (muted) while the pointer is on it, fading in over the still
                Loader {
                    anchors.fill: parent
                    active: lc.hot && !lc.gif && win.shown
                    sourceComponent: Video {
                        source: Wall.url(lc.path)
                        fillMode: VideoOutput.PreserveAspectCrop
                        loops: MediaPlayer.Infinite
                        muted: true
                        autoPlay: true
                        opacity: playbackState === MediaPlayer.PlayingState && position > 80 ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: Theme.ms(300); easing.type: Easing.OutCubic } }
                    }
                }
                // shade, name and a LIVE badge
                Rectangle {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    height: parent.height * 0.42
                    gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.6) } }
                }
                Label {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.margins: 12
                    elide: Text.ElideRight
                    text: lc.path.replace(/^.*\//, "").replace(/\.[^.]+$/, "")
                    color: "#ffffff"; strong: true; font.pixelSize: Theme.sizeSmall
                }
                Rectangle {
                    anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 10
                    width: badge.implicitWidth + 18; height: 22; radius: 11
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Row {
                        id: badge
                        anchors.centerIn: parent
                        spacing: 5
                        Rectangle {
                            width: 7; height: 7; radius: 3.5; color: "#ff5a6e"; anchors.verticalCenter: parent.verticalCenter
                            SequentialAnimation on opacity { running: lc.hot || lc.current; loops: Animation.Infinite; NumberAnimation { to: 0.25; duration: 600 } NumberAnimation { to: 1; duration: 600 } }
                        }
                        Label { text: lc.gif ? "GIF" : "LIVE"; color: "#ffffff"; strong: true; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                Bubble { visible: lc.current; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; size: 26; icon: "check"; on: true }
            }

            Item {
                id: liveView
                visible: win.liveTab
                y: head.height + 12
                width: parent.width
                height: parent.height - y

                // add one, its folder, sound, pausing under fullscreen apps
                RowLayout {
                    id: liveBar
                    width: parent.width
                    height: 40
                    spacing: 8
                    Button { text: "Add video…"; icon: "add"; primary: true; onClicked: Wall.addLive() }
                    Button { text: "Open folder"; icon: "folder_open"; onClicked: Wall.openLiveDir() }
                    Item { Layout.fillWidth: true }
                    Label { text: "Sound"; muted: true; font.pixelSize: Theme.sizeSmall }
                    Toggle { checked: Store.get("wallpaper.liveSound", false) === true; onToggled: on => Store.set("wallpaper.liveSound", on) }
                    Label { Layout.leftMargin: 10; text: "Pause under fullscreen apps"; muted: true; font.pixelSize: Theme.sizeSmall }
                    Toggle { checked: Store.get("wallpaper.livePause", true) !== false; onToggled: on => Store.set("wallpaper.livePause", on) }
                }

                Empty {
                    anchors.centerIn: liveGrid
                    width: liveGrid.width
                    visible: Wall.live.length === 0
                    icon: "animated_images"
                    title: "No live wallpapers yet"
                    sub: "Add a video (mp4, webm, mkv, mov) or a GIF and it plays behind your windows. They're kept in " + Wall.liveDir.replace(Wall.home, "~") + "."
                    button: "Add video…"
                    buttonIcon: "add"
                    onActed: Wall.addLive()
                }

                GridView {
                    SmoothWheel {}
                    id: liveGrid
                    y: liveBar.height + 12
                    width: parent.width
                    height: parent.height - y
                    clip: true
                    cellWidth: width / 3
                    cellHeight: cellWidth * 0.6
                    model: Wall.live
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Item {
                        id: lcell
                        required property string modelData
                        required property int index
                        width: liveGrid.cellWidth
                        height: liveGrid.cellHeight
                        LiveCard {
                            anchors.fill: parent
                            anchors.margins: 6
                            path: lcell.modelData
                            hot: lma.containsMouse || (liveGrid.currentIndex === lcell.index && liveGrid.activeFocus)
                            current: lcell.modelData === win.currentPath
                        }
                        MouseArea {
                            id: lma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mouse => { if (mouse.button === Qt.RightButton) Wall.setFor(win.screenName, lcell.modelData); else Wall.set(lcell.modelData); }
                        }
                    }
                }
            }

            // ── grid ──
            GridView {
                SmoothWheel {}
                id: grid
                visible: !win.coverflow && !win.liveTab
                y: head.height + 12
                width: parent.width
                height: parent.height - y
                clip: true
                cellWidth: width / 5
                cellHeight: cellWidth * 0.64
                model: win.list
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: gcell
                    required property string modelData
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    Card {
                        anchors.fill: parent
                        anchors.margins: 5
                        path: gcell.modelData
                        current: gcell.modelData === win.currentPath || grid.currentIndex === gcell.index && grid.activeFocus
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => { if (mouse.button === Qt.RightButton) Wall.setFor(win.screenName, gcell.modelData); else Wall.set(gcell.modelData); }
                    }
                }
            }
        }
    }

    // blur behind it (Theme → Effects), shaped like it
    BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
    Region {
        id: blurShape
        // (gone the moment it starts closing: the blur cannot fade out with it)
        item: win.shown ? panel : null
        radius: panel.radius
    }
}
