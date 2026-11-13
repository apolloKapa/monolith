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
// the middle one to set it, right-click for this screen only, Esc to close. With more than one
// screen, "Set on" picks which one a click sets (All, or one screen; Wall.aim).
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
    // the screen a click sets ("" = all of them); a screen that's gone counts as all
    readonly property string aimName: Wall.aim !== "" && Quickshell.screens.some(s => s.name === Wall.aim) ? Wall.aim : ""
    readonly property string currentPath: Wall.pathFor(aimName || screenName)
    function pick(p) { if (aimName === "") Wall.set(p); else Wall.setFor(aimName, p); }
    readonly property bool coverflow: Store.get("wallpaper.view", "flow") === "flow"
    // Pictures, Live (videos and GIFs) or Favourites (the starred ones of both); the tab you used last
    readonly property string tab: { const t = Store.get("wallpaper.tab", "pictures"); return t === "live" || t === "favs" ? t : "pictures"; }
    readonly property bool liveTab: tab === "live"
    readonly property bool favTab: tab === "favs"
    readonly property bool picTab: tab === "pictures"
    readonly property var tabs: ["pictures", "live", "favs"]
    // the cards' list: replaced only when the pictures themselves change (every saved setting
    // re-runs Store.get bindings, and a new list would send the views back to the top)
    property var picList: []
    property var liveList: []
    property var favList: []
    readonly property var list: liveTab ? liveList : favTab ? favList : picList
    function syncList() {
        if (Wall.pictures.join("\n") !== picList.join("\n")) picList = Wall.pictures;
        if (Wall.live.join("\n") !== liveList.join("\n")) liveList = Wall.live;
        // (in the folder's order; a starred file that's gone isn't shown)
        const favs = Wall.images.filter(i => Wall.isFav(i));
        if (favs.join("\n") !== favList.join("\n")) favList = favs;
    }
    // the scroll of both grids, noted when it closes or changes tab (the wheel animates contentY,
    // so there's no "movement ended" to listen to)
    function notePos() {
        if (!placed) return;
        if (grid.contentHeight > 0) Wall.rememberPos("gridY", grid.contentY);
        if (liveGrid.contentHeight > 0) Wall.rememberPos("liveY", liveGrid.contentY);
        if (favGrid.contentHeight > 0) Wall.rememberPos("favY", favGrid.contentY);
    }
    Connections { target: Wall; function onImagesChanged() { win.syncList(); } function onFavouritesChanged() { win.syncList(); } }

    // back where you were last time; the first time, at the wallpaper you have
    // (until it has put the views back, their moves aren't "where you were")
    property bool placed: false
    function restorePos() {
        const pos = Wall.pickerPos;
        const pic = Math.max(0, picList.indexOf(currentPath)), vid = Math.max(0, liveList.indexOf(currentPath));
        flow.currentIndex = pos.flow !== undefined ? Math.min(pos.flow, Math.max(0, picList.length - 1)) : pic;
        if (pos.gridY !== undefined) grid.contentY = Math.min(pos.gridY, Math.max(0, grid.contentHeight - grid.height));
        else grid.positionViewAtIndex(pic, GridView.Center);
        if (pos.liveY !== undefined) liveGrid.contentY = Math.min(pos.liveY, Math.max(0, liveGrid.contentHeight - liveGrid.height));
        else liveGrid.positionViewAtIndex(vid, GridView.Center);
        if (pos.favY !== undefined) favGrid.contentY = Math.min(pos.favY, Math.max(0, favGrid.contentHeight - favGrid.height));
        placed = true;
    }
    function opened() { syncList(); Wall.rescan(); Qt.callLater(restorePos); keys.forceActiveFocus(); }
    // it's made already open (shell.qml loads it when the picker opens), so start here too
    Component.onCompleted: if (shown) opened()
    onShownChanged: if (shown) opened(); else { notePos(); Wall.savePos(); }

    // the room behind it dims; a click there closes it
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: 0.38 * win.t
    }
    MouseArea { anchors.fill: parent; enabled: win.shown; onClicked: HubState.wallOpen = false }

    // ── the bubble that becomes the panel ──
    readonly property real bubble: 64
    readonly property real panelW: Math.min(width - 80, 1560)
    readonly property real panelH: Math.min(height - 100, 860)
    SmoothRect {
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
                readonly property var g: win.liveTab ? liveGrid : win.favTab ? favGrid : grid
                readonly property bool f: win.coverflow && win.picTab
                Keys.onLeftPressed: if (f) flow.decrementCurrentIndex(); else g.moveCurrentIndexLeft()
                Keys.onRightPressed: if (f) flow.incrementCurrentIndex(); else g.moveCurrentIndexRight()
                Keys.onUpPressed: if (!f) g.moveCurrentIndexUp()
                Keys.onDownPressed: if (!f) g.moveCurrentIndexDown()
                Keys.onTabPressed: Store.set("wallpaper.tab", win.tabs[(win.tabs.indexOf(win.tab) + 1) % win.tabs.length])
                Keys.onReturnPressed: { const i = f ? flow.currentIndex : g.currentIndex; if (win.list.length) win.pick(win.list[i]); }
                // S: star the one under the cursor (a favourite, for the playlist)
                Keys.onPressed: event => { if (event.key === Qt.Key_S) { const i = f ? flow.currentIndex : g.currentIndex; if (win.list.length) Wall.toggleFav(win.list[i]); event.accepted = true; } }
            }

            RowLayout {
                id: head
                width: parent.width
                height: 40
                Icon { name: "wallpaper"; size: 22; filled: true; color: Theme.accent }
                Label { text: "Wallpaper"; strong: true; font.pixelSize: Theme.sizeTitle + 2 }
                Segmented { Layout.leftMargin: 10; Layout.preferredWidth: 330; height: 36; opts: [["pictures", "Pictures"], ["live", "Live"], ["favs", "Favourites"]]; value: win.tab; onPicked: v => Store.set("wallpaper.tab", v) }
                // which screen a click sets: all of them, or just one
                Label { visible: Quickshell.screens.length > 1; Layout.leftMargin: 10; text: "Set on"; muted: true; font.pixelSize: Theme.sizeSmall }
                Segmented {
                    visible: Quickshell.screens.length > 1
                    Layout.preferredWidth: 90 * opts.length; height: 36
                    opts: [["", "All"]].concat(Quickshell.screens.map(s => [s.name, s.name]))
                    value: win.aimName
                    onPicked: v => Wall.aim = v
                }
                Label {
                    Layout.leftMargin: 8; Layout.fillWidth: true; elide: Text.ElideRight; muted: true; font.pixelSize: Theme.sizeSmall
                    text: win.favTab ? win.favList.length + (win.favList.length === 1 ? " favourite" : " favourites") + "   ·   S or the star to add or remove"
                        : win.liveTab ? Wall.live.length + (Wall.live.length === 1 ? " live wallpaper" : " live wallpapers") + "   ·   hover to preview"
                                      : Wall.dir.replace(Wall.home, "~") + "   ·   " + Wall.pictures.length + " pictures"
                }
                Segmented { visible: win.picTab; Layout.preferredWidth: 180; height: 36; opts: [["flow", "Coverflow"], ["grid", "Grid"]]; value: win.coverflow ? "flow" : "grid"; onPicked: v => Store.set("wallpaper.view", v) }
                Segmented { Layout.preferredWidth: 160; height: 36; opts: [["dark", "Dark"], ["light", "Light"]]; value: Theme.modeName; onPicked: v => Store.set("theme.mode", v) }
                Pressable {
                    Layout.preferredWidth: 36; Layout.preferredHeight: 36
                    color: hovered ? Theme.containerHigh : "transparent"
                    onClicked: HubState.wallOpen = false
                    Icon { anchors.centerIn: parent; name: "close"; size: 20 }
                }
            }

            // the star in a card's corner: a favourite (for the playlist); shows on hover, or always once starred
            component Star: Pressable {
                property string path: ""
                property bool hot: false
                readonly property bool fav: Wall.isFav(path)
                anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 12
                width: 30; height: 30
                radius: 15
                visible: fav || hot
                color: hovered ? Theme.containerHigh : Qt.alpha(Theme.frame, 0.8)
                onClicked: Wall.toggleFav(path)
                Icon { anchors.centerIn: parent; name: "star"; size: 18; filled: parent.fav; color: parent.fav ? Theme.accent : Theme.text }
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
                // its small copy once Wall has made it (the full picture only if that failed)
                readonly property string thumbState: Wall.picThumbState(card.path)
                // waiting: the picture's colours as a soft blur (its BlurHash) until it's in
                Placeholder {
                    anchors.fill: parent
                    source: Wall.isVideo(card.path) ? "" : card.path
                    loading: !Wall.isVideo(card.path) && pic.status !== Image.Ready && win.shown
                }
                Image {
                    id: pic
                    anchors.fill: parent
                    visible: !Wall.isVideo(card.path)
                    source: Wall.isVideo(card.path) || card.path === "" ? ""
                          : card.thumbState === "ok" ? "file://" + Wall.picThumb(card.path)
                          : card.thumbState === "fail" ? Wall.url(card.path) : ""
                    sourceSize: Qt.size(960, 600)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(240); easing.type: Easing.OutCubic } }
                }
            }

            // ── coverflow: the pictures turn away on both sides of the middle one ──
            PathView {
                id: flow
                onCurrentIndexChanged: if (win.placed && win.shown && win.picList.length) Wall.rememberPos("flow", currentIndex)
                visible: win.coverflow && win.picTab
                y: head.height + 12
                width: parent.width
                height: parent.height - y - 34
                model: win.picList
                pathItemCount: Math.min(9, win.picList.length)
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: 380
                readonly property real cardW: Math.min(760, width * 0.46)
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
                            else win.pick(fc.modelData);
                        }
                    }
                    Star { path: fc.modelData; hot: fc.middle }
                }
                WheelHandler { onWheel: event => { if (event.angleDelta.y > 0 || event.angleDelta.x > 0) flow.decrementCurrentIndex(); else flow.incrementCurrentIndex(); } }
            }
            Label {
                visible: win.coverflow && win.picTab && win.picList.length > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                width: parent.width * 0.7
                horizontalAlignment: Text.AlignHCenter
                text: win.picList.length ? (win.picList[flow.currentIndex] || "").replace(/^.*\//, "") + "   ·   " + (flow.currentIndex + 1) + " / " + win.picList.length : ""
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
                // waiting: the video's first frame as a soft blur (its BlurHash) until the still is in
                Placeholder {
                    anchors.fill: parent
                    source: lc.path
                    loading: still.status !== Image.Ready && !lc.gif && win.shown
                }
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
                    model: win.liveList
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
                            onClicked: mouse => { if (mouse.button === Qt.RightButton) Wall.setFor(win.screenName, lcell.modelData); else win.pick(lcell.modelData); }
                        }
                        Star { path: lcell.modelData; hot: lma.containsMouse || hovered }
                    }
                }
            }

            // ── grid ──
            GridView {
                SmoothWheel {}
                id: grid
                visible: !win.coverflow && win.picTab
                y: head.height + 12
                width: parent.width
                height: parent.height - y
                clip: true
                cellWidth: width / 5
                cellHeight: cellWidth * 0.64
                model: win.picList
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
                        onClicked: mouse => { if (mouse.button === Qt.RightButton) Wall.setFor(win.screenName, gcell.modelData); else win.pick(gcell.modelData); }
                    }
                    HoverHandler { id: ghov }
                    Star { path: gcell.modelData; hot: ghov.hovered; anchors.margins: 10 }
                }
            }

            // ── favourites: the starred pictures and live wallpapers together ──
            Empty {
                anchors.centerIn: favGrid
                width: favGrid.width
                visible: win.favTab && win.favList.length === 0
                icon: "star"
                title: "No favourites yet"
                sub: "Star a wallpaper (the star in a card's corner, or S on the one you're on) and it shows up here. The playlist can play just your favourites too."
            }
            GridView {
                SmoothWheel {}
                id: favGrid
                visible: win.favTab
                y: head.height + 12
                width: parent.width
                height: parent.height - y
                clip: true
                cellWidth: width / 4
                cellHeight: cellWidth * 0.62
                model: win.favList
                boundsBehavior: Flickable.StopAtBounds
                delegate: Item {
                    id: fcell
                    required property string modelData
                    required property int index
                    readonly property bool moving: Wall.isVideo(modelData) || Wall.isAnimated(modelData)
                    readonly property bool cur: modelData === win.currentPath
                    readonly property bool keyed: favGrid.currentIndex === index && favGrid.activeFocus
                    width: favGrid.cellWidth
                    height: favGrid.cellHeight
                    Card {
                        visible: !fcell.moving
                        anchors.fill: parent
                        anchors.margins: 6
                        path: fcell.moving ? "" : fcell.modelData
                        current: fcell.cur || fcell.keyed
                    }
                    Bubble { visible: fcell.cur && !fcell.moving; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 16; size: 26; icon: "check"; on: true }
                    LiveCard {
                        visible: fcell.moving
                        anchors.fill: parent
                        anchors.margins: 6
                        path: fcell.moving ? fcell.modelData : ""
                        hot: fcell.moving && (fma.containsMouse || fcell.keyed)
                        current: fcell.cur
                    }
                    MouseArea {
                        id: fma
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => { if (mouse.button === Qt.RightButton) Wall.setFor(win.screenName, fcell.modelData); else win.pick(fcell.modelData); }
                    }
                    // (below the LIVE badge on a live one)
                    Star { path: fcell.modelData; hot: fma.containsMouse; anchors.topMargin: fcell.moving ? 40 : 12 }
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
        radius: panel.blurRadius
    }
}
