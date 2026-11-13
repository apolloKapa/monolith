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
    // (folded away while a picture is being chosen: the file dialog opens under this layer)
    readonly property bool shown: HubState.open && here && !Pictures.picking

    WlrLayershell.namespace: "monolith-island"
    // above fullscreen windows while open (a keybind over a game or video still shows it)
    WlrLayershell.layer: overlay ? WlrLayer.Overlay : WlrLayer.Top
    readonly property bool overlay: shown || wasOpen || toastOn
    onOverlayChanged: if (overlay) Qt.callLater(HubState.raisedOverlay)
    // Settings is a window you work in: clicks elsewhere go to your other windows and don't
    // close it, and it takes the keyboard only when you click into it (Escape or its bar
    // button closes it)
    readonly property bool pinned: shown && HubState.page === "settings"
    WlrLayershell.keyboardFocus: shown && !HubState.authOpen ? (pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // collapsed only the island takes the mouse; open, a click anywhere else closes it
    mask: win.pinned ? pinnedMask : plainMask
    // (no bar on this screen: nothing takes clicks there, unless a notification is showing)
    Region {
        id: plainMask
        item: win.shown ? fullArea : (!(win.barHere || win.toastGrows) ? null : (win.tucked ? sensor : island))
        // a notification out of a full-width bar, or under a floating one
        Region { item: !win.shown && drop.height > 1 ? dropBody : null }
        Region { item: !win.shown && toastCard.visible ? toastCard : null }
    }
    Region {
        id: pinnedMask
        item: island
        // (the card as it is now, zoom included: taken from the card itself, the region was read
        // once while it was still zooming in from 94 % and the card's edge then let clicks through)
        Region {
            readonly property bool on: floatCard.visible
            readonly property real k: floatCard.scale
            width: on ? Math.ceil(floatCard.width * k) : 0
            height: on ? Math.ceil(floatCard.height * k) : 0
            x: Math.floor(floatCard.x + (floatCard.width - floatCard.width * k) * blurBox.fx)
            y: Math.floor(floatCard.y + (floatCard.height - floatCard.height * k) * blurBox.fy)
        }
        Region { item: win.dropped || drop.height > 1 ? dropBody : null }
    }
    Item { id: fullArea; anchors.fill: parent }

    // auto-hide (Settings → Status line): the collapsed island slides up, and comes back when
    // the pointer touches the top edge
    readonly property bool autohide: Store.get("status.autohide", false) === true
    readonly property bool tucked: autohide && !win.shown && !sensorHover.hovered && !barHover.hovered
    Item { id: sensor; x: island.x; y: Theme.barBottom ? win.height - 3 : 0; width: island.width; height: 3; HoverHandler { id: sensorHover } }
    readonly property bool bottom: Theme.barBottom

    MouseArea { anchors.fill: parent; enabled: win.shown && !win.pinned; onClicked: HubState.close() }

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
        "wellbeing":     { icon: "self_improvement", title: "Wellbeing",   w: 960 },
        "keys":          { icon: "keyboard_command_key", title: "Keys",    w: 860 },
        "settings":      { icon: "settings",       title: "Settings",      w: 1140 }
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
    // (a menu growing out of the island is never narrower than the bar in it; a card or a menu
    // dropping out of a full bar keeps its own width: following the bar's, it changed by a few
    // pixels whenever a module's text did, the CPU % or the clock, and the menu kept resizing)
    // never wider than the screen (Settings is 1140 wide: on a 1024 px screen it was cut off on
    // both sides); a floating card keeps clear of a side bar and the screen's edges
    readonly property real maxOpenW: docked ? width - 2 * Theme.islandEar - 16 : width - floatCard.leftRoom - floatCard.rightRoom - 2 * pad
    readonly property real openW: Math.min(maxOpenW, grownLike ? Math.max(bar.needWidth, (pageInfo[HubState.page] || pageInfo.search).w) : (pageInfo[HubState.page] || pageInfo.search).w)
    readonly property bool grownLike: place === "top" && !Theme.barFloats && !side && !Theme.fullBar
    // as tall as the page wants, but never past the screen: a floating card keeps clear of the bar
    // and the screen's edges (on a short screen, 720 px, it ran off the bottom)
    readonly property real maxOpenH: docked ? height - 40 : height - floatCard.topRoom - floatCard.bottomRoom + Theme.islandH - pad
    readonly property real openH: Math.min(maxOpenH, Theme.islandH + fieldH + (compact ? 8 : 8 + tabsH + 10) + (currentPage ? currentPage.implicitHeight : 200) + pad)
    readonly property real restW: Theme.barWidth(width, bar.needWidth)
    readonly property bool barShort: restW < width - 2 * Theme.barMargin - 1   // a full bar that doesn't reach the screen's sides
    // the bar can be off on some screens (Settings → Bar); menus still open there
    // (a bar down the side is its own window, SideBar: the island then only holds the menus)
    readonly property bool side: Theme.barSide !== ""
    readonly property bool barHere: !side && (Store.get("bar.hiddenScreens", []) || []).indexOf(modelData.name) === -1
    // the bar's own background shows when it's open, or per its opacity setting
    readonly property bool barSolid: shown || toastOn || Theme.barOpacity >= 0.99

    // where menus open (Settings → Menus): out of the island (top), or as a floating card in
    // the middle of the screen or on the right; then the island stays a bar
    // (each menu can have its own place, Settings → Menus & launcher)
    readonly property string place: Store.get("menus.positions." + HubState.page, "") || Store.get("menus.position", "top")
    // a floating bar (Solid, Modular) has nothing to grow out of: its menus open just under it
    // (nor does a bar down the side: its menus open beside it)
    readonly property bool docked: place === "top" && !Theme.barFloats && !side
    // the island grows into the menu; a full-width bar stays put and the menu drops out of it
    readonly property bool grown: shown && docked && !Theme.fullBar
    readonly property bool dropped: shown && docked && Theme.fullBar

    // a new notification drops out of the island (on the screen you're using) while it's closed
    // (on the screen it came up on: it stays there when you switch windows to another screen)
    readonly property var myToasts: Notifs.popupsOn(modelData.name, Quickshell.screens.length ? Quickshell.screens[0].name : "").filter(p => !Notifs.leaving[p.id])
    readonly property bool toastOn: !side && !shown && myToasts.length > 0 && Store.get("notifications.style", "island") !== "corner"
    readonly property var toast: myToasts.length > 0 ? myToasts[0] : null
    // where it shows, like the menus of each bar: the island grows into it; a full-width bar
    // stays put and it drops out of the bar as its own shape; a floating bar (Solid, Modular)
    // gets a card just under it. (Growing a full or floating bar made the whole bar come down.)
    // Kept while it goes away, so it leaves from where it came.
    // (an island spread wide is a full bar too: growing it brought the whole top down)
    readonly property string toastWhere: Theme.barFloats ? "card" : (Theme.fullBar || restW > 760 ? "drop" : "island")
    property string toastHost: toastWhere
    onToastOnChanged: if (toastOn) toastHost = toastWhere
    onToastWhereChanged: if (toastOn) toastHost = toastWhere
    readonly property bool toastGrows: toastOn && toastHost === "island"
    // (holds them while the pointer is on one, only while one shows: see Notifs.holders)
    readonly property bool toastHolding: toastOn && toastHover.hovered
    onToastHoldingChanged: Notifs.setHold("island:" + modelData.name, toastHolding)
    Component.onDestruction: Notifs.setHold("island:" + modelData.name, false)
    readonly property real toastW: Math.min(560, width - 40)
    // pages stay loaded while the island shrinks back after being open (not for a toast)
    property bool wasOpen: false

    // ── the island ──
    IslandShape {
        id: island
        bodyW: win.grown ? win.openW : (win.toastGrows ? Math.max(win.restW, 520) : win.restW)
        height: win.grown ? win.openH : (win.toastGrows ? Theme.islandH + toastArea.implicitHeight + win.pad : Theme.islandH)
        r: win.grown || win.toastGrows ? Theme.islandRadius : (Theme.fullBar ? (win.barShort ? Theme.islandRadius / 2 : 0) : Theme.barRound(height))
        // a floating bar draws its own rounded background (Solid) or none at all (Modular: its
        // sections have pills), so the hanging shape stays empty
        // the Frame paints the bar's background itself (as part of one shape), so here it's empty
        readonly property bool empty: Theme.barFloats || (Theme.frameBand && !win.grown)
        fill: empty ? "transparent" : (win.barSolid ? Theme.frame : Qt.alpha(Theme.frame, Theme.frame.a * Theme.barOpacity))
        shadow: !empty && (win.barSolid || Theme.barOpacity > 0.3)
        outline: !empty
        // a screen with the bar turned off keeps it off while a menu is open, unless the menu
        // opens out of the bar itself (a floating menu has nothing to do with the bar)
        opacity: win.barHere || win.toastOn || (win.shown && win.docked) ? 1 : 0
        ear: Theme.fullBar && !win.grown ? 0 : Theme.islandEar
        onHeightChanged: if (!win.shown && height <= Theme.islandH + 1) win.wasOpen = false
        x: Math.round((win.width - width) / 2)
        flipped: win.bottom
        y: win.bottom ? win.height - height - (win.tucked ? -Theme.islandH - Theme.barMargin + 3 : Theme.barMargin)
                      : (win.tucked ? -Theme.islandH - Theme.barMargin + 3 : Theme.barMargin)
        Behavior on bodyW { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sizeCurve } }
        Behavior on height { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sizeCurve } }
        Behavior on r { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        Behavior on y { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }

        // Solid: one rounded floating bar; Modular gets one too while a notification drops out
        Rectangle {
            id: solidBg
            anchors.fill: parent
            visible: Theme.barFloats && (Theme.barStyle === "solid" || win.toastGrows)
            radius: win.toastGrows ? Theme.islandRadius : Theme.barRound(height)
            color: win.barSolid || win.toastOn ? Theme.frame : Qt.alpha(Theme.frame, Theme.frame.a * Theme.barOpacity)
            border.width: Theme.outlineW
            border.color: Theme.outlineColor
            CardShadow { visible: win.barSolid || win.toastOn || Theme.barOpacity > 0.3 }
        }
        // Frame: a notification dropping out gets a background below the bar only (the frame
        // already paints the bar's strip; painting it again would show darker in see-through styles)
        Item {
            visible: Theme.frameBand && win.toastGrows
            x: island.e; y: win.bottom ? 0 : Theme.islandH
            width: island.bodyW; height: Math.max(0, island.height - Theme.islandH)
            clip: true
            Rectangle {
                y: win.bottom ? 0 : -radius
                width: parent.width; height: parent.height + radius
                radius: Theme.islandRadius
                color: Theme.frame
                border.width: Theme.outlineW; border.color: Theme.outlineColor
            }
        }
        // clicks on the island stay on the island
        MouseArea { anchors.fill: parent }

        // everything inside sits in the body (between the ears) and is clipped to it
        Item {
            id: body
            x: island.e
            width: island.bodyW
            height: island.height
            // only while it's bigger than the bar (a menu or notification, or shrinking back):
            // at rest the clip would cut the bar's own shadows (Modular's pills) with a hard edge
            clip: win.shown || win.toastGrows || island.height > Theme.islandH + 0.5

            HoverHandler { id: barHover }
            // Theme → Effects (grain, edge light) while it's a menu
            PanelFx { anchors.fill: parent; radius: island.rr; visible: win.grown && (Theme.fxGrain || Theme.fxEdge) }

            // the bar row, centred at the top
            IslandBar {
                id: bar
                screenName: win.modelData.name
                trayWindow: win
                y: win.bottom ? body.height - Theme.islandH : 0
                x: Theme.fullBar ? 0 : Math.round((body.width - width) / 2)
                width: Theme.fullBar ? body.width : (Theme.barSpread ? Math.max(needWidth, win.restW) : implicitWidth)
            }

            // ── a new notification, while closed ──
            Column {
                id: toastArea
                parent: win.toastHost === "card" ? toastCard : (win.toastHost === "drop" ? dropBody : body)
                x: win.pad
                y: win.toastHost === "island" ? (win.bottom ? body.height - Theme.islandH - height : Theme.islandH)
                   : (win.toastHost === "drop" ? (win.bottom ? win.pad : win.pad * 0.5) : win.pad)
                width: parent.width - 2 * win.pad
                spacing: 6
                // it drops down out of the island (rises out of it when the bar is at the bottom)
                // as the island opens up, with a little bounce, and goes back up into it
                // (named `fall`, and always read as toastArea.fall: this file has an item with the
                // id `drop`, and ids win over properties, so `drop * 1.8` was that item times 1.8,
                // NaN: the notification was invisible inside an island that had opened for it)
                property real fall: win.toastOn ? 1 : 0
                Behavior on fall { NumberAnimation { duration: win.toastOn ? Theme.ms(460) : Theme.popOutMs; easing.type: win.toastOn ? Easing.OutBack : Easing.InCubic; easing.overshoot: 1.1 } }
                opacity: Math.max(0, Math.min(1, toastArea.fall * 1.8))
                visible: opacity > 0.01
                transform: Translate { y: (1 - toastArea.fall) * (win.bottom ? 1 : -1) * (toastArea.height * 0.7 + 20) }
                HoverHandler { id: toastHover }
                Loader {
                    width: parent.width
                    active: win.toast !== null
                    sourceComponent: NotificationCard {
                        notif: win.toast
                        screenName: win.modelData.name
                        onClosed: Notifs.dismissPopup(win.toast, flying)
                    }
                }
                Pressable {
                    visible: win.myToasts.length > 1
                    width: moreLabel.implicitWidth + 24
                    height: 26
                    color: Theme.containerHigh
                    onClicked: HubState.toggle("notifications", win.modelData.name)
                    Label { id: moreLabel; anchors.centerIn: parent; text: "+" + (win.myToasts.length - 1) + " more"; font.pixelSize: Theme.sizeSmall; strong: true }
                }
            }

            // ── open: the search field, the page tabs, the page ──
            Item {
                id: openArea
                // in the island, or in the floating card
                parent: !win.docked ? floatCard : (Theme.fullBar ? dropBody : body)
                // laid out at the size the menu is going to (not the size it has while it grows or
                // shrinks there), so the page doesn't reflow and seem to rescale on every change;
                // kept in the middle while the card around it catches up
                readonly property real goalW: !win.docked ? Math.round(win.openW + 2 * win.pad) : win.openW
                readonly property real goalH: !win.docked ? Math.round(win.openH - Theme.islandH + win.pad) : (Theme.fullBar ? win.openH - Theme.islandH : win.openH)
                x: Math.round((parent.width - width) / 2)
                y: win.docked && !Theme.fullBar && !win.bottom ? Theme.islandH + 2 : win.pad
                width: (win.shown ? goalW : parent.width) - 2 * win.pad
                height: (win.shown ? goalH : parent.height) - y - (win.docked && !Theme.fullBar && win.bottom ? Theme.islandH + 2 : win.pad)
                opacity: win.shown ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { enabled: !HubState.snap; NumberAnimation { duration: win.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
                // and a little zoom, from the bar's side
                scale: win.shown || Theme.fxUnfold ? 1 : Theme.popScale
                transformOrigin: win.bottom && win.docked ? Item.Bottom : Item.Top
                Behavior on scale { enabled: !HubState.snap; NumberAnimation { duration: win.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.enterCurve : Theme.exitCurve } }
                // Unfold (Theme → Effects): the menu opens out of a thin bright line through its
                // middle and folds back into it
                // (a floating menu unfolds whole, card and all: see floatCard; here it's the
                // content of a menu growing out of the bar)
                readonly property bool unfolds: Theme.fxUnfold && win.docked
                property real unfold: win.shown ? 1 : 0
                Behavior on unfold { enabled: Theme.fxUnfold; NumberAnimation { duration: win.shown ? Theme.ms(420) : Theme.ms(200); easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.enterCurve : Theme.exitCurve } }
                transform: Scale {
                    origin.x: openArea.width / 2; origin.y: openArea.height / 2
                    yScale: openArea.unfolds ? Math.max(0.012, openArea.unfold) : 1
                    xScale: openArea.unfolds ? 0.985 + 0.015 * openArea.unfold : 1
                }
                Rectangle {
                    z: 100
                    visible: openArea.unfolds && openArea.unfold < 0.98 && openArea.unfold > 0.001
                    anchors.centerIn: parent
                    width: parent.width * (0.4 + 0.6 * Math.min(1, openArea.unfold * 3))
                    height: Math.max(2, 3 / Math.max(0.05, openArea.unfold))
                    radius: height / 2
                    color: Theme.accent
                    opacity: 1 - openArea.unfold
                }

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
                    Rectangle {
                        id: fieldTile
                        readonly property bool on: !win.usesQuery && !win.tabbed
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32
                        radius: Theme.corner(height, -2)
                        color: on ? Theme.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.shortMs } }
                        SequentialAnimation {
                            id: tilePop
                            NumberAnimation { target: fieldTile; property: "scale"; from: 0.6; to: 1; duration: Theme.ms(380); easing.type: Easing.OutBack }
                        }
                        NumberAnimation { id: tileTurn; target: fieldTile; property: "rotation"; from: -20; to: 0; duration: Theme.ms(380); easing.type: Easing.OutCubic }
                        Connections { target: HubState; function onPageChanged() { tilePop.restart(); tileTurn.restart(); } }
                    }
                    Icon {
                        id: fieldIcon
                        x: 14
                        anchors.verticalCenter: parent.verticalCenter
                        name: (win.pageInfo[HubState.page] || win.pageInfo.search).icon
                        size: 20
                        filled: fieldTile.on
                        color: fieldTile.on ? Theme.onAccent : Theme.accent
                        scale: fieldTile.scale
                        rotation: fieldTile.rotation
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
                            if (win.tabbed) HubState.go("search"); else text = "";
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
                            onClicked: { HubState.go(modelData); query.forceActiveFocus(); }
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
                // and kept (hidden) for a few minutes after it closes, so opening it again doesn't
                // build it all over again (on an older laptop that was a good part of a second
                // before anything moved). Search, the launcher, is built soon after the shell
                // starts and kept.
                Item {
                    id: pages
                    y: win.compact ? field.height + 8 : tabs.y + tabs.height + 10
                    width: parent.width
                    height: parent.height - y
                    // (a page cut short by a small screen stays inside the card)
                    clip: !!win.currentPage && win.currentPage.implicitHeight > height + 1
                    Repeater {
                        model: HubState.pages
                        Loader {
                            id: pl
                            required property string modelData
                            readonly property string pageId: modelData
                            property bool seen: false
                            width: pages.width
                            // the room there is (a page's own height was used as is, so on a
                            // short screen it was laid out taller than the card and spilled out)
                            height: pages.height
                            active: win.here && (seen || (win.open && HubState.page === modelData))
                            source: "../hub/" + modelData.charAt(0).toUpperCase() + modelData.slice(1) + "Page.qml"
                            onLoaded: {
                                Qt.callLater(() => pl.seen = true);
                                if (item.hasOwnProperty("query")) item.query = Qt.binding(() => query.text);
                                if (modelData === "search") item.done.connect(() => { query.text = ""; HubState.close(); });
                            }
                            readonly property bool keep: modelData === "search"
                            Connections { target: win; function onOpenChanged() { if (win.open) letGo.stop(); else if (!pl.keep) letGo.restart(); } }
                            Timer { id: letGo; interval: 5 * 60 * 1000; onTriggered: if (!win.open) pl.seen = false }
                            // the launcher ready before it's first needed (when the shell has settled)
                            Timer { interval: 4000; running: pl.keep && win.here; onTriggered: pl.seen = true }
                        }
                    }
                }
            }
        }
    }

    // ── the menu dropping out of a full-width bar: a shape hanging from the bar's bottom edge ──
    IslandShape {
        id: drop
        visible: (Theme.fullBar || toasting) && height > 1
        // (a notification drops out of it too, when the bar is full width)
        readonly property bool toasting: !win.dropped && win.toastOn && win.toastHost === "drop"
        bodyW: win.dropped ? win.openW : (toasting ? win.toastW : 160)
        height: win.dropped ? win.openH - Theme.islandH : (toasting ? toastArea.implicitHeight + win.pad * 1.5 : 0)
        r: Theme.islandRadius
        x: Math.round((win.width - width) / 2)
        flipped: win.bottom
        // hanging from the bar's edge, wherever the bar sits (a margin round an island bar)
        y: win.bottom ? island.y - height + (Theme.see < 0.999 || Theme.barOpacity < 0.999 ? 0 : 1)
                      : island.y + Theme.islandH - (Theme.see < 0.999 || Theme.barOpacity < 0.999 ? 0 : 1)
        Behavior on bodyW { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sizeCurve } }
        Behavior on height { NumberAnimation { duration: win.dropped ? Theme.springMs : 220; easing.type: Easing.BezierSpline; easing.bezierCurve: win.dropped ? Theme.sizeCurve : Theme.exitCurve } }
        onHeightChanged: if (!win.shown && height <= 1) win.wasOpen = false
        MouseArea { anchors.fill: parent }
        Item { id: dropBody; x: drop.e; width: drop.bodyW; height: drop.height; clip: true }
    }

    // ── a notification under a floating bar (Solid, Modular): its own card ──
    SmoothRect {
        id: toastCard
        readonly property bool on: win.toastOn && win.toastHost === "card"
        width: win.toastW
        height: Math.round(toastArea.implicitHeight + 2 * win.pad)
        x: Math.round((win.width - width) / 2)
        y: win.bottom ? island.y - height - 8 : island.y + Theme.islandH + 8
        radius: Theme.islandRadius
        color: Theme.frame
        border.width: Theme.outlineW
        border.color: Theme.outlineColor
        clip: true
        opacity: on ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: toastCard.on ? Theme.fastMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sizeCurve } }
        CardShadow {}
        MouseArea { anchors.fill: parent }
    }

    // ── the floating card (menus in the middle or on the right) ──
    SmoothRect {
        id: floatCard
        visible: !win.docked && opacity > 0.01
        // whole pixels: a fractional card size blurs what's in it
        width: Math.round(win.openW + 2 * win.pad)
        height: Math.round(win.openH - Theme.islandH + win.pad)
        // morphs from one menu to the next while open; a menu opened fresh takes its own size
        // at once (it used to stretch from the last menu's size as it faded in)
        Behavior on width { enabled: !HubState.snap; NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sizeCurve } }
        Behavior on height { enabled: !HubState.snap; NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sizeCurve } }
        // where: the middle, an edge (left, right, bottom; "top-center" under the bar) or a corner
        // "top" means by the bar: next to it at the bottom when the bar is there
        // (by a bar down the side: beside it, in the middle of that edge)
        readonly property string spot: win.side && win.place.startsWith("top") ? Theme.barSide : (win.bottom && win.place.startsWith("top") ? "bottom" + win.place.slice(3) : win.place)
        readonly property bool onLeft: spot.indexOf("left") !== -1
        readonly property bool onRight: spot.indexOf("right") !== -1
        readonly property bool onTop: spot.startsWith("top")
        readonly property bool onBottom: spot.startsWith("bottom")
        // clear of the bar, wherever it is
        readonly property real leftRoom: 16 + (Theme.barSide === "left" ? Theme.sideRoom : 0)
        readonly property real rightRoom: 16 + (Theme.barSide === "right" ? Theme.sideRoom : 0)
        x: onLeft ? leftRoom : (onRight ? win.width - width - rightRoom : Math.round((win.width - width) / 2))
        readonly property real topRoom: win.bottom || win.side ? 16 : Theme.islandH + Theme.barMargin + 14
        readonly property real bottomRoom: win.bottom ? Theme.islandH + Theme.barMargin + 14 : 16
        y: onTop ? topRoom : (onBottom ? win.height - height - bottomRoom : Math.max(topRoom, Math.min(win.height - height - bottomRoom, Math.round((win.height - height) / 2))))
        radius: Theme.islandRadius
        color: Theme.frame
        border.width: Theme.outlineW
        border.color: Theme.outlineColor
        // fades in with a little zoom from where it sits, and out the same way
        // Unfold (Theme → Effects): instead, the whole card opens out of a thin bright line through
        // its middle and folds back into it
        readonly property real unfold: openArea.unfold
        opacity: Theme.fxUnfold ? (win.shown || unfold > 0.02 ? 1 : 0) : win.cardFade
        scale: Theme.fxUnfold ? 1 : Theme.popScale + (1 - Theme.popScale) * win.cardZoom
        transform: Scale {
            origin.x: floatCard.width / 2; origin.y: floatCard.height / 2
            yScale: Theme.fxUnfold ? Math.max(0.006, floatCard.unfold) : 1
            xScale: Theme.fxUnfold ? 0.96 + 0.04 * floatCard.unfold : 1
        }
        Rectangle {
            z: 100
            visible: Theme.fxUnfold && floatCard.unfold < 0.98 && floatCard.unfold > 0.001
            anchors.centerIn: parent
            width: parent.width * (0.5 + 0.5 * Math.min(1, floatCard.unfold * 3))
            height: Math.max(2, 3 / Math.max(0.02, floatCard.unfold))
            radius: height / 2
            color: Theme.accent
            opacity: 1 - floatCard.unfold
        }
        transformOrigin: onTop ? (onLeft ? Item.TopLeft : (onRight ? Item.TopRight : Item.Top)) : (onBottom ? (onLeft ? Item.BottomLeft : (onRight ? Item.BottomRight : Item.Bottom)) : (onLeft ? Item.Left : (onRight ? Item.Right : Item.Center)))
        CardShadow {}
        MouseArea { anchors.fill: parent }
        PanelFx { anchors.fill: parent; radius: floatCard.radius }
        // pages let go once it has faded out
        onOpacityChanged: if (!win.shown && opacity < 0.01) win.wasOpen = false
    }

    // open, or still shrinking back
    readonly property bool open: shown || wasOpen

    // the floating card's fade and zoom (0 hidden … 1 shown). Run as animations rather than
    // Behaviors so a menu opened fresh (HubState.snap) starts from hidden: it carried on from
    // wherever the last menu's closing had got to
    property real cardFade: 0
    property real cardZoom: 0
    ParallelAnimation {
        id: cardIn
        NumberAnimation { target: win; property: "cardFade"; to: 1; duration: Theme.popInMs; easing.type: Easing.OutCubic }
        NumberAnimation { target: win; property: "cardZoom"; to: 1; duration: Theme.popInMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
    }
    ParallelAnimation {
        id: cardOut
        NumberAnimation { target: win; property: "cardFade"; to: 0; duration: Theme.popOutMs; easing.type: Easing.OutCubic }
        NumberAnimation { target: win; property: "cardZoom"; to: 0; duration: Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve }
    }
    onShownChanged: {
        if (shown) { cardOut.stop(); if (HubState.snap) { cardFade = 0; cardZoom = 0; } cardIn.restart(); }
        else { cardIn.stop(); cardOut.restart(); }
    }
    Connections { target: win; function onShownChanged() { if (win.shown) win.opened(); } }
    function opened() { tilePop.restart(); tileTurn.restart(); wasOpen = true; query.text = HubState.preset; HubState.preset = ""; query.forceActiveFocus(); }
    Connections {
        target: HubState
        function onPresetRequested() { if (win.shown && HubState.preset !== "") { query.text = HubState.preset; HubState.preset = ""; } }
        function onRefocus() { if (win.shown) query.forceActiveFocus(); }
    }

    // blur behind it (Theme → Effects), shaped like it. Not over a fullscreen app: blurring a
    // game or a video under the menu on every frame made menus late there on older laptops
    readonly property bool overFullscreen: Niri.fullscreenOn(modelData.name)
    BackgroundEffect.blurRegion: Theme.blur && !overFullscreen ? blurShape : null
    Region {
        id: blurShape
        // (a screen with the bar turned off has no bar to blur behind: only its open menu)
        // (the Frame style's band is the frame's: it blurs behind itself. Blurred here too, niri's
        // blur showed the wallpaper over the frame, so the band didn't match the frame's sides)
        // each part is cut exactly like what's drawn there: a square blur showed as a lighter
        // patch round the corners of a rounded bar
        readonly property bool barOn: (win.barHere && !(Theme.frameBand && !win.grown)) || win.toastGrows || (win.shown && win.docked)
        // (these are worked out from where the bar is, not handed the bar's parts: a region taken
        // from an item only follows that item's own position and size, so when the bar slid away
        // (auto-hide) its parts didn't move themselves and the blur stayed behind where it was)
        // Solid (and Modular with a notification out of it): its rounded rectangle
        Region {
            readonly property bool on: blurShape.barOn && solidBg.visible
            x: island.x; y: island.y
            width: on ? island.width : 0; height: on ? island.height : 0
            radius: solidBg.radius
        }
        // Modular: only its pills (not the gaps between them)
        readonly property bool pillsOn: blurShape.barOn && !solidBg.visible && Theme.barStyle === "modular"
        readonly property real pillX: island.x + body.x + bar.x
        readonly property real pillY: island.y + body.y + bar.y
        Region {
            readonly property Item p: bar.leftPill
            readonly property bool on: blurShape.pillsOn && p.visible
            x: blurShape.pillX + p.x; y: blurShape.pillY + p.y
            width: on ? p.width : 0; height: on ? p.height : 0
            radius: p.radius
        }
        Region {
            readonly property Item p: bar.midPill
            readonly property bool on: blurShape.pillsOn && p.visible
            x: blurShape.pillX + p.x; y: blurShape.pillY + p.y
            width: on ? p.width : 0; height: on ? p.height : 0
            radius: p.radius
        }
        Region {
            readonly property Item p: bar.rightPill
            readonly property bool on: blurShape.pillsOn && p.visible
            x: blurShape.pillX + p.x; y: blurShape.pillY + p.y
            width: on ? p.width : 0; height: on ? p.height : 0
            radius: p.radius
        }
        // the hanging shapes (Island, Fill, Frame): square against the edge, its ears too
        EdgeBlur {
            on: blurShape.barOn && !island.empty
            edge: win.bottom ? "bottom" : "top"
            bx: island.x + island.e; by: island.y; bw: island.bodyW; bh: island.height
            r: island.rr; e: island.e
        }
        // the menu (or notification) dropping out of a full-width bar
        EdgeBlur {
            on: (win.dropped || drop.height > 1) && drop.visible
            edge: win.bottom ? "bottom" : "top"
            bx: drop.x + drop.e; by: drop.y; bw: drop.bodyW; bh: drop.height
            r: drop.rr; e: drop.e
        }
        Region { item: blurBox.on ? blurBox : null; radius: floatCard.blurRadius * blurBox.k }
        Region { item: toastCard.on && toastCard.opacity > 0.6 ? toastCard : null; radius: toastCard.blurRadius }
    }
    // Where the floating card's blur is. The blur can't fade: it's there or it isn't. Kept on
    // until the card had faded out, it stayed behind as an empty blurred box after the menu
    // was gone (and showed up before the menu did). So it's on only while the card is mostly
    // there: it goes the moment the menu starts closing, and comes once the card has come in.
    // Unfolding, it's as tall as the card is at that moment.
    Item {
        id: blurBox
        // (and only once the menu's own page is showing: the card comes in a moment before it,
        // and an empty blurred card read as a ghost of the menu)
        readonly property bool pageIn: !!win.currentPage && win.currentPage.opacity > 0.6
        readonly property bool on: !win.docked && pageIn && (Theme.fxUnfold ? floatCard.unfold > 0.04 : (win.shown && floatCard.opacity > 0.4))
        readonly property real part: Theme.fxUnfold ? Math.max(0.01, floatCard.unfold) : 1
        // the card zooms in and out from its own corner or side: the blur shrinks with it
        readonly property real k: floatCard.scale
        readonly property real fx: floatCard.onLeft ? 0 : (floatCard.onRight ? 1 : 0.5)
        readonly property real fy: floatCard.onTop ? 0 : (floatCard.onBottom ? 1 : 0.5)
        width: Math.round(floatCard.width * k)
        height: Math.round(floatCard.height * k * part)
        x: Math.round(floatCard.x + (floatCard.width - width) * fx)
        y: Math.round(floatCard.y + (floatCard.height * k - height) / 2 + (floatCard.height - floatCard.height * k) * fy)
    }
}
