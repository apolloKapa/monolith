import QtQuick
import Quickshell
import Quickshell.Io
import "../core/emoji.js" as Emoji
import "../core"
import "../ui"

// Search: apps (the ones you open most first), a calculator, `>` commands in a terminal,
// `:` emojis (Enter copies) and `/` or `~` files (Enter opens).
Page {
    id: page
    pageId: "search"
    property string query: ""
    signal done()

    readonly property real rowH: 52
    readonly property int maxRows: Number(Store.get("search.rows", 7))
    // the height it has with nothing typed; while you search it stays that tall (the results
    // scroll inside it) so the menu doesn't jump about as you type
    readonly property bool typing: query.trim() !== ""
    // the apps' part: as many rows as Settings → Launcher → Results shown
    readonly property real listH: showGrid ? Math.min(maxRows * rowH, appGrid.contentHeight) : Math.max(1, Math.min(results.length, maxRows)) * rowH
    // favourites above or below add to that; beside it, the taller of the two
    readonly property real naturalH: fixedH > 0 ? fixedH
        : catBar.height + (favSide ? Math.max(listH, favBlockH) : favBlockH + listH)
    // (the favourites' own height, from their grid: beside the apps the favourites' box is as tall as
    // the launcher, so reading the box here looped while switching sides)
    readonly property real favBlockH: showFavs ? favGrid.height + 12 : 0
    // Settings → Launcher → Height: a fixed height instead (0: as tall as its rows)
    readonly property real fixedH: Math.max(0, Number(Store.get("search.height", 0)))
    property real restH: 0
    // checked a moment later: on the first key the results change before `typing` turns true
    onNaturalHChanged: Qt.callLater(keepRest)
    function keepRest() { if (!typing) restH = naturalH; }
    Component.onCompleted: { rebuildApps(); rebuildFavs(); restH = naturalH; }
    implicitHeight: typing && restH > 0 ? restH : naturalH
    // all apps as a grid of icons while nothing is typed (Settings → Launcher)
    readonly property bool showGrid: Store.get("search.grid", false) === true && query.trim() === ""
    readonly property int gridColumns: Number(Store.get("search.gridColumns", 6))

    // ── favourites: pinned apps, shown as a grid above everything (searching too) ──
    // (desktop ids; the earlier Monolith's list to start with). Right-click an app to pin or unpin.
    readonly property var favIds: Store.get("search.favorites", null) || Prefs.favorites
    // (made again only when the favourites or the hidden apps really change: every saved setting
    // makes the store's values new, and lists made from them on each one were rebuilt each time,
    // which threw the launcher back to its top whenever you favourited or hid something)
    readonly property string favKey: JSON.stringify(favIds) + "|" + JSON.stringify(hiddenIds)
    property var favs: []
    function rebuildFavs() { favs = favIds.map(id => DesktopEntries.byId(id) || DesktopEntries.byId(id + ".desktop")).filter(e => e && !isHidden(e)); }
    onFavKeyChanged: rebuildFavs()
    // apps you hid (right-click → Hide, or Settings → Menus & launcher → Hidden apps): still
    // installed, just not in the launcher
    readonly property var hiddenIds: Store.get("search.hidden", []) || []
    function isHidden(entry) { return hiddenIds.indexOf(entry.id) !== -1; }
    function hide(entry) { if (!isHidden(entry)) Store.set("search.hidden", hiddenIds.concat([entry.id])); }
    // the right-click menu: which app, and where (in the page)
    property var menuEntry: null
    property point menuAt: Qt.point(0, 0)
    function openMenu(entry, item) { menuEntry = entry; menuAt = item.mapToItem(page, item.width / 2, item.height / 2); }
    // where the favourites are (Settings → Launcher): above the apps, below them, or in a column
    // on their left or right
    readonly property string favPlace: Store.get("search.favPlace", "top")
    readonly property bool favSide: favPlace === "left" || favPlace === "right"
    // beside the apps they're a narrow column (their own number per row)
    readonly property int favColumns: favSide ? Number(Store.get("search.favSideColumns", 2)) : Number(Store.get("search.favColumns", 6))
    readonly property real favSideW: favColumns * 88
    // favourites stay at the top while you search too (the results list under them)
    readonly property bool showFavs: favs.length > 0 && Store.get("search.showFavorites", true) !== false
    function isFav(entry) { return favIds.some(id => id === entry.id || id + ".desktop" === entry.id || id === entry.id.replace(/\.desktop$/, "")); }
    function toggleFav(entry) {
        const id = entry.id.replace(/\.desktop$/, "");
        Store.set("search.favorites", isFav(entry) ? favIds.filter(x => x !== id && x + ".desktop" !== entry.id && x !== entry.id) : favIds.concat([id]));
    }
    // drag a favourite to another place in the grid
    property int favDrag: -1
    property point favPos: Qt.point(0, 0)
    function favIdOf(entry) { return favIds.find(id => id === entry.id || id + ".desktop" === entry.id || id === entry.id.replace(/\.desktop$/, "")) || entry.id.replace(/\.desktop$/, ""); }
    function moveFav(from, to) {
        if (from === to || from < 0) return;
        const shown = favs.map(e => favIdOf(e));
        const id = shown.splice(from, 1)[0];
        shown.splice(Math.max(0, Math.min(to, shown.length)), 0, id);
        Store.set("search.favorites", shown.concat(favIds.filter(x => shown.indexOf(x) === -1)));
    }
    function favIndexAt(p) {
        const col = Math.max(0, Math.min(favColumns - 1, Math.floor(p.x / favGrid.cellW)));
        const row = Math.max(0, Math.floor(p.y / (84 + favGrid.rowSpacing)));
        return Math.min(favs.length - 1, row * favColumns + col);
    }
    function launch(entry) { entry.execute(); Store.set("launches." + entry.id.replace(/\./g, "_"), uses(entry.id) + 1); page.done(); }

    // how often each app was opened from here, for the order
    // how often each app was opened (ranks them first), unless that's switched off
    function uses(id) { return Store.get("search.ranking", true) === false ? 0 : Number(Store.get("launches." + id.replace(/\./g, "_"), 0)); }
    // every app that shows (not hidden), the ones you open most first; made again only when the
    // apps or the hidden ones change, keeping where the list was scrolled to
    readonly property string appsKey: JSON.stringify(hiddenIds) + "|" + (Store.get("search.ranking", true) !== false)
    property var apps: []
    function rebuildApps() {
        const ly = list.contentY, gy = appGrid.contentY, ci = list.currentIndex;
        apps = DesktopEntries.applications.values.filter(a => !a.noDisplay && hiddenIds.indexOf(a.id) === -1)
            .slice().sort((a, b) => (uses(b.id) - uses(a.id)) || a.name.localeCompare(b.name));
        // (the list puts its selection back on the first one when its contents change: back where it was)
        Qt.callLater(() => {
            list.currentIndex = Math.max(0, Math.min(ci, results.length - 1));
            list.contentY = Math.max(0, Math.min(ly, list.contentHeight - list.height));
            appGrid.contentY = Math.max(0, Math.min(gy, appGrid.contentHeight - appGrid.height));
        });
    }
    onAppsKeyChanged: rebuildApps()
    Connections { target: DesktopEntries.applications; function onValuesChanged() { page.rebuildApps(); page.rebuildFavs(); } }

    // category tabs over the apps while nothing is typed (Settings → Launcher): the freedesktop
    // main categories that have at least one app
    readonly property bool showCats: Store.get("search.categories", false) === true && !typing
    readonly property var catDefs: [["all", "All"], ["Network", "Web"], ["Game", "Games"], ["AudioVideo", "Media"], ["Office", "Office"],
        ["Development", "Code"], ["Graphics", "Design"], ["System", "System"], ["Utility", "Tools"]]
    function inCat(a, c) { return c === "all" || (a.categories || []).indexOf(c) !== -1; }
    readonly property var cats: catDefs.filter(c => c[0] === "all" || apps.some(a => inCat(a, c[0])))
    property string cat: "all"
    readonly property var shownApps: showCats && cat !== "all" ? apps.filter(a => inCat(a, cat)) : apps
    function stepCat(d) { const i = cats.findIndex(c => c[0] === cat); cat = cats[(Math.max(0, i) + d + cats.length) % cats.length][0]; }

    // files: the folder typed so far, or a name search under home
    property var files: []
    function fileQuery(q) { fileTimer.q = q; fileTimer.restart(); }
    Timer {
        id: fileTimer
        property string q: ""
        interval: 120
        onTriggered: {
            fileProc.running = false;
            fileProc.command = ["sh", "-c",
                "q=\"$1\"; case \"$q\" in \"~\"*) q=\"$HOME${q#\\~}\";; esac; " +
                "if [ -d \"$q\" ]; then ls -1Ap \"$q\" | head -40 | sed \"s|^|${q%/}/|\"; " +
                "else d=$(dirname \"$q\"); b=$(basename \"$q\"); [ -d \"$d\" ] && find \"$d\" -maxdepth 3 -iname \"*$b*\" -not -path '*/.*' 2>/dev/null | head -40; fi", "_", q];
            fileProc.running = true;
        }
    }
    Process {
        id: fileProc
        stdout: StdioCollector { onStreamFinished: page.files = text.split("\n").filter(l => l) }
    }
    // (typing starts the list at the top; the list changing under you, an app hidden, keeps your place)
    onQueryChanged: { list.currentIndex = 0; const q = query.trim(); if (q.startsWith("/") || q.startsWith("~")) fileQuery(q); }

    function score(a, q) {
        const n = a.name.toLowerCase();
        if (n === q) return 100;
        if (n.startsWith(q)) return 80;
        if (n.split(/[\s\-_.]/).some(w => w.startsWith(q))) return 60;
        if (n.indexOf(q) !== -1) return 40;
        const extra = ((a.genericName || "") + " " + (a.keywords || []).join(" ") + " " + (a.comment || "")).toLowerCase();
        if (extra.indexOf(q) !== -1) return 20;
        return 0;
    }

    function calc(q) {
        if (!/^[\d\s+\-*/().,%^]+$/.test(q) || !/[+\-*/%^]/.test(q)) return null;
        try {
            const v = Function('"use strict"; return (' + q.replace(/\^/g, "**").replace(/,/g, ".") + ')')();
            return (typeof v === "number" && isFinite(v)) ? String(Math.round(v * 1e10) / 1e10) : null;
        } catch (e) { return null; }
    }

    readonly property var results: {
        const q = query.trim().toLowerCase();
        if (q.startsWith(">")) {
            const cmd = query.trim().substring(1).trim();
            return [{ kind: "cmd", name: cmd === "" ? "Type a command" : cmd, sub: "Run in a terminal", icon: "terminal", cmd: cmd }];
        }
        if (q.startsWith(":")) {
            // by its short name (:sob, :joy:, :thumbsup), its name ("loudly crying") or a tag ("sad");
            // exact short names first, then ones that start with what you typed, then the rest
            const e = q.substring(1).trim().replace(/:$/, "");
            const words = e.replace(/_/g, " ");
            const score = x => {
                if (e === "") return 5;
                const codes = (x[3] || "").split(" ");
                if (codes.indexOf(e) !== -1) return 0;
                if (codes.some(c => c.startsWith(e))) return 1;
                if (x[1].startsWith(words)) return 2;
                if (codes.some(c => c.indexOf(e) !== -1) || x[1].indexOf(words) !== -1) return 3;
                if ((x[4] || "").split(" ").some(t => t.startsWith(words))) return 4;
                return -1;
            };
            const hits = Emoji.list.map((x, i) => [x, score(x), i]).filter(h => h[1] >= 0)
                .sort((a, b) => a[1] - b[1] || a[2] - b[2]).slice(0, 60).map(h => h[0]);
            return hits.map(x => ({ kind: "emoji", name: x[1], glyph: x[0],
                sub: (x[3] ? ":" + x[3].split(" ")[0] + ":  ·  " : "") + Emoji.groups[x[2]] + " · Enter copies" }));
        }
        if (q.startsWith("/") || q.startsWith("~")) {
            return files.map(f => ({ kind: "file", name: f.replace(/\/$/, "").split("/").pop(), sub: f.replace(Quickshell.env("HOME"), "~"), path: f, icon: f.endsWith("/") ? "folder" : "draft" }));
        }
        const out = [];
        const r = calc(q);
        if (r !== null) out.push({ kind: "calc", name: r, sub: "Copy the result", icon: "calculate", value: r });
        if (q === "") return out.concat(shownApps.map(a => ({ kind: "app", entry: a })));
        const scored = apps.map(a => ({ a: a, s: score(a, q) })).filter(x => x.s > 0).sort((x, y) => y.s - x.s);
        return out.concat(scored.map(x => ({ kind: "app", entry: x.a })));
    }
    onResultsChanged: list.currentIndex = Math.max(0, Math.min(list.currentIndex, results.length - 1))

    function activate(i) {
        const it = results[i];
        if (!it) return;
        if (it.kind === "app") { it.entry.execute(); Store.set("launches." + it.entry.id.replace(/\./g, "_"), uses(it.entry.id) + 1); }
        else if (it.kind === "emoji") Quickshell.execDetached(["wl-copy", "--", it.glyph]);
        else if (it.kind === "file") Quickshell.execDetached(["xdg-open", it.path]);
        else if (it.kind === "calc") Quickshell.execDetached(["wl-copy", "--", it.value]);
        else if (it.kind === "cmd" && it.cmd !== "") Quickshell.execDetached(["sh", "-c", "kitty -e sh -c " + JSON.stringify(it.cmd + "; exec $SHELL")]);
        page.done();
    }

    Keys.onUpPressed: list.currentIndex = Math.max(0, list.currentIndex - 1)
    Keys.onDownPressed: list.currentIndex = Math.min(results.length - 1, list.currentIndex + 1)
    Keys.onReturnPressed: activate(list.currentIndex)
    // Alt+←/→: the previous / next category
    Keys.onLeftPressed: event => { if (page.showCats && (event.modifiers & Qt.AltModifier)) page.stepCat(-1); else event.accepted = false; }
    Keys.onRightPressed: event => { if (page.showCats && (event.modifiers & Qt.AltModifier)) page.stepCat(1); else event.accepted = false; }
    Keys.onEnterPressed: activate(list.currentIndex)

    Item {
        id: catBar
        width: parent.width
        height: page.showCats ? 44 : 0
        visible: page.showCats
        Segmented {
            width: parent.width; height: 34
            opts: page.cats
            value: page.cat
            onPicked: v => page.cat = v
        }
    }
    Item {
        id: favArea
        readonly property bool showing: page.showFavs
        x: page.favPlace === "right" ? parent.width - width : 0
        y: page.favPlace === "bottom" ? parent.height - height : catBar.height
        width: page.favSide ? page.favSideW : parent.width
        height: !showing ? 0 : (page.favSide ? parent.height - catBar.height : favGrid.height + 12)
        visible: showing
        // (beside the apps, they scroll if there are more than fit)
        clip: page.favSide
        Grid {
            id: favGrid
            width: parent.width
            columns: page.favColumns
            rowSpacing: 4
            readonly property real cellW: width / page.favColumns
            Repeater {
                model: page.favs
                Pressable {
                    id: favTile
                    required property var modelData
                    required property int index
                    width: favGrid.cellW - 4
                    height: 84
                    readonly property bool dragged: page.favDrag === index
                    readonly property bool target: page.favDrag >= 0 && page.favDrag !== index && page.favIndexAt(page.favPos) === index
                    color: target ? Qt.alpha(Theme.accent, 0.18) : (hovered ? Theme.containerHigh : "transparent")
                    border.width: target ? 2 : 0
                    border.color: Theme.accent
                    opacity: dragged ? 0.3 : 1
                    onClicked: page.launch(modelData)
                    onRightClicked: page.openMenu(modelData, favTile)
                    // drag it (move a little while holding) to put it somewhere else
                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: page.favDrag === favTile.index ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                        property point start
                        property bool moved: false
                        onPressed: mouse => { start = Qt.point(mouse.x, mouse.y); moved = false; }
                        onPositionChanged: mouse => {
                            if (!pressed) return;
                            if (!moved && Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) > 8) { moved = true; page.favDrag = favTile.index; }
                            if (moved) page.favPos = mapToItem(favGrid, mouse.x, mouse.y);
                        }
                        // end the drag first, then reorder: saving rebuilds the grid (this tile too)
                        onReleased: {
                            const from = favTile.index, to = page.favIndexAt(page.favPos), wasMoved = moved, entry = favTile.modelData;
                            page.favDrag = -1;
                            moved = false;
                            if (wasMoved) Qt.callLater(() => page.moveFav(from, to));
                            else page.launch(entry);
                        }
                        onCanceled: page.favDrag = -1
                    }
                    Column {
                        anchors.centerIn: parent
                        width: parent.width - 8
                        spacing: 6
                        Image {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 40; height: 40
                            sourceSize: Qt.size(80, 80)
                            source: Quickshell.iconPath(parent.parent.modelData.icon, "application-x-executable")
                            asynchronous: true; smooth: true; mipmap: true
                        }
                        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: parent.parent.modelData.name; font.pixelSize: Theme.sizeSmall }
                    }
                }
            }
        }
        // the line between them and the apps, on the apps' side
        Rectangle {
            readonly property string side: ({ top: "bottom", bottom: "top", left: "right", right: "left" })[page.favPlace] || "bottom"
            x: side === "right" ? parent.width - 4 : (side === "left" ? 3 : 0)
            y: side === "bottom" ? parent.height - 6 : (side === "top" ? 5 : 0)
            width: side === "left" || side === "right" ? 1 : parent.width
            height: side === "left" || side === "right" ? parent.height : 1
            color: Theme.ringTrack
        }
        // the favourite being carried
        Rectangle {
            visible: page.favDrag >= 0
            z: 50
            width: 64; height: 64
            radius: Theme.corner(64, 6)
            x: page.favPos.x - width / 2
            y: page.favPos.y - height / 2
            color: Theme.accentContainer
            border.width: 2; border.color: Theme.accent
            Image {
                anchors.centerIn: parent
                width: 40; height: 40
                sourceSize: Qt.size(80, 80)
                source: page.favDrag >= 0 && page.favs[page.favDrag] ? Quickshell.iconPath(page.favs[page.favDrag].icon, "application-x-executable") : ""
            }
        }
    }

    GridView {
        SmoothWheel {}
        id: appGrid
        visible: page.showGrid
        anchors.fill: parent
        anchors.topMargin: (page.favPlace === "top" ? favArea.height : 0) + catBar.height
        anchors.bottomMargin: page.favPlace === "bottom" ? favArea.height : 0
        anchors.leftMargin: page.favPlace === "left" && favArea.showing ? page.favSideW + 8 : 0
        anchors.rightMargin: page.favPlace === "right" && favArea.showing ? page.favSideW + 8 : 0
        clip: true
        cellWidth: width / page.gridColumns
        cellHeight: 92
        boundsBehavior: Flickable.StopAtBounds
        model: page.showGrid ? page.shownApps : []
        delegate: Pressable {
            id: gridTile
            required property var modelData
            width: appGrid.cellWidth - 4
            height: 88
            color: hovered ? Theme.containerHigh : "transparent"
            onClicked: page.launch(modelData)
            onRightClicked: page.openMenu(modelData, gridTile)
            Column {
                anchors.centerIn: parent
                width: parent.width - 8
                spacing: 6
                Image { anchors.horizontalCenter: parent.horizontalCenter; width: 40; height: 40; sourceSize: Qt.size(80, 80); source: Quickshell.iconPath(parent.parent.modelData.icon, "application-x-executable"); asynchronous: true; smooth: true; mipmap: true }
                Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: parent.parent.modelData.name; font.pixelSize: Theme.sizeSmall }
            }
        }
    }

    ListView {
        SmoothWheel {}
        id: list
        visible: !page.showGrid
        anchors.fill: parent
        anchors.topMargin: (page.favPlace === "top" ? favArea.height : 0) + catBar.height
        anchors.bottomMargin: page.favPlace === "bottom" ? favArea.height : 0
        anchors.leftMargin: page.favPlace === "left" && favArea.showing ? page.favSideW + 8 : 0
        anchors.rightMargin: page.favPlace === "right" && favArea.showing ? page.favSideW + 8 : 0
        clip: true
        model: page.results
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: Theme.moveMs
        highlightMoveVelocity: -1
        highlight: Rectangle {
            radius: Theme.corner(page.rowH)
            color: Theme.selected
        }
        onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

        delegate: Pressable {
            id: row
            required property var modelData
            required property int index
            width: list.width
            height: page.rowH
            color: "transparent"
            onClicked: page.activate(index)
            // right-click an app: favourite or not, or hide it
            onRightClicked: if (isApp) page.openMenu(modelData.entry, row)

            readonly property bool isApp: modelData.kind === "app"
            readonly property string title: isApp ? modelData.entry.name : modelData.name
            readonly property string sub: isApp ? (modelData.entry.comment || modelData.entry.genericName || "") : modelData.sub

            Rectangle {
                id: iconBox
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: Theme.corner(36, 4)
                color: Theme.control
                Image {
                    anchors.centerIn: parent
                    visible: row.isApp
                    width: 24
                    height: 24
                    sourceSize: Qt.size(48, 48)
                    source: row.isApp ? Quickshell.iconPath(row.modelData.entry.icon, "application-x-executable") : ""
                    asynchronous: true
                    smooth: true
                    mipmap: true
                }
                Text {
                    anchors.centerIn: parent
                    visible: row.modelData.kind === "emoji"
                    text: row.modelData.glyph || ""
                    font.pixelSize: 22
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !row.isApp && row.modelData.kind !== "emoji"
                    name: row.isApp ? "" : (row.modelData.icon || "")
                    size: 20
                    color: Theme.accent
                }
            }
            Column {
                anchors.left: iconBox.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Label { width: parent.width - 24; text: row.title; strong: row.index === list.currentIndex }
                Label { width: parent.width; text: row.sub; muted: true; font.pixelSize: Theme.sizeSmall; visible: text !== "" }
            }
            Icon { visible: row.isApp && page.isFav(row.modelData.entry); anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; name: "star"; filled: true; size: 16; color: Theme.accent }
        }
    }

    // ── an app's right-click menu ──
    MouseArea {
        anchors.fill: parent
        z: 90
        visible: page.menuEntry !== null
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: page.menuEntry = null
    }
    Rectangle {
        id: appMenu
        z: 91
        visible: page.menuEntry !== null
        width: 230
        height: menuCol.implicitHeight + 12
        x: Math.max(4, Math.min(page.width - width - 4, page.menuAt.x - width / 2))
        y: Math.max(4, Math.min(page.height - height - 4, page.menuAt.y))
        radius: Theme.corner(80, 6)
        color: Theme.containerHigh
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        CardShadow {}
        component MenuRow: Pressable {
            property string icon: ""
            property string text: ""
            property bool danger: false
            width: menuCol.width; height: 36
            color: hovered ? Theme.control : "transparent"
            Icon { x: 10; anchors.verticalCenter: parent.verticalCenter; name: parent.icon; size: 18; color: parent.danger ? Theme.danger : Theme.text }
            Label { x: 38; anchors.verticalCenter: parent.verticalCenter; text: parent.text; color: parent.danger ? Theme.danger : Theme.text }
        }
        Column {
            id: menuCol
            x: 6; y: 6
            width: parent.width - 12
            Label { x: 10; width: parent.width - 20; height: 28; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; text: page.menuEntry ? page.menuEntry.name : ""; strong: true; font.pixelSize: Theme.sizeSmall }
            MenuRow { icon: "open_in_new"; text: "Open"; onClicked: { const e = page.menuEntry; page.menuEntry = null; page.launch(e); } }
            MenuRow {
                readonly property bool fav: !!page.menuEntry && page.isFav(page.menuEntry)
                icon: fav ? "star_border" : "star"
                text: fav ? "Remove from favourites" : "Add to favourites"
                onClicked: { page.toggleFav(page.menuEntry); page.menuEntry = null; }
            }
            MenuRow { icon: "visibility_off"; text: "Hide from the launcher"; danger: true; onClicked: { page.hide(page.menuEntry); page.menuEntry = null; } }
        }
    }
    Keys.onEscapePressed: event => { if (page.menuEntry) { page.menuEntry = null; event.accepted = true; } else event.accepted = false; }
}
