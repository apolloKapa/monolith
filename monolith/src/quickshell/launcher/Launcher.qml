import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import "../"
import "../reusables"
import "../WindowRegistry.js" as WindowRegistry
import "./EmojiData.js" as EmojiData

PanelWindow {
    id: launcherWindow

    screen: LauncherController.screen

    WlrLayershell.namespace: "qs-applauncher"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: launcherWindow.isVisible
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region { item: topBarHole; intersection: Intersection.Xor }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) {
        return (typeof Scaler !== "undefined" && Scaler.s) ? Scaler.s(val) : val;
    }

    function closeLauncher() {
        LauncherController.hide();
    }

    property bool isVisible: LauncherController.isVisible
    property int configRevision: 0
    property bool appsLoaded: false
    // the app list was rebuilt after the last close, so opening needn't redo it
    property bool listFresh: false
    property real introItems: 1.0
    property int currentTabIndex: 0

    property string tabAppsTitle: (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_applications", "Applications") : "Applications"
    property string tabFilesTitle: (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_files", "Files") : "Files"
    property string tabEmojisTitle: (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_emojis", "Emojis") : "Emojis"

    function saveLastTab() {
        let dir = (typeof Caching !== "undefined" && typeof Caching.getCacheDir === "function") ? Caching.getCacheDir("launcher") : "";
        if (dir) {
            Quickshell.execDetached(["bash", "-c", "mkdir -p '" + dir + "' && echo '" + currentTabIndex + "' > '" + dir + "/last_tab.txt'"]);
        }
    }

    onCurrentTabIndexChanged: {
        saveLastTab();
        if (tabSwitch.currentIndex !== currentTabIndex) {
            tabSwitch.currentIndex = currentTabIndex;
        }
        if (currentTabIndex === 0) {
            executeFilter(searchInput.text);
        } else if (currentTabIndex === 1) {
            executeFileSearch(searchInput.text);
        } else {
            executeEmojiFilter(searchInput.text);
        }
        launcherWindow.grabInputFocus();
    }

    FileView {
        id: lastTabWatcher
        path: (typeof Caching !== "undefined" && typeof Caching.getCacheDir === "function") ? (Caching.getCacheDir("launcher") + "/last_tab.txt") : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let val = text().trim();
                if (val !== "") {
                    let idx = parseInt(val);
                    if (!isNaN(idx) && (idx >= 0 && idx <= 2)) {
                        launcherWindow.currentTabIndex = idx;
                        tabSwitch.currentIndex = idx;
                    }
                }
            } catch(e) {}
        }
    }

    // the apps' entrance: each item starts a little after the one before (a gentle wave,
    // capped so long lists don't wait) and its own fade and rise overlap a lot, so it reads
    // as one smooth motion instead of items popping in one by one
    function introAt(idx, span) {
        let start = Math.min(idx, 12) * 0.032;
        return Math.min(1.0, Math.max(0.0, (introItems - start) / span));
    }
    function getItemProgress(idx) {
        if (introItems >= 1.0) return 1.0;
        if (introItems <= 0.0) return 0.0;
        let p = introAt(idx, 0.62);
        return 1 - Math.pow(1 - p, 3);
    }

    function getItemOpacity(idx) {
        if (introItems >= 1.0) return 1.0;
        if (introItems <= 0.0) return 0.0;
        let p = introAt(idx, 0.5);
        return p * p * (3 - 2 * p);
    }

    // the apps used to ripple in on open; now they're simply there when the card appears
    function restartItemsIntro() {
        itemsIntroSequence.stop();
        introItems = 1.0;
    }

    SequentialAnimation {
        id: itemsIntroSequence
        running: false
        PauseAnimation { duration: (50) * ThemeBackend.animScale }
        NumberAnimation {
            target: launcherWindow
            property: "introItems"
            from: 0.0
            to: 1.0
            duration: (820) * ThemeBackend.animScale
            easing.type: Easing.Linear
        }
    }

    Component.onCompleted: {
        if (smartRanking) {
            rankFetcher.running = true;
        }
        loadApps();
        appsLoaded = true;
        if (currentTabIndex === 0) {
            executeFilter("");
        } else if (currentTabIndex === 1) {
            executeFileSearch("");
        } else {
            executeEmojiFilter("");
        }
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        // (it used to close on every settings save, so pinning or reordering an app closed it;
        // moving the launcher or the bar still closes it, see onAttachEdgeChanged and below)
        function onSettingsLoaded() {
            launcherWindow.configRevision++;
        }
    }

    Connections {
        target: (typeof I18n !== "undefined") ? I18n : null
        function onLanguageChanged() {
            launcherWindow.tabAppsTitle = (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_applications", "Applications") : "Applications";
            launcherWindow.tabFilesTitle = (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_files", "Files") : "Files";
            launcherWindow.tabEmojisTitle = (typeof I18n !== "undefined") ? I18n.t("applauncher.tab_emojis", "Emojis") : "Emojis";
            if (launcherWindow.isVisible) {
                launcherWindow.loadApps();
                if (launcherWindow.currentTabIndex === 0) {
                    launcherWindow.executeFilter(searchInput.text);
                } else if (launcherWindow.currentTabIndex === 1) {
                    launcherWindow.executeFileSearch(searchInput.text);
                } else {
                    launcherWindow.executeEmojiFilter(searchInput.text);
                }
            } else {
                launcherWindow.appsLoaded = false;
            }
        }
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined") ? DesktopEntries : null
        function onApplicationsChanged() {
            if (launcherWindow.isVisible) {
                launcherWindow.loadApps();
                if (launcherWindow.currentTabIndex === 0) {
                    launcherWindow.executeFilter(searchInput.text);
                }
            } else {
                launcherWindow.appsLoaded = false;
            }
        }
    }

    Connections {
        target: (typeof DesktopEntries !== "undefined" && DesktopEntries.applications) ? DesktopEntries.applications : null
        function onValuesChanged() {
            if (launcherWindow.isVisible) {
                launcherWindow.loadApps();
                if (launcherWindow.currentTabIndex === 0) {
                    launcherWindow.executeFilter(searchInput.text);
                }
            } else {
                launcherWindow.appsLoaded = false;
            }
        }
    }

    property var defaultLauncherSettings: ({
        "position": "top",
        "width": 600,
        "itemCount": 6,
        "terminalCommand": "kitty -e",
        "smartRanking": true,
        "favorites": [],
        "showRail": true,
        "showTabs": true,
        "gridView": false,
        "gridColumns": 5,
        "favColumns": 4,
        "appOrder": [],
        "showDescriptions": true
    })

    property var rawLauncherSettings: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.launcher) {
            return Config.rawSettings.launcher;
        }
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("launcher", defaultLauncherSettings);
        }
        return defaultLauncherSettings;
    }

    property string launcherPosition: (rawLauncherSettings && rawLauncherSettings.position !== undefined) ? rawLauncherSettings.position : "top"
    property real customWidth: (rawLauncherSettings && rawLauncherSettings.width !== undefined && !isNaN(rawLauncherSettings.width) && rawLauncherSettings.width > 0) ? rawLauncherSettings.width : 600
    property int customItemCount: (rawLauncherSettings && rawLauncherSettings.itemCount !== undefined && !isNaN(rawLauncherSettings.itemCount) && rawLauncherSettings.itemCount > 0) ? rawLauncherSettings.itemCount : 6
    property string terminalCommand: (rawLauncherSettings && rawLauncherSettings.terminalCommand !== undefined) ? rawLauncherSettings.terminalCommand : "kitty -e"
    property bool smartRanking: (rawLauncherSettings && rawLauncherSettings.smartRanking !== undefined) ? rawLauncherSettings.smartRanking : true
    // Settings -> Launcher: the left rail (tabs + favourite apps), grid view, descriptions
    property var favorites: (rawLauncherSettings && Array.isArray(rawLauncherSettings.favorites)) ? rawLauncherSettings.favorites : []
    // the favourites rail, except in the emoji picker (Meta+.), which shows only emojis
    readonly property bool showRailSetting: !(rawLauncherSettings && rawLauncherSettings.showRail === false)
    readonly property bool showRail: showRailSetting && LauncherController.mode !== "emoji"
    // Settings -> Launcher -> Tabs: the Applications / Files / Emojis switch. Off, the launcher opens
    // on Applications, and the emoji picker has its own key (monolith msg toggle emoji)
    property bool showTabs: !(rawLauncherSettings && rawLauncherSettings.showTabs === false)
    property bool gridView: !!(rawLauncherSettings && rawLauncherSettings.gridView === true)
    property int gridColumns: (rawLauncherSettings && Number(rawLauncherSettings.gridColumns) >= 3) ? Math.min(8, Number(rawLauncherSettings.gridColumns)) : 5
    property bool showDescriptions: !(rawLauncherSettings && rawLauncherSettings.showDescriptions === false)
    // apps show as a grid (only the Applications tab; files stay a list)
    readonly property bool appGridActive: gridView && currentTabIndex === 0
    // the favourites pane: the left part of the launcher, a grid of pinned apps under the tabs
    property int favColumns: (rawLauncherSettings && Number(rawLauncherSettings.favColumns) >= 2) ? Math.min(6, Number(rawLauncherSettings.favColumns)) : 4
    property var appOrder: (rawLauncherSettings && Array.isArray(rawLauncherSettings.appOrder)) ? rawLauncherSettings.appOrder : []
    readonly property real favCellH: s(84)
    readonly property int favRows: Math.max(1, Math.ceil(favoriteApps.length / favColumns))

    function saveLauncher(patch) {
        let cur = JSON.parse(JSON.stringify(Config.getSetting("launcher", defaultLauncherSettings) || {}));
        for (let k in patch) cur[k] = patch[k];
        Config.setSetting("launcher", cur);
    }
    // The grid's slots count the favourites it shows (favoriteApps). Pinned apps that aren't
    // installed any more stay in `favorites` but aren't shown, so slot numbers aren't indexes
    // into it: a drag used them as if they were and moved the wrong app. These work on the
    // shown ones and leave the hidden ones where they are.
    function withShownFavorites(change) {
        let shown = favoriteApps.map(a => a.desktop_id);
        let moved = change(shown.slice());
        let out = [], k = 0;
        for (const id of favorites) {
            if (shown.indexOf(id) !== -1) { if (k < moved.length) out.push(moved[k++]); }
            else out.push(id);
        }
        while (k < moved.length) out.push(moved[k++]);
        saveLauncher({ "favorites": out });
    }
    // move a favourite from one slot to another (dragging in the grid)
    function moveFavorite(from, to) {
        let n = favoriteApps.length;
        if (from < 0 || from >= n) return;
        to = Math.max(0, Math.min(n - 1, to));
        if (from === to) return;
        withShownFavorites(ids => { let it = ids.splice(from, 1)[0]; ids.splice(to, 0, it); return ids; });
    }
    // pin an app at a slot (dragging a list row onto the grid)
    function pinAt(desktopId, slot) {
        if (!desktopId) return;
        withShownFavorites(ids => {
            let i = ids.indexOf(desktopId);
            if (i !== -1) ids.splice(i, 1);
            slot = Math.max(0, Math.min(ids.length, slot));
            ids.splice(slot, 0, desktopId);
            return ids;
        });
    }
    // reorder the list (dragging a row); the order is kept for the unfiltered list
    function moveListItem(from, to) {
        if (from < 0 || from >= appModel.count) return;
        to = Math.max(0, Math.min(appModel.count - 1, to));
        if (from === to) return;
        appModel.move(from, to, 1);
        let order = [];
        for (let i = 0; i < appModel.count; i++) {
            let id = appModel.get(i).desktop_id;
            if (id) order.push(id);
        }
        // keep the place of apps not shown right now (the pinned ones)
        for (let j = 0; j < appOrder.length; j++) if (order.indexOf(appOrder[j]) === -1) order.push(appOrder[j]);
        appList.currentIndex = to;
        saveLauncher({ "appOrder": order });
    }

    function isFavorite(desktopId) {
        return desktopId !== "" && favorites.indexOf(desktopId) !== -1;
    }
    function toggleFavorite(desktopId) {
        if (!desktopId) return;
        let cur = JSON.parse(JSON.stringify(Config.getSetting("launcher", defaultLauncherSettings) || {}));
        let favs = Array.isArray(cur.favorites) ? cur.favorites.slice() : [];
        let i = favs.indexOf(desktopId);
        if (i === -1) favs.push(desktopId); else favs.splice(i, 1);
        cur.favorites = favs;
        Config.setSetting("launcher", cur);
    }
    // favourites as app entries (name, icon, desktop_id), in the order they were pinned
    readonly property var favoriteApps: {
        let out = [];
        for (let i = 0; i < favorites.length; i++) {
            for (let j = 0; j < allApps.length; j++) {
                if (allApps[j].desktop_id === favorites[i]) { out.push(allApps[j]); break; }
            }
        }
        return out;
    }
    function iconUrl(ic) {
        if (!ic) return "";
        if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
        if (ic.startsWith("/")) return "file://" + ic;
        let baseName = ic.replace(/\.(png|svg|xpm|ico)$/i, "");
        if (typeof Quickshell !== "undefined" && typeof Quickshell.iconPath === "function") {
            let resolved = Quickshell.iconPath(ic) || Quickshell.iconPath(baseName);
            if (resolved && resolved.length > 0) return resolved.startsWith("/") ? ("file://" + resolved) : resolved;
        }
        return "image://icon/" + baseName;
    }

    onSmartRankingChanged: {
        if (launcherWindow.isVisible) {
            loadApps();
            if (launcherWindow.currentTabIndex === 0) {
                executeFilter(searchInput.text);
            }
        } else {
            launcherWindow.appsLoaded = false;
        }
    }

    property var rawBarSettings: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) ? Config.rawSettings.bar : ({});
    }

    property string barStyle: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
        let s = Config.rawSettings.bar.style;
        if (typeof s === "string") return s;
        if (s && typeof s === "object") {
            if (s.fill || s.mode === "fill") return "fill";
            if (s.solid || s.mode === "solid") return "solid";
        }
        return "modular";
    }

    property string barPosition: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "top";
        return Config.rawSettings.bar.position || "top";
    }

    property bool barAutohide: (rawBarSettings && rawBarSettings.autohide !== undefined) ? Boolean(rawBarSettings.autohide) : false

    readonly property bool isOsdFullscreen: (typeof OsdController !== "undefined") ? Boolean(OsdController.isFullscreen) : false

    readonly property bool isToplevelFullscreen: {
        try {
            if (typeof ToplevelManager !== "undefined" && ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.fullscreen) {
                let atl = ToplevelManager.activeToplevel;
                if (atl.screens && atl.screens.length > 0) {
                    return atl.screens.indexOf(launcherWindow.screen) !== -1;
                }
                return true;
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isHyprlandFullscreen: {
        try {
            if (typeof Hyprland !== "undefined" && Hyprland.focusedWorkspace) {
                return Boolean(Hyprland.focusedWorkspace.hasFullscreen || (Hyprland.activeToplevel && Hyprland.activeToplevel.fullscreen));
            }
        } catch (e) {}
        return false;
    }

    readonly property bool isFullscreenActive: isOsdFullscreen || isToplevelFullscreen || isHyprlandFullscreen

    readonly property bool isBarEffectivelyHidden: barAutohide || isFullscreenActive

    property real barHeight: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height) ? s(Config.rawSettings.bar.height) : s(40);
    }

    property bool isBarAttachable: barStyle === "solid" || barStyle === "fill"
    property bool barMatchesLauncher: isBarAttachable && (attachEdge === barPosition) && !isBarEffectivelyHidden

    property string attachEdge: launcherPosition
    property bool isSideAttached: attachEdge === "left" || attachEdge === "right"
    property bool isCentered: attachEdge === "center"

    onAttachEdgeChanged: {
        LauncherController.hide();
    }

    onBarStyleChanged: {
        LauncherController.hide();
    }

    onBarPositionChanged: {
        LauncherController.hide();
    }

    // ── the launcher's shape: one floating rounded surface. The search row sits at its top
    // (its bottom at the bottom edge) and the pinned apps, the results and a footer unfold out
    // of it. Nothing is attached to a screen edge: the position setting only says where it floats.
    readonly property real launcherW: Math.round(s(customWidth) + s(60))
    readonly property real capsuleH: s(64)
    readonly property real footerH: s(42)
    // the search pill sits inset in the search row; the card's corner is the pill's
    // radius plus that inset, so the two curves run side by side
    readonly property real pillInset: s(8)
    readonly property real pillH: capsuleH - 2 * pillInset
    readonly property real sectionGap: s(10)
    readonly property real bodyPad: s(16)
    readonly property real bodyPadTop: s(8)
    // roundness follows Settings -> Theme -> border radius (0 in the square styles): nothing is
    // rounder than that, and the card's corner is the search pill's plus its inset (concentric)
    readonly property real roundBase: ThemeBackend.borderRadius
    function rr(h) { return Math.max(0, Math.min(h / 2, roundBase)); }
    readonly property real pillR: rr(pillH)
    function innerR(inset) { return Math.max(0, pillR - inset); }
    readonly property real bodyRadius: roundBase <= 0 ? 0 : pillR + pillInset
    readonly property real edgeMargin: s(16)
    readonly property real rowH: s(50)
    readonly property real rowSpacing: s(4)
    readonly property real rowStep: rowH + rowSpacing
    readonly property real gridCellH: s(100)
    readonly property int emojiColumns: 7
    readonly property real emojiCellH: s(62)
    readonly property real emojiTabsH: currentTabIndex === 2 ? s(38) + s(8) : 0
    readonly property real innerW: launcherW - 2 * bodyPad

    // the colours every round thing uses
    // Material 3 roles: tonal surfaces, secondary-container selection, primary accents
    readonly property bool glassy: ThemeBackend.liquidGlass
    readonly property color accent: ThemeBackend.primary
    // Orbit already lifts the panel colour (base) to this layer
    readonly property color surfaceColor: Qt.alpha(ThemeBackend.orbit ? ThemeBackend.base : ThemeBackend.surfaceContainer, ThemeBackend.elementOpacity)
    readonly property color searchFill: glassy ? Qt.alpha("#ffffff", 0.10) : Qt.alpha(ThemeBackend.surfaceContainerHighest, Math.max(0.7, ThemeBackend.elementOpacity))
    readonly property color selectColor: glassy ? Qt.alpha("#ffffff", 0.18) : ThemeBackend.secondaryContainer
    readonly property color onSelect: glassy ? "#ffffff" : ThemeBackend.onSecondaryContainer
    readonly property color hoverColor: Qt.alpha(ThemeBackend.text, 0.08)
    readonly property color bubbleColor: glassy ? Qt.alpha("#ffffff", 0.10) : ThemeBackend.surfaceContainerHighest
    readonly property color dividerColor: glassy ? Qt.alpha("#ffffff", 0.16) : ThemeBackend.outlineVariant

    // smooth easing used everywhere: no overshoot, long soft tail
    readonly property int easeMain: Easing.OutQuint
    function dur(ms) { return ms * ThemeBackend.animScale; }

    // pinned apps show on the Applications tab while nothing is typed (and while a row is
    // being dragged, so it can be dropped on them)
    readonly property bool queryEmpty: searchInput.text.trim() === ""
    readonly property bool favShown: showRail && currentTabIndex === 0 && (queryEmpty || listDrag.active)
    readonly property real favCellW: innerW / favColumns
    readonly property int favRowsShown: Math.min(2, favRows + (favPane.dropSlot >= favoriteApps.length && favoriteApps.length % favColumns === 0 ? 1 : 0))
    // where the results' entrance wave starts: after the pinned rows
    readonly property real introOffset: favShown && favoriteApps.length > 0 ? favRowsShown : 0
    readonly property real favAreaH: favShown ? ((favoriteApps.length > 0 ? favRowsShown * favCellH : s(48)) + s(17)) : 0

    readonly property real resultsH: {
        if (currentTabIndex === 2) {
            let rows = Math.ceil(emojiModel.count / emojiColumns);
            if (rows <= 0) return emojiTabsH + s(80);
            let maxRows = Math.max(3, Math.round(customItemCount * rowStep / emojiCellH));
            return emojiTabsH + Math.min(rows, maxRows) * emojiCellH;
        }
        if (appModel.count <= 0) return (queryEmpty && favShown) ? 0 : s(70);
        if (appGridActive) {
            let rows = Math.ceil(appModel.count / gridColumns);
            let shown = Math.min(rows, Math.max(2, Math.round(customItemCount * s(48) / gridCellH)));
            return Math.max(1, shown) * gridCellH;
        }
        return Math.min(appModel.count, customItemCount) * rowStep - rowSpacing;
    }
    readonly property real targetBodyH: (favAreaH + resultsH) > 0 ? bodyPadTop + footerH + favAreaH + resultsH : 0

    property real animatedBodyH: targetBodyH
    Behavior on animatedBodyH {
        enabled: launcherWindow.isVisible
        NumberAnimation { duration: launcherWindow.dur(380); easing.type: Easing.OutQuint }
    }

    visible: isVisible || container.animProgress > 0.001

    property var allApps: []
    property var usageRanks: ({ "focus": {}, "launch": {}, "context": {} })
    property bool isKeyboardNav: false
    property string pendingQuery: ""

    function grabInputFocus() {
        searchInput.forceActiveFocus();
        if (typeof searchInput.forceInputFocus === "function") {
            searchInput.forceInputFocus();
        }
    }

    Process {
        id: rankFetcher
        running: false
        command: Caching.qsDir ? ["python3", Caching.qsDir + "/launcher/app_rank.py", "--rank"] : []

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        launcherWindow.usageRanks = JSON.parse(this.text);
                        if (!launcherWindow.isVisible || appModel.count === 0) {
                            launcherWindow.loadApps();
                            launcherWindow.appsLoaded = true;
                            if (launcherWindow.currentTabIndex === 0) {
                                launcherWindow.executeFilter(searchInput.text);
                            }
                        }
                    }
                } catch(e) {}
            }
        }
    }

    property string fileSearchScript: "import os, sys, json\nq = sys.argv[1] if len(sys.argv) > 1 else ''\nhome = os.path.expanduser('~')\nres = []\nif q.startswith('/') or q.startswith('~'):\n    p = os.path.expanduser(q)\n    d = p if (os.path.isdir(p) and (q.endswith('/') or q.endswith('\\\\'))) else (os.path.dirname(p) or home)\n    pref = '' if (os.path.isdir(p) and (q.endswith('/') or q.endswith('\\\\'))) else os.path.basename(p).lower()\n    if os.path.isdir(d):\n        try:\n            entries = sorted(os.listdir(d), key=lambda x: (not os.path.isdir(os.path.join(d, x)), x.lower()))\n            for item in entries:\n                if item.startswith('.') and not pref.startswith('.'):\n                    continue\n                if not pref or pref in item.lower():\n                    full = os.path.join(d, item)\n                    res.append({'name': item, 'path': full, 'isDir': os.path.isdir(full)})\n                    if len(res) >= 40: break\n        except Exception: pass\nelse:\n    s = q.lower().strip()\n    targets = [home, os.path.join(home, 'Desktop'), os.path.join(home, 'Documents'), os.path.join(home, 'Downloads'), os.path.join(home, 'Pictures'), os.path.join(home, 'Videos'), os.path.join(home, 'Music')]\n    seen = set()\n    for t in targets:\n        if not os.path.isdir(t): continue\n        try:\n            for root, dirs, files in os.walk(t):\n                rel = os.path.relpath(root, t)\n                if rel != '.' and rel.count(os.sep) >= 2:\n                    dirs.clear()\n                    continue\n                dirs[:] = [dr for dr in dirs if not dr.startswith('.') and dr not in ('node_modules', '.git', '.cache', 'target', 'build', '.local')]\n                if s:\n                    for dr in dirs:\n                        if s in dr.lower():\n                            full = os.path.join(root, dr)\n                            if full not in seen:\n                                seen.add(full)\n                                res.append({'name': dr, 'path': full, 'isDir': True})\n                                if len(res) >= 40: break\n                for fn in files:\n                    if fn.startswith('.'): continue\n                    if not s or s in fn.lower():\n                        full = os.path.join(root, fn)\n                        if full not in seen:\n                            seen.add(full)\n                            res.append({'name': fn, 'path': full, 'isDir': False})\n                            if len(res) >= 40: break\n                if len(res) >= 40: break\n        except Exception: pass\n        if len(res) >= 40: break\nprint(json.dumps(res[:40]))"

    Process {
        id: fileSearchProcess
        running: false
        command: []

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    if (this.text && this.text.trim().length > 0) {
                        let parsed = JSON.parse(this.text);
                        let items = [];
                        for (let i = 0; i < parsed.length; i++) {
                            let p = parsed[i];
                            items.push({
                                name: p.name,
                                description: p.path,
                                desktop_id: "",
                                icon: "",
                                fontIcon: launcherWindow.getFileFontIcon(p.name, p.isDir),
                                score: 0,
                                isCommand: false,
                                command: "",
                                isCalc: false,
                                isSearch: false,
                                searchUrl: "",
                                calcResult: "",
                                isWidget: false,
                                widgetTarget: "",
                                isFile: true,
                                filePath: p.path,
                                isDir: p.isDir
                            });
                        }
                        if (launcherWindow.currentTabIndex === 1) {
                            launcherWindow.applyModelItems(items);
                        }
                    } else if (launcherWindow.currentTabIndex === 1) {
                        launcherWindow.applyModelItems([]);
                    }
                } catch(e) {}
            }
        }
    }

    function getFileFontIcon(name, isDir) {
        if (isDir) return "󰉋";
        let ext = name.split(".").pop().toLowerCase();
        if (["png", "jpg", "jpeg", "webp", "gif", "svg"].indexOf(ext) !== -1) return "󰋩";
        if (["mp4", "mkv", "webm", "avi", "mov"].indexOf(ext) !== -1) return "󰕧";
        if (["mp3", "wav", "flac", "ogg", "m4a"].indexOf(ext) !== -1) return "󰎆";
        if (["zip", "tar", "gz", "xz", "7z", "rar", "bz2"].indexOf(ext) !== -1) return "󰛫";
        if (["pdf"].indexOf(ext) !== -1) return "󰈦";
        if (["js", "ts", "qml", "py", "sh", "rs", "c", "cpp", "h", "json", "html", "css", "nix"].indexOf(ext) !== -1) return "󰅩";
        if (["txt", "md", "doc", "docx", "odt"].indexOf(ext) !== -1) return "󰈙";
        return "󰈔";
    }

    Timer {
        id: focusTimer
        interval: 30
        repeat: false
        onTriggered: {
            launcherWindow.grabInputFocus();
        }
    }

    Timer {
        id: focusRetryTimer
        interval: 120
        repeat: false
        onTriggered: {
            launcherWindow.grabInputFocus();
        }
    }

    Timer {
        id: focusFinalTimer
        interval: 250
        repeat: false
        onTriggered: {
            launcherWindow.grabInputFocus();
        }
    }

    Timer {
        id: keyboardNavTimer
        interval: 500
        repeat: false
        onTriggered: {
            launcherWindow.isKeyboardNav = false;
        }
    }

    Timer {
        id: filterDebounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            executeFilter(launcherWindow.pendingQuery);
        }
    }

    Timer {
        id: fileDebounceTimer
        interval: 80
        repeat: false
        onTriggered: {
            executeFileSearch(launcherWindow.pendingQuery);
        }
    }

    Timer {
        id: emojiDebounceTimer
        interval: 60
        repeat: false
        onTriggered: {
            executeEmojiFilter(launcherWindow.pendingQuery);
        }
    }

    // after the close animation: empty the search and rebuild the list for next time
    function resetAfterClose() {
        if (launcherWindow.isVisible) return;
        if (searchInput.text !== "") searchInput.clear();
        appList.resetScroll();
        emojiGrid.resetScroll();
        loadApps();
        launcherWindow.appsLoaded = true;
        executeFilter("");
        launcherWindow.listFresh = true;
    }

    function applyOpenMode() {
        if (LauncherController.mode === "emoji") launcherWindow.currentTabIndex = 2;
        else if (!launcherWindow.showTabs || LauncherController.mode === "apps") launcherWindow.currentTabIndex = 0;
    }

    Connections {
        target: LauncherController
        function onModeChanged() { if (launcherWindow.isVisible) launcherWindow.applyOpenMode(); }
    }

    onIsVisibleChanged: {
        if (isVisible) {
            launcherWindow.applyOpenMode();
            tabSwitch.currentIndex = launcherWindow.currentTabIndex;
            const fresh = launcherWindow.listFresh && launcherWindow.appsLoaded && searchInput.text === "";
            launcherWindow.listFresh = false;
            if (!launcherWindow.appsLoaded) {
                launcherWindow.loadApps();
                launcherWindow.appsLoaded = true;
            }
            if (searchInput.text !== "") {
                searchInput.clear();
                filterDebounceTimer.stop();
                fileDebounceTimer.stop();
                emojiDebounceTimer.stop();
            } else {
                filterDebounceTimer.stop();
                fileDebounceTimer.stop();
                emojiDebounceTimer.stop();
            }
            if (launcherWindow.currentTabIndex === 0) {
                if (!fresh) executeFilter("");
            } else if (launcherWindow.currentTabIndex === 1) {
                executeFileSearch("");
            } else {
                executeEmojiFilter("");
            }
            if (launcherWindow.smartRanking && !rankFetcher.running) {
                rankFetcher.running = true;
            }
            launcherWindow.grabInputFocus();
            focusTimer.restart();
            focusRetryTimer.restart();
            focusFinalTimer.restart();
        } else {
            filterDebounceTimer.stop();
            fileDebounceTimer.stop();
            emojiDebounceTimer.stop();
            focusTimer.stop();
            focusRetryTimer.stop();
            focusFinalTimer.stop();
            keyboardNavTimer.stop();
            if (fileSearchProcess.running) {
                fileSearchProcess.running = false;
            }
        }
    }

    function normalizeDecimalCommas(expr) {
        let out = "";
        let parens = [];
        for (let i = 0; i < expr.length; i++) {
            let ch = expr[i];
            if (ch === "(") {
                parens.push({ isPow: /pow\s*$/i.test(expr.substring(0, i)), commas: 0 });
            } else if (ch === ")") {
                parens.pop();
            } else if (ch === ",") {
                let top = parens.length > 0 ? parens[parens.length - 1] : null;
                if (top && top.isPow) {
                    if (++top.commas > 1) return null;
                    out += ch;
                    continue;
                }
                if (/\d/.test(expr[i - 1] || "") && /\d/.test(expr[i + 1] || "")) {
                    out += ".";
                    continue;
                }
                return null;
            }
            out += ch;
        }
        return out;
    }

    function evaluateMath(expr) {
        if (!expr) return null;
        let trimmed = expr.trim();
        if (trimmed.length === 0 || trimmed.startsWith(">")) return null;

        let normalized = normalizeDecimalCommas(trimmed);
        if (normalized === null) return null;

        let parsed = normalized
            .replace(/×/g, "*")
            .replace(/÷/g, "/")
            .replace(/\bpi\b/gi, "Math.PI")
            .replace(/\be\b/gi, "Math.E")
            .replace(/\bsqrt\b/gi, "Math.sqrt")
            .replace(/\bsin\b/gi, "Math.sin")
            .replace(/\bcos\b/gi, "Math.cos")
            .replace(/\btan\b/gi, "Math.tan")
            .replace(/\babs\b/gi, "Math.abs")
            .replace(/\blog\b/gi, "Math.log")
            .replace(/\bpow\b/gi, "Math.pow")
            .replace(/\^/g, "**");

        let testStr = parsed.replace(/Math\.(PI|E|sqrt|sin|cos|tan|abs|log|pow)/g, "");
        if (!/^[\d\s\+\-\*\/\%\(\)\.\,]+$/.test(testStr)) {
            return null;
        }

        if (!/[\+\-\*\/\%\^]/.test(trimmed) && !/\b(sqrt|sin|cos|tan|abs|log|pow|pi|e)\b/i.test(trimmed)) {
            return null;
        }

        try {
            let res = Function('"use strict"; return (' + parsed + ')')();
            if (typeof res === "number" && !isNaN(res) && isFinite(res)) {
                return Number(Math.round(res * 1e12) / 1e12).toString();
            }
        } catch (e) {
            return null;
        }
        return null;
    }

    function loadApps() {
        let arr = [];

        if (typeof DesktopEntries !== "undefined" && DesktopEntries.applications && DesktopEntries.applications.values) {
            let entries = DesktopEntries.applications.values;
            for (let i = 0; i < entries.length; i++) {
                let e = entries[i];
                if (e.noDisplay) continue;

                let score = 0;
                if (launcherWindow.smartRanking) {
                    let wmclassLower = (e.startupClass || "").toLowerCase();
                    let idLower = e.id.toLowerCase();
                    let baseName = idLower.endsWith(".desktop") ? idLower.slice(0, -8) : idLower;
                    let appNameLower = (e.name || "").toLowerCase();

                    let f_score = usageRanks.focus[wmclassLower] || 0;
                    if (f_score === 0) f_score = usageRanks.focus[baseName] || 0;
                    if (f_score === 0) f_score = usageRanks.focus[appNameLower] || 0;

                    let l_score = usageRanks.launch[e.name] || 0;

                    let c_score = (usageRanks.context && usageRanks.context[wmclassLower]) || 0;
                    if (c_score === 0) c_score = (usageRanks.context && usageRanks.context[baseName]) || 0;
                    if (c_score === 0) c_score = (usageRanks.context && usageRanks.context[appNameLower]) || 0;

                    score = f_score + l_score + (0.5 * c_score);
                }

                arr.push({
                    name: e.name,
                    description: e.comment || "",
                    desktop_id: e.id,
                    icon: e.icon || "",
                    fontIcon: "",
                    score: score,
                    isCommand: false,
                    command: "",
                    isCalc: false,
                    isSearch: false,
                    searchUrl: "",
                    calcResult: "",
                    isWidget: false,
                    widgetTarget: "",
                    isFile: false,
                    filePath: "",
                    isDir: false
                });
            }
        }

        let widgetList = (typeof WindowRegistry !== "undefined" && WindowRegistry.getWidgetLauncherEntries)
            ? WindowRegistry.getWidgetLauncherEntries(typeof I18n !== "undefined" ? I18n : null)
            : [];

        for (let j = 0; j < widgetList.length; j++) {
            let w = widgetList[j];
            let wScore = 0;
            if (launcherWindow.smartRanking) {
                wScore = (usageRanks.launch && (usageRanks.launch[w.id] || usageRanks.launch[w.name] || usageRanks.launch["qs-widget-" + w.id])) || 0;
            }
            arr.push({
                name: w.name,
                description: w.description || "",
                desktop_id: "qs-widget-" + w.id,
                icon: w.icon || "",
                fontIcon: w.fontIcon || "",
                score: wScore,
                isCommand: false,
                command: "",
                isCalc: false,
                isSearch: false,
                searchUrl: "",
                calcResult: "",
                isWidget: true,
                widgetTarget: w.id,
                isFile: false,
                filePath: "",
                isDir: false
            });
        }

        arr.sort(function(a, b) {
            if (launcherWindow.smartRanking && a.score !== b.score) {
                return b.score - a.score;
            }
            return a.name.localeCompare(b.name);
        });

        let unique = {};
        let finalArr = [];
        for (let i = 0; i < arr.length; i++) {
            if (!unique[arr[i].name]) {
                unique[arr[i].name] = true;
                finalArr.push(arr[i]);
            }
        }

        launcherWindow.allApps = finalArr;
    }

    ListModel {
        id: appModel
    }

    ListModel {
        id: emojiModel
    }

    function filterApps(query) {
        launcherWindow.pendingQuery = query;
        filterDebounceTimer.restart();
    }

    function filterFiles(query) {
        launcherWindow.pendingQuery = query;
        fileDebounceTimer.restart();
    }

    function filterEmojis(query) {
        launcherWindow.pendingQuery = query;
        emojiDebounceTimer.restart();
    }

    // the emoji picker's tabs: Unicode's groups. Typing searches every group
    readonly property var emojiCategories: EmojiData.categories
    readonly property var emojiCategoryIcons: ({
        "Smileys & Emotion": "😀", "People & Body": "👋", "Animals & Nature": "🐻", "Food & Drink": "🍔",
        "Travel & Places": "✈️", "Activities": "⚽", "Objects": "💡", "Symbols": "❤️", "Flags": "🏁"
    })
    property string emojiCategory: EmojiData.categories[0]
    onEmojiCategoryChanged: if (currentTabIndex === 2) executeEmojiFilter(searchInput.text)
    function cycleEmojiCategory(step) {
        const list = emojiCategories;
        const i = Math.max(0, list.indexOf(emojiCategory));
        emojiCategory = list[(i + step + list.length) % list.length];
    }

    function executeEmojiFilter(query) {
        launcherWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        const q = query ? query.trim() : "";
        // a whole group when browsing (People has ~400); the best 300 matches when searching
        let results = q === "" ? EmojiData.search("", 0, launcherWindow.emojiCategory) : EmojiData.search(q, 300);
        applyEmojiModelItems(results);
    }

    function applyEmojiModelItems(filtered) {
        let minCount = Math.min(emojiModel.count, filtered.length);
        for (let i = 0; i < minCount; i++) {
            let cur = emojiModel.get(i);
            let target = filtered[i];
            if (cur.emoji !== target.emoji || cur.name !== target.name || cur.category !== target.category) {
                emojiModel.set(i, {
                    emoji: target.emoji,
                    name: target.name,
                    category: target.category,
                    keywordsText: target.keywords ? target.keywords.join(", ") : ""
                });
            }
        }

        if (emojiModel.count > filtered.length) {
            for (let i = emojiModel.count - 1; i >= filtered.length; i--) {
                emojiModel.remove(i);
            }
        } else if (emojiModel.count < filtered.length) {
            for (let i = emojiModel.count; i < filtered.length; i++) {
                let target = filtered[i];
                emojiModel.append({
                    emoji: target.emoji,
                    name: target.name,
                    category: target.category,
                    keywordsText: target.keywords ? target.keywords.join(", ") : ""
                });
            }
        }

        emojiGrid.resetScroll();
        if (emojiModel.count > 0) {
            emojiGrid.currentIndex = 0;
        } else {
            emojiGrid.currentIndex = -1;
        }
    }

    function executeFileSearch(query) {
        launcherWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();
        if (fileSearchProcess.running) {
            fileSearchProcess.running = false;
        }
        fileSearchProcess.command = ["python3", "-c", launcherWindow.fileSearchScript, query ? query.trim() : ""];
        fileSearchProcess.running = true;
    }

    function isSubsequence(sub, str) {
        let i = 0;
        let j = 0;
        while (i < sub.length && j < str.length) {
            if (sub[i] === str[j]) {
                i++;
            }
            j++;
        }
        return i === sub.length;
    }

    function applyModelItems(filtered) {
        let minCount = Math.min(appModel.count, filtered.length);
        for (let i = 0; i < minCount; i++) {
            let cur = appModel.get(i);
            let target = filtered[i];
            if (cur.name !== target.name
                || cur.desktop_id !== target.desktop_id
                || cur.description !== target.description
                || cur.icon !== target.icon
                || cur.fontIcon !== target.fontIcon
                || cur.command !== target.command
                || cur.calcResult !== target.calcResult
                || cur.isCommand !== target.isCommand
                || cur.isCalc !== target.isCalc
                || cur.isSearch !== target.isSearch
                || cur.searchUrl !== target.searchUrl
                || cur.isWidget !== target.isWidget
                || cur.widgetTarget !== target.widgetTarget
                || cur.isFile !== target.isFile
                || cur.filePath !== target.filePath
                || cur.isDir !== target.isDir) {
                appModel.set(i, target);
            }
        }

        if (appModel.count > filtered.length) {
            for (let i = appModel.count - 1; i >= filtered.length; i--) {
                appModel.remove(i);
            }
        } else if (appModel.count < filtered.length) {
            for (let i = appModel.count; i < filtered.length; i++) {
                appModel.append(filtered[i]);
            }
        }

        appList.resetScroll();

        if (appModel.count > 0) {
            appList.currentIndex = 0;
        } else {
            appList.currentIndex = -1;
        }
    }

    function executeFilter(query) {
        launcherWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        let rawTrimmed = query.trim();
        let q = query.toLowerCase().trim();
        let filtered = [];

        if (rawTrimmed.startsWith(">")) {
            let cmd = rawTrimmed.substring(1).trim();
            if (cmd.length > 0) {
                filtered.push({
                    name: "> " + cmd,
                    description: typeof I18n !== "undefined" ? I18n.t("applauncher.command_run", { cmd: cmd }) : ("Execute command: " + cmd),
                    desktop_id: "",
                    icon: "",
                    fontIcon: "󰆍",
                    score: 10000000,
                    isCommand: true,
                    command: cmd,
                    isCalc: false,
                    isSearch: false,
                    searchUrl: "",
                    calcResult: "",
                    isWidget: false,
                    widgetTarget: "",
                    isFile: false,
                    filePath: "",
                    isDir: false
                });
            } else {
                filtered.push({
                    name: "> ...",
                    description: typeof I18n !== "undefined" ? I18n.t("applauncher.command_hint") : "Type a command to execute",
                    desktop_id: "",
                    icon: "",
                    fontIcon: "󰆍",
                    score: 10000000,
                    isCommand: false,
                    command: "",
                    isCalc: false,
                    isSearch: false,
                    searchUrl: "",
                    calcResult: "",
                    isWidget: false,
                    widgetTarget: "",
                    isFile: false,
                    filePath: "",
                    isDir: false
                });
            }
        }

        let mathResult = evaluateMath(rawTrimmed);
        if (mathResult !== null) {
            filtered.push({
                name: rawTrimmed + " = " + mathResult,
                description: typeof I18n !== "undefined" ? I18n.t("applauncher.calc_result") : "Calculation result (Enter to copy)",
                desktop_id: "",
                icon: "",
                fontIcon: "󰃬",
                score: 9000000,
                isCommand: false,
                command: "",
                isCalc: true,
                isSearch: false,
                searchUrl: "",
                calcResult: mathResult,
                isWidget: false,
                widgetTarget: "",
                isFile: false,
                filePath: "",
                isDir: false
            });
        }

        for (let i = 0; i < allApps.length; i++) {
            let app = allApps[i];
            let nameLower = app.name ? app.name.toLowerCase() : "";
            let descLower = app.description ? app.description.toLowerCase() : "";

            let matchQuality = 0;
            let matches = false;

            if (q.length === 0) {
                matches = true;
            } else if (!rawTrimmed.startsWith(">")) {
                if (nameLower === q) {
                    matchQuality = 100000;
                    matches = true;
                } else if (nameLower.startsWith(q)) {
                    matchQuality = 50000;
                    matches = true;
                } else if (nameLower.includes(q)) {
                    matchQuality = 10000;
                    matches = true;
                } else if (descLower.includes(q)) {
                    matchQuality = 5000;
                    matches = true;
                } else if (isSubsequence(q, nameLower)) {
                    matchQuality = 1000;
                    matches = true;
                }
            }

            if (matches) {
                filtered.push({
                    name: app.name,
                    description: app.description,
                    desktop_id: app.desktop_id,
                    icon: app.icon,
                    fontIcon: app.fontIcon || "",
                    score: app.score + matchQuality,
                    isCommand: false,
                    command: "",
                    isCalc: false,
                    isSearch: false,
                    searchUrl: "",
                    calcResult: "",
                    isWidget: app.isWidget || false,
                    widgetTarget: app.widgetTarget || "",
                    isFile: false,
                    filePath: "",
                    isDir: false
                });
            }
        }

        if (q.length > 0) {
            filtered.sort(function(a, b) {
                if (a.score !== b.score) {
                    return b.score - a.score;
                }
                return a.name.localeCompare(b.name);
            });
        } else {
            // the plain list: the rest of the apps (favourites live in their grid), in the
            // order you dragged them into; apps never moved keep their place after those
            if (launcherWindow.showRail) filtered = filtered.filter(it => !launcherWindow.isFavorite(it.desktop_id || ""));
            let order = launcherWindow.appOrder;
            if (order.length > 0) {
                let pos = {};
                for (let i = 0; i < order.length; i++) pos[order[i]] = i;
                let idx = filtered.map((it, i) => ({ it: it, i: i }));
                idx.sort((a, b) => {
                    let pa = pos[a.it.desktop_id], pb = pos[b.it.desktop_id];
                    if (pa !== undefined && pb !== undefined) return pa - pb;
                    if (pa !== undefined) return -1;
                    if (pb !== undefined) return 1;
                    return a.i - b.i;
                });
                filtered = idx.map(x => x.it);
            }
        }

        applyModelItems(filtered);
    }
    onFavoritesChanged: if (launcherWindow.currentTabIndex === 0 && searchInput.text.trim() === "") filterApps("")

    function activateIndex(index) {
        if (index < 0 || index >= appModel.count) return;
        let item = appModel.get(index);
        if (!item) return;

        if (item.isFile) {
            let script = "p=\"$1\"\n"
                + "if [ -d \"$p\" ]; then\n"
                + "  xdg-open \"$p\"\n"
                + "  exit 0\n"
                + "fi\n"
                + "mime=$(xdg-mime query filetype \"$p\" 2>/dev/null)\n"
                + "handler=\"\"\n"
                + "if [ -n \"$mime\" ]; then\n"
                + "  handler=$(xdg-mime query default \"$mime\" 2>/dev/null)\n"
                + "fi\n"
                + "if [ -n \"$handler\" ]; then\n"
                + "  xdg-open \"$p\" 2>/dev/null && exit 0\n"
                + "fi\n"
                + "if command -v nautilus >/dev/null 2>&1; then\n"
                + "  nautilus --select \"$p\" >/dev/null 2>&1 &\n"
                + "else\n"
                + "  xdg-open \"$(dirname \"$p\")\" >/dev/null 2>&1 &\n"
                + "fi";
            Quickshell.execDetached(["bash", "-c", script, "_", item.filePath]);
            closeLauncher();
            return;
        }

        if (item.isCommand) {
            if (item.command && item.command.trim().length > 0) {
                let term = launcherWindow.terminalCommand ? launcherWindow.terminalCommand.trim() : "";
                let fullCmd = term !== "" ? (term + " " + item.command) : item.command;
                Quickshell.execDetached(["bash", "-c", fullCmd]);
            }
            closeLauncher();
            return;
        }

        if (item.isCalc) {
            Quickshell.execDetached(["wl-copy", "--", item.calcResult]);
            closeLauncher();
            return;
        }

        if (item.isWidget) {
            launchWidget(item.name, item.widgetTarget);
            return;
        }

        launchApp(item.name, item.desktop_id);
    }

    function activateEmoji(index) {
        if (index < 0 || index >= emojiModel.count) return;
        let item = emojiModel.get(index);
        if (!item) return;
        Quickshell.execDetached(["wl-copy", "--", item.emoji]);
        closeLauncher();
    }

    function launchWidget(widgetName, widgetTarget) {
        if (Caching.qsDir) {
            Quickshell.execDetached(["bash", Caching.qsDir + "/../scripts/qs_manager.sh", "open", widgetTarget]);
        } else {
            Quickshell.execDetached(["qs_manager", "open", widgetTarget]);
        }
        closeLauncher();
    }

    function launchApp(appName, desktopId) {
        let entry = DesktopEntries.byId(desktopId);
        if (entry) {
            entry.execute();
        }
        if (Caching.qsDir) {
            Quickshell.execDetached(["python3", Caching.qsDir + "/launcher/app_rank.py", "--log-launch", "--name", appName]);
        }
        closeLauncher();
    }

    Item {
        id: topBarHole

        property int barThickness: launcherWindow.barHeight
        property string bp: launcherWindow.barPosition
        property bool activeBar: !launcherWindow.isBarEffectivelyHidden

        x: (activeBar && bp === "right") ? launcherWindow.width - barThickness : 0
        y: (activeBar && bp === "bottom") ? launcherWindow.height - barThickness : 0
        width: !activeBar ? 0 : ((bp === "left" || bp === "right") ? barThickness : launcherWindow.width)
        height: !activeBar ? 0 : ((bp === "top" || bp === "bottom") ? barThickness : launcherWindow.height)
    }

    MouseArea {
        anchors.fill: parent
        enabled: launcherWindow.isVisible
        onClicked: closeLauncher()
    }

    // a rounded surface: the theme's panel colour over the wallpaper glass
    component RoundSurface: Rectangle {
        color: launcherWindow.surfaceColor
        // Orbit draws this hairline on every surface itself (SurfaceEffects)
        border.width: ThemeBackend.orbit ? 0 : 1
        border.color: ThemeBackend.liquidGlass ? Qt.alpha("#ffffff", 0.14) : Qt.alpha(ThemeBackend.outlineVariant, 0.5)
        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: parent.radius
        }
    }

    // a key in the footer's hints: a small round keycap and a word
    component KeyHint: Row {
        id: keyHint
        property string key: ""
        property string label: ""
        spacing: launcherWindow.s(5)
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            height: launcherWindow.s(18)
            width: Math.max(height, keyText.implicitWidth + launcherWindow.s(12))
            radius: launcherWindow.rr(height)
            color: "transparent"
            border.width: 1
            border.color: launcherWindow.dividerColor
            Text {
                id: keyText
                anchors.centerIn: parent
                text: keyHint.key
                font.family: ThemeBackend.fontFamily
                font.pixelSize: launcherWindow.s(9)
                font.weight: Font.DemiBold
                color: ThemeBackend.subtext0
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: keyHint.label
            font.family: ThemeBackend.fontFamily
            font.pixelSize: launcherWindow.s(10)
            color: Qt.alpha(ThemeBackend.subtext0, 0.85)
        }
    }


    // an app icon (theme icon or a font glyph when there is none)
    component AppIcon: Item {
        id: appIcon
        property string icon: ""
        property string fontIcon: ""
        property string fallback: "󰵆"
        property color glyphColor: ThemeBackend.subtext0
        Image {
            id: appIconImg
            anchors.fill: parent
            readonly property bool ready: status === Image.Ready
            readonly property bool failed: appIcon.fontIcon !== "" || appIcon.icon === "" || status === Image.Error || status === Image.Null
            visible: !failed
            opacity: ready ? 1 : 0
            scale: ready ? 1 : 0.8
            Behavior on opacity { NumberAnimation { duration: launcherWindow.dur(220); easing.type: Easing.OutCubic } }
            Behavior on scale { NumberAnimation { duration: launcherWindow.dur(320); easing.type: Easing.OutQuint } }
            source: appIcon.fontIcon !== "" ? "" : launcherWindow.iconUrl(appIcon.icon)
            sourceSize: Qt.size(96, 96)
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            smooth: true
            mipmap: true
            // white-glyph icons vanish in light styles
            layer.enabled: !ThemeBackend.darkMode
            layer.mipmap: true
            layer.smooth: true
            layer.effect: InkIcon {}
        }
        Text {
            anchors.centerIn: parent
            visible: appIconImg.failed
            text: appIcon.fontIcon !== "" ? appIcon.fontIcon : appIcon.fallback
            font.family: ThemeBackend.iconFont
            font.pixelSize: Math.round(appIcon.height * 0.72)
            color: appIcon.glyphColor
            Behavior on color { ColorAnimation { duration: launcherWindow.dur(200) } }
        }
    }

    Item {
        id: container

        MouseArea { anchors.fill: parent }

        // 0 → 1 while opening; everything below derives its entrance from it
        // driven by openAnim / closeAnim below, not a Behavior: the window needs a couple of
        // frames to appear on screen after it's shown, and a Behavior started right away spent
        // most of its motion before anything was visible
        property real animProgress: 0.0
        // Material 3 motion: emphasized decelerate to enter, emphasized accelerate to leave
        NumberAnimation {
            id: openAnim
            target: container
            property: "animProgress"
            to: 1.0
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
        }
        NumberAnimation {
            id: closeAnim
            target: container
            property: "animProgress"
            to: 0.0
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
        }
        // start the opening once the surface is up (two frames)
        Timer {
            id: openKick
            interval: 34
            onTriggered: { openAnim.restart(); launcherWindow.restartItemsIntro(); }
        }
        Connections {
            target: launcherWindow
            function onIsVisibleChanged() { container.syncOpen(); }
        }
        Component.onCompleted: syncOpen()
        // the launcher's own animation speed: your animation settings, but not Game Mode. Game
        // Mode turns on while a fullscreen app is focused (and can flip while the launcher takes
        // focus), which made the opening jump or vanish half-way. Taken once per open/close.
        function motionScale() {
            return ThemeBackend.animationsEnabled ? 1.0 / Math.max(0.25, ThemeBackend.animationSpeed) : 0;
        }
        function syncOpen() {
            const sc = motionScale();
            openAnim.duration = 500 * sc;
            closeAnim.duration = 200 * sc;
            if (launcherWindow.isVisible) {
                closeAnim.stop();
                if (animProgress < 0.01 && sc > 0) {
                    animProgress = 0;
                    openKick.restart();
                } else {
                    openAnim.restart();
                    launcherWindow.restartItemsIntro();
                }
            } else {
                openKick.stop();
                openAnim.stop();
                if (animProgress <= 0.001) launcherWindow.resetAfterClose();
                else closeAnim.restart();
            }
        }
        readonly property real bodyProgress: launcherWindow.isVisible ? Math.max(0, Math.min(1, (animProgress - 0.05) / 0.6)) : 1
        // closed and faded out: now reset the list for next time (doing it while it faded
        // made the items vanish and the card jump)
        onAnimProgressChanged: if (!launcherWindow.isVisible && animProgress <= 0.001) launcherWindow.resetAfterClose()
        readonly property bool atBottom: launcherWindow.attachEdge === "bottom"
        readonly property real enterDir: atBottom ? 1 : -1

        function barOn(edge) {
            return launcherWindow.barPosition === edge && !launcherWindow.isBarEffectivelyHidden ? launcherWindow.barHeight : 0;
        }
        // where the search capsule sits; the card grows away from it
        readonly property real capsuleY: {
            if (launcherWindow.attachEdge === "top") return launcherWindow.edgeMargin + barOn("top");
            if (atBottom) return launcherWindow.height - launcherWindow.edgeMargin - barOn("bottom") - launcherWindow.capsuleH;
            return Math.round(launcherWindow.height * 0.22);
        }
        readonly property real shownBodyH: launcherWindow.animatedBodyH

        width: launcherWindow.launcherW
        height: launcherWindow.capsuleH + shownBodyH
        opacity: launcherWindow.isVisible ? Math.min(1, animProgress * 1.4) : animProgress
        scale: launcherWindow.isVisible ? 0.9 + 0.1 * animProgress : 0.96 + 0.04 * animProgress
        transformOrigin: atBottom ? Item.Bottom : Item.Top
        transform: Translate { y: container.enterDir * launcherWindow.s(launcherWindow.isVisible ? 32 : 12) * (1 - container.animProgress) }
        x: {
            if (launcherWindow.attachEdge === "left") return launcherWindow.edgeMargin + barOn("left");
            if (launcherWindow.attachEdge === "right") return launcherWindow.width - launcherWindow.edgeMargin - barOn("right") - width;
            return Math.floor((launcherWindow.width - width) / 2);
        }
        y: atBottom ? capsuleY - shownBodyH : capsuleY

        // the one surface behind everything: a pill while it holds only the search row,
        // a rounded card once the results unfold
        RoundSurface {
            id: launcherSurface
            anchors.fill: parent
            radius: Math.min(launcherWindow.bodyRadius, height / 2)
        }

        // ── the search row ──────────────────────────────────────────────────
        Item {
            id: capsule
            z: 2
            width: parent.width
            height: launcherWindow.capsuleH
            y: container.atBottom ? parent.height - height : 0

            // the filled search pill (Material's search bar)
            Rectangle {
                id: searchPill
                x: launcherWindow.pillInset
                y: launcherWindow.pillInset
                width: parent.width - 2 * x
                height: launcherWindow.pillH
                radius: launcherWindow.pillR
                color: launcherWindow.searchFill
            }

            // the round mode bubble on the left
            Rectangle {
                id: modeBubble
                x: searchPill.x + launcherWindow.s(6)
                anchors.verticalCenter: parent.verticalCenter
                width: launcherWindow.pillH - launcherWindow.s(12)
                height: width
                radius: launcherWindow.innerR(launcherWindow.s(6))
                color: launcherWindow.glassy ? Qt.alpha("#ffffff", 0.16) : ThemeBackend.primaryContainer
                Text {
                    id: modeGlyph
                    anchors.centerIn: parent
                    text: launcherWindow.currentTabIndex === 1 ? "󰉋" : (launcherWindow.currentTabIndex === 2 ? "󰞅" : "󰍉")
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: launcherWindow.s(18)
                    color: launcherWindow.glassy ? "#ffffff" : ThemeBackend.onPrimaryContainer
                }
                SequentialAnimation {
                    id: bubblePulse
                    NumberAnimation { target: modeGlyph; property: "scale"; to: 0.55; duration: launcherWindow.dur(110); easing.type: Easing.InCubic }
                    NumberAnimation { target: modeGlyph; property: "scale"; to: 1.0; duration: launcherWindow.dur(380); easing.type: Easing.OutQuint }
                }
                Connections {
                    target: launcherWindow
                    function onCurrentTabIndexChanged() { bubblePulse.restart(); }
                }
            }

            Input {
                id: searchInput
                z: 10
                focus: true
                Keys.priority: Keys.BeforeItem
                anchors.left: modeBubble.right
                anchors.leftMargin: launcherWindow.s(8)
                anchors.right: emojiHint.visible ? emojiHint.left : tabSwitch.left
                anchors.rightMargin: launcherWindow.s(6)
                anchors.verticalCenter: parent.verticalCenter
                height: launcherWindow.s(38)

                baseColor: "transparent"
                bgOpacity: 0.0
                accentColor: launcherWindow.accent
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                borderColor: "transparent"
                cornerRadius: height / 2
                fontPixelSize: launcherWindow.s(15)
                charSpacing: 1

                placeholderText: {
                    if (launcherWindow.currentTabIndex === 1) {
                        return typeof I18n !== "undefined" ? I18n.t("applauncher.placeholder_files", "Search files or enter path...") : "Search files or enter path...";
                    } else if (launcherWindow.currentTabIndex === 2) {
                        return typeof I18n !== "undefined" ? I18n.t("applauncher.placeholder_emojis", "Search emojis by name or keyword...") : "Search emojis by name or keyword...";
                    }
                    return typeof I18n !== "undefined" ? I18n.t("applauncher.placeholder", "Start with > for a command...") : "Start with > for a command...";
                }
                showClearButton: true

                onHasFocusChanged: {
                    if (!searchInput.hasFocus && launcherWindow.isVisible) {
                        if (launcherWindow.currentTabIndex === 2) emojiGrid.forceActiveFocus();
                        else appList.forceActiveFocus();
                    }
                }

                onTextEdited: function(newText) {
                    if (launcherWindow.currentTabIndex === 0) filterApps(newText);
                    else if (launcherWindow.currentTabIndex === 1) filterFiles(newText);
                    else filterEmojis(newText);
                }
                onCleared: {
                    if (launcherWindow.currentTabIndex === 0) filterApps("");
                    else if (launcherWindow.currentTabIndex === 1) filterFiles("");
                    else filterEmojis("");
                }

                Keys.onTabPressed: function(event) {
                    // Shift+Tab can arrive as Tab with Shift held (not as Backtab): go back then
                    if (launcherWindow.currentTabIndex === 2 && !launcherWindow.showTabs) { launcherWindow.cycleEmojiCategory((event.modifiers & Qt.ShiftModifier) ? -1 : 1); event.accepted = true; return; }
                    if (!launcherWindow.showTabs) { event.accepted = true; return; }
                    launcherWindow.currentTabIndex = (launcherWindow.currentTabIndex + 1) % 3;
                    event.accepted = true;
                }
                Keys.onBacktabPressed: function(event) {
                    if (launcherWindow.currentTabIndex === 2 && !launcherWindow.showTabs) { launcherWindow.cycleEmojiCategory(-1); event.accepted = true; return; }
                    if (!launcherWindow.showTabs) { event.accepted = true; return; }
                    launcherWindow.currentTabIndex = (launcherWindow.currentTabIndex + 2) % 3;
                    event.accepted = true;
                }
                Keys.onDownPressed: function(event) {
                    launcherWindow.isKeyboardNav = true;
                    keyboardNavTimer.restart();
                    const cols = launcherWindow.emojiColumns;
                    if (launcherWindow.currentTabIndex === 2) {
                        if (emojiGrid.currentIndex + cols < emojiModel.count) emojiGrid.currentIndex += cols;
                        else if (emojiGrid.currentIndex < emojiModel.count - 1) emojiGrid.currentIndex = emojiModel.count - 1;
                    } else if (launcherWindow.appGridActive) {
                        appList.currentIndex = Math.min(appModel.count - 1, appList.currentIndex + launcherWindow.gridColumns);
                    } else if (appList.currentIndex < appModel.count - 1) {
                        appList.currentIndex++;
                    }
                    event.accepted = true;
                }
                Keys.onUpPressed: function(event) {
                    launcherWindow.isKeyboardNav = true;
                    keyboardNavTimer.restart();
                    const cols = launcherWindow.emojiColumns;
                    if (launcherWindow.currentTabIndex === 2) {
                        if (emojiGrid.currentIndex >= cols) emojiGrid.currentIndex -= cols;
                    } else if (launcherWindow.appGridActive) {
                        appList.currentIndex = Math.max(0, appList.currentIndex - launcherWindow.gridColumns);
                    } else if (appList.currentIndex > 0) {
                        appList.currentIndex--;
                    }
                    event.accepted = true;
                }
                Keys.onLeftPressed: function(event) {
                    if (launcherWindow.appGridActive && searchInput.text === "") {
                        appList.currentIndex = Math.max(0, appList.currentIndex - 1);
                        event.accepted = true;
                    } else if (launcherWindow.currentTabIndex === 2) {
                        launcherWindow.isKeyboardNav = true;
                        keyboardNavTimer.restart();
                        if (emojiGrid.currentIndex > 0) emojiGrid.currentIndex--;
                        event.accepted = true;
                    }
                }
                Keys.onRightPressed: function(event) {
                    if (launcherWindow.appGridActive && searchInput.text === "") {
                        appList.currentIndex = Math.min(appModel.count - 1, appList.currentIndex + 1);
                        event.accepted = true;
                    } else if (launcherWindow.currentTabIndex === 2) {
                        launcherWindow.isKeyboardNav = true;
                        keyboardNavTimer.restart();
                        if (emojiGrid.currentIndex < emojiModel.count - 1) emojiGrid.currentIndex++;
                        event.accepted = true;
                    }
                }
                Keys.onReturnPressed: function(event) {
                    if (launcherWindow.currentTabIndex === 2) activateEmoji(emojiGrid.currentIndex);
                    else activateIndex(appList.currentIndex);
                    event.accepted = true;
                }
                Keys.onEscapePressed: function(event) {
                    closeLauncher();
                    event.accepted = true;
                }
            }

            // the name of the highlighted emoji, quietly on the right
            Text {
                id: emojiHint
                visible: launcherWindow.currentTabIndex === 2 && text !== ""
                anchors.right: tabSwitch.left
                anchors.rightMargin: launcherWindow.s(10)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, launcherWindow.s(150))
                elide: Text.ElideRight
                text: (emojiGrid.currentIndex >= 0 && emojiGrid.currentIndex < emojiModel.count) ? emojiModel.get(emojiGrid.currentIndex).name : ""
                font.family: ThemeBackend.fontFamily
                font.pixelSize: launcherWindow.s(11)
                color: ThemeBackend.subtext0
            }

            // the tabs: three round buttons with a dot of colour that glides between them
            Item {
                id: tabSwitch
                property int currentIndex: launcherWindow.currentTabIndex
                readonly property real chip: launcherWindow.pillH - launcherWindow.s(12)
                readonly property real gap: launcherWindow.s(4)
                visible: launcherWindow.showTabs
                anchors.right: parent.right
                anchors.rightMargin: visible ? launcherWindow.pillInset + launcherWindow.s(6) : launcherWindow.pillInset
                anchors.verticalCenter: parent.verticalCenter
                width: visible ? chip * 3 + gap * 2 : 0
                height: chip

                Rectangle {
                    id: tabDot
                    width: tabSwitch.chip
                    height: width
                    radius: launcherWindow.innerR(launcherWindow.s(6))
                    x: launcherWindow.currentTabIndex * (tabSwitch.chip + tabSwitch.gap)
                    color: launcherWindow.selectColor
                    Behavior on x { NumberAnimation { duration: launcherWindow.dur(420); easing.type: Easing.OutQuint } }
                }

                Repeater {
                    model: [
                        { glyph: "󰀻", title: launcherWindow.tabAppsTitle },
                        { glyph: "󰉋", title: launcherWindow.tabFilesTitle },
                        { glyph: "󰞅", title: launcherWindow.tabEmojisTitle }
                    ]
                    Item {
                        id: tabChip
                        required property var modelData
                        required property int index
                        readonly property bool active: launcherWindow.currentTabIndex === index
                        x: index * (tabSwitch.chip + tabSwitch.gap)
                        width: tabSwitch.chip
                        height: tabSwitch.chip
                        Rectangle {
                            anchors.fill: parent
                            radius: launcherWindow.innerR(launcherWindow.s(6))
                            color: launcherWindow.hoverColor
                            opacity: chipMa.containsMouse && !tabChip.active ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: launcherWindow.dur(180) } }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: tabChip.modelData.glyph
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: launcherWindow.s(15)
                            color: tabChip.active ? launcherWindow.onSelect : ThemeBackend.subtext0
                            scale: chipMa.pressed ? 0.85 : 1
                            Behavior on color { ColorAnimation { duration: launcherWindow.dur(260) } }
                            Behavior on scale { NumberAnimation { duration: launcherWindow.dur(220); easing.type: Easing.OutQuint } }
                        }
                        MouseArea {
                            id: chipMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: launcherWindow.currentTabIndex = tabChip.index
                        }
                        ToolTip.visible: chipMa.containsMouse
                        ToolTip.delay: 500
                        ToolTip.text: tabChip.modelData.title
                    }
                }
            }
        }

        // ── the results card ────────────────────────────────────────────────
        Item {
            id: bgCard
            z: 1
            width: parent.width
            visible: height > 1
            height: container.shownBodyH
            y: container.atBottom ? 0 : launcherWindow.capsuleH
            opacity: container.bodyProgress
            clip: true

            // the footer: how many results, and round key hints
            Item {
                id: footer
                x: launcherWindow.s(24)
                width: parent.width - 2 * x
                height: launcherWindow.footerH
                y: container.atBottom ? contentContainer.y - height : contentContainer.y + contentContainer.height

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    readonly property int n: launcherWindow.currentTabIndex === 2 ? emojiModel.count : appModel.count
                    text: {
                        if (launcherWindow.currentTabIndex === 2) return I18n.t("applauncher.count_emojis", "%1 emojis").replace("%1", n);
                        if (launcherWindow.currentTabIndex === 1) return I18n.t("applauncher.count_files", "%1 files").replace("%1", n);
                        return I18n.t("applauncher.count_results", "%1 apps").replace("%1", n + (launcherWindow.favShown ? launcherWindow.favoriteApps.length : 0));
                    }
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: launcherWindow.s(10)
                    color: Qt.alpha(ThemeBackend.subtext0, 0.75)
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: launcherWindow.s(14)
                    KeyHint {
                        key: "↵"
                        label: launcherWindow.currentTabIndex === 2 ? I18n.t("applauncher.hint_copy", "copy") : I18n.t("applauncher.hint_open", "open")
                    }
                    KeyHint {
                        visible: launcherWindow.showTabs || launcherWindow.currentTabIndex === 2
                        key: "Tab"
                        label: launcherWindow.showTabs ? I18n.t("applauncher.hint_switch", "switch") : I18n.t("applauncher.hint_group", "group")
                    }
                    KeyHint {
                        visible: launcherWindow.currentTabIndex === 0 && launcherWindow.showRail
                        key: "R-click"
                        label: I18n.t("applauncher.hint_pin", "pin")
                    }
                }
            }

            Item {
                id: contentContainer
                x: launcherWindow.bodyPad
                y: container.atBottom ? parent.height - launcherWindow.bodyPadTop - height : launcherWindow.bodyPadTop
                width: launcherWindow.innerW
                // laid out at full size; the card reveals it as it grows
                height: Math.max(0, launcherWindow.animatedBodyH - launcherWindow.bodyPadTop - launcherWindow.footerH)
                clip: true

                // ── pinned apps: round bubbles, drag to reorder, right-click to unpin
                Item {
                    id: favPane
                    x: 0
                    y: 0
                    width: parent.width
                    height: Math.max(0, launcherWindow.favAreaH - launcherWindow.s(17))
                    visible: opacity > 0.01
                    opacity: launcherWindow.favShown ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: launcherWindow.dur(260); easing.type: Easing.OutCubic } }
                    clip: true

                    readonly property real cellW: launcherWindow.favCellW
                    property int dragFrom: -1
                    property int dragTo: -1
                    // a list row being dragged over the pane: where it would land
                    property int dropSlot: -1

                    function slotAt(px, py) {
                        let col = Math.max(0, Math.min(launcherWindow.favColumns - 1, Math.floor(px / cellW)));
                        let row = Math.max(0, Math.floor((py + favFlick.contentY) / launcherWindow.favCellH));
                        return row * launcherWindow.favColumns + col;
                    }
                    // where tile i sits while something is dragged
                    function shownSlot(i) {
                        if (dragFrom >= 0 && dragTo >= 0) {
                            if (i === dragFrom) return dragTo;
                            if (dragFrom < dragTo && i > dragFrom && i <= dragTo) return i - 1;
                            if (dragFrom > dragTo && i >= dragTo && i < dragFrom) return i + 1;
                        }
                        if (dropSlot >= 0 && i >= dropSlot) return i + 1;
                        return i;
                    }

                    // nothing pinned yet: a soft round hint
                    Rectangle {
                        anchors.fill: parent
                        visible: launcherWindow.favoriteApps.length === 0
                        radius: launcherWindow.rr(height)
                        color: favPane.dropSlot >= 0 ? Qt.alpha(launcherWindow.accent, 0.14) : "transparent"
                        border.width: 1
                        border.color: favPane.dropSlot >= 0 ? launcherWindow.accent : Qt.alpha(ThemeBackend.text, 0.12)
                        Text {
                            anchors.centerIn: parent
                            width: parent.width - launcherWindow.s(24)
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: I18n.t("applauncher.favorites_empty", "Drag apps here, or right-click one, to pin it")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: launcherWindow.s(11)
                            color: ThemeBackend.subtext0
                        }
                    }

                    Flickable {
                        id: favFlick
                        anchors.fill: parent
                        contentHeight: (launcherWindow.favRows + (favPane.dropSlot >= 0 ? 1 : 0)) * launcherWindow.favCellH
                        boundsBehavior: Flickable.StopAtBounds
                        interactive: favPane.dragFrom < 0

                        Repeater {
                            model: launcherWindow.favoriteApps
                            delegate: Item {
                                id: favTile
                                required property var modelData
                                required property int index
                                readonly property int slot: favPane.shownSlot(index)
                                readonly property bool dragging: favPane.dragFrom === index
                                readonly property real wave: Math.floor(index / launcherWindow.favColumns) + (index % launcherWindow.favColumns) * 0.35
                                readonly property real intro: launcherWindow.getItemProgress(wave)
                                width: favPane.cellW
                                height: launcherWindow.favCellH
                                x: dragging ? favDragX : (slot % launcherWindow.favColumns) * favPane.cellW
                                y: dragging ? favDragY : Math.floor(slot / launcherWindow.favColumns) * launcherWindow.favCellH
                                z: dragging ? 10 : 1
                                opacity: launcherWindow.getItemOpacity(wave)
                                property real favDragX: 0
                                property real favDragY: 0
                                Behavior on x { enabled: !favTile.dragging; NumberAnimation { duration: launcherWindow.dur(320); easing.type: Easing.OutQuint } }
                                Behavior on y { enabled: !favTile.dragging; NumberAnimation { duration: launcherWindow.dur(320); easing.type: Easing.OutQuint } }

                                Rectangle {
                                    id: favBubble
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    y: launcherWindow.s(4)
                                    width: launcherWindow.s(52)
                                    height: width
                                    radius: launcherWindow.rr(width)
                                    color: favTile.dragging ? Qt.alpha(launcherWindow.accent, 0.3)
                                         : (favMa.containsMouse ? ThemeBackend.secondaryContainer : launcherWindow.bubbleColor)
                                    scale: (favTile.dragging ? 1.12 : (favMa.pressed ? 0.92 : (favMa.containsMouse ? 1.06 : 1.0))) * (0.86 + 0.14 * favTile.intro)
                                    Behavior on color { ColorAnimation { duration: launcherWindow.dur(220) } }
                                    Behavior on scale { NumberAnimation { duration: launcherWindow.dur(280); easing.type: Easing.OutQuint } }

                                    AppIcon {
                                        anchors.centerIn: parent
                                        width: launcherWindow.s(30)
                                        height: width
                                        icon: favTile.modelData.icon || ""
                                        fontIcon: favTile.modelData.fontIcon || ""
                                    }
                                }
                                Text {
                                    anchors.top: favBubble.bottom
                                    anchors.topMargin: launcherWindow.s(5)
                                    width: parent.width - launcherWindow.s(6)
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    horizontalAlignment: Text.AlignHCenter
                                    text: favTile.modelData.name
                                    elide: Text.ElideRight
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: launcherWindow.s(10)
                                    color: favMa.containsMouse ? ThemeBackend.text : ThemeBackend.subtext0
                                    Behavior on color { ColorAnimation { duration: launcherWindow.dur(200) } }
                                }

                                MouseArea {
                                    id: favMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: true
                                    cursorShape: favTile.dragging ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    property point pressAt
                                    property point grabOffset
                                    property bool dragged: false
                                    onPressed: (mouse) => {
                                        dragged = false;
                                        pressAt = mapToItem(favPane, mouse.x, mouse.y);
                                        grabOffset = Qt.point(mouse.x, mouse.y);
                                    }
                                    onPositionChanged: (mouse) => {
                                        if (!pressed || !(mouse.buttons & Qt.LeftButton)) return;
                                        let p = mapToItem(favPane, mouse.x, mouse.y);
                                        if (favPane.dragFrom < 0 && Math.abs(p.x - pressAt.x) + Math.abs(p.y - pressAt.y) > launcherWindow.s(8)) {
                                            dragged = true;
                                            favPane.dragFrom = favTile.index;
                                            favPane.dragTo = favTile.index;
                                        }
                                        if (favPane.dragFrom === favTile.index) {
                                            favTile.favDragX = p.x - grabOffset.x;
                                            favTile.favDragY = p.y - grabOffset.y + favFlick.contentY;
                                            favPane.dragTo = Math.min(launcherWindow.favoriteApps.length - 1, favPane.slotAt(p.x, p.y));
                                        }
                                    }
                                    onReleased: {
                                        if (favPane.dragFrom === favTile.index) {
                                            let from = favPane.dragFrom, to = favPane.dragTo;
                                            favPane.dragFrom = -1;
                                            favPane.dragTo = -1;
                                            launcherWindow.moveFavorite(from, to);
                                        }
                                    }
                                    onCanceled: { favPane.dragFrom = -1; favPane.dragTo = -1; }
                                    onClicked: (mouse) => {
                                        if (dragged) return;
                                        if (mouse.button === Qt.RightButton) {
                                            launcherWindow.toggleFavorite(favTile.modelData.desktop_id);
                                            return;
                                        }
                                        let id = String(favTile.modelData.desktop_id);
                                        if (id.startsWith("qs-widget-")) launcherWindow.launchWidget(favTile.modelData.name, id.substring(10));
                                        else launcherWindow.launchApp(favTile.modelData.name, favTile.modelData.desktop_id);
                                    }
                                }
                            }
                        }

                        // where a dragged list row would be pinned: an empty ring
                        Rectangle {
                            visible: favPane.dropSlot >= 0 && launcherWindow.favoriteApps.length > 0
                            width: launcherWindow.s(52)
                            height: width
                            radius: launcherWindow.rr(width)
                            x: (favPane.dropSlot % launcherWindow.favColumns) * favPane.cellW + (favPane.cellW - width) / 2
                            y: Math.floor(favPane.dropSlot / launcherWindow.favColumns) * launcherWindow.favCellH + launcherWindow.s(4)
                            color: Qt.alpha(launcherWindow.accent, 0.12)
                            border.width: 2
                            border.color: launcherWindow.accent
                        }

                        WheelScroll {}
                    }
                }

                // a short rounded divider under the pinned apps
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: listContainer.y - launcherWindow.s(9)
                    width: parent.width - launcherWindow.s(16)
                    height: 1
                    color: launcherWindow.dividerColor
                    opacity: favPane.opacity * (appModel.count > 0 && launcherWindow.favoriteApps.length > 0 ? 1 : 0)
                }

                // a list row being dragged (to reorder the list, or onto the pinned apps)
                Rectangle {
                    id: rowGhost
                    z: 50
                    visible: listDrag.active
                    width: launcherWindow.s(200)
                    height: launcherWindow.s(40)
                    x: listDrag.pos.x - width / 2
                    y: listDrag.pos.y - height / 2
                    radius: launcherWindow.rr(height)
                    color: ThemeBackend.material ? ThemeBackend.secondaryContainer : ThemeBackend.surface1
                    opacity: 0.95
                    Text {
                        anchors.centerIn: parent
                        width: parent.width - launcherWindow.s(20)
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: listDrag.name
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Medium
                        font.pixelSize: launcherWindow.s(12)
                        color: ThemeBackend.material ? ThemeBackend.onSecondaryContainer : ThemeBackend.text
                    }
                }

                QtObject {
                    id: listDrag
                    property bool active: false
                    property int from: -1
                    property int to: -1
                    property string name: ""
                    property string desktopId: ""
                    property point pos: Qt.point(0, 0)
                    // reordering only makes sense in the plain list (no search typed)
                    readonly property bool canReorder: searchInput.text.trim() === "" && launcherWindow.currentTabIndex === 0
                    function overPane() { return launcherWindow.favShown && pos.y < listContainer.y - launcherWindow.s(2); }
                    function update(p) {
                        pos = p;
                        if (overPane()) {
                            let q = favPane.mapFromItem(contentContainer, p.x, p.y);
                            favPane.dropSlot = Math.min(launcherWindow.favoriteApps.length, favPane.slotAt(q.x, q.y));
                            to = -1;
                        } else {
                            favPane.dropSlot = -1;
                            if (canReorder) {
                                let l = appList.mapFromItem(contentContainer, p.x, p.y);
                                to = Math.max(0, Math.min(appModel.count - 1, Math.floor((l.y + appList.contentY) / launcherWindow.rowStep)));
                            }
                        }
                    }
                    function finish() {
                        if (!active) return;
                        if (overPane() && desktopId) launcherWindow.pinAt(desktopId, favPane.dropSlot);
                        else if (canReorder && to >= 0) launcherWindow.moveListItem(from, to);
                        active = false;
                        from = -1;
                        to = -1;
                        favPane.dropSlot = -1;
                    }
                }

                // ── the results ──────────────────────────────────────────────
                Item {
                    id: listContainer
                    z: 1
                    width: parent.width
                    y: launcherWindow.favAreaH
                    Behavior on y { NumberAnimation { duration: launcherWindow.dur(420); easing.type: Easing.OutQuint } }
                    height: Math.max(0, launcherWindow.resultsH)
                    clip: true

                    NumberAnimation {
                        id: scrollAnim
                        target: appList
                        property: "contentY"
                        duration: launcherWindow.dur(320)
                        easing.type: Easing.OutQuint
                    }

                    // nothing matched
                    Column {
                        anchors.centerIn: parent
                        visible: launcherWindow.currentTabIndex !== 2 && appModel.count === 0 && !(launcherWindow.queryEmpty && launcherWindow.favShown)
                        spacing: launcherWindow.s(4)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰍉"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: launcherWindow.s(20)
                            color: Qt.alpha(ThemeBackend.subtext0, 0.7)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: I18n.t("applauncher.no_results", "Nothing found")
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: launcherWindow.s(12)
                            color: ThemeBackend.subtext0
                        }
                    }

                    ListView {
                        id: appList
                        anchors.fill: parent
                        visible: launcherWindow.currentTabIndex !== 2 && !launcherWindow.appGridActive
                        interactive: !listDrag.active
                        clip: true
                        model: appModel
                        spacing: launcherWindow.rowSpacing
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: launcherWindow.s(500)
                        highlightFollowsCurrentItem: false

                        Keys.forwardTo: [searchInput]

                        Keys.onPressed: function(event) {
                            if (event.text && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
                                launcherWindow.grabInputFocus();
                                searchInput.text += event.text;
                                event.accepted = true;
                            }
                        }

                        function resetScroll() {
                            scrollAnim.stop();
                            contentY = 0;
                        }

                        onContentYChanged: {
                            if (contentY < 0 && !moving && !flicking) contentY = 0;
                        }

                        function ensureVisible(idx, animated) {
                            if (idx < 0 || appModel.count === 0) return;
                            let step = launcherWindow.rowStep;
                            let itemTop = idx * step;
                            let itemBottom = itemTop + launcherWindow.rowH;
                            let curContentY = scrollAnim.running ? scrollAnim.to : contentY;
                            let totalH = Math.max(0, appModel.count * step - spacing);
                            let maxScroll = Math.max(0, totalH - height);
                            let newContentY = curContentY;
                            if (itemTop < curContentY) newContentY = itemTop;
                            else if (itemBottom > curContentY + height) newContentY = itemBottom - height;
                            newContentY = Math.max(0, Math.min(maxScroll, newContentY));
                            if (Math.abs(newContentY - contentY) > 0.5) {
                                scrollAnim.stop();
                                if (animated) {
                                    scrollAnim.from = contentY;
                                    scrollAnim.to = newContentY;
                                    scrollAnim.start();
                                } else {
                                    contentY = newContentY;
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) ensureVisible(currentIndex, launcherWindow.isKeyboardNav);
                        }

                        // the selection: one pill that glides from row to row
                        Rectangle {
                            id: morphHighlight
                            parent: appList.contentItem
                            z: 0
                            readonly property bool valid: appList.count > 0 && appList.currentIndex >= 0
                            visible: opacity > 0.001
                            opacity: valid ? launcherWindow.getItemOpacity(appList.currentIndex + launcherWindow.introOffset) : 0.0
                            x: 0
                            width: appList.width
                            height: launcherWindow.rowH
                            radius: launcherWindow.rr(height)
                            color: launcherWindow.selectColor
                            y: valid ? appList.currentIndex * launcherWindow.rowStep : 0
                            Behavior on y { NumberAnimation { duration: launcherWindow.dur(340); easing.type: Easing.OutQuint } }
                        }

                        delegate: Item {
                            id: delegateRoot
                            width: ListView.view ? ListView.view.width : 0
                            height: launcherWindow.rowH
                            z: 1
                            readonly property bool isSelected: index === appList.currentIndex
                            readonly property real intro: launcherWindow.getItemProgress(index + launcherWindow.introOffset)
                            // the row being dragged fades; a line shows where it will go
                            opacity: (listDrag.active && listDrag.from === index) ? 0.35 : launcherWindow.getItemOpacity(index + launcherWindow.introOffset)
                            transform: Translate { y: launcherWindow.s(10) * (1.0 - delegateRoot.intro) }

                            Rectangle {
                                visible: listDrag.active && listDrag.to === index && listDrag.from !== index
                                z: 20
                                x: launcherWindow.s(20)
                                width: parent.width - launcherWindow.s(40)
                                height: launcherWindow.s(3)
                                radius: height / 2
                                color: launcherWindow.accent
                                y: listDrag.to > listDrag.from ? parent.height + appList.spacing / 2 - height / 2 : -appList.spacing / 2 - height / 2
                            }

                            Item {
                                anchors.fill: parent
                                scale: ma.pressed ? 0.97 : 1.0
                                Behavior on scale { NumberAnimation { duration: launcherWindow.dur(240); easing.type: Easing.OutQuint } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: launcherWindow.rr(height)
                                    color: launcherWindow.hoverColor
                                    opacity: ma.containsMouse && !delegateRoot.isSelected ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: launcherWindow.dur(200); easing.type: Easing.OutCubic } }
                                }

                                RowLayout {
                                    layoutDirection: I18n.layoutDirection
                                    anchors.fill: parent
                                    anchors.leftMargin: launcherWindow.s(7)
                                    anchors.rightMargin: launcherWindow.s(16)
                                    spacing: launcherWindow.s(12)

                                    Rectangle {
                                        Layout.preferredWidth: launcherWindow.rowH - launcherWindow.s(12)
                                        Layout.preferredHeight: Layout.preferredWidth
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: launcherWindow.rr(width)
                                        color: delegateRoot.isSelected ? Qt.alpha(launcherWindow.accent, 0.18) : launcherWindow.bubbleColor
                                        Behavior on color { ColorAnimation { duration: launcherWindow.dur(260) } }
                                        AppIcon {
                                            anchors.centerIn: parent
                                            width: launcherWindow.s(22)
                                            height: width
                                            icon: model.icon || ""
                                            fontIcon: model.fontIcon || ""
                                            fallback: model.isCalc ? "󰃬" : (model.isCommand ? "󰆍" : "󰵆")
                                            glyphColor: delegateRoot.isSelected ? launcherWindow.accent : ThemeBackend.subtext0
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: launcherWindow.s(1)
                                        Text {
                                            Layout.fillWidth: true
                                            text: model.name
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: launcherWindow.s(13)
                                            font.weight: delegateRoot.isSelected ? Font.DemiBold : Font.Normal
                                            color: delegateRoot.isSelected ? launcherWindow.onSelect : ThemeBackend.text
                                            horizontalAlignment: I18n.textAlignment
                                            elide: Text.ElideRight
                                        }
                                        Text {
                                            Layout.fillWidth: true
                                            visible: launcherWindow.showDescriptions && model.description !== undefined && model.description !== null && model.description !== ""
                                            text: model.description || ""
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: launcherWindow.s(10)
                                            color: ThemeBackend.subtext0
                                            opacity: 0.85
                                            horizontalAlignment: I18n.textAlignment
                                            elide: Text.ElideRight
                                        }
                                    }

                                    // pinned (when not selected) or "Enter opens it" (when selected)
                                    Item {
                                        Layout.preferredWidth: launcherWindow.s(18)
                                        Layout.fillHeight: true
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰐃"
                                            visible: launcherWindow.showRail && launcherWindow.isFavorite(model.desktop_id || "")
                                            opacity: delegateRoot.isSelected ? 0 : 0.7
                                            font.family: ThemeBackend.iconFont
                                            font.pixelSize: launcherWindow.s(12)
                                            color: ThemeBackend.subtext0
                                            Behavior on opacity { NumberAnimation { duration: launcherWindow.dur(200) } }
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            anchors.horizontalCenterOffset: delegateRoot.isSelected ? 0 : -launcherWindow.s(8)
                                            text: "󰌑"
                                            opacity: delegateRoot.isSelected ? 0.8 : 0
                                            font.family: ThemeBackend.iconFont
                                            font.pixelSize: launcherWindow.s(14)
                                            color: launcherWindow.accent
                                            Behavior on opacity { NumberAnimation { duration: launcherWindow.dur(260) } }
                                            Behavior on anchors.horizontalCenterOffset { NumberAnimation { duration: launcherWindow.dur(360); easing.type: Easing.OutQuint } }
                                        }
                                    }
                                }

                                MouseArea {
                                    id: ma
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    preventStealing: listDrag.active
                                    cursorShape: listDrag.active ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    property point pressAt
                                    property bool dragged: false
                                    onPressed: (mouse) => { dragged = false; pressAt = mapToItem(contentContainer, mouse.x, mouse.y); }
                                    onPositionChanged: (mouse) => {
                                        if (!pressed || !(mouse.buttons & Qt.LeftButton) || model.isFile || !model.desktop_id) return;
                                        let p = mapToItem(contentContainer, mouse.x, mouse.y);
                                        if (!listDrag.active && Math.abs(p.x - pressAt.x) + Math.abs(p.y - pressAt.y) > launcherWindow.s(10)) {
                                            dragged = true;
                                            listDrag.active = true;
                                            listDrag.from = index;
                                            listDrag.name = model.name;
                                            listDrag.desktopId = model.desktop_id;
                                        }
                                        if (listDrag.active) listDrag.update(p);
                                    }
                                    onReleased: { if (listDrag.active) listDrag.finish(); }
                                    onCanceled: { listDrag.active = false; favPane.dropSlot = -1; }
                                    onClicked: (mouse) => {
                                        if (dragged) return;
                                        if (mouse.button === Qt.RightButton) {
                                            if (model.desktop_id && !model.isFile) launcherWindow.toggleFavorite(model.desktop_id);
                                            return;
                                        }
                                        launcherWindow.isKeyboardNav = false;
                                        appList.currentIndex = index;
                                        activateIndex(index);
                                    }
                                }
                            }
                        }

                        WheelScroll {}
                    }

                    // apps as a grid of round bubbles (Settings -> Launcher -> Grid view);
                    // shares appList's selection
                    GridView {
                        id: appGrid
                        anchors.fill: parent
                        visible: launcherWindow.appGridActive
                        clip: true
                        model: appModel
                        cellWidth: width / launcherWindow.gridColumns
                        cellHeight: launcherWindow.gridCellH
                        currentIndex: appList.currentIndex
                        boundsBehavior: Flickable.StopAtBounds
                        highlightFollowsCurrentItem: false
                        cacheBuffer: launcherWindow.s(800)
                        reuseItems: false
                        Keys.forwardTo: [searchInput]
                        onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, GridView.Contain)

                        readonly property real bubble: launcherWindow.s(60)

                        // the selection: a round bubble that glides between icons
                        Rectangle {
                            parent: appGrid.contentItem
                            z: 0
                            readonly property bool valid: appGrid.count > 0 && appList.currentIndex >= 0
                            visible: opacity > 0.001
                            opacity: valid ? launcherWindow.getItemOpacity(launcherWindow.introOffset + Math.floor(appList.currentIndex / launcherWindow.gridColumns) + (appList.currentIndex % launcherWindow.gridColumns) * 0.35) : 0
                            width: appGrid.bubble
                            height: width
                            radius: launcherWindow.rr(width)
                            color: launcherWindow.selectColor
                            x: valid ? (appList.currentIndex % launcherWindow.gridColumns) * appGrid.cellWidth + (appGrid.cellWidth - width) / 2 : 0
                            y: valid ? Math.floor(appList.currentIndex / launcherWindow.gridColumns) * appGrid.cellHeight + launcherWindow.s(8) : 0
                            Behavior on x { NumberAnimation { duration: launcherWindow.dur(360); easing.type: Easing.OutQuint } }
                            Behavior on y { NumberAnimation { duration: launcherWindow.dur(360); easing.type: Easing.OutQuint } }
                        }

                        delegate: Item {
                            id: gridCell
                            width: appGrid.cellWidth
                            height: appGrid.cellHeight
                            z: 1
                            readonly property bool selected: index === appList.currentIndex
                            readonly property real wave: launcherWindow.introOffset + Math.floor(index / launcherWindow.gridColumns) + (index % launcherWindow.gridColumns) * 0.35
                            readonly property real intro: launcherWindow.getItemProgress(wave)
                            opacity: launcherWindow.getItemOpacity(wave)
                            scale: 0.94 + 0.06 * gridCell.intro
                            transform: Translate { y: launcherWindow.s(14) * (1.0 - gridCell.intro) }

                            Rectangle {
                                id: gridBubble
                                anchors.horizontalCenter: parent.horizontalCenter
                                y: launcherWindow.s(8)
                                width: appGrid.bubble
                                height: width
                                radius: launcherWindow.rr(width)
                                color: gma.containsMouse && !gridCell.selected ? launcherWindow.hoverColor : "transparent"
                                scale: gma.pressed ? 0.9 : (gma.containsMouse ? 1.05 : 1.0)
                                Behavior on color { ColorAnimation { duration: launcherWindow.dur(200) } }
                                Behavior on scale { NumberAnimation { duration: launcherWindow.dur(280); easing.type: Easing.OutQuint } }
                                AppIcon {
                                    anchors.centerIn: parent
                                    width: launcherWindow.s(38)
                                    height: width
                                    icon: model.icon || ""
                                    fontIcon: model.fontIcon || ""
                                    fallback: model.isCalc ? "󰃬" : (model.isCommand ? "󰆍" : "󰵆")
                                    glyphColor: gridCell.selected ? launcherWindow.accent : ThemeBackend.subtext0
                                }
                                // pinned: a small dot on the bubble's rim
                                Rectangle {
                                    visible: launcherWindow.showRail && launcherWindow.isFavorite(model.desktop_id || "")
                                    width: launcherWindow.s(7)
                                    height: width
                                    radius: width / 2
                                    color: launcherWindow.accent
                                    x: parent.width * 0.85 - width / 2
                                    y: parent.height * 0.15 - height / 2
                                }
                            }
                            Text {
                                anchors.top: gridBubble.bottom
                                anchors.topMargin: launcherWindow.s(6)
                                width: parent.width - launcherWindow.s(8)
                                anchors.horizontalCenter: parent.horizontalCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: model.name
                                elide: Text.ElideRight
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: launcherWindow.s(11)
                                font.weight: gridCell.selected ? Font.DemiBold : Font.Normal
                                color: gridCell.selected ? ThemeBackend.text : ThemeBackend.subtext0
                                Behavior on color { ColorAnimation { duration: launcherWindow.dur(220) } }
                            }

                            MouseArea {
                                id: gma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: (mouse) => {
                                    if (mouse.button === Qt.RightButton) {
                                        if (model.desktop_id && !model.isFile) launcherWindow.toggleFavorite(model.desktop_id);
                                        return;
                                    }
                                    launcherWindow.isKeyboardNav = false;
                                    appList.currentIndex = index;
                                    activateIndex(index);
                                }
                            }
                        }

                        WheelScroll {}
                    }

                    // the emoji groups: round buttons with a gliding dot; Tab / Shift+Tab move between them
                    Item {
                        id: emojiTabs
                        visible: launcherWindow.currentTabIndex === 2
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        readonly property real chip: launcherWindow.s(38)
                        readonly property real gap: Math.max(launcherWindow.s(2), Math.min(launcherWindow.s(8), (parent.width - chip * launcherWindow.emojiCategories.length) / Math.max(1, launcherWindow.emojiCategories.length - 1)))
                        width: chip * launcherWindow.emojiCategories.length + gap * (launcherWindow.emojiCategories.length - 1)
                        height: chip
                        readonly property bool searching: searchInput.text.trim() !== ""
                        readonly property int activeIndex: launcherWindow.emojiCategories.indexOf(launcherWindow.emojiCategory)

                        Rectangle {
                            visible: !emojiTabs.searching
                            width: emojiTabs.chip
                            height: width
                            radius: launcherWindow.rr(width)
                            color: launcherWindow.selectColor
                            x: Math.max(0, emojiTabs.activeIndex) * (emojiTabs.chip + emojiTabs.gap)
                            Behavior on x { NumberAnimation { duration: launcherWindow.dur(420); easing.type: Easing.OutQuint } }
                        }

                        Repeater {
                            model: launcherWindow.emojiCategories
                            Item {
                                id: catTab
                                required property var modelData
                                required property int index
                                readonly property bool active: !emojiTabs.searching && launcherWindow.emojiCategory === modelData
                                x: index * (emojiTabs.chip + emojiTabs.gap)
                                width: emojiTabs.chip
                                height: emojiTabs.chip
                                Text {
                                    anchors.centerIn: parent
                                    text: launcherWindow.emojiCategoryIcons[catTab.modelData] || "•"
                                    font.pixelSize: launcherWindow.s(17)
                                    opacity: catTab.active || catMouse.containsMouse ? 1.0 : 0.55
                                    scale: catMouse.pressed ? 0.85 : (catMouse.containsMouse ? 1.1 : 1.0)
                                    Behavior on opacity { NumberAnimation { duration: launcherWindow.dur(200) } }
                                    Behavior on scale { NumberAnimation { duration: launcherWindow.dur(260); easing.type: Easing.OutQuint } }
                                }
                                MouseArea {
                                    id: catMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        // a tab while searching: leave the search and show that group
                                        if (emojiTabs.searching) searchInput.text = "";
                                        launcherWindow.emojiCategory = catTab.modelData;
                                        launcherWindow.executeEmojiFilter("");
                                        launcherWindow.grabInputFocus();
                                    }
                                }
                                ToolTip.visible: catMouse.containsMouse
                                ToolTip.delay: 500
                                ToolTip.text: catTab.modelData
                            }
                        }
                    }

                    GridView {
                        id: emojiGrid
                        anchors.fill: parent
                        anchors.topMargin: emojiTabs.visible ? emojiTabs.height + launcherWindow.s(8) : 0
                        visible: launcherWindow.currentTabIndex === 2
                        clip: true
                        model: emojiModel
                        cellWidth: width / launcherWindow.emojiColumns
                        cellHeight: launcherWindow.emojiCellH
                        currentIndex: 0
                        boundsBehavior: Flickable.StopAtBounds
                        cacheBuffer: launcherWindow.s(400)
                        highlightFollowsCurrentItem: false

                        Keys.forwardTo: [searchInput]

                        Keys.onPressed: function(event) {
                            if (event.text && event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Escape && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backtab) {
                                launcherWindow.grabInputFocus();
                                searchInput.text += event.text;
                                event.accepted = true;
                            }
                        }

                        function resetScroll() {
                            emojiScrollAnim.stop();
                            contentY = 0;
                        }

                        onContentYChanged: {
                            if (contentY < 0 && !moving && !flicking) contentY = 0;
                        }

                        function ensureVisible(idx, animated) {
                            if (idx < 0 || emojiModel.count === 0) return;
                            const cols = launcherWindow.emojiColumns;
                            let rowH = cellHeight;
                            let itemTop = Math.floor(idx / cols) * rowH;
                            let itemBottom = itemTop + rowH;
                            let curContentY = emojiScrollAnim.running ? emojiScrollAnim.to : contentY;
                            let totalH = Math.max(0, Math.ceil(emojiModel.count / cols) * rowH);
                            let maxScroll = Math.max(0, totalH - height);
                            let newContentY = curContentY;
                            if (itemTop < curContentY) newContentY = itemTop;
                            else if (itemBottom > curContentY + height) newContentY = itemBottom - height;
                            newContentY = Math.max(0, Math.min(maxScroll, newContentY));
                            if (Math.abs(newContentY - contentY) > 0.5) {
                                emojiScrollAnim.stop();
                                if (animated) {
                                    emojiScrollAnim.from = contentY;
                                    emojiScrollAnim.to = newContentY;
                                    emojiScrollAnim.start();
                                } else {
                                    contentY = newContentY;
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) ensureVisible(currentIndex, launcherWindow.isKeyboardNav);
                        }

                        NumberAnimation {
                            id: emojiScrollAnim
                            target: emojiGrid
                            property: "contentY"
                            duration: launcherWindow.dur(300)
                            easing.type: Easing.OutQuint
                        }

                        // the selection: a round bubble that glides between emojis
                        Rectangle {
                            parent: emojiGrid.contentItem
                            z: 0
                            readonly property bool valid: emojiGrid.currentIndex >= 0 && emojiGrid.currentIndex < emojiGrid.count
                            visible: valid
                            width: Math.min(emojiGrid.cellWidth, emojiGrid.cellHeight) - launcherWindow.s(8)
                            height: width
                            radius: launcherWindow.rr(width)
                            color: launcherWindow.selectColor
                            x: valid ? (emojiGrid.currentIndex % launcherWindow.emojiColumns) * emojiGrid.cellWidth + (emojiGrid.cellWidth - width) / 2 : 0
                            y: valid ? Math.floor(emojiGrid.currentIndex / launcherWindow.emojiColumns) * emojiGrid.cellHeight + (emojiGrid.cellHeight - height) / 2 : 0
                            Behavior on x { NumberAnimation { duration: launcherWindow.dur(300); easing.type: Easing.OutQuint } }
                            Behavior on y { NumberAnimation { duration: launcherWindow.dur(300); easing.type: Easing.OutQuint } }
                        }

                        delegate: Item {
                            id: emojiDelegateRoot
                            width: emojiGrid.cellWidth
                            height: emojiGrid.cellHeight
                            z: 1
                            readonly property bool isSelected: index === emojiGrid.currentIndex
                            readonly property real intro: launcherWindow.getItemProgress(Math.floor(index / launcherWindow.emojiColumns))
                            opacity: launcherWindow.getItemOpacity(Math.floor(index / launcherWindow.emojiColumns))
                            transform: Translate { y: launcherWindow.s(12) * (1.0 - emojiDelegateRoot.intro) }

                            Text {
                                anchors.centerIn: parent
                                text: model.emoji
                                font.pixelSize: launcherWindow.s(24)
                                scale: emojiMa.pressed ? 0.85 : (emojiDelegateRoot.isSelected ? 1.15 : 1.0)
                                Behavior on scale { NumberAnimation { duration: launcherWindow.dur(300); easing.type: Easing.OutQuint } }
                            }

                            MouseArea {
                                id: emojiMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    launcherWindow.isKeyboardNav = false;
                                    emojiGrid.currentIndex = index;
                                    activateEmoji(index);
                                }
                                onEntered: {
                                    if (!launcherWindow.isKeyboardNav) emojiGrid.currentIndex = index;
                                }
                            }
                        }

                        WheelScroll {}
                    }

                    Column {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: emojiTabs.height / 2
                        visible: launcherWindow.currentTabIndex === 2 && emojiModel.count === 0
                        spacing: launcherWindow.s(4)
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: "󰞅"
                            font.family: ThemeBackend.iconFont
                            font.pixelSize: launcherWindow.s(20)
                            color: Qt.alpha(ThemeBackend.subtext0, 0.7)
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: typeof I18n !== "undefined" ? I18n.t("applauncher.no_emojis_found", "No emojis found") : "No emojis found"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: launcherWindow.s(12)
                            color: ThemeBackend.subtext0
                        }
                    }
                }
            }
        }
    }
}
