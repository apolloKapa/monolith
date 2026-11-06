import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"
import "../hub"

// The island: one shape hanging from the top edge of every screen. Collapsed it's the bar
// (IslandBar); opened it grows (springs) into the page you picked, keeping the bar on top:
// the control center, search, notifications, media… Pages are the hub's pages (hub/). Typing
// searches from any page, Tab / Shift+Tab move between pages, Esc closes.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property bool here: HubState.screenName === "" ? (Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]) : HubState.screenName === modelData.name
    readonly property bool shown: HubState.open && here

    WlrLayershell.namespace: "monolith-island"
    // above fullscreen windows while open (a keybind over a game or video still shows it)
    WlrLayershell.layer: shown || wasOpen || toastOn ? WlrLayer.Overlay : WlrLayer.Top
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // collapsed only the island takes the mouse; open, a click anywhere else closes it
    mask: Region { item: win.shown ? fullArea : (win.tucked ? sensor : island) }
    Item { id: fullArea; anchors.fill: parent }

    // auto-hide (Settings → Status line): the collapsed island slides up, and comes back when
    // the pointer touches the top edge
    readonly property bool autohide: Store.get("status.autohide", false) === true
    readonly property bool tucked: autohide && !win.shown && !sensorHover.hovered && !barHover.hovered
    Item { id: sensor; x: island.x; width: island.width; height: 3; HoverHandler { id: sensorHover } }

    MouseArea { anchors.fill: parent; enabled: win.shown; onClicked: HubState.close() }

    readonly property var pageInfo: ({
        "search":        { icon: "search",         title: "Search",        w: Number(Store.get("search.width", 640)) },
        "quick":         { icon: "page_info",      title: "Control center", w: 1040 },
        "notifications": { icon: "notifications",  title: "Notifications", w: 680 },
        "media":         { icon: "music_note",     title: "Media",         w: 720 },
        "calendar":      { icon: "calendar_month", title: "Calendar",      w: 780 },
        "sound":         { icon: "volume_up",      title: "Sound",         w: 680 },
        "network":       { icon: "wifi",           title: "Network",       w: 680 },
        "clipboard":     { icon: "content_paste",  title: "Clipboard",     w: 680 },
        "windows":       { icon: "select_window",  title: "Windows",       w: 860 },
        "capture":       { icon: "screenshot_region", title: "Capture",    w: 680 },
        "gaming":        { icon: "sports_esports", title: "Gaming",        w: 960 },
        "tools":         { icon: "construction",   title: "Tools",         w: 900 },
        "wellbeing":     { icon: "self_improvement", title: "Wellbeing",   w: 860 },
        "keys":          { icon: "keyboard_command_key", title: "Keys",    w: 860 },
        "settings":      { icon: "settings",       title: "Settings",      w: 860 }
    })
    readonly property Item currentLoader: pages.children.find(l => l.pageId === HubState.page) || null
    readonly property Item currentPage: currentLoader ? currentLoader.item : null

    readonly property real pad: Theme.islandPad
    readonly property real fieldH: 46
    // each menu is its own window; Settings → Menus can put them back together with tabs
    readonly property bool tabbed: Store.get("menus.tabs", false) === true
    // Search is compact: no tab row (Tab still moves to the other pages, and they show it)
    readonly property bool compact: HubState.page === "search" || !tabbed
    readonly property real tabsH: compact ? 0 : 38
    // menus you filter by typing keep the search field; the rest show their name there
    readonly property bool usesQuery: HubState.page === "search" || !!(currentPage && currentPage.usesQuery)
    // the body's size: the bar's when collapsed, the page's when open
    readonly property real openW: Math.max(bar.implicitWidth, (pageInfo[HubState.page] || pageInfo.search).w)
    readonly property real openH: Math.min(height - 40, Theme.islandH + fieldH + (compact ? 8 : 8 + tabsH + 10) + (currentPage ? currentPage.implicitHeight : 200) + pad)
    readonly property real restW: Theme.fullBar ? Math.round(width * Theme.barLength) : Math.max(Theme.islandMinW, bar.implicitWidth)
    // the bar can be off on some screens (Settings → Bar); menus still open there
    readonly property bool barHere: (Store.get("bar.hiddenScreens", []) || []).indexOf(modelData.name) === -1
    // the bar's own background shows when it's open, or per its opacity setting
    readonly property bool barSolid: shown || toastOn || Theme.barOpacity >= 0.99

    // where menus open (Settings → Menus): out of the island (top), or as a floating card in
    // the middle of the screen or on the right; then the island stays a bar
    // (each menu can have its own place, Settings → Menus & launcher)
    readonly property string place: Store.get("menus.positions." + HubState.page, "") || Store.get("menus.position", "top")
    readonly property bool docked: place === "top"
    // the island grows into the menu; a full-width bar stays put and the menu drops out of it
    readonly property bool grown: shown && docked && !Theme.fullBar
    readonly property bool dropped: shown && docked && Theme.fullBar

    // a new notification drops out of the island (on the screen you're using) while it's closed
    readonly property bool toastScreen: Niri.focusedOutput !== "" ? Niri.focusedOutput === modelData.name : (Quickshell.screens.length > 0 && modelData === Quickshell.screens[0])
    readonly property bool toastOn: !shown && toastScreen && Notifs.popups.length > 0 && Store.get("notifications.style", "island") !== "corner"
    readonly property var toast: Notifs.popups.length > 0 ? Notifs.popups[0] : null
    // pages stay loaded while the island shrinks back after being open (not for a toast)
    property bool wasOpen: false

    // ── the island ──
    IslandShape {
        id: island
        bodyW: win.grown ? win.openW : (win.toastOn ? Math.max(win.restW, 520) : win.restW)
        height: win.grown ? win.openH : (win.toastOn ? Theme.islandH + toastArea.implicitHeight + win.pad : Theme.islandH)
        r: win.grown || win.toastOn ? Theme.islandRadius : (Theme.fullBar ? (Theme.barLength < 0.999 ? Theme.islandRadius / 2 : 0) : height / 2)
        fill: win.barSolid ? Theme.frame : Qt.alpha(Theme.frame, Theme.frame.a * Theme.barOpacity)
        shadow: win.barSolid || Theme.barOpacity > 0.3
        opacity: win.barHere || win.shown || win.toastOn ? 1 : 0
        ear: Theme.fullBar && !win.grown ? 0 : Theme.islandEar
        onHeightChanged: if (!win.shown && height <= Theme.islandH + 1) win.wasOpen = false
        x: Math.round((win.width - width) / 2)
        y: win.tucked ? -Theme.islandH + 3 : 0
        Behavior on bodyW { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
        Behavior on height { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
        Behavior on r { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        Behavior on y { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }

        // clicks on the island stay on the island
        MouseArea { anchors.fill: parent }

        // everything inside sits in the body (between the ears) and is clipped to it
        Item {
            id: body
            x: island.e
            width: island.bodyW
            height: island.height
            clip: true

            HoverHandler { id: barHover }

            // the bar row, centred at the top
            IslandBar {
                id: bar
                screenName: win.modelData.name
                trayWindow: win
                x: Theme.fullBar ? 0 : Math.round((body.width - width) / 2)
                width: Theme.fullBar ? body.width : implicitWidth
            }

            // ── a new notification, while closed ──
            Column {
                id: toastArea
                x: win.pad
                y: Theme.islandH
                width: body.width - 2 * win.pad
                spacing: 6
                opacity: win.toastOn ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: win.toastOn ? 260 : 120 } }
                HoverHandler { onHoveredChanged: Notifs.hold = hovered }
                Loader {
                    width: parent.width
                    active: win.toast !== null
                    sourceComponent: NotificationCard {
                        notif: win.toast
                        onClosed: Notifs.dismissPopup(win.toast)
                    }
                }
                Pressable {
                    visible: Notifs.popups.length > 1
                    width: moreLabel.implicitWidth + 24
                    height: 26
                    color: Theme.containerHigh
                    onClicked: HubState.toggle("notifications", win.modelData.name)
                    Label { id: moreLabel; anchors.centerIn: parent; text: "+" + (Notifs.popups.length - 1) + " more"; font.pixelSize: Theme.sizeSmall; strong: true }
                }
            }

            // ── open: the search field, the page tabs, the page ──
            Item {
                id: openArea
                // in the island, or in the floating card
                parent: !win.docked ? floatCard : (Theme.fullBar ? dropBody : body)
                x: win.pad
                y: win.docked && !Theme.fullBar ? Theme.islandH + 2 : win.pad
                width: parent.width - 2 * win.pad
                height: parent.height - y - win.pad
                opacity: win.shown ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: win.shown ? 260 : 90 } }

                Rectangle {
                    id: field
                    width: parent.width
                    height: win.fieldH
                    radius: Theme.corner(height)
                    color: win.usesQuery || win.tabbed ? Theme.containerHigh : "transparent"
                    // a menu of its own: its name instead of a search field
                    Label {
                        visible: !win.usesQuery && !win.tabbed
                        anchors.left: fieldIcon.right; anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: (win.pageInfo[HubState.page] || win.pageInfo.search).title
                        strong: true
                        font.pixelSize: Theme.sizeTitle + 2
                    }
                    Pressable {
                        visible: !win.usesQuery && !win.tabbed
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: 36; height: 36
                        color: hovered ? Theme.containerHigh : "transparent"
                        onClicked: HubState.close()
                        Icon { anchors.centerIn: parent; name: "close"; size: 20; color: Theme.subtext }
                    }
                    Icon {
                        id: fieldIcon
                        x: 16
                        anchors.verticalCenter: parent.verticalCenter
                        name: (win.pageInfo[HubState.page] || win.pageInfo.search).icon
                        size: 20
                        color: Theme.accent
                    }
                    TextInput {
                        id: query
                        anchors.left: fieldIcon.right
                        anchors.leftMargin: 12
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeTitle
                        color: Theme.text
                        selectionColor: Theme.selected
                        clip: true
                        focus: win.shown
                        // still takes the keys (Esc, arrows for the page) on a menu without a search
                        opacity: win.usesQuery || win.tabbed ? 1 : 0
                        Label {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: query.text === ""
                            text: HubState.page === "search" ? "Search apps   ·   > run   ·   : emoji   ·   / files" : (HubState.page === "clipboard" ? "Filter the clipboard" : (HubState.page === "keys" ? "Filter keybinds" : "Type to search"))
                            muted: true
                            font.pixelSize: Theme.sizeTitle
                        }
                        onTextEdited: {
                            if (text === "" || win.usesQuery) return;
                            if (win.tabbed) HubState.page = "search"; else text = "";
                        }
                        Keys.onEscapePressed: { if (text !== "") text = ""; else HubState.close(); }
                        Keys.onTabPressed: event => { if (win.tabbed) { HubState.step((event.modifiers & Qt.ShiftModifier) ? -1 : 1); event.accepted = true; } else event.accepted = false; }
                        Keys.onBacktabPressed: event => { if (win.tabbed) HubState.step(-1); else event.accepted = false; }
                        Keys.forwardTo: win.currentPage ? [win.currentPage] : []
                    }
                }

                // the tabs: the current page named on a tonal pill, the rest as icons
                Item {
                    id: tabs
                    y: field.height + 8
                    visible: !win.compact
                    clip: true
                    width: parent.width
                    height: 38
                    readonly property real gap: 4
                    readonly property real iconW: Math.min(46, (width - 170 - gap * (HubState.pages.length - 1)) / (HubState.pages.length - 1))
                    readonly property real wideW: width - (HubState.pages.length - 1) * (iconW + gap)
                    readonly property int cur: HubState.pages.indexOf(HubState.page)
                    function tabX(i) { return i * (iconW + gap) + (i > cur ? wideW - iconW : 0); }
                    Rectangle {
                        x: tabs.tabX(tabs.cur)
                        width: tabs.wideW
                        height: parent.height
                        radius: height / 2
                        color: Theme.accentContainer
                        Behavior on x { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
                    }
                    Repeater {
                        model: HubState.pages
                        Pressable {
                            required property string modelData
                            required property int index
                            readonly property bool isCur: HubState.page === modelData
                            x: tabs.tabX(index)
                            width: isCur ? tabs.wideW : tabs.iconW
                            height: tabs.height
                            clip: true
                            color: "transparent"
                            radius: height / 2
                            Behavior on x { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
                            onClicked: { HubState.page = modelData; query.forceActiveFocus(); }
                            Row {
                                anchors.centerIn: parent
                                spacing: 6
                                Icon {
                                    name: win.pageInfo[modelData].icon
                                    size: 18
                                    filled: parent.parent.isCur
                                    color: parent.parent.isCur ? Theme.onAccentContainer : Theme.subtext
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Label {
                                    visible: parent.parent.isCur
                                    text: win.pageInfo[modelData].title
                                    strong: true
                                    color: Theme.onAccentContainer
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }
                    }
                }

                // the pages: built on the screen the island is open on, each when first opened,
                // and let go once it closes
                Item {
                    id: pages
                    y: win.compact ? field.height + 8 : tabs.y + tabs.height + 10
                    width: parent.width
                    height: parent.height - y
                    Repeater {
                        model: HubState.pages
                        Loader {
                            id: pl
                            required property string modelData
                            readonly property string pageId: modelData
                            property bool seen: false
                            width: pages.width
                            active: win.here && win.open && (seen || HubState.page === modelData)
                            source: "../hub/" + modelData.charAt(0).toUpperCase() + modelData.slice(1) + "Page.qml"
                            onLoaded: {
                                Qt.callLater(() => pl.seen = true);
                                if (item.hasOwnProperty("query")) item.query = Qt.binding(() => query.text);
                                if (modelData === "search") item.done.connect(() => { query.text = ""; HubState.close(); });
                            }
                            Connections { target: win; function onOpenChanged() { if (!win.open) pl.seen = false; } }
                        }
                    }
                }
            }
        }
    }

    // ── the menu dropping out of a full-width bar: a shape hanging from the bar's bottom edge ──
    IslandShape {
        id: drop
        visible: Theme.fullBar && height > 1
        bodyW: win.dropped ? win.openW : 160
        height: win.dropped ? win.openH - Theme.islandH : 0
        r: Theme.islandRadius
        x: Math.round((win.width - width) / 2)
        y: Theme.islandH - 1
        Behavior on bodyW { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
        Behavior on height { NumberAnimation { duration: win.dropped ? Theme.springMs : 220; easing.type: Easing.BezierSpline; easing.bezierCurve: win.dropped ? Theme.springCurve : Theme.exitCurve } }
        onHeightChanged: if (!win.shown && height <= 1) win.wasOpen = false
        MouseArea { anchors.fill: parent }
        Item { id: dropBody; x: drop.e; width: drop.bodyW; height: drop.height; clip: true }
    }

    // ── the floating card (menus in the middle or on the right) ──
    Rectangle {
        id: floatCard
        visible: !win.docked && opacity > 0.01
        width: win.openW + 2 * win.pad
        height: win.openH - Theme.islandH + win.pad
        Behavior on width { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
        Behavior on height { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
        // where: the middle, an edge (left, right, bottom; "top-center" under the bar) or a corner
        readonly property bool onLeft: win.place.indexOf("left") !== -1
        readonly property bool onRight: win.place.indexOf("right") !== -1
        readonly property bool onTop: win.place.startsWith("top")
        readonly property bool onBottom: win.place.startsWith("bottom")
        x: onLeft ? 16 : (onRight ? win.width - width - 16 : Math.round((win.width - width) / 2))
        y: onTop ? Theme.islandH + 14 : (onBottom ? win.height - height - 16 : Math.max(Theme.islandH + 14, Math.round((win.height - height) / 2)))
        radius: Theme.islandRadius
        color: Theme.frame
        border.width: Theme.outlineW
        border.color: Theme.outlineColor
        opacity: win.shown ? 1 : 0
        scale: win.shown ? 1 : 0.94
        transformOrigin: onTop ? (onLeft ? Item.TopLeft : (onRight ? Item.TopRight : Item.Top)) : (onBottom ? (onLeft ? Item.BottomLeft : (onRight ? Item.BottomRight : Item.Bottom)) : (onLeft ? Item.Left : (onRight ? Item.Right : Item.Center)))
        // it slides in from its side
        transform: Translate {
            x: (win.shown ? 0 : 1) * (floatCard.onLeft ? -40 : (floatCard.onRight ? 40 : 0))
            y: (win.shown ? 0 : 1) * (floatCard.onTop ? -30 : (floatCard.onBottom ? 40 : 0))
            Behavior on x { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
            Behavior on y { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
        }
        Behavior on opacity { NumberAnimation { duration: win.shown ? 220 : 160 } }
        Behavior on scale { NumberAnimation { duration: win.shown ? Theme.springMs : 160; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.springCurve : Theme.exitCurve } }
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: Theme.shadowBlur; shadowColor: Theme.shadowColor; shadowVerticalOffset: Theme.shadowY; shadowHorizontalOffset: Theme.shadowX }
        MouseArea { anchors.fill: parent }
        // pages let go once it has faded out
        onOpacityChanged: if (!win.shown && opacity < 0.01) win.wasOpen = false
    }

    // open, or still shrinking back
    readonly property bool open: shown || wasOpen

    onShownChanged: if (shown) { wasOpen = true; query.text = HubState.preset; HubState.preset = ""; query.forceActiveFocus(); }
    Connections {
        target: HubState
        function onPresetRequested() { if (win.shown && HubState.preset !== "") { query.text = HubState.preset; HubState.preset = ""; } }
    }

    // blur behind it (Theme → Effects), shaped like it
    BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
    Region {
        id: blurShape
        item: body
        radius: island.rr
        Region { item: win.dropped || drop.height > 1 ? dropBody : null; radius: drop.rr }
        Region { item: floatCard.visible ? floatCard : null; radius: floatCard.radius }
    }
}
