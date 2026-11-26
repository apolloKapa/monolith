import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
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
    // (a screenshot being taken over an open menu: the capture overlay has the keyboard)
    WlrLayershell.keyboardFocus: shown && !HubState.authOpen && !Capture.active ? (pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive) : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // collapsed only the island takes the mouse; open, a click anywhere else closes it
    mask: win.pinned ? pinnedMask : plainMask
    // (no bar on this screen: nothing takes clicks there, unless a notification is showing)
    Region {
        id: plainMask
        item: win.shown ? fullArea : (!(win.barHere || win.toastGrows) ? null : (win.tucked ? (win.covered ? null : sensor) : island))
        // a notification out of a full-width bar, or under a floating one
        Region { item: !win.shown && drop.height > 1 ? dropBody : null }
        // the sides a menu opens from by hover
        Region { item: senseL.live ? senseL : null }
        Region { item: senseR.live ? senseR : null }
        Region { item: senseB.live ? senseB : null }
        // the modules outside the bar
        Region { item: outLeft.visible ? outLeft : null }
        Region { item: outRight.visible ? outRight : null }
        Region { item: !win.shown && toastCard.visible ? toastCard : null }
    }
    Region {
        id: pinnedMask
        item: island
        Region { item: outLeft.visible ? outLeft : null }
        Region { item: outRight.visible ? outRight : null }
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
        // an open drop-down list in this window, also where it hangs past the card
        Region {
            readonly property var a: win.popHere ? HubState.popArea : null
            x: a ? Math.floor(a.x) : 0; y: a ? Math.floor(a.y) : 0
            width: a ? Math.ceil(a.w) + 1 : 0; height: a ? Math.ceil(a.h) + 1 : 0
        }
    }
    readonly property bool popHere: {
        const a = HubState.popArea;
        if (!a) return false;
        for (let p = a.owner; p; p = p.parent) if (p === floatCard || p === drop) return true;
        return false;
    }
    Item { id: fullArea; anchors.fill: parent }
    // Animations → Workspace switching → Glitch or the style's effect, and niri's Fade, Slide and
    // fade and Slide sideways (island/WorkspaceFade.qml): drawn in this window, under everything in it,
    // so it's over the windows and under the bar (a window of its own was made after the bar,
    // once the setting had loaded, and niri put it over the bar)
    Loader {
        anchors.fill: parent
        z: -1000
        active: { const st = (Store.get("animations.workspaceSwitch", {}) || {}).style; return st === "glitch" || st === "fx" || (!Niri.hyprland && ["fade", "slide", "slidefadevert"].indexOf(st) !== -1); }
        sourceComponent: WorkspaceFade { screenName: win.modelData.name }
    }

    // auto-hide (Settings → Status line): the collapsed island slides up, and comes back when
    // the pointer touches the top edge
    readonly property bool autohide: Store.get("status.autohide", false) === true
    // Hyprland: a window as big as the screen that isn't fullscreen (a game's borderless mode)
    // sits under the bar, so the bar slides away for it (real fullscreen covers the bar already);
    // the screen's top edge doesn't bring it back then, it would catch the game's mouse
    readonly property bool covered: Niri.hyprland && Niri.fullscreenOn(modelData.name)
    readonly property bool tucked: (autohide || covered) && !win.shown && (covered || (!sensorHover.hovered && !barHover.hovered))
    // the Frame, auto-hide: windows make room for the bar while it's out (island/Frame.qml)
    readonly property bool barIsOut: Theme.frameHide && barHere && !tucked && !covered
    onBarIsOutChanged: HubState.setBarOut(modelData.name, barIsOut)
    // (the Frame's border on the bar's edge is the whole strip you touch to bring the bar back)
    readonly property real sensorH: Theme.frameHide ? Math.max(3, Theme.frameW) : 3
    Item { id: sensor; x: Theme.frameHide ? 0 : island.x; y: Theme.barBottom ? win.height - win.sensorH : 0; width: Theme.frameHide ? win.width : island.width; height: win.sensorH; HoverHandler { id: sensorHover } }
    readonly property bool bottom: Theme.barBottom

    MouseArea { anchors.fill: parent; enabled: win.shown && !win.pinned; onClicked: HubState.close() }

    readonly property var pageInfo: ({
        "search":        { icon: "search",         title: "Search",        w: Number(Store.get("search.width", 640)) + (Desk.on ? 56 : 0) },
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

    // (more when the corners are very round: Theme.inset)
    readonly property real pad: Theme.inset(Theme.islandRadius, Theme.islandPad)
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
    readonly property bool grownLike: fromBar && !Theme.barFloats && !side && !Theme.fullBar
    // as tall as the page wants, but never past the screen: a floating card keeps clear of the bar
    // and the screen's edges (on a short screen, 720 px, it ran off the bottom)
    readonly property real maxOpenH: docked ? height - 40 : height - floatCard.topRoom - floatCard.bottomRoom + Theme.islandH - pad
    readonly property real openH: Math.min(maxOpenH, Theme.islandH + fieldH + (compact ? 8 : 8 + tabsH + 10) + pageH + pad)
    // the page's height; while a page is still being built (pages build in the background) the
    // last one's, so the card doesn't shrink to a guess and grow again
    property real pageH: 200
    readonly property real wantPageH: currentPage ? currentPage.implicitHeight : -1
    onWantPageHChanged: if (wantPageH >= 0) pageH = wantPageH
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
    // Two settings (Settings → Menus & launcher): out of the bar (menus.barPlace: off, or at the
    // bar's start, middle or end), else a floating place (menus.position). Each menu can have its own
    // too, the same two: menus.barPlaces.<menu> ("same" as the default, off, start, center, end)
    // and menus.positions.<menu> (a floating place; "" the default's). (Before each menu had the
    // two, menus.positions.<menu> held either: "bar-start" | "bar-center" | "bar-end", or a
    // floating place that also meant "not out of the bar". Still read that way where
    // menus.barPlaces.<menu> isn't set.)
    // (before there were two, "top" meant out of the bar, in the middle: it still does)
    // (out of a side of the screen: "left", "right", "bottom". The menu comes out through the
    // frame there, one piece with it; in the other bar styles, out of the screen's edge)
    readonly property var outPlaces: ["off", "start", "center", "end", "left", "right", "bottom"]
    readonly property string barPlaceDefault: {
        const b = String(Store.get("menus.barPlace", ""));
        if (outPlaces.indexOf(b) !== -1) return b;
        return String(Store.get("menus.position", "top")) === "top" ? "center" : "off";
    }
    readonly property string floatDefault: { const p = String(Store.get("menus.position", "center")); return p === "top" ? "center" : p; }
    function placeOf(page) {
        const own = String(Store.get("menus.positions." + page, "") || "");
        const ownBar = String(Store.get("menus.barPlaces." + page, "") || "");
        const ownFloat = own !== "" && own !== "top" && !own.startsWith("bar-") ? own : "";
        let bar;
        if (outPlaces.indexOf(ownBar) !== -1) bar = ownBar;
        else if (ownBar === "same") bar = barPlaceDefault;
        else if (own === "top" || own.startsWith("bar-")) bar = own === "top" ? "center" : own.slice(4);
        else if (ownFloat !== "") bar = "off";
        else bar = barPlaceDefault;
        if (bar === "left" || bar === "right" || bar === "bottom") return "edge-" + bar;
        return bar !== "off" ? "bar-" + bar : (ownFloat !== "" ? ownFloat : floatDefault);
    }
    // (Dynamic, opened from a module of the bar: a menu set to come out of the bar floats in its
    // floating place instead, so it has somewhere to travel to)
    function floatOf(page) {
        const own = String(Store.get("menus.positions." + page, "") || "");
        return own !== "" && own !== "top" && !own.startsWith("bar-") ? own : floatDefault;
    }
    readonly property string place: {
        Store.revision;
        const p = placeOf(cardPage);
        return dynFrom && Theme.animOn && Theme.menuAnim === "dynamic" && p.startsWith("bar-") ? floatOf(cardPage) : p;
    }
    Connections {
        target: HubState
        function onOriginChanged() { const o = HubState.origin; if (o && o.screen === win.modelData.name) win.dynFrom = o; }
        // another menu over this one, by a keybind: it goes back into its own module
        function onPageChanged() {
            if (!win.shown || Theme.menuAnim !== "dynamic") return;
            const o = HubState.origin;
            if (o && Date.now() - o.t < 400) return;
            const b = win.moduleBox(HubState.page);
            if (b) win.dynFrom = b;
        }
    }
    // out of a side of the screen (not the bar's own edge: there it comes out of the bar)
    readonly property string joinEdge: place.startsWith("edge-") && place.slice(5) !== Theme.barEdge ? place.slice(5) : ""
    // ── opening by hover (Settings → Menus & launcher): rest the pointer on the middle of a side
    // a menu comes out of, and it opens; it closes again a moment after the pointer leaves it ──
    readonly property bool edgeHover: Store.get("menus.edgeHover", false) === true
    function edgeMenu(e) {
        if (e === Theme.barEdge) return "";
        Store.revision;
        for (const p of HubState.pages) if (placeOf(p) === "edge-" + e) return p;
        return "";
    }
    readonly property var hoverEdges: edgeHover ? ["left", "right", "bottom"].filter(e => edgeMenu(e) !== "") : []
    onHoverEdgesChanged: if (modelData === Quickshell.screens[0]) HubState.hoverEdges = hoverEdges
    property bool hoverOpened: false
    Connections { target: win; function onShownChanged() { if (!win.shown) win.hoverOpened = false; } }
    component EdgeSensor: Item {
        id: es
        required property string side
        readonly property bool vert: side !== "bottom"
        readonly property real t: Math.max(3, Theme.barStyle === "frame" ? Theme.frameW : 3)
        readonly property bool live: win.hoverEdges.indexOf(side) !== -1 && !win.shown && !win.covered && win.barHere
        visible: live
        // (the middle of the edge: its ends are left to the corners and whatever else lives there)
        x: side === "right" ? win.width - t : (vert ? 0 : win.width * 0.3)
        y: side === "bottom" ? win.height - t : win.height * 0.3
        width: vert ? t : win.width * 0.4
        height: vert ? win.height * 0.4 : t
        HoverHandler { onHoveredChanged: if (hovered) openSoon.restart(); else openSoon.stop() }
        Timer { id: openSoon; interval: 160; onTriggered: { const m = win.edgeMenu(es.side); if (m !== "" && es.live) { win.hoverOpened = true; HubState.show(m, win.modelData.name); win.hoverOpened = true; } } }
    }
    EdgeSensor { id: senseL; side: "left" }
    EdgeSensor { id: senseR; side: "right" }
    EdgeSensor { id: senseB; side: "bottom" }
    Timer { id: hoverClose; interval: 380; onTriggered: if (win.hoverOpened && win.shown && !cardHover.hovered) HubState.close() }
    readonly property bool fromBar: place.startsWith("bar-")
    readonly property string barAlign: fromBar ? place.slice(4) : "center"
    readonly property real barFrac: barAlign === "start" ? 0 : (barAlign === "end" ? 1 : 0.5)
    // the page the floating card is placed for: HubState.page, followed here so that the card's
    // spot before a switch can be read first, and the card glides from there to the new menu's
    // spot (each menu keeps its own: its position, or where it was dragged) instead of jumping
    // (set here only, not bound: bound, it would move before the old spot could be read)
    property string cardPage: ""
    Component.onCompleted: cardPage = HubState.page
    Connections {
        target: HubState
        function onPageChanged() {
            const glide = win.shown && !win.docked && !HubState.snap && win.cardZoom > 0.5 && Theme.animOn;
            // (from where it is now, mid-glide included, so a quick second switch turns smoothly)
            const cx = floatCard.x, cy = floatCard.y;
            cardGlide.stop();
            win.cardPage = HubState.page;
            if (!glide) { floatCard.glideWait = false; floatCard.glideX = 0; floatCard.glideY = 0; return; }
            floatCard.glideX = floatCard.glideX + (cx - floatCard.x);
            floatCard.glideY = floatCard.glideY + (cy - floatCard.y);
            // (held where it was until the new menu's first frame is drawn: building it stalls that
            // frame, and an animation started before it lost its first third and looked like a jump)
            floatCard.glideWait = true;
        }
    }
    // out of the bar: the island grows into the menu; a full-width bar (Full, Frame) or a floating
    // one (Solid, Modular) stays put and the menu drops out of it, joined to it by curved shoulders.
    // (a bar down the side: its menus open beside it, as a card at that edge)
    // (Modular: its sections are pills of their own, with no bar between them. A menu dropped
    // out of the bar hung from an edge that isn't there, its top cut straight off in mid-air:
    // there it opens as a card of its own just under the bar, at the bar's start, middle or end)
    readonly property bool pillBar: Theme.barStyle === "modular"
    readonly property bool docked: fromBar && !side && !pillBar
    readonly property bool dropMode: Theme.fullBar || Theme.barFloats
    readonly property bool grown: shown && docked && !dropMode
    readonly property bool dropped: shown && docked && dropMode

    // a new notification drops out of the island (on the screen you're using) while it's closed
    // (on the screen it came up on: it stays there when you switch windows to another screen)
    readonly property var myToasts: Notifs.popupsOn(modelData.name, Quickshell.screens.length ? Quickshell.screens[0].name : "").filter(p => !Notifs.leaving[p.id])
    // (also with a floating menu open: it used to wait until the menu closed, so a notification
    // that came meanwhile went unseen. A menu growing out of the bar has the island itself, so
    // there it still waits)
    readonly property bool toastOn: !side && (!shown || !docked) && myToasts.length > 0 && Store.get("notifications.style", "island") !== "corner"
    // the newest, unless one is held under the pointer: that one stays until it's let go (a new
    // notification took its place mid-swipe, and the swiped copy froze where it was held)
    property var heldToast: null
    readonly property var toast: heldToast && myToasts.indexOf(heldToast) >= 0 ? heldToast : (myToasts.length > 0 ? myToasts[0] : null)
    // where it shows, like the menus of each bar: the island grows into it; a full-width bar
    // stays put and it drops out of the bar as its own shape; a floating bar (Solid, Modular)
    // gets a card just under it. (Growing a full or floating bar made the whole bar come down.)
    // Kept while it goes away, so it leaves from where it came.
    // (an island spread wide is a full bar too: growing it brought the whole top down)
    // (with a floating menu open: its own card, over the menu, which moves out of its way)
    readonly property string toastWhere: shown || Theme.barFloats ? "card" : (Theme.fullBar || restW > 760 ? "drop" : "island")
    property string toastHost: toastWhere
    onToastOnChanged: if (toastOn) toastHost = toastWhere
    onToastWhereChanged: if (toastOn) toastHost = toastWhere
    readonly property bool toastGrows: toastOn && toastHost === "island"
    // (holds them while the pointer is on one, only while one shows: see Notifs.holders)
    readonly property bool toastHolding: toastOn && toastHover.hovered
    onToastHoldingChanged: Notifs.setHold("island:" + modelData.name, toastHolding)
    Component.onDestruction: { Notifs.setHold("island:" + modelData.name, false); HubState.setBarOut(modelData.name, false); HubState.setFrameGap(modelData.name, null, "menu"); }
    readonly property real toastW: Math.min(560, width - 40)
    // pages stay loaded while the island shrinks back after being open (not for a toast)
    property bool wasOpen: false

    // ── modules outside the bar (Settings → Bar: Outside left / right): on the bar's line, just
    // beside it, each side on a see-through pill of its own. They come and go with the bar and
    // follow it (tucked away, it takes them along) ──
    readonly property real outGap: Math.max(8, Number(Store.get("bar.sectionGap", 14)))
    // room for them beside the bar: from the bar's set length, not from what's in it (which
    // changes as outside modules join it or leave it: that would go round in circles). No room
    // (a bar across the screen, or too long for them beside it): they join the bar's ends
    readonly property real outRoom: (width - Theme.barWidth(width, 0)) / 2 - Theme.islandEar - outGap - 4
    readonly property bool outFits: (!Theme.fullBar || barShort) && outLeftBar.implicitWidth <= outRoom && outRightBar.implicitWidth <= outRoom
    SmoothRect {
        id: outLeft
        readonly property var keys: bar.stored.outLeft || []
        readonly property bool on: bar.outside && keys.length > 0 && outLeftBar.contentLen > 0
        visible: on && opacity > 0.01
        opacity: island.opacity
        height: Theme.islandH
        width: outLeftBar.width
        x: Math.round(Math.max(4, Math.min(win.width - width - 4, island.x - win.outGap - width)))
        y: island.y + (win.bottom ? island.height - Theme.islandH : 0)
        radius: Theme.barRound(height)
        color: Qt.alpha(Theme.frame, Theme.frame.a * 0.55)
        border.width: Math.max(1, Theme.outlineW)
        border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        CardShadow { visible: Theme.barOpacity > 0.3 }
        IslandBar {
            id: outLeftBar
            only: outLeft.keys
            screenName: win.modelData.name
            trayWindow: win
            width: implicitWidth
        }
    }
    SmoothRect {
        id: outRight
        readonly property var keys: bar.stored.outRight || []
        readonly property bool on: bar.outside && keys.length > 0 && outRightBar.contentLen > 0
        visible: on && opacity > 0.01
        opacity: island.opacity
        height: Theme.islandH
        width: outRightBar.width
        x: Math.round(Math.max(4, Math.min(win.width - width - 4, island.x + island.width + win.outGap)))
        y: island.y + (win.bottom ? island.height - Theme.islandH : 0)
        radius: Theme.barRound(height)
        color: Qt.alpha(Theme.frame, Theme.frame.a * 0.55)
        border.width: Math.max(1, Theme.outlineW)
        border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        CardShadow { visible: Theme.barOpacity > 0.3 }
        IslandBar {
            id: outRightBar
            only: outRight.keys
            screenName: win.modelData.name
            trayWindow: win
            width: implicitWidth
        }
    }

    // ── the Frame with auto-hide: drawn here, whole, in the bar's own window (island/Frame.qml
    // only keeps windows off it then). Its border along the bar's edge swells into the bar as it
    // comes out and shrinks back to a border as it goes, the inside corners staying round all the
    // way; it follows the bar's own position, so the two never part. One shape, so one colour,
    // one shadow and one blur all the way round: with the sides in the frame's window and the
    // moving edge in this one, the sides' shadow showed through the edge and the two were
    // never quite the same colour where they met ──
    Item {
        id: frameEdge
        visible: Theme.frameHide && win.barHere
        anchors.fill: parent
        // how much of the bar's row is on the screen now, never less than the border
        readonly property real out: win.bottom ? win.height - (island.y + island.height) + Theme.islandH : island.y + Theme.islandH
        readonly property real h: Math.max(Theme.frameW, Math.min(Theme.islandH, out))
        readonly property real r: Math.min(Theme.frameRadius, Math.max(0, hole.width / 2), Math.max(0, hole.height / 2))
        // (its edge is on the move: between the border and the whole bar)
        readonly property bool moving: h > Theme.frameW + 0.5 && h < Theme.islandH - 0.5
        readonly property color col: Theme.frameFill
        // (a borderless game under the bar: nothing of the shell over it)
        opacity: win.covered ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.fastMs } }
        // the inside (the screen your windows get)
        Item {
            id: hole
            x: Theme.frameW
            y: win.bottom ? Theme.frameW : frameEdge.h
            width: win.width - 2 * Theme.frameW
            height: win.height - Theme.frameW - frameEdge.h
        }
        Shape {
            id: frameShape
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // the shadow falls inwards. Not while the edge is moving: the shadow is made from a
            // picture of the whole frame, and making that again for every frame of the motion
            // (the whole screen, blurred, 240 times a second) is what made it stutter; it comes
            // back the moment the edge is still
            layer.enabled: Theme.barOpacity > 0.3 && !frameEdge.moving
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: Theme.shadowBlur
                shadowColor: Theme.shadowColor
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }
            ShapePath {
                fillColor: frameEdge.col
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill
                startX: 0; startY: 0
                PathLine { x: frameShape.width; y: 0 }
                PathLine { x: frameShape.width; y: frameShape.height }
                PathLine { x: 0; y: frameShape.height }
                PathLine { x: 0; y: 0 }
                PathMove { x: hole.x + frameEdge.r; y: hole.y }
                PathLine { x: hole.x + hole.width - frameEdge.r; y: hole.y }
                PathArc { x: hole.x + hole.width; y: hole.y + frameEdge.r; radiusX: frameEdge.r; radiusY: frameEdge.r }
                PathLine { x: hole.x + hole.width; y: hole.y + hole.height - frameEdge.r }
                PathArc { x: hole.x + hole.width - frameEdge.r; y: hole.y + hole.height; radiusX: frameEdge.r; radiusY: frameEdge.r }
                PathLine { x: hole.x + frameEdge.r; y: hole.y + hole.height }
                PathArc { x: hole.x; y: hole.y + hole.height - frameEdge.r; radiusX: frameEdge.r; radiusY: frameEdge.r }
                PathLine { x: hole.x; y: hole.y + frameEdge.r }
                PathArc { x: hole.x + frameEdge.r; y: hole.y; radiusX: frameEdge.r; radiusY: frameEdge.r }
            }
        }
        // its outline (the style's, or the one picked in Settings → Bar), along the inside edge
        FrameLine {
            anchors.fill: parent
            hx: hole.x; hy: hole.y; hw: hole.width; hh: hole.height
            r: frameEdge.r; lw: Theme.frameOutlineW; lineColor: Theme.frameOutlineColor
            gap: HubState.frameGapOn(win.modelData.name)
        }
    }

    // the gap a menu makes in the frame's outline: dropped out of the bar, or out of a side
    readonly property var menuGap: drop.frameGap || floatCard.frameGap
    onMenuGapChanged: HubState.setFrameGap(modelData.name, menuGap, "menu")

    // ── the island ──
    IslandShape {
        id: island
        bodyW: win.grown ? win.openW : (win.toastGrows ? Math.max(win.restW, 520) : win.restW)
        height: win.grown ? win.openH : (win.toastGrows ? Theme.islandH + toastArea.implicitHeight + win.pad : Theme.islandH)
        // grown, it hangs where the menu is set to come out (the bar's start, middle or end)
        // (how far along: 0 the start, 0.5 the middle, 1 the end. Animating this one number, not
        // x, keeps it in step with its width as both change: an x worked out from a width still on
        // its way lagged behind it, and the island slid in from the side)
        property real along: win.grown ? win.barFrac : 0.5
        Behavior on along { NumberAnimation { duration: win.grown ? Theme.menuIn(Theme.growMs) : Theme.menuOut(Theme.shrinkMs); easing.type: Easing.BezierSpline; easing.bezierCurve: win.grown ? Theme.springyCurve : Theme.sizeCurve } }
        r: win.grown || win.toastGrows ? Theme.islandRadius : (Theme.fullBar ? (win.barShort ? Theme.islandRadius / 2 : 0) : Theme.barRound(height))
        // a floating bar draws its own rounded background (Solid) or none at all (Modular: its
        // sections have pills), so the hanging shape stays empty
        // the Frame paints the bar's background itself (as part of one shape), so here it's empty
        // (Desktop mode switching: the Frame's bar takes its band along while it travels to the
        // other edge, island/Frame.qml thins its own band to the border meanwhile)
        readonly property bool empty: Theme.barFloats || ((Theme.frameBand || Theme.frameHide) && !win.grown && !Desk.moving)
        // (the bar's own background while it's a bar; grown into a menu it's a menu's)
        readonly property color barCol: win.grown || win.toastGrows ? Theme.frame : Theme.barFill
        fill: empty ? "transparent" : (win.barSolid ? barCol : Qt.alpha(barCol, barCol.a * Theme.barOpacity))
        shadow: !empty && (win.barSolid || Theme.barOpacity > 0.3)
        outline: !empty
        // a screen with the bar turned off keeps it off while a menu is open, unless the menu
        // opens out of the bar itself (a floating menu has nothing to do with the bar)
        opacity: win.barHere || win.toastOn || (win.shown && win.docked) ? 1 : 0
        ear: Theme.fullBar && !win.grown ? 0 : Theme.islandEar
        // (a menu grown out of the bar is closed once the island is back to its size; a floating
        // one when its card has gone: the island settled first and cut the card's way out short)
        onHeightChanged: if (!win.shown && win.docked && height <= Theme.islandH + 1) win.wasOpen = false
        x: Math.round(Math.max(0, Math.min(win.width - width, 8 + (win.width - 16 - width) * along)))
        flipped: win.bottom
        // (tucked away it leaves 3 px to touch; in the Frame it goes all the way, the border is there)
        readonly property real away: -Theme.islandH - Theme.barMargin + (Theme.frameHide ? 0 : 3)
        y: win.bottom ? win.height - height - (win.tucked ? away : Theme.barMargin)
                      : (win.tucked ? away : Theme.barMargin)
        // growing into a menu: with a bit of spring (a little past, and back); going back to a bar:
        // smoothly and quicker. Its place along the bar moves the same way
        Behavior on bodyW { NumberAnimation { duration: Desk.moving ? Desk.travelMs : (win.grown ? Theme.menuIn(Theme.growMs) : Theme.menuOut(Theme.shrinkMs)); easing.type: Easing.BezierSpline; easing.bezierCurve: Desk.moving ? [0.65, 0.0, 0.35, 1.0, 1, 1] : (win.grown ? Theme.springyCurve : Theme.sizeCurve) } }
        Behavior on height { NumberAnimation { duration: win.grown ? Theme.menuIn(Theme.growMs) : Theme.menuOut(Theme.shrinkMs); easing.type: Easing.BezierSpline; easing.bezierCurve: win.grown ? Theme.springyCurve : Theme.sizeCurve } }
        Behavior on r { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        // (the Frame's bar coming out of the frame and going back: a little longer, out with a
        // soft landing and back in gathering speed, so the frame's edge is seen swelling)
        // (Desktop mode switching, core/Desk.qml: the bar travels across the screen to the
        // taskbar's edge and back, slower, gathering speed and landing softly)
        Behavior on y { NumberAnimation {
            duration: Desk.moving ? Desk.travelMs : (Theme.frameHide && Theme.animOn ? Math.max(200, Theme.ms(460)) : Theme.moveMs)
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Desk.moving ? [0.65, 0.0, 0.35, 1.0, 1, 1] : (Theme.frameHide ? (win.tucked ? [0.4, 0.0, 0.7, 0.2, 1, 1] : [0.2, 0.9, 0.2, 1.0, 1, 1]) : Theme.standardCurve) } }

        // Solid: one rounded floating bar; Modular gets one too while a notification drops out
        // (a SmoothRect: the Cyberpunk style cuts its corner)
        SmoothRect {
            id: solidBg
            anchors.fill: parent
            visible: Theme.barFloats && (Theme.barStyle === "solid" || win.toastGrows)
            radius: win.toastGrows ? Theme.islandRadius : Theme.barRound(height)
            color: win.toastOn ? Theme.frame : (win.barSolid ? Theme.barFill : Qt.alpha(Theme.barFill, Theme.barFill.a * Theme.barOpacity))
            border.width: Theme.outlineW
            border.color: Theme.outlineColor
            CardShadow { visible: win.barSolid || win.toastOn || Theme.barOpacity > 0.3 }
            PanelFx { anchors.fill: parent; radius: solidBg.radius; visible: Theme.chamfer; animate: false }
        }
        // Frame: a notification dropping out gets a background below the bar only (the frame
        // already paints the bar's strip; painting it again would show darker in see-through styles)
        Item {
            visible: Theme.frameBand && win.toastGrows
            x: island.e; y: win.bottom ? 0 : Theme.islandH
            width: island.bodyW; height: Math.max(0, island.height - Theme.islandH)
            clip: true
            SmoothRect {
                smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
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
            PanelFx { anchors.fill: parent; radius: Theme.rnd(island.rr); visible: win.grown && (Theme.fxGrain || Theme.fxEdge) }

            // the bar row, centred at the top
            IslandBar {
                id: bar
                screenName: win.modelData.name
                trayWindow: win
                // (a bar that reaches the screen's sides has no room beside it: its outside
                // modules join its ends)
                outside: win.outFits
                maxLen: Math.max(100, win.width - 2 * Theme.barMargin)
                y: win.bottom ? body.height - Theme.islandH : 0
                // (squeezed: laid out longer by as much as it's drawn smaller, about its middle)
                x: Math.round((body.width - width) / 2)
                width: (Theme.fullBar ? body.width : (Theme.barSpread ? Math.max(needWidth, win.restW) : implicitWidth)) / squeeze
                scale: squeeze
                transformOrigin: Item.Center
            }

            // ── a new notification, while closed ──
            Column {
                id: toastArea
                parent: win.toastHost === "card" ? toastBody : (win.toastHost === "drop" ? dropBody : body)
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
                        onHeldChanged: win.heldToast = held ? notif : null
                        onClosed: Notifs.dismissPopup(win.toast, flying, flying)
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
                parent: !win.docked ? cardClip : (win.dropMode ? dropBody : body)
                // laid out at the size the menu is going to (not the size it has while it grows or
                // shrinks there), so the page doesn't reflow and seem to rescale on every change;
                // kept in the middle while the card around it catches up
                readonly property real goalW: !win.docked ? Math.round(win.openW + 2 * win.pad) : win.openW
                readonly property real goalH: !win.docked ? Math.round(win.openH - Theme.islandH + win.pad) : (win.dropMode ? win.openH - Theme.islandH : win.openH)
                // (Dynamic: it keeps its place in the growing shape's corner; centred in the shape, it slid sideways as the shape widened)
                // (and stays put while the shape overshoots round it: `ow`)
                x: !win.docked && floatCard.dyn ? Math.round((floatCard.width - width + floatCard.ow) / 2) : Math.round((parent.width - width) / 2)
                y: win.docked && !win.dropMode && !win.bottom ? Theme.islandH + 2 : win.pad
                // (Dynamic: its full size going back in too. Laid out at the shrinking shape's size,
                // centred on the card, it slid off to the right of the shape as it went, and the
                // shape cut it off: it has to ride in the shape's corner both ways)
                readonly property bool keepSize: win.shown || (!win.docked && floatCard.dyn)
                width: (keepSize ? goalW : parent.width) - 2 * win.pad
                height: (keepSize ? goalH : parent.height) - y - (win.docked && !win.dropMode && win.bottom ? Theme.islandH + 2 : win.pad)
                // (closing a floating menu, what's in it stays and goes with the card: the card
                // fades and moves away whole. On its own it had gone before the card moved, which
                // read as no animation at all)
                opacity: win.shown || (!win.docked && Theme.animOn) ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { enabled: !HubState.snap; Anim { kind: win.shown ? "enter" : "exit" } }
                // and a little zoom, from the bar's side
                scale: win.shown || Theme.fxUnfold ? 1 : Theme.popScale
                transformOrigin: win.bottom && win.docked ? Item.Bottom : Item.Top
                Behavior on scale { enabled: !HubState.snap; Anim { kind: win.shown ? "enter" : "exit"; duration: win.shown ? Theme.menuIn(Theme.popInMs) : Theme.menuOut(Theme.popOutMs) } }
                // Unfold (Theme → Effects): the menu opens out of a thin bright line through its
                // middle and folds back into it
                // (a floating menu unfolds whole, card and all: see floatCard; here it's the
                // content of a menu growing out of the bar)
                readonly property bool unfolds: Theme.fxUnfold && win.docked
                property real unfold: win.shown ? 1 : 0
                Behavior on unfold { enabled: Theme.fxUnfold; NumberAnimation { duration: win.shown ? Theme.menuIn(Theme.ms(420)) : Theme.menuOut(Theme.ms(200)); easing.type: Easing.BezierSpline; easing.bezierCurve: win.shown ? Theme.enterCurve : Theme.exitCurve } }
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
                    radius: (Theme.chamfer || Theme.square) ? 0 : height / 2
                    color: Theme.accent
                    opacity: 1 - openArea.unfold
                }

                SmoothRect {
                    smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
                    id: field
                    width: parent.width
                    height: win.fieldH
                    radius: Theme.corner(height)
                    color: win.usesQuery || win.tabbed ? Theme.containerHigh : Qt.alpha(Theme.containerHigh, 0)
                    Behavior on color { ColorAnimation { duration: Theme.ms(220); easing.type: Easing.OutCubic } }
                    // a menu of its own: its name instead of a search field. Switching menus, the
                    // name slides out and the new one in from the same side the page comes from
                    Label {
                        id: menuTitle
                        readonly property bool on: !win.usesQuery && !win.tabbed
                        readonly property string want: (win.pageInfo[HubState.page] || win.pageInfo.search).title
                        property real shift: 0
                        visible: opacity > 0.01
                        opacity: 0
                        anchors.left: fieldIcon.right; anchors.leftMargin: 12 + shift
                        anchors.verticalCenter: parent.verticalCenter
                        strong: true
                        font.pixelSize: Theme.sizeTitle + 2
                        function update() {
                            titleSwap.stop(); titleIn.stop(); titleOut.stop();
                            if (!Theme.animOn || !win.shown) { text = want; opacity = on ? 1 : 0; shift = 0; return; }
                            if (!on) { titleOut.start(); return; }
                            if (opacity < 0.05 || text === want) { text = want; if (opacity < 0.05) shift = HubState.dir * 14; titleIn.start(); return; }
                            titleSwap.start();
                        }
                        // (after both have settled: the menu and whether it has a search field change
                        // together, in no set order)
                        onWantChanged: Qt.callLater(update)
                        onOnChanged: Qt.callLater(update)
                        Component.onCompleted: { text = want; opacity = on ? 1 : 0; }
                        Connections { target: win; function onShownChanged() { if (win.shown) { menuTitle.titleSwap.stop(); menuTitle.text = menuTitle.want; menuTitle.shift = 0; menuTitle.opacity = menuTitle.on ? 1 : 0; } } }
                        property alias titleSwap: titleSwapAnim
                        SequentialAnimation {
                            id: titleSwapAnim
                            ParallelAnimation {
                                NumberAnimation { target: menuTitle; property: "opacity"; to: 0; duration: Theme.ms(110); easing.type: Easing.InCubic }
                                NumberAnimation { target: menuTitle; property: "shift"; to: -HubState.dir * 10; duration: Theme.ms(110); easing.type: Easing.InCubic }
                            }
                            ScriptAction { script: { menuTitle.text = menuTitle.want; menuTitle.shift = HubState.dir * 14; } }
                            ParallelAnimation {
                                NumberAnimation { target: menuTitle; property: "opacity"; to: 1; duration: Theme.ms(260); easing.type: Easing.OutCubic }
                                NumberAnimation { target: menuTitle; property: "shift"; to: 0; duration: Theme.ms(380); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
                            }
                        }
                        SequentialAnimation {
                            id: titleIn
                            // (a beat after the search field has gone)
                            PauseAnimation { duration: Theme.ms(70) }
                            ParallelAnimation {
                                NumberAnimation { target: menuTitle; property: "opacity"; to: 1; duration: Theme.ms(260); easing.type: Easing.OutCubic }
                                NumberAnimation { target: menuTitle; property: "shift"; to: 0; duration: Theme.ms(380); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
                            }
                        }
                        ParallelAnimation {
                            id: titleOut
                            NumberAnimation { target: menuTitle; property: "opacity"; to: 0; duration: Theme.ms(120); easing.type: Easing.OutCubic }
                            NumberAnimation { target: menuTitle; property: "shift"; to: -HubState.dir * 10; duration: Theme.ms(160); easing.type: Easing.OutCubic }
                        }
                    }
                    SmoothRect {
                        smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
                        id: fieldTile
                        readonly property bool on: !win.usesQuery && !win.tabbed
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 32; height: 32
                        radius: Theme.corner(height, -2)
                        color: on ? Theme.accent : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.shortMs } }
                        // The menu's icon coming in, each style its own way, from one progress
                        // (tp: 0 … 1). At 1 everything is at rest (upright, full size, in place), and
                        // it's put at 1 whatever happens: two animations (a pop and a turn) could be
                        // left half done, and the tile stayed tilted
                        readonly property string kind: Theme.animOn ? (Theme.fxKind || "pop") : "none"
                        property real tp: 1
                        readonly property real e: Math.max(0, Math.min(1, tp))
                        function backOut(t) { const c1 = 1.7, c3 = c1 + 1, u = t - 1; return 1 + c3 * u * u * u + c1 * u * u; }
                        function damp(t, f) { return Math.sin(t * Math.PI * f) * (1 - t) * (1 - t); }
                        readonly property real tScale: e >= 1 ? 1
                            : kind === "pop" ? 0.6 + 0.4 * backOut(e)
                            : kind === "liquid" ? 1 + 0.22 * damp(e, 5) * -1 + (e < 0.15 ? -0.4 * (1 - e / 0.15) : 0)
                            : kind === "fjord" ? 0.86 + 0.14 * e
                            : kind === "luxe" ? 0.82 + 0.18 * (1 - Math.pow(1 - e, 3))
                            : kind === "concrete" ? 1 + (e > 0.55 && e < 0.8 ? 0.06 * Math.sin((e - 0.55) / 0.25 * Math.PI) : 0)
                            : 1
                        readonly property real tRot: e >= 1 ? 0
                            : kind === "doodle" ? 14 * damp(e, 4)
                            : kind === "industrial" ? -90 * (1 - backOut(e))
                            : 0
                        readonly property real tOp: e >= 1 ? 1
                            : kind === "cyber" ? (e < 0.7 ? (Math.floor(e * 18) % 3 === 0 ? 0.2 : 1) : 1)
                            : kind === "terminal" ? (e < 0.75 ? (Math.floor(e * 8) % 2 === 0 ? 0 : 1) : 1)
                            : kind === "fjord" ? e
                            : kind === "luxe" ? Math.min(1, e * 1.6)
                            : kind === "paper" ? Math.min(1, e * 3)
                            : kind === "pop" || kind === "liquid" ? Math.min(1, e * 4)
                            : 1
                        readonly property real tDx: e >= 1 ? 0 : kind === "cyber" && e < 0.7 ? ((Math.floor(e * 23) % 5) - 2) * 2 : 0
                        readonly property real tDy: e >= 1 ? 0 : kind === "concrete" ? (e < 0.55 ? -16 * (1 - Math.pow(e / 0.55, 2)) : 0) : 0
                        readonly property real tSx: e >= 1 ? 1 : kind === "paper" ? Math.max(0.02, 1 - Math.pow(1 - e, 3)) : 1
                        readonly property real tGlow: e >= 1 ? 0 : kind === "luxe" ? Math.sin(e * Math.PI) * 0.6 : 0
                        scale: tScale
                        rotation: tRot
                        opacity: tOp
                        transform: [
                            Scale { origin.x: 16; origin.y: 16; xScale: fieldTile.tSx },
                            Translate { x: fieldTile.tDx; y: fieldTile.tDy }
                        ]
                        // (Luxe: a soft gold glow round it as it rises)
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width + 10; height: width
                            radius: width / 2
                            color: "transparent"
                            border.width: 2
                            border.color: Qt.alpha(Theme.accent, fieldTile.tGlow)
                            visible: fieldTile.tGlow > 0.01
                        }
                        readonly property int tMs: kind === "none" ? 0 : Theme.ms(({ pop: 420, liquid: 620, cyber: 420, doodle: 560, terminal: 460, paper: 420, fjord: 600, concrete: 520, industrial: 480, luxe: 640 })[kind] || 420)
                        NumberAnimation { id: tileAnim; target: fieldTile; property: "tp"; from: 0; to: 1; duration: Math.max(1, fieldTile.tMs); easing.type: fieldTile.kind === "pop" || fieldTile.kind === "liquid" || fieldTile.kind === "industrial" ? Easing.OutCubic : Easing.Linear }
                        Timer { id: tileSafe; interval: fieldTile.tMs + 250; onTriggered: { tileAnim.stop(); fieldTile.tp = 1; } }
                        function play() { if (kind === "none") { tp = 1; return; } tileAnim.restart(); tileSafe.restart(); }
                        Connections { target: HubState; function onPageChanged() { fieldTile.play(); } }
                        onVisibleChanged: if (!visible) { tileAnim.stop(); tp = 1; }
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
                        opacity: fieldTile.opacity
                        transform: [
                            Scale { origin.x: 10; origin.y: 10; xScale: fieldTile.tSx },
                            Translate { x: fieldTile.tDx; y: fieldTile.tDy }
                        ]
                    }
                    TextInput {
                        Keys.onPressed: e => Sounds.key(e)   // (a sound for each key; never takes it)
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
                        // (no cursor while the field is hidden: it still takes the keys, but a blinking
                        // cursor nobody can see redrew the whole menu twice a second)
                        cursorDelegate: Component { Caret { input: query; shown: win.usesQuery || win.tabbed } }
                        // still takes the keys (Esc, arrows for the page) on a menu without a search
                        opacity: win.usesQuery || win.tabbed ? 1 : 0
                        // (goes quickly, so it's gone before a menu's name slides in over it)
                        // (and comes back a beat after a menu's name has gone)
                        Behavior on opacity {
                            SequentialAnimation {
                                PauseAnimation { duration: win.usesQuery || win.tabbed ? Theme.ms(70) : 0 }
                                NumberAnimation { duration: win.usesQuery || win.tabbed ? Theme.ms(200) : Theme.ms(80); easing.type: Easing.OutCubic }
                            }
                        }
                        Label {
                            id: queryHint
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: query.text === ""
                            // (a menu without a search field keeps the last wording while it fades out)
                            readonly property string want: HubState.page === "search" ? "Search apps   ·   > run   ·   : emoji   ·   / files" : (HubState.page === "clipboard" ? "Filter the clipboard" : (HubState.page === "keys" ? "Filter keybinds" : "Type to search"))
                            property string kept: want
                            function keep() { if (win.usesQuery || win.tabbed) kept = want; }
                            onWantChanged: Qt.callLater(keep)
                            Connections { target: win; function onUsesQueryChanged() { Qt.callLater(queryHint.keep); } }
                            text: kept
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
                        radius: (Theme.chamfer || Theme.square) ? 0 : height / 2
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
                            radius: (Theme.chamfer || Theme.square) ? 0 : height / 2
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
                // and kept (hidden) after it closes, so opening it again doesn't build it all over
                // again (on an older laptop that was a good part of a second before anything
                // moved). Search, the launcher, is built soon after the shell
                // starts and kept.
                Item {
                    id: pages
                    y: win.compact ? field.height + 8 : tabs.y + tabs.height + 10
                    width: parent.width
                    height: parent.height - y
                    // (a page cut short by a small screen stays inside the card)
                    clip: !!win.currentPage && win.currentPage.implicitHeight > height + 1
                    // ... and scrolls there: the wheel moves the page up to show the rest (on a
                    // small screen the control centre's Monitor tab ended mid-card, with no way
                    // down). Named like a Flickable's, so a slider under the pointer leaves the
                    // wheel to it (ui/Slider looks for these)
                    readonly property int flickableDirection: 1
                    readonly property real contentHeight: win.currentPage ? win.currentPage.implicitHeight : 0
                    readonly property real over: Math.max(0, contentHeight - height)
                    property real contentY: 0
                    onOverChanged: if (contentY > over) contentY = over
                    Connections { target: HubState; function onPageChanged() { pages.contentY = 0; } }
                    Behavior on contentY { NumberAnimation { duration: Theme.ms(140); easing.type: Easing.OutCubic } }
                    WheelHandler {
                        enabled: pages.over > 1
                        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                        onWheel: e => {
                            const d = e.pixelDelta.y !== 0 ? e.pixelDelta.y : e.angleDelta.y / 120 * 110;
                            pages.contentY = Math.max(0, Math.min(pages.over, pages.contentY - d));
                        }
                    }
                    Rectangle {
                        visible: pages.over > 1
                        z: 5
                        anchors.right: parent.right
                        width: 4; radius: 2
                        height: Math.max(30, pages.height * pages.height / Math.max(1, pages.contentHeight))
                        y: (pages.height - height) * pages.contentY / Math.max(1, pages.over)
                        color: Qt.alpha(Theme.text, 0.35)
                    }
                    Repeater {
                        model: HubState.pages
                        Loader {
                            id: pl
                            required property string modelData
                            readonly property string pageId: modelData
                            property bool seen: false
                            // switching menus: the page that's going keeps the width it had (it
                            // used to jump to the new menu's width and stretch as it faded), in
                            // the middle; the one coming fills the room
                            readonly property bool isCur: HubState.page === modelData
                            readonly property real ownW: Math.min(win.maxOpenW, (win.pageInfo[modelData] || win.pageInfo.search).w)
                            width: isCur ? pages.width : ownW
                            // (and its own height: tied to the room there is, it grew or shrank with
                            // the new menu's card and reflowed as it faded)
                            readonly property bool leaving: !isCur && !!item && win.shown
                            x: Math.round((pages.width - width) / 2)
                            y: isCur ? -Math.round(pages.contentY) : 0
                            // built in the background, so opening a menu for the first time doesn't
                            // freeze everything for a moment (the card's change raced ahead while
                            // the old page sat there, fully drawn, stretched across it)
                            asynchronous: true
                            // the room there is (a page's own height was used as is, so on a
                            // short screen it was laid out taller than the card and spilled out)
                            height: leaving ? item.implicitHeight : pages.height
                            active: win.here && (seen || (win.open && HubState.page === modelData))
                            source: "../hub/" + modelData.charAt(0).toUpperCase() + modelData.slice(1) + "Page.qml"
                            onLoaded: {
                                Qt.callLater(() => pl.seen = true);
                                if (item.hasOwnProperty("query")) item.query = Qt.binding(() => query.text);
                                if (modelData === "search") item.done.connect(() => { query.text = ""; HubState.close(); });
                            }
                            // (kept once built: let go a few minutes after closing, the next open
                            // rebuilt it in the background while the card was already coming in, so
                            // the card grew to the last menu's height, then jumped to this one's
                            // and the page faded in late, the first open after a while only)
                            readonly property bool keep: modelData === "search"
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
        visible: (win.dropMode || toasting) && height > 1
        // (a notification drops out of it too, when the bar is full width)
        readonly property bool toasting: !win.dropped && win.toastOn && win.toastHost === "drop"
        bodyW: win.dropped ? win.openW : (toasting ? win.toastW : 160)
        height: win.dropped ? win.openH - Theme.islandH : (toasting ? toastArea.implicitHeight + win.pad * 1.5 : 0)
        r: Theme.islandRadius
        // one piece with the bar it grows out of: the bar's own colour (the bar and the menu were
        // two different shades, with a seam where they met), no outline across the join, and in
        // the Frame the frame's line, which leaves a gap here and runs on round the menu
        // (or, Settings → Menus → Hanging from the bar: a darker shade, as if it hung from
        // behind the bar. See-through, its shadow kept under it does that; solid, a darker fill)
        readonly property color own: Theme.barStyle === "frame" ? Theme.frameFill : Theme.barFill
        readonly property bool under: Theme.menuHang === "under" && Theme.barStyle !== "frame"
        fill: under && own.a >= 0.99 ? Qt.rgba(own.r * 0.72, own.g * 0.72, own.b * 0.72, own.a) : own
        hollowShadow: !under
        baseLine: false
        lineW: Theme.barStyle === "frame" ? Theme.frameOutlineW : Theme.outlineW
        lineColor: Theme.barStyle === "frame" ? Theme.frameOutlineColor : Theme.outlineColor
        readonly property var frameGap: Theme.barStyle === "frame" && visible && height > 1
            ? { edge: Theme.barEdge, a: x, b: x + width } : null
        // where along the bar it hangs: its start or end (in from the bar's ends by their
        // roundness, so the shoulder meets the bar's straight edge), or the middle
        readonly property real barL: island.x + island.e
        readonly property real barR: island.x + island.e + island.bodyW
        readonly property real inset: Math.max(10, Theme.islandRadius * 0.6)
        // how far along (0 start, 0.5 middle, 1 end), animated as one number so its place keeps in
        // step with its width (see the island's). Going back in it stays where it is; a
        // notification hangs from the middle
        property real along: win.dropped || !toasting ? win.barFrac : 0.5
        Behavior on along { enabled: drop.height > 1; NumberAnimation { duration: win.dropped ? Theme.menuIn(Theme.growMs) : Theme.menuOut(Theme.shrinkMs); easing.type: Easing.BezierSpline; easing.bezierCurve: win.dropped ? Theme.springyCurve : Theme.sizeCurve } }
        readonly property real midX: (win.width - bodyW) / 2
        readonly property real wantBodyX: along <= 0.5 ? barL + inset + (midX - barL - inset) * along * 2
                                                       : midX + (barR - inset - bodyW - midX) * (along - 0.5) * 2
        x: Math.round(Math.max(0, Math.min(win.width - width, wantBodyX - e)))
        flipped: win.bottom
        // hanging from the bar's edge, wherever the bar sits (a margin round an island bar)
        y: win.bottom ? island.y - height + (Theme.see < 0.999 || Theme.barOpacity < 0.999 ? 0 : 1)
                      : island.y + Theme.islandH - (Theme.see < 0.999 || Theme.barOpacity < 0.999 ? 0 : 1)
        // growing out of the bar with a bit of spring; going back in smoothly and quicker
        Behavior on bodyW { NumberAnimation { duration: win.dropped ? Theme.menuIn(Theme.growMs) : Theme.menuOut(Theme.shrinkMs); easing.type: Easing.BezierSpline; easing.bezierCurve: win.dropped ? Theme.springyCurve : Theme.sizeCurve } }
        Behavior on height { NumberAnimation { duration: win.dropped ? Theme.menuIn(Theme.growMs) : Theme.menuOut(Theme.shrinkMs); easing.type: Easing.BezierSpline; easing.bezierCurve: win.dropped ? Theme.springyCurve : Theme.exitCurve } }
        onHeightChanged: if (!win.shown && win.docked && height <= 1) win.wasOpen = false
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
        // (over a floating menu that's open)
        z: 5
        opacity: on ? 1 : 0
        visible: opacity > 0.01
        Behavior on opacity { NumberAnimation { duration: toastCard.on ? Theme.fastMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on height { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sizeCurve } }
        CardShadow {}
        MouseArea { anchors.fill: parent }
        // what's in it is kept within the card as it comes down into it (the card itself isn't
        // clipped: that cut its shadow off, and the card sat on the screen with a hard edge)
        Item { id: toastBody; anchors.fill: parent; clip: true }
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
        // Out of a side of the screen (win.joinEdge): flat against that side (the frame's inside
        // edge in the Frame), one piece with it: the frame's own colour and outline, which leaves
        // a gap there and runs on round the menu, the corners by the edge joined to it with the
        // same curves as a menu out of the bar. It slides out of the edge and back into it
        readonly property string joined: win.joinEdge
        readonly property real edgeInset: Theme.barStyle === "frame" ? Theme.frameW : 0
        // (out of a Modular bar: by the bar, see win.pillBar)
        readonly property string near: win.fromBar && win.pillBar ? "top-" + (win.barAlign === "start" ? "left" : (win.barAlign === "end" ? "right" : "center")) : win.place
        readonly property string spot: joined !== "" ? joined : (win.side && (win.fromBar || win.place.startsWith("top")) ? Theme.barSide : (win.bottom && near.startsWith("top") ? "bottom" + near.slice(3) : near))
        readonly property bool onLeft: spot.indexOf("left") !== -1
        readonly property bool onRight: spot.indexOf("right") !== -1
        readonly property bool onTop: spot.startsWith("top")
        readonly property bool onBottom: spot.startsWith("bottom")
        // clear of the bar, wherever it is
        readonly property real leftRoom: joined !== "" ? edgeInset : 16 + (Theme.barSide === "left" ? Theme.sideRoom : 0)
        readonly property real rightRoom: joined !== "" ? edgeInset : 16 + (Theme.barSide === "right" ? Theme.sideRoom : 0)
        readonly property real homeX: onLeft ? leftRoom : (onRight ? win.width - width - rightRoom : Math.round((win.width - width) / 2))
        // moved by hand (drag an empty part of it): kept for each menu; a double-click on an empty
        // part puts it back. Always kept on the screen
        readonly property var moved: joined !== "" ? null : Store.get("menus.moved." + win.cardPage, null)
        property point dragBy: Qt.point(0, 0)
        // (a switch's glide: the way still to go from the last menu's spot, down to 0)
        property real glideX: 0
        property real glideY: 0
        property bool glideWait: false
        Connections {
            target: floatCard.Window.window
            enabled: floatCard.glideWait
            function onFrameSwapped() { floatCard.glideWait = false; cardGlide.restart(); }
        }
        // (a travel across the screen: the standard curve, which eases in, rather than the size's,
        // which goes almost all the way in its first frames and read as a jump over that distance)
        ParallelAnimation {
            id: cardGlide
            Anim { target: floatCard; property: "glideX"; to: 0; duration: Theme.springMs }
            Anim { target: floatCard; property: "glideY"; to: 0; duration: Theme.springMs }
        }
        // (the glide kept on the screen too: as the card grows on the way it would cross the edge)
        x: Math.round(Math.max(0, Math.min(win.width - width, Math.max(0, Math.min(win.width - width, homeX + (moved ? Number(moved.x) || 0 : 0) + dragBy.x)) + glideX)))
        readonly property real topRoom: win.bottom || win.side ? 16 : Theme.islandH + Theme.barMargin + 14
        readonly property real bottomRoom: joined === "bottom" ? edgeInset : (win.bottom ? Theme.islandH + Theme.barMargin + 14 : 16)
        readonly property real homeY: onTop ? topRoom : (onBottom ? win.height - height - bottomRoom : Math.max(topRoom, Math.min(win.height - height - bottomRoom, Math.round((win.height - height) / 2))))
        // where it'd be, and how far a notification's card pushes it (down under a top bar, up over
        // a bottom one) while it shows over the menu, so the notification can be read
        readonly property real baseY: Math.max(0, Math.min(win.height - height, homeY + (moved ? Number(moved.y) || 0 : 0) + dragBy.y)) + glideY
        readonly property real toastPushWant: !(toastCard.on && win.shown) ? 0
            : (win.bottom ? Math.min(0, toastCard.y - 12 - (baseY + height)) : Math.max(0, toastCard.y + toastCard.height + 12 - baseY))
        property real toastPush: toastPushWant
        Behavior on toastPush { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sizeCurve } }
        y: Math.round(Math.max(0, Math.min(win.height - height, baseY + toastPush)))
        radius: Theme.islandRadius
        color: joined !== "" || dyn ? "transparent" : Theme.frame
        border.width: joined !== "" || dyn ? 0 : Theme.outlineW
        border.color: Theme.outlineColor
        // (joined to an edge: its shape, drawn behind what's in it, turned to hang from that edge)
        Item {
            visible: floatCard.joined !== ""
            readonly property bool vert: floatCard.joined !== "bottom"
            width: vert ? floatCard.height + 2 * edgeShape.e : floatCard.width + 2 * edgeShape.e
            height: vert ? floatCard.width : floatCard.height
            anchors.centerIn: parent
            rotation: ({ right: 90, bottom: 180, left: -90 })[floatCard.joined] || 0
            IslandShape {
                id: edgeShape
                anchors.fill: parent
                bodyW: parent.width - 2 * e
                r: Theme.islandRadius
                fill: Theme.barStyle === "frame" ? Theme.frameFill : Theme.barFill
                baseLine: false
                lineW: Theme.barStyle === "frame" ? Theme.frameOutlineW : Theme.outlineW
                lineColor: Theme.barStyle === "frame" ? Theme.frameOutlineColor : Theme.outlineColor
            }
        }
        // how far out of its edge it is (0 … 1), eased: the slide it opens and closes with
        readonly property real outK: 1 - Math.pow(1 - Math.max(0, Math.min(1, win.cardZoom)), 3)
        readonly property real slideBy: joined === "" ? 0 : (1 - outK) * ((joined === "bottom" ? height : width) + edgeInset + 4)
        // (the gap it makes in the frame's outline, along that edge)
        readonly property var frameGap: joined !== "" && Theme.barStyle === "frame" && visible && outK > 0.01
            ? (joined === "bottom" ? { edge: joined, a: x - edgeShape.e, b: x + width + edgeShape.e } : { edge: joined, a: y - edgeShape.e, b: y + height + edgeShape.e }) : null
        HoverHandler { id: cardHover; onHoveredChanged: if (hovered) hoverClose.stop(); else if (win.hoverOpened) hoverClose.restart() }
        // fades in with a little zoom from where it sits, and out the same way
        // Unfold (Theme → Effects): instead, the whole card opens out of a thin bright line through
        // its middle and folds back into it
        readonly property real unfold: openArea.unfold
        // (it fades in as it fades out. Opening, the card used to be there at once and only its
        // contents faded: it jumped in, and didn't match the way it left. The blur behind joins
        // once it's nearly half there. Dynamic: over the first of its way out of the module)
        // (Cyberpunk: whole until it's gone, CyberFx glitches it in and the Blackwall takes it)
        opacity: dyn ? Math.max(0, Math.min(1, win.dynK / 0.14))
               : joined !== "" ? (win.shown || win.cardZoom > 0.002 ? 1 : 0)
               : Theme.fxUnfold ? (win.shown || unfold > 0.02 ? 1 : 0) : (Theme.cyber ? (win.shown || win.cardZoom > 0.002 ? 1 : 0) : win.cardFade)
        // How menus open (Theme.menuAnim), driven by cardZoom (0 … 1), and back the same way
        // (Dynamic, from a module of the bar: in any style. With nothing to come out of, the usual way)
        // (Desktop mode's start menu has its own: it rises out of the taskbar, straight, as one
        // piece. Grown out of the start button it came in from off to the side, the button not
        // being under the menu's middle)
        readonly property bool startMenu: Desk.on && win.cardPage === "search" && joined === ""
        readonly property bool dyn: joined === "" && !startMenu && Theme.animOn && Theme.menuAnim === "dynamic" && !!win.dynFrom
        readonly property string anim: joined !== "" ? "edge" : startMenu && Theme.animOn && !Theme.cyber ? "rise" : dyn ? "dynamic"
            : (Theme.animOn && !Theme.cyber ? (Theme.menuAnim === "dynamic" ? "zoom" : Theme.menuAnim) : "none")
        // Dynamic: the module itself grows into the menu. A shape (`shell`, below) starts as the
        // module's own box and changes its real size and place into the menu's, quickly, a touch
        // past it, and settles; the menu's content rides in its top-left corner at full size,
        // uncovered as the shape grows and fading in over the first part. Closing, it gathers speed
        // back into the module. (It was the whole menu scaled down and flown across: a small copy
        // of the menu, not the module opening up.) `mk`: how far the shape has got, 0 the module's
        // box … 1 the menu's (a little over 1 on the way in: the overshoot)
        readonly property real mk: Math.max(0, win.dynK)
        // the shape's box, in this card's own coordinates
        readonly property real fromX: dyn ? win.dynFrom.x - x : 0
        readonly property real fromY: dyn ? win.dynFrom.y - y : 0
        readonly property real fromW: dyn ? win.dynFrom.w : width
        readonly property real fromH: dyn ? win.dynFrom.h : height
        // (the overshoot only makes it a touch bigger, evenly round its middle: its place stops
        // where the card is. It used to carry on past that too, so the whole menu swung a few
        // pixels off to the far side of the module and back, off centre)
        readonly property real mp: Math.min(1, mk)
        readonly property real ow: dyn && mk > 1 ? (width - fromW) * (mk - 1) : 0
        readonly property real oh: dyn && mk > 1 ? (height - fromH) * (mk - 1) : 0
        readonly property real mx: dyn ? fromX * (1 - mp) - ow / 2 : 0
        readonly property real my: dyn ? fromY * (1 - mp) - oh / 2 : 0
        readonly property real mw: dyn ? Math.max(8, fromW + (width - fromW) * mk) : width
        readonly property real mh: dyn ? Math.max(8, fromH + (height - fromH) * mk) : height
        // what's in it: in over the first part of the way, out before the shape is small again
        readonly property real contentK: !dyn ? 1 : Math.max(0, Math.min(1, (win.dynK - 0.2) / 0.45))
        // (pop: overshoots a little and settles)
        function backOut(t) { const c1 = 1.5, c3 = c1 + 1, u = t - 1; return 1 + c3 * u * u * u + c1 * u * u; }
        // (Fjord: its frost doesn't move, so the card also grows in from 94 % over the first
        // part of it, and fades in: it was there in one frame, as a slab of ice)
        readonly property real fjordIn: Theme.fxKind === "fjord" ? Math.min(1, win.cardZoom / 0.4) : 1
        scale: dyn || joined !== "" ? 1 : Theme.fxKind === "fjord" ? 0.94 + 0.06 * (1 - Math.pow(1 - fjordIn, 3))
             : anim === "zoom" ? Theme.popScale + (1 - Theme.popScale) * win.cardZoom
             : anim === "pop" ? 0.84 + 0.16 * backOut(win.cardZoom)
             : anim === "rise" ? 0.95 + 0.05 * win.cardZoom
             : 1
        transform: [
            Scale {
                origin.x: floatCard.width / 2; origin.y: floatCard.height / 2
                yScale: Theme.fxUnfold && floatCard.joined === "" ? Math.max(0.006, floatCard.unfold) : 1
                xScale: Theme.fxUnfold && floatCard.joined === "" ? 0.96 + 0.04 * floatCard.unfold : 1
            },
            Translate {
                // (rise: from the taskbar's side, whichever edge it's on)
                readonly property real rise: floatCard.anim === "rise" ? (1 - win.cardZoom) * 56 : 0
                x: floatCard.dyn ? 0 : floatCard.joined === "left" ? -floatCard.slideBy : (floatCard.joined === "right" ? floatCard.slideBy
                    : (Theme.barEdge === "left" ? -rise : (Theme.barEdge === "right" ? rise : 0)))
                y: floatCard.dyn ? 0 : floatCard.joined === "bottom" ? floatCard.slideBy
                    : floatCard.anim === "slide" ? (1 - win.cardZoom) * 40 : (floatCard.anim === "drop" ? -(1 - win.cardZoom) * 40
                    : (Theme.barEdge === "bottom" ? rise : (Theme.barEdge === "top" ? -rise : 0)))
            }
        ]
        Rectangle {
            z: 100
            visible: Theme.fxUnfold && floatCard.unfold < 0.98 && floatCard.unfold > 0.001
            anchors.centerIn: parent
            width: parent.width * (0.5 + 0.5 * Math.min(1, floatCard.unfold * 3))
            height: Math.max(2, 3 / Math.max(0.02, floatCard.unfold))
            radius: (Theme.chamfer || Theme.square) ? 0 : height / 2
            color: Theme.accent
            opacity: 1 - floatCard.unfold
        }
        transformOrigin: dyn ? Item.Center : onTop ? (onLeft ? Item.TopLeft : (onRight ? Item.TopRight : Item.Top)) : (onBottom ? (onLeft ? Item.BottomLeft : (onRight ? Item.BottomRight : Item.Bottom)) : (onLeft ? Item.Left : (onRight ? Item.Right : Item.Center)))
        CardShadow { visible: floatCard.joined === "" && !floatCard.dyn }
        // (Dynamic: the card's own shape, growing out of the module and back)
        SmoothRect {
            id: shell
            smoothing: 0
            visible: floatCard.dyn
            x: floatCard.mx; y: floatCard.my
            width: floatCard.mw; height: floatCard.mh
            radius: Math.min(Theme.islandRadius, height / 2, width / 2)
            color: Theme.frame
            border.width: Theme.outlineW
            border.color: Theme.outlineColor
            CardShadow {}
        }
        CyberFx { target: floatCard; allowed: floatCard.joined === "" && !floatCard.dyn; p: win.shown ? win.cardZoom : 1 - win.cardZoom; going: !win.shown }
        // (takes the clicks that land on the card but on nothing in it)
        MouseArea { anchors.fill: parent }
        PanelFx { anchors.fill: parent; radius: floatCard.radius; visible: (Theme.fxGrain || Theme.fxEdge || Theme.chamfer) && (!floatCard.dyn || (win.shown && win.dynK > 0.97)) }
        // what's inside (openArea) is laid out at the size the menu is going to; this keeps it
        // within the card while the card grows to that size (it showed past the card's edges)
        // (Dynamic: it's the growing shape's box, and what's in it rides in its corner)
        Item {
            id: cardClip
            x: floatCard.mx; y: floatCard.my
            width: floatCard.mw; height: floatCard.mh
            opacity: floatCard.contentK
            clip: true; z: 1
        }
        // moving the card: Super (Meta) + drag anywhere on it, over what's in it too. Without
        // Super the press goes on to what's under it (a plain drag on the card moved it, and
        // dragging in a menu, a slider's knob just off its track, carried the whole menu off).
        // Super + double-click puts it back in its usual place.
        MouseArea {
            id: cardDrag
            anchors.fill: parent
            z: 50
            property point from: Qt.point(0, 0)
            property bool moving: false
            // (a cursor only while moving: one all the time hid the menu's own, the hand over buttons)
            cursorShape: moving ? Qt.ClosedHandCursor : undefined
            onPressed: m => {
                if (!(m.modifiers & Qt.MetaModifier)) { m.accepted = false; return; }
                from = mapToItem(null, m.x, m.y); moving = false;
            }
            onPositionChanged: m => {
                if (!pressed) return;
                const p = mapToItem(null, m.x, m.y);
                const d = Qt.point(p.x - from.x, p.y - from.y);
                if (!moving && Math.abs(d.x) + Math.abs(d.y) < 6) return;
                moving = true;
                floatCard.dragBy = d;
            }
            onReleased: {
                if (!moving) return;
                moving = false;
                // kept as where it ended up (on the screen), from its usual place
                Store.set("menus.moved." + HubState.page, { x: floatCard.x - floatCard.glideX - floatCard.homeX, y: floatCard.y - floatCard.toastPush - floatCard.glideY - floatCard.homeY });
                floatCard.dragBy = Qt.point(0, 0);
            }
            onCanceled: { moving = false; floatCard.dragBy = Qt.point(0, 0); }
            onDoubleClicked: m => { if (m.modifiers & Qt.MetaModifier) Store.unset("menus.moved." + HubState.page); }
        }
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
    // Dynamic (How menus open): the module of the bar this menu was opened from, kept while it's
    // open so it goes back into the same one. A journey across the screen, so it gets longer
    // than a fade in place (never under a quarter of a second: shorter, it's a jump again)
    property var dynFrom: null
    readonly property bool dynOn: floatCard.dyn
    // It moves on a spring, not along a curve over a set time: the shape is pulled towards the
    // menu's box (or back to the module's), so it leaves fast, goes a touch past and settles, and
    // one that's turned round half-way (closed while opening, opened again while closing) carries
    // on from where it is at the speed it has, with no jump. `dynK`: 0 the module's box … 1 the
    // menu's. Coming, it's a little under-damped (about 2 % past); going back it's pulled straight
    // into the module and stops there. The speed settings make the spring stiffer or looser.
    property real dynK: 0
    property real dynV: 0
    readonly property real dynGoal: shown && (cardIn.running || cardZoom > 0) ? 1 : 0
    readonly property real dynFastIn: Math.max(0.4, Math.min(1.5, Theme.menuInSpeed / Math.max(0.01, Theme.animScale)))
    readonly property real dynFastOut: Math.max(0.4, Math.min(1.5, Theme.menuOutSpeed / Math.max(0.01, Theme.animScale)))
    readonly property int dynInMs: Math.round(330 / dynFastIn)
    readonly property int dynOutMs: Math.round(280 / dynFastOut)
    FrameAnimation {
        running: win.dynK !== win.dynGoal || win.dynV !== 0
        onTriggered: {
            const goal = win.dynGoal;
            if (!win.dynOn) { win.dynK = goal; win.dynV = 0; return; }
            const coming = goal > 0.5;
            const w = coming ? 22 * win.dynFastIn : 17.3 * win.dynFastOut;       // how stiff
            const z = coming ? 0.78 : 0.8;                                       // how damped
            let k = win.dynK, v = win.dynV;
            const n = 4, dt = Math.min(0.05, frameTime) / n;
            for (let i = 0; i < n; i++) { v += (w * w * (goal - k) - 2 * z * w * v) * dt; k += v * dt; }
            if (!coming && k <= 0) { k = 0; v = 0; }                              // back in the module: done
            else if (Math.abs(goal - k) < 0.0006 && Math.abs(v) < 0.02) { k = goal; v = 0; }
            win.dynK = k; win.dynV = v;
        }
    }
    function moduleBox(page) { return bar.moduleBox(page) || outLeftBar.moduleBox(page) || outRightBar.moduleBox(page); }
    ParallelAnimation {
        id: cardIn
        NumberAnimation { target: win; property: "cardFade"; to: 1; duration: win.dynOn ? win.dynInMs : Theme.menuInMs; easing.type: Easing.OutCubic }
        NumberAnimation { target: win; property: "cardZoom"; to: 1; duration: win.dynOn ? win.dynInMs : Theme.menuInMs; easing.type: Theme.cyber || win.dynOn ? Easing.Linear : Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
    }
    ParallelAnimation {
        id: cardOut
        onFinished: if (!win.shown) win.dynFrom = null
        // (closing: the fade holds back so the way out is seen; it ends with the motion)
        NumberAnimation { target: win; property: "cardFade"; to: 0; duration: win.dynOn ? win.dynOutMs : Theme.menuGoMs; easing.type: Theme.cyber ? Easing.OutCubic : Easing.InQuad }
        NumberAnimation { target: win; property: "cardZoom"; to: 0; duration: win.dynOn ? win.dynOutMs : Theme.menuGoMs; easing.type: Theme.cyber || win.dynOn ? Easing.Linear : Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve }
    }
    onShownChanged: {
        if (shown) {
            cardOut.stop();
            const o = HubState.origin;
            // (not opened from a module: a keybind, a command. Out of its module all the same, if it has one on the bar)
            dynFrom = o && o.screen === modelData.name && Date.now() - o.t < 2500 ? o : (Theme.animOn && Theme.menuAnim === "dynamic" ? moduleBox(HubState.page) : null);
            if (HubState.snap) { cardFade = 0; cardZoom = 0; }
            // A menu that isn't built yet (its first opening since the shell started, or on this
            // screen): the animation waits the few frames until it is, then plays as always.
            // Started at once, the card came in empty at the last menu's size, jumped to this
            // one's, and the page faded in late: a different animation, that one time only.
            if (!win.currentPage && !win.docked) { cardFade = 0; cardZoom = 0; pageWait.restart(); }
            else { pageWait.stop(); cardIn.restart(); }
        }
        else { cardIn.stop(); cardOut.restart(); }
    }
    Connections { target: win; function onShownChanged() { if (win.shown) win.opened(); } }
    // (at most this long: a page that's slow to build doesn't hold the menu back for ever)
    Timer { id: pageWait; interval: 400; onTriggered: if (win.shown) cardIn.restart() }
    onCurrentPageChanged: if (pageWait.running && currentPage) { pageWait.stop(); Qt.callLater(() => { if (win.shown) cardIn.restart(); }); }
    function opened() { fieldTile.play(); wasOpen = true; query.text = HubState.preset; HubState.preset = ""; query.forceActiveFocus(); }
    Connections {
        target: HubState
        function onPresetRequested() { if (win.shown && HubState.preset !== "") { query.text = HubState.preset; HubState.preset = ""; } }
        function onRefocus() { if (win.shown) query.forceActiveFocus(); }
    }

    // blur behind it (Theme → Effects), shaped like it. Not over a fullscreen app: blurring a
    // game or a video under the menu on every frame made menus late there on older laptops
    // (only when that's turned off, or in Game mode: it used to be always, and with any app in
    // fullscreen the menus lost their blur with the Blur switch on, which read as broken)
    readonly property bool overFullscreen: !Theme.blurOverFullscreen && Niri.fullscreenOn(modelData.name)
    // (none while auto-hide has the bar slid away: its blur would sit off the screen, and
    // Hyprland blurred the whole screen for that)
    // Smooth sailing (core/Intro): the whole bar glides in from its edge when the shell first
    // starts (its blur waits until it's there: a blur region can't move with it)
    Binding { target: win.contentItem; property: "y"; value: (win.bottom ? 1 : -1) * (1 - Intro.barK) * (Theme.islandH + Theme.barMargin + 28); when: Intro.playing; restoreMode: Binding.RestoreBindingOrValue }
    Binding { target: win.contentItem; property: "opacity"; value: Intro.barK; when: Intro.playing; restoreMode: Binding.RestoreBindingOrValue }
    // (and only once the bar is all the way on the screen: coming back from auto-hide, the blur
    // switched on as the slide started, while the bar was still above the screen's edge; for that
    // frame the blur region lay outside the window and Hyprland blurred the whole screen, which
    // looked like the screen shaking. It comes on as the bar arrives, like the Intro's)
    readonly property bool islandIn: island.y >= -0.5 && island.y + island.height <= win.height + 0.5
    BackgroundEffect.blurRegion: Theme.blur && !Intro.playing && !Desk.moving && !overFullscreen && islandIn && !(win.tucked && !win.toastGrows && !Theme.frameHide) ? blurShape : null
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
            radius: (Theme.chamfer || Theme.square) ? 0 : solidBg.radius
            CutBlur { bx: island.x; by: island.y; bw: island.width; bh: island.height; c: solidBg.r }
        }
        // Modular: only its pills (not the gaps between them)
        readonly property bool pillsOn: blurShape.barOn && !solidBg.visible && Theme.barStyle === "modular"
        readonly property real pillX: island.x + body.x + bar.x
        readonly property real pillY: island.y + body.y + bar.y
        Region {
            id: pillRegL
            readonly property Item p: bar.leftPill
            readonly property bool on: blurShape.pillsOn && p.visible
            x: blurShape.pillX + p.x; y: blurShape.pillY + p.y
            width: on ? p.width : 0; height: on ? p.height : 0
            radius: (Theme.chamfer || Theme.square) ? 0 : p.radius
            CutBlur { bx: blurShape.pillX + pillRegL.p.x; by: blurShape.pillY + pillRegL.p.y; bw: pillRegL.p.width; bh: pillRegL.p.height; c: pillRegL.p.r }
        }
        Region {
            id: pillRegM
            readonly property Item p: bar.midPill
            readonly property bool on: blurShape.pillsOn && p.visible
            x: blurShape.pillX + p.x; y: blurShape.pillY + p.y
            width: on ? p.width : 0; height: on ? p.height : 0
            radius: (Theme.chamfer || Theme.square) ? 0 : p.radius
            CutBlur { bx: blurShape.pillX + pillRegM.p.x; by: blurShape.pillY + pillRegM.p.y; bw: pillRegM.p.width; bh: pillRegM.p.height; c: pillRegM.p.r }
        }
        Region {
            id: pillRegR
            readonly property Item p: bar.rightPill
            readonly property bool on: blurShape.pillsOn && p.visible
            x: blurShape.pillX + p.x; y: blurShape.pillY + p.y
            width: on ? p.width : 0; height: on ? p.height : 0
            radius: (Theme.chamfer || Theme.square) ? 0 : p.radius
            CutBlur { bx: blurShape.pillX + pillRegR.p.x; by: blurShape.pillY + pillRegR.p.y; bw: pillRegR.p.width; bh: pillRegR.p.height; c: pillRegR.p.r }
        }
        // the Frame with auto-hide (frameEdge): the whole frame, the screen minus its inside
        Region {
            item: frameEdge.visible && !win.covered ? fullArea : null
            Region { item: hole; radius: frameEdge.r; intersection: Intersection.Subtract }
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
        Region {
            // (Dynamic: its shape (`shell`) has plain round corners, tighter than a continuous
            // corner's reach: with the card's radius the blur stopped short of the corners, which
            // showed the sharp backdrop through them)
            // (its own place and size, not `item: blurBox`: an item's region is read once, when it
            // comes on. A menu zooming in from 94 % was about 98 % then, so the blur stayed that
            // much short of the card's far edge: 17 px on a wide menu like Settings)
            // (flush with the card. A pixel inside, to hide the blur's unsmoothed edge, left the
            // sharp backdrop showing as a dark line all the way round; the corner's radius is
            // already one more than the card's (SmoothRect.blurRadius), which keeps that edge
            // under the card's own where it curves)
            x: blurBox.x; y: blurBox.y
            width: blurBox.on ? blurBox.width : 0; height: blurBox.on ? blurBox.height : 0
            radius: floatCard.dyn ? shell.blurRadius : floatCard.blurRadius * blurBox.k
            CutBlur { bx: blurBox.x; by: blurBox.y; bw: blurBox.width; bh: blurBox.height; c: floatCard.r * blurBox.k }
        }
        Region {
            item: toastCard.on && toastCard.opacity > 0.6 ? toastCard : null; radius: toastCard.blurRadius
            CutBlur { bx: toastCard.x; by: toastCard.y; bw: toastCard.width; bh: toastCard.height; c: toastCard.r }
        }
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
        readonly property bool pageReady: !!win.currentPage && win.currentPage.opacity > 0.6
        readonly property bool pageIn: held || pageReady
        // once a page has come in, it stays while the card does: switching menus used to drop
        // it until the new page was in, so the card flashed see-through (washed out) every time
        property bool held: false
        onPageReadyChanged: if (pageReady && win.shown) held = true
        Connections { target: win; function onShownChanged() { if (!win.shown) blurBox.held = false; } }
        // (opening: from the very start, so the card fades in over a backdrop that's already
        // blurred and the look only ever settles towards the final one. Switched on part-way, it
        // jumped: on at 40 % the bright blur shone through the half-faded card (a flash); on at
        // the end, the card came in over the sharp backdrop and the blur then swept in)
        // (Cyberpunk: once the card has mostly glitched in; from the start, an empty blurred box
        // showed before any of the card did)
        // (Fjord and Industrial: once the panel has faded in, 8 and 10 %: from 0 the blur showed as
        // an empty box, its edges a band, for the frames before the panel was there)
        // Each style's effect gets its own moments: [on, coming in, once it's this far; off, going,
        // once it's back below this]. Frost (Fjord) and the shutter (Industrial) cover the whole
        // card from their first frame, and Doodle draws its outline first, so the blur can be
        // there from the start; the ones that bring the card in a piece at a time (the glitch,
        // Luxe's light, the ripple, the fold, the typing, the slam) wait until most of it is
        // there. Going, it stays until the card is mostly gone, instead of leaving the moment the
        // menu starts closing: that showed the sharp backdrop through the card all the way out.
        // (Before, every effect waited for 70 % coming in and dropped at once going, so Fjord's
        // frost came in over a sharp backdrop, then the blur popped in under it)
        readonly property var moments: ({ "": [0, 0.45], cyber: [0.7, 0.75], fjord: [0.16, 0.25], industrial: [0.1, 0.3], doodle: [0.15, 0.5],
                                          liquid: [0.45, 0.55], paper: [0.5, 0.55], terminal: [0.55, 0.7], concrete: [0.55, 0.6], luxe: [0.5, 0.55] })
        readonly property var when: moments[Theme.fxKind] || moments.cyber
        // (Dynamic: only once it's nearly in its place; the blur doesn't travel with it)
        readonly property bool on: !win.docked && (floatCard.dyn ? win.dynK > 0.97 : Theme.fxUnfold ? floatCard.unfold > 0.04
            // (coming in, only once the menu's own page shows: before that the card can still be
            // the last menu's size and place, and a blurred box sat there with nothing in it)
            : win.shown ? (pageIn && (Theme.cyber ? win.cardZoom >= when[0] : win.cardFade > when[1]))
            : (Theme.cyber ? win.cardZoom > when[1] : win.cardFade > when[1]))
        readonly property real part: Theme.fxUnfold ? Math.max(0.01, floatCard.unfold) : 1
        // the card zooms in and out from its own corner or side: the blur shrinks with it
        readonly property real k: floatCard.scale
        readonly property real fx: floatCard.onLeft ? 0 : (floatCard.onRight ? 1 : 0.5)
        readonly property real fy: floatCard.onTop ? 0 : (floatCard.onBottom ? 1 : 0.5)
        // (Dynamic: the shape's own box, as it settles. Its region is set from these numbers,
        // so it follows; at the card's box it showed as a dark band beside the shape on the
        // side it was still coming from, and the shape swelled past it)
        readonly property bool dyn: floatCard.dyn
        width: dyn ? Math.round(floatCard.mw) : Math.round(floatCard.width * k)
        height: dyn ? Math.round(floatCard.mh) : Math.round(floatCard.height * k * part)
        x: dyn ? Math.round(floatCard.x + floatCard.mx) : Math.round(floatCard.x + (floatCard.width - width) * fx)
        y: dyn ? Math.round(floatCard.y + floatCard.my) : Math.round(floatCard.y + (floatCard.height * k - height) / 2 + (floatCard.height - floatCard.height * k) * fy)
    }
}
