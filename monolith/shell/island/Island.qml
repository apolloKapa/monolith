import QtQuick
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
    WlrLayershell.layer: WlrLayer.Top
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
        "search":        { icon: "search",         title: "Search",        w: 680 },
        "quick":         { icon: "page_info",      title: "Control center", w: 1040 },
        "notifications": { icon: "notifications",  title: "Notifications", w: 680 },
        "media":         { icon: "music_note",     title: "Media",         w: 720 },
        "calendar":      { icon: "calendar_month", title: "Calendar",      w: 780 },
        "sound":         { icon: "volume_up",      title: "Sound",         w: 680 },
        "network":       { icon: "wifi",           title: "Network",       w: 680 },
        "clipboard":     { icon: "content_paste",  title: "Clipboard",     w: 680 },
        "windows":       { icon: "select_window",  title: "Windows",       w: 860 },
        "capture":       { icon: "screenshot_region", title: "Capture",    w: 680 },
        "tools":         { icon: "construction",   title: "Tools",         w: 900 },
        "wellbeing":     { icon: "self_improvement", title: "Wellbeing",   w: 860 },
        "keys":          { icon: "keyboard_command_key", title: "Keys",    w: 860 },
        "wallpaper":     { icon: "wallpaper",      title: "Wallpaper",     w: 860 },
        "settings":      { icon: "settings",       title: "Settings",      w: 860 }
    })
    readonly property Item currentLoader: pages.children.find(l => l.pageId === HubState.page) || null
    readonly property Item currentPage: currentLoader ? currentLoader.item : null

    readonly property real pad: Theme.islandPad
    readonly property real fieldH: 46
    readonly property real tabsH: 38
    // the body's size: the bar's when collapsed, the page's when open
    readonly property real openW: Math.max(bar.implicitWidth, (pageInfo[HubState.page] || pageInfo.search).w)
    readonly property real openH: Math.min(height - 40, Theme.islandH + fieldH + 8 + tabsH + 10 + (currentPage ? currentPage.implicitHeight : 200) + pad)
    readonly property real restW: Math.max(Theme.islandMinW, bar.implicitWidth)

    // ── the island ──
    IslandShape {
        id: island
        bodyW: win.shown ? win.openW : win.restW
        height: win.shown ? win.openH : Theme.islandH
        r: win.shown ? Theme.islandRadius : height / 2
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
                x: Math.round((body.width - width) / 2)
                width: implicitWidth
            }

            // ── open: the search field, the page tabs, the page ──
            Item {
                id: openArea
                x: win.pad
                y: Theme.islandH + 2
                width: body.width - 2 * win.pad
                height: body.height - y - win.pad
                opacity: win.shown ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: win.shown ? 260 : 90 } }

                Rectangle {
                    id: field
                    width: parent.width
                    height: win.fieldH
                    radius: Theme.corner(height)
                    color: Theme.containerHigh
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
                        Label {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: query.text === ""
                            text: HubState.page === "search" ? "Search apps   ·   > run   ·   : emoji   ·   / files" : (HubState.page === "clipboard" ? "Filter the clipboard" : (HubState.page === "keys" ? "Filter keybinds" : "Type to search"))
                            muted: true
                            font.pixelSize: Theme.sizeTitle
                        }
                        onTextEdited: if (text !== "" && !(win.currentPage && win.currentPage.usesQuery)) HubState.page = "search"
                        Keys.onEscapePressed: { if (text !== "") text = ""; else HubState.close(); }
                        Keys.onTabPressed: event => { HubState.step((event.modifiers & Qt.ShiftModifier) ? -1 : 1); event.accepted = true; }
                        Keys.onBacktabPressed: HubState.step(-1)
                        Keys.forwardTo: win.currentPage ? [win.currentPage] : []
                    }
                }

                // the tabs: the current page named on a tonal pill, the rest as icons
                Item {
                    id: tabs
                    y: field.height + 8
                    width: parent.width
                    height: win.tabsH
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
                    y: tabs.y + tabs.height + 10
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

    // open, or still shrinking back
    readonly property bool open: shown || island.height > Theme.islandH + 2

    onShownChanged: if (shown) { query.text = HubState.preset; HubState.preset = ""; query.forceActiveFocus(); }
    Connections {
        target: HubState
        function onPresetRequested() { if (win.shown && HubState.preset !== "") { query.text = HubState.preset; HubState.preset = ""; } }
    }
}
