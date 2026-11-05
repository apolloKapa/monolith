import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The hub: one floating card that every surface lives in. The header holds the search field
// and the page tabs; the body is the open page. Switching pages morphs the card to the new
// page's size instead of opening another panel.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property bool here: HubState.screenName === "" ? (Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]) : HubState.screenName === modelData.name
    readonly property bool shown: HubState.open && here

    WlrLayershell.namespace: "monolith-hub"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // open, or still closing
    readonly property bool open: shown || card.progress > 0.001
    visible: open
    mask: Region { item: shown ? fullArea : card }

    Item { id: fullArea; anchors.fill: parent }

    // click outside: close
    MouseArea {
        anchors.fill: parent
        enabled: win.shown
        onClicked: HubState.close()
    }

    readonly property var pageInfo: ({
        "search":        { icon: "search",         title: "Search",        w: 680 },
        "quick":         { icon: "tune",           title: "Quick",         w: 680 },
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
        "settings":      { icon: "settings",       title: "Settings",      w: 820 }
    })
    readonly property Item currentLoader: pages.children.find(l => l.pageId === HubState.page) || null
    readonly property Item currentPage: currentLoader ? currentLoader.item : null

    readonly property real pad: 10
    readonly property real headerH: 52
    readonly property real tabsH: 40
    readonly property real targetW: (pageInfo[HubState.page] || pageInfo.search).w
    readonly property real targetH: pad + headerH + 8 + tabsH + 10 + (currentPage ? currentPage.implicitHeight : 200) + pad

    Item {
        id: card
        // opening: grow from 92% and rise into place; closing: a quick fade and drop
        property real progress: win.shown ? 1 : 0
        Behavior on progress {
            NumberAnimation {
                duration: win.shown ? Theme.enterMs : Theme.exitMs
                easing.type: Easing.BezierSpline
                easing.bezierCurve: win.shown ? Theme.enterCurve : Theme.exitCurve
            }
        }

        width: win.targetW
        height: Math.min(win.targetH, win.height - 120)
        Behavior on width { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        Behavior on height { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        x: Math.round((win.width - width) / 2)
        y: Math.round(win.height * 0.16)
        opacity: Math.min(1, progress * 1.6)
        scale: 0.92 + 0.08 * progress
        transformOrigin: Item.Top
        transform: Translate { y: -24 * (1 - card.progress) }

        MouseArea { anchors.fill: parent }   // clicks on the card stay on the card

        Rectangle {
            id: surface
            anchors.fill: parent
            radius: Theme.corner(win.headerH, win.pad)
            color: Theme.card
            border.width: 1
            border.color: Theme.hairline
            clip: true

            // ── header: the search field, always there (typing on any page searches) ──
            Rectangle {
                id: header
                x: win.pad
                y: win.pad
                width: parent.width - 2 * win.pad
                height: win.headerH
                radius: Theme.corner(height)
                color: Theme.containerHigh

                Bubble {
                    id: pageBubble
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    size: parent.height - 16
                    icon: (win.pageInfo[HubState.page] || win.pageInfo.search).icon
                    on: true
                }
                TextInput {
                    id: query
                    anchors.left: pageBubble.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeTitle - 1
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
                        font.pixelSize: Theme.sizeTitle - 1
                    }
                    // typing searches, unless the page filters by it itself (Clipboard)
                    onTextEdited: if (text !== "" && !(win.currentPage && win.currentPage.usesQuery)) HubState.page = "search"
                    Keys.onEscapePressed: { if (text !== "") text = ""; else HubState.close(); }
                    Keys.onTabPressed: event => { HubState.step((event.modifiers & Qt.ShiftModifier) ? -1 : 1); event.accepted = true; }
                    Keys.onBacktabPressed: HubState.step(-1)
                    Keys.forwardTo: win.currentPage ? [win.currentPage] : []
                }
            }

            // ── tabs: one per page, a tonal pill that glides under the current one ──
            Item {
                id: tabs
                x: win.pad
                y: header.y + header.height + 8
                width: parent.width - 2 * win.pad
                height: win.tabsH
                // the current tab is wide and named; the rest share what's left as icons
                readonly property real gap: 4
                readonly property real iconW: Math.min(44, (width - 150 - gap * (HubState.pages.length - 1)) / (HubState.pages.length - 1))
                readonly property real wideW: width - (HubState.pages.length - 1) * (iconW + gap)
                readonly property int cur: HubState.pages.indexOf(HubState.page)
                function tabX(i) { return i * (iconW + gap) + (i > cur ? wideW - iconW : 0); }

                Rectangle {
                    x: tabs.tabX(tabs.cur)
                    width: tabs.wideW
                    height: parent.height
                    radius: Theme.corner(height)
                    color: Theme.selected
                    Behavior on x { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
                    Behavior on width { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
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
                        Behavior on x { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
                        Behavior on width { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
                        onClicked: { HubState.page = modelData; query.forceActiveFocus(); }
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon {
                                name: win.pageInfo[modelData].icon
                                size: 18
                                filled: HubState.page === modelData
                                color: HubState.page === modelData ? Theme.text : Theme.subtext
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Label {
                                visible: parent.parent.isCur
                                text: win.pageInfo[modelData].title
                                strong: HubState.page === modelData
                                color: HubState.page === modelData ? Theme.text : Theme.subtext
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                    }
                }
            }

            // ── the pages: only the current one shows; it fades in as the card morphs ──
            Item {
                id: pages
                x: win.pad
                y: tabs.y + tabs.height + 10
                width: parent.width - 2 * win.pad
                height: parent.height - y - win.pad

                // built only on the screen the hub is open on, each page when first opened;
                // all of them are let go again once the hub has closed (memory)
                Repeater {
                    model: HubState.pages
                    Loader {
                        id: pl
                        required property string modelData
                        readonly property string pageId: modelData
                        property bool seen: false
                        width: pages.width
                        active: win.here && win.open && (seen || HubState.page === modelData)
                        source: modelData.charAt(0).toUpperCase() + modelData.slice(1) + "Page.qml"
                        onLoaded: {
                            Qt.callLater(() => pl.seen = true);   // (later: not inside the "active" change)
                            if (item.hasOwnProperty("query")) item.query = Qt.binding(() => query.text);
                            if (modelData === "search") item.done.connect(() => { query.text = ""; HubState.close(); });
                        }
                        Connections { target: win; function onOpenChanged() { if (!win.open) pl.seen = false; } }
                    }
                }
            }
        }
    }

    // opening resets the search and takes the keyboard
    onShownChanged: if (shown) { query.text = HubState.preset; HubState.preset = ""; query.forceActiveFocus(); }
    Connections {
        target: HubState
        function onPresetRequested() { if (win.shown && HubState.preset !== "") { query.text = HubState.preset; HubState.preset = ""; } }
    }
}
