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
import "./SearchProviders.js" as SearchProviders

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
    property real introItems: 0.0
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

    function getItemProgress(idx) {
        if (introItems >= 1.0) return 1.0;
        if (introItems <= 0.0) return 0.0;
        let start = Math.min(idx, 10) * 0.04;
        let p = Math.min(1.0, Math.max(0.0, (introItems - start) / 0.42));
        if (p <= 0.0) return 0.0;
        if (p >= 1.0) return 1.0;
        let c1 = 0.85;
        let c3 = c1 + 1;
        return 1 + c3 * Math.pow(p - 1, 3) + c1 * Math.pow(p - 1, 2);
    }

    function getItemOpacity(idx) {
        if (introItems >= 1.0) return 1.0;
        if (introItems <= 0.0) return 0.0;
        let start = Math.min(idx, 10) * 0.04;
        let p = Math.min(1.0, Math.max(0.0, (introItems - start) / 0.28));
        return p;
    }

    function restartItemsIntro() {
        introItems = 0.0;
        itemsIntroSequence.restart();
    }

    SequentialAnimation {
        id: itemsIntroSequence
        running: false
        PauseAnimation { duration: (60) * ThemeBackend.animScale }
        NumberAnimation {
            target: launcherWindow
            property: "introItems"
            from: 0.0
            to: 1.0
            duration: (520) * ThemeBackend.animScale
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
        "searchProvider": "google",
        "favorites": [],
        "showRail": true,
        "gridView": false,
        "gridColumns": 5,
        "favColumns": 4,
        "appOrder": [],
        "showDescriptions": true,
        "webSearch": true
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
    property string searchProvider: (rawLauncherSettings && rawLauncherSettings.searchProvider !== undefined) ? rawLauncherSettings.searchProvider : SearchProviders.DEFAULT_ID
    property bool smartRanking: (rawLauncherSettings && rawLauncherSettings.smartRanking !== undefined) ? rawLauncherSettings.smartRanking : true
    // Settings -> Launcher: the left rail (tabs + favourite apps), grid view, descriptions, web search
    property var favorites: (rawLauncherSettings && Array.isArray(rawLauncherSettings.favorites)) ? rawLauncherSettings.favorites : []
    property bool showRail: !(rawLauncherSettings && rawLauncherSettings.showRail === false)
    property bool gridView: !!(rawLauncherSettings && rawLauncherSettings.gridView === true)
    property int gridColumns: (rawLauncherSettings && Number(rawLauncherSettings.gridColumns) >= 3) ? Math.min(8, Number(rawLauncherSettings.gridColumns)) : 5
    property bool showDescriptions: !(rawLauncherSettings && rawLauncherSettings.showDescriptions === false)
    property bool webSearch: !(rawLauncherSettings && rawLauncherSettings.webSearch === false)
    // apps show as a grid (only the Applications tab; files stay a list)
    readonly property bool appGridActive: gridView && currentTabIndex === 0
    // the favourites pane: the left part of the launcher, a grid of pinned apps under the tabs
    property int favColumns: (rawLauncherSettings && Number(rawLauncherSettings.favColumns) >= 2) ? Math.min(6, Number(rawLauncherSettings.favColumns)) : 4
    property var appOrder: (rawLauncherSettings && Array.isArray(rawLauncherSettings.appOrder)) ? rawLauncherSettings.appOrder : []
    readonly property real railW: showRail ? Math.round(s(customWidth) * 0.72) : 0
    readonly property real favCellH: s(86)
    readonly property int favRows: Math.max(1, Math.ceil(favoriteApps.length / favColumns))

    function saveLauncher(patch) {
        let cur = JSON.parse(JSON.stringify(Config.getSetting("launcher", defaultLauncherSettings) || {}));
        for (let k in patch) cur[k] = patch[k];
        Config.setSetting("launcher", cur);
    }
    // move a favourite from one slot to another (dragging in the grid)
    function moveFavorite(from, to) {
        let favs = favorites.slice();
        if (from < 0 || from >= favs.length) return;
        to = Math.max(0, Math.min(favs.length - 1, to));
        if (from === to) return;
        let it = favs.splice(from, 1)[0];
        favs.splice(to, 0, it);
        saveLauncher({ "favorites": favs });
    }
    // pin an app at a slot (dragging a list row onto the grid)
    function pinAt(desktopId, slot) {
        if (!desktopId) return;
        let favs = favorites.slice();
        let i = favs.indexOf(desktopId);
        if (i !== -1) favs.splice(i, 1);
        slot = Math.max(0, Math.min(favs.length, slot));
        favs.splice(slot, 0, desktopId);
        saveLauncher({ "favorites": favs });
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
    // the web button: search what's typed, or start a "?" web query
    function webButton() {
        let q = searchInput.text.trim();
        if (q.startsWith("?")) q = q.substring(1).trim();
        if (q.length > 0 && !q.startsWith(">")) {
            Quickshell.execDetached(["xdg-open", SearchProviders.urlFor(launcherWindow.searchProvider, q)]);
            closeLauncher();
        } else {
            if (launcherWindow.currentTabIndex !== 0) launcherWindow.currentTabIndex = 0;
            searchInput.text = "? ";
            filterApps(searchInput.text);
            launcherWindow.grabInputFocus();
        }
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

    property real cornerRadius: ThemeBackend.borderRadius <= 16 ? ThemeBackend.borderRadius * 2 : Math.min(32, 32 - 16 * Math.exp(-(ThemeBackend.borderRadius - 16) / 12))
    property real outerCornerRadius: cornerRadius

    property real baseLauncherWidth: s(customWidth) + (showRail ? railW + s(13) : 0)
    property real collapsedCenterHeight: s(110)

    readonly property real gridCellH: s(92)
    readonly property real railMinH: showRail ? (s(28) + s(10) + favRows * favCellH) : 0
    property real targetLauncherHeight: {
        let headerH = s(36) + (showRail ? 0 : s(28) + s(8)) + s(28);
        let listMin = railMinH > 0 ? s(36) + s(8) + railMinH + s(28) : 0;
        if (appGridActive) {
            let rows = Math.ceil(appModel.count / gridColumns);
            let shown = Math.min(rows, Math.max(2, Math.round(customItemCount * s(48) / gridCellH)));
            return Math.max(listMin, headerH + s(8) + Math.max(1, shown) * gridCellH);
        }
        if (currentTabIndex === 2) {
            let totalRows = Math.ceil(emojiModel.count / 5);
            if (totalRows <= 0) {
                return headerH;
            }
            return Math.max(listMin, headerH + s(8) + (Math.min(totalRows, customItemCount) * s(60)));
        }
        let count = Math.min(appModel.count, customItemCount);
        if (count <= 0) {
            return Math.max(listMin, headerH);
        }
        return Math.max(listMin, headerH + s(8) + (count * s(48)));
    }

    property real animatedLauncherHeight: targetLauncherHeight
    Behavior on animatedLauncherHeight {
        NumberAnimation {
            duration: (300) * ThemeBackend.animScale
            easing.type: Easing.OutCubic
        }
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

    onIsVisibleChanged: {
        if (isVisible) {
            tabSwitch.currentIndex = launcherWindow.currentTabIndex;
            restartItemsIntro();
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
                executeFilter("");
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
            itemsIntroSequence.stop();
            introItems = 0.0;
            launcherWindow.appsLoaded = false;
            appList.resetScroll();
            emojiGrid.resetScroll();
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
            if (launcherWindow.smartRanking) {
                loadApps();
                executeFilter("");
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

    function executeEmojiFilter(query) {
        launcherWindow.isKeyboardNav = false;
        if (keyboardNavTimer.running) keyboardNavTimer.stop();

        let results = EmojiData.search(query ? query.trim() : "", 150);
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
                || cur.score !== target.score
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

        if (launcherWindow.webSearch && rawTrimmed.startsWith("?")) {
            let term = rawTrimmed.substring(1).trim();
            let provider = SearchProviders.find(launcherWindow.searchProvider);
            filtered.push({
                name: term.length > 0 ? "? " + term : "? ...",
                description: term.length > 0
                    ? (typeof I18n !== "undefined" ? I18n.t("applauncher.search_run", { provider: provider.name }) : ("Search " + provider.name))
                    : (typeof I18n !== "undefined" ? I18n.t("applauncher.search_hint", { provider: provider.name }) : "Type to search the web"),
                desktop_id: "",
                icon: "",
                fontIcon: "󰖟",
                score: 10000000,
                isCommand: false,
                command: "",
                isCalc: false,
                isSearch: term.length > 0,
                searchUrl: term.length > 0 ? SearchProviders.urlFor(launcherWindow.searchProvider, term) : "",
                calcResult: "",
                isWidget: false,
                widgetTarget: "",
                isFile: false,
                filePath: "",
                isDir: false
            });
            applyModelItems(filtered);
            return;
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

        if (item.isSearch) {
            if (item.searchUrl) Quickshell.execDetached(["xdg-open", item.searchUrl]);
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

        x: {
            if (!activeBar) return 0;
            if (bp === "left") return 0;
            if (bp === "right") return launcherWindow.width - barThickness;
            return 0;
        }

        y: {
            if (!activeBar) return 0;
            if (bp === "top") return 0;
            if (bp === "bottom") return launcherWindow.height - barThickness;
            return 0;
        }

        width: {
            if (!activeBar) return 0;
            if (bp === "left" || bp === "right") return barThickness;
            return launcherWindow.width;
        }

        height: {
            if (!activeBar) return 0;
            if (bp === "top" || bp === "bottom") return barThickness;
            return launcherWindow.height;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: launcherWindow.isVisible
        onClicked: closeLauncher()
    }

    Item {
        id: container

        MouseArea {
            anchors.fill: parent
        }

        property real animProgress: launcherWindow.isVisible ? 1.0 : 0.0
        Behavior on animProgress {
            NumberAnimation {
                duration: (launcherWindow.isVisible ? (launcherWindow.isCentered ? 420 : 340) : (launcherWindow.isCentered ? 200 : 150)) * ThemeBackend.animScale
                easing.type: launcherWindow.isVisible ? Easing.OutBack : Easing.InQuad
                easing.overshoot: launcherWindow.isVisible ? 1.28 : 1.0
            }
        }

        property real dynamicCornerRadius: Math.round(Math.max(0, Math.min(launcherWindow.outerCornerRadius, (launcherWindow.isSideAttached ? width : height) * 0.5)))

        x: {
            if (launcherWindow.attachEdge === "left") {
                return launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
            }
            if (launcherWindow.attachEdge === "right") {
                let offset = launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
                return (launcherWindow.width - offset) - width;
            }
            return Math.floor((launcherWindow.width - width) / 2);
        }

        y: {
            if (launcherWindow.attachEdge === "top") {
                return launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
            }
            if (launcherWindow.attachEdge === "bottom") {
                let offset = launcherWindow.barMatchesLauncher ? launcherWindow.barHeight : 0;
                return (launcherWindow.height - offset) - height;
            }
            return Math.floor((launcherWindow.height - height) / 2);
        }

        width: launcherWindow.isSideAttached
               ? Math.round(launcherWindow.baseLauncherWidth * animProgress)
               : Math.round(launcherWindow.baseLauncherWidth)

        height: {
            if (launcherWindow.isCentered) {
                let baseH = launcherWindow.collapsedCenterHeight;
                let targetH = Math.max(baseH, launcherWindow.animatedLauncherHeight);
                return baseH + (targetH - baseH) * animProgress;
            }
            if (!launcherWindow.isSideAttached) {
                return launcherWindow.animatedLauncherHeight * animProgress;
            }
            return launcherWindow.animatedLauncherHeight;
        }

        opacity: launcherWindow.isCentered
                 ? Math.max(0.0, Math.min(1.0, animProgress * 1.5))
                 : ((launcherWindow.isVisible || animProgress > 0.001) ? 1.0 : 0.0)

        transformOrigin: Item.Center

        GlassFillets {
            id: launcherFillets
            card: bgCard
            filletRadius: ThemeBackend.rad(launcherWindow.isCentered ? 0 : container.dynamicCornerRadius)
            filletDir: launcherWindow.attachEdge === "top" ? Qt.vector2d(0, -1)
                     : launcherWindow.attachEdge === "bottom" ? Qt.vector2d(0, 1)
                     : launcherWindow.attachEdge === "left" ? Qt.vector2d(-1, 0)
                     : Qt.vector2d(1, 0)
        }

        ShaderEffect {
            visible: !launcherWindow.isCentered && container.dynamicCornerRadius > 0.5
            x: {
                if (launcherWindow.attachEdge === "left") return 0;
                if (launcherWindow.attachEdge === "right") return parent.width - container.dynamicCornerRadius;
                return -container.dynamicCornerRadius;
            }
            y: {
                if (launcherWindow.attachEdge === "bottom") return parent.height - container.dynamicCornerRadius;
                if (launcherWindow.attachEdge === "left" || launcherWindow.attachEdge === "right") return -container.dynamicCornerRadius;
                return 0;
            }
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: {
                if (launcherWindow.attachEdge === "bottom") return 3.0;
                if (launcherWindow.attachEdge === "left") return 2.0;
                if (launcherWindow.attachEdge === "right") return 3.0;
                return 1.0;
            }
            property color color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            fragmentShader: "file://" + Caching.monolithDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        ShaderEffect {
            visible: !launcherWindow.isCentered && container.dynamicCornerRadius > 0.5
            x: {
                if (launcherWindow.attachEdge === "left") return 0;
                if (launcherWindow.attachEdge === "right") return parent.width - container.dynamicCornerRadius;
                return parent.width;
            }
            y: {
                if (launcherWindow.attachEdge === "bottom") return parent.height - container.dynamicCornerRadius;
                if (launcherWindow.attachEdge === "left" || launcherWindow.attachEdge === "right") return parent.height;
                return 0;
            }
            width: container.dynamicCornerRadius
            height: container.dynamicCornerRadius
            property vector2d itemSize: Qt.vector2d(width, height)
            property real cornerIndex: {
                if (launcherWindow.attachEdge === "bottom") return 2.0;
                if (launcherWindow.attachEdge === "left") return 0.0;
                if (launcherWindow.attachEdge === "right") return 1.0;
                return 0.0;
            }
            property color color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            fragmentShader: "file://" + Caching.monolithDir + "/assets/shaders/ui/corner_cutout.frag.qsb"
        }

        Rectangle {
            id: bgCard
            anchors.fill: parent
            radius: ThemeBackend.rad(container.dynamicCornerRadius)
            readonly property bool flatCorners: !launcherWindow.isCentered
            topLeftRadius: ThemeBackend.rad((flatCorners && (launcherWindow.attachEdge === "top" || launcherWindow.attachEdge === "left")) ? 0 : container.dynamicCornerRadius)
            topRightRadius: ThemeBackend.rad((flatCorners && (launcherWindow.attachEdge === "top" || launcherWindow.attachEdge === "right")) ? 0 : container.dynamicCornerRadius)
            bottomLeftRadius: ThemeBackend.rad((flatCorners && (launcherWindow.attachEdge === "bottom" || launcherWindow.attachEdge === "left")) ? 0 : container.dynamicCornerRadius)
            bottomRightRadius: ThemeBackend.rad((flatCorners && (launcherWindow.attachEdge === "bottom" || launcherWindow.attachEdge === "right")) ? 0 : container.dynamicCornerRadius)
            color: Qt.alpha(ThemeBackend.base, ThemeBackend.elementOpacity)
            border.width: 0
            border.color: launcherWindow.isCentered ? Qt.alpha(ThemeBackend.surface2, 0.6) : "transparent"
            clip: true

            WallpaperBlur {
                z: -1
                anchors.fill: parent
                topLeftRadius: ThemeBackend.rad(parent.topLeftRadius)
                topRightRadius: ThemeBackend.rad(parent.topRightRadius)
                bottomLeftRadius: ThemeBackend.rad(parent.bottomLeftRadius)
                bottomRightRadius: ThemeBackend.rad(parent.bottomRightRadius)
                filletRadius: ThemeBackend.rad(launcherFillets.filletRadius)
                filletDir: launcherFillets.filletDir
            }

            Item {
                id: contentContainer
                anchors.fill: parent
                anchors.margins: launcherWindow.s(14)
                visible: width > 0 && height > 0
                clip: true

                readonly property bool isSearchAtBottom: launcherWindow.attachEdge === "bottom"

                Input {
                    id: searchInput
                    z: 10
                    focus: true
                    Keys.priority: Keys.BeforeItem
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.rightMargin: launcherWindow.webSearch ? launcherWindow.s(44) : 0
                    y: contentContainer.isSearchAtBottom ? Math.max(0, parent.height - height) : 0
                    height: launcherWindow.s(36)

                    baseColor: ThemeBackend.surface0
                    bgOpacity: ThemeBackend.glassActive ? 0.0 : 1.0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: launcherWindow.s(12)
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
                            if (launcherWindow.currentTabIndex === 2) {
                                emojiGrid.forceActiveFocus();
                            } else {
                                appList.forceActiveFocus();
                            }
                        }
                    }

                    onTextEdited: function(newText) {
                        if (launcherWindow.currentTabIndex === 0) {
                            filterApps(newText);
                        } else if (launcherWindow.currentTabIndex === 1) {
                            filterFiles(newText);
                        } else {
                            filterEmojis(newText);
                        }
                    }
                    onCleared: {
                        if (launcherWindow.currentTabIndex === 0) {
                            filterApps("");
                        } else if (launcherWindow.currentTabIndex === 1) {
                            filterFiles("");
                        } else {
                            filterEmojis("");
                        }
                    }

                    Keys.onTabPressed: function(event) {
                        launcherWindow.currentTabIndex = (launcherWindow.currentTabIndex + 1) % 3;
                        tabSwitch.currentIndex = launcherWindow.currentTabIndex;
                        event.accepted = true;
                    }
                    Keys.onBacktabPressed: function(event) {
                        launcherWindow.currentTabIndex = (launcherWindow.currentTabIndex + 2) % 3;
                        tabSwitch.currentIndex = launcherWindow.currentTabIndex;
                        event.accepted = true;
                    }
                    Keys.onDownPressed: function(event) {
                        launcherWindow.isKeyboardNav = true;
                        keyboardNavTimer.restart();
                        if (launcherWindow.currentTabIndex === 2) {
                            if (emojiGrid.currentIndex + 5 < emojiModel.count) {
                                emojiGrid.currentIndex += 5;
                            } else if (emojiGrid.currentIndex < emojiModel.count - 1) {
                                emojiGrid.currentIndex = emojiModel.count - 1;
                            }
                        } else if (launcherWindow.appGridActive) {
                            appList.currentIndex = Math.min(appModel.count - 1, appList.currentIndex + launcherWindow.gridColumns);
                        } else {
                            if (appList.currentIndex < appModel.count - 1) {
                                appList.currentIndex++;
                            }
                        }
                        event.accepted = true;
                    }
                    Keys.onUpPressed: function(event) {
                        launcherWindow.isKeyboardNav = true;
                        keyboardNavTimer.restart();
                        if (launcherWindow.currentTabIndex === 2) {
                            if (emojiGrid.currentIndex >= 5) {
                                emojiGrid.currentIndex -= 5;
                            }
                        } else if (launcherWindow.appGridActive) {
                            appList.currentIndex = Math.max(0, appList.currentIndex - launcherWindow.gridColumns);
                        } else {
                            if (appList.currentIndex > 0) {
                                appList.currentIndex--;
                            }
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
                            if (emojiGrid.currentIndex > 0) {
                                emojiGrid.currentIndex--;
                            }
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
                            if (emojiGrid.currentIndex < emojiModel.count - 1) {
                                emojiGrid.currentIndex++;
                            }
                            event.accepted = true;
                        }
                    }
                    Keys.onReturnPressed: function(event) {
                        if (launcherWindow.currentTabIndex === 2) {
                            activateEmoji(emojiGrid.currentIndex);
                        } else {
                            activateIndex(appList.currentIndex);
                        }
                        event.accepted = true;
                    }
                    Keys.onEscapePressed: function(event) {
                        closeLauncher();
                        event.accepted = true;
                    }
                }

                // web search button next to the search field (Settings -> Launcher -> Web search)
                IconButton {
                    id: webBtn
                    z: 10
                    visible: launcherWindow.webSearch
                    anchors.right: parent.right
                    y: searchInput.y
                    size: launcherWindow.s(36)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰖟"
                    iconFontSize: launcherWindow.s(16)
                    glassShadow: 0
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    onClicked: launcherWindow.webButton()
                }

                // the tabs: a row here, or icons in the rail when it's on
                Switch {
                    id: tabSwitch
                    z: 10
                    x: 0
                    width: launcherWindow.showRail ? launcherWindow.railW : parent.width
                    y: launcherWindow.showRail
                       ? (contentContainer.isSearchAtBottom ? listContainer.y + listContainer.height - height : listContainer.y)
                       : (contentContainer.isSearchAtBottom
                          ? (searchInput.y - height - launcherWindow.s(8))
                          : (searchInput.y + searchInput.height + launcherWindow.s(8)))
                    height: launcherWindow.s(28)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: launcherWindow.s(11)
                    baseColor: ThemeBackend.surface0
                    bgOpacity: ThemeBackend.glassActive ? 0.0 : 1.0
                    accentColor: ThemeBackend.mauve
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    options: [launcherWindow.tabAppsTitle, launcherWindow.tabFilesTitle, launcherWindow.tabEmojisTitle]
                    currentIndex: launcherWindow.currentTabIndex
                    onValueChanged: function(index, value) {
                        launcherWindow.currentTabIndex = index;
                    }
                    onToggled: function(index) {
                        launcherWindow.currentTabIndex = index;
                    }
                }

                // the favourites pane: under the tabs, a grid of pinned apps. Drag tiles to reorder;
                // drag a row from the list onto it to pin; right-click a tile to unpin.
                Item {
                    id: favPane
                    visible: launcherWindow.showRail
                    x: 0
                    y: contentContainer.isSearchAtBottom ? listContainer.y : tabSwitch.y + tabSwitch.height + launcherWindow.s(10)
                    width: launcherWindow.railW
                    height: contentContainer.isSearchAtBottom ? tabSwitch.y - launcherWindow.s(10) - y : listContainer.y + listContainer.height - y
                    clip: true

                    readonly property real cellW: width / launcherWindow.favColumns
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

                    Text {
                        anchors.centerIn: parent
                        width: parent.width - launcherWindow.s(24)
                        visible: launcherWindow.favoriteApps.length === 0
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        text: I18n.t("applauncher.favorites_empty", "Drag apps here, or right-click one, to pin it")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: launcherWindow.s(12)
                        color: ThemeBackend.subtext0
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
                                width: favPane.cellW
                                height: launcherWindow.favCellH
                                x: dragging ? favDragX : (slot % launcherWindow.favColumns) * favPane.cellW
                                y: dragging ? favDragY : Math.floor(slot / launcherWindow.favColumns) * launcherWindow.favCellH
                                z: dragging ? 10 : 1
                                property real favDragX: 0
                                property real favDragY: 0
                                Behavior on x { enabled: !favTile.dragging; NumberAnimation { duration: (180) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
                                Behavior on y { enabled: !favTile.dragging; NumberAnimation { duration: (180) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: launcherWindow.s(3)
                                    radius: ThemeBackend.pill ? launcherWindow.s(22) : ThemeBackend.borderRadius
                                    color: favTile.dragging ? (ThemeBackend.material ? ThemeBackend.secondaryContainer : ThemeBackend.surface1)
                                                            : (favMa.containsMouse ? Qt.alpha(ThemeBackend.text, 0.07) : "transparent")
                                    scale: favTile.dragging ? 1.06 : 1.0
                                    Behavior on scale { NumberAnimation { duration: (120) * ThemeBackend.animScale } }
                                }

                                Column {
                                    anchors.centerIn: parent
                                    width: parent.width - launcherWindow.s(8)
                                    spacing: launcherWindow.s(5)
                                    Item {
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        width: launcherWindow.s(40)
                                        height: width
                                        Image {
                                            id: favIcon
                                            anchors.fill: parent
                                            visible: !favTile.modelData.fontIcon && status === Image.Ready
                                            source: favTile.modelData.fontIcon ? "" : launcherWindow.iconUrl(favTile.modelData.icon || "")
                                            sourceSize: Qt.size(96, 96)
                                            asynchronous: true
                                            smooth: true
                                            mipmap: true
                                        }
                                        Text {
                                            anchors.centerIn: parent
                                            visible: !favIcon.visible
                                            text: favTile.modelData.fontIcon || "󰵆"
                                            font.family: ThemeBackend.iconFont
                                            font.pixelSize: launcherWindow.s(24)
                                            color: ThemeBackend.subtext0
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        horizontalAlignment: Text.AlignHCenter
                                        text: favTile.modelData.name
                                        elide: Text.ElideRight
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: launcherWindow.s(11)
                                        color: ThemeBackend.text
                                    }
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

                        // where a dragged list row would be pinned
                        Rectangle {
                            visible: favPane.dropSlot >= 0
                            x: (favPane.dropSlot % launcherWindow.favColumns) * favPane.cellW + launcherWindow.s(3)
                            y: Math.floor(favPane.dropSlot / launcherWindow.favColumns) * launcherWindow.favCellH + launcherWindow.s(3)
                            width: favPane.cellW - launcherWindow.s(6)
                            height: launcherWindow.favCellH - launcherWindow.s(6)
                            radius: ThemeBackend.pill ? launcherWindow.s(22) : ThemeBackend.borderRadius
                            color: "transparent"
                            border.width: 2
                            border.color: ThemeBackend.mauve
                        }
                    }
                }

                // the line between the favourites and the list
                Rectangle {
                    visible: launcherWindow.showRail
                    x: launcherWindow.railW + launcherWindow.s(6)
                    y: Math.min(tabSwitch.y, listContainer.y) + launcherWindow.s(4)
                    width: 1
                    height: Math.max(0, Math.max(listContainer.y + listContainer.height, favPane.y + favPane.height) - y - launcherWindow.s(4))
                    color: Qt.alpha(ThemeBackend.text, 0.12)
                }

                // a list row being dragged (to reorder the list, or onto the favourites to pin it)
                Rectangle {
                    id: rowGhost
                    z: 50
                    visible: listDrag.active
                    width: launcherWindow.s(220)
                    height: launcherWindow.s(40)
                    x: listDrag.pos.x - width / 2
                    y: listDrag.pos.y - height / 2
                    radius: height / 2
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
                    function overPane() { return launcherWindow.showRail && pos.x < launcherWindow.railW + launcherWindow.s(6); }
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
                                to = Math.max(0, Math.min(appModel.count - 1, Math.floor((l.y + appList.contentY) / (launcherWindow.s(44) + appList.spacing))));
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

                Item {
                    id: listContainer
                    z: 1
                    anchors.left: parent.left
                    anchors.leftMargin: launcherWindow.showRail ? launcherWindow.railW + launcherWindow.s(13) : 0
                    anchors.right: parent.right
                    y: contentContainer.isSearchAtBottom ? 0
                       : (launcherWindow.showRail ? searchInput.y + searchInput.height + launcherWindow.s(8) : (tabSwitch.y + tabSwitch.height + launcherWindow.s(8)))
                    height: contentContainer.isSearchAtBottom
                            ? Math.max(0, (launcherWindow.showRail ? searchInput.y : tabSwitch.y) - launcherWindow.s(8))
                            : Math.max(0, parent.height - y)
                    clip: true

                    opacity: launcherWindow.isCentered
                             ? Math.max(0.0, Math.min(1.0, (container.animProgress - 0.2) / 0.8))
                             : 1.0

                    NumberAnimation {
                        id: scrollAnim
                        target: appList
                        property: "contentY"
                        duration: (260) * ThemeBackend.animScale
                        easing.type: Easing.OutCubic
                    }

                    Item {
                        id: highlightGlassLayer
                        visible: ThemeBackend.liquidGlass && appList.visible && morphHighlight.visible
                        width: appList.width
                        height: morphHighlight.height
                        x: morphHighlight.x + launcherWindow.s(-20) * (1.0 - launcherWindow.getItemProgress(appList.currentIndex))
                        y: morphHighlight.y - appList.contentY
                        opacity: morphHighlight.opacity

                        readonly property bool isMoving: Math.abs(morphHighlight.y - morphHighlight.targetY) > 0.5
                        property real lift: (highlightLayerGlass.active && isMoving) ? 1.0 : 0.0
                        Behavior on lift { NumberAnimation { duration: (240) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
                        transform: Scale {
                            origin.x: highlightGlassLayer.width / 2
                            origin.y: highlightGlassLayer.height / 2
                            xScale: 1.0 + 0.015 * highlightGlassLayer.lift
                            yScale: 1.0 + 0.1 * highlightGlassLayer.lift
                        }

                        GlassFill {
                            id: highlightLayerGlass
                            anchors.fill: parent
                            radius: ThemeBackend.rad(morphHighlight.radius)
                            forceOpaque: true
                            tintColor: ThemeBackend.text
                            tintAmount: 0
                            tintStrength: 1.0
                            press: 0.6 + 0.4 * highlightGlassLayer.lift
                        }
                    }

                    HoverHandler {
                        id: listHover
                        enabled: appList.visible
                    }

                    ListView {
                        id: appList
                        anchors.fill: parent
                        visible: launcherWindow.currentTabIndex !== 2 && !launcherWindow.appGridActive
                        interactive: !listDrag.active
                        clip: true
                        model: appModel
                        spacing: launcherWindow.s(4)
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

                        function getItemY(idx) {
                            return idx * (launcherWindow.s(44) + spacing);
                        }

                        function resetScroll() {
                            scrollAnim.stop();
                            contentY = 0;
                        }

                        property bool scrolling: false

                        Timer {
                            id: scrollSettleTimer
                            interval: 200
                            onTriggered: appList.scrolling = false
                        }

                        function refreshHover() {
                            if (!listHover.hovered || !visible) {
                                hoverItem = null;
                                return;
                            }
                            const px = contentX + listHover.point.position.x;
                            const py = contentY + listHover.point.position.y;
                            const item = itemAt(px, py) || itemAt(px, py - spacing);
                            hoverItem = (item && !item.isSelected) ? item : null;
                        }

                        onCountChanged: refreshHover()

                        readonly property point cursorPos: listHover.point.position
                        onCursorPosChanged: refreshHover()

                        Connections {
                            target: listHover
                            function onHoveredChanged() { appList.refreshHover(); }
                        }

                        onContentYChanged: {
                            scrolling = true;
                            scrollSettleTimer.restart();
                            refreshHover();
                            if (contentY < 0 && !moving && !flicking) {
                                contentY = 0;
                            }
                        }

                        function ensureVisible(idx, animated) {
                            if (idx < 0 || appModel.count === 0) return;
                            let itemH = launcherWindow.s(44);
                            let step = itemH + spacing;
                            let itemTop = idx * step;
                            let itemBottom = itemTop + itemH;

                            let curContentY = scrollAnim.running ? scrollAnim.to : contentY;
                            let totalH = Math.max(0, appModel.count * step - spacing);
                            let maxScroll = Math.max(0, totalH - height);
                            let newContentY = curContentY;

                            if (itemTop < curContentY) {
                                newContentY = itemTop;
                            } else if (itemBottom > curContentY + height) {
                                newContentY = itemBottom - height;
                            }

                            newContentY = Math.max(0, Math.min(maxScroll, newContentY));

                            if (Math.abs(newContentY - contentY) > 0.5) {
                                if (animated) {
                                    scrollAnim.stop();
                                    scrollAnim.from = contentY;
                                    scrollAnim.to = newContentY;
                                    scrollAnim.start();
                                } else {
                                    scrollAnim.stop();
                                    contentY = newContentY;
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) {
                                ensureVisible(currentIndex, launcherWindow.isKeyboardNav);
                            }
                            refreshHover();
                        }

                        property Item hoverItem: null

                        GlassLens {
                            id: rowHoverLens
                            parent: appList.contentItem
                            z: -1
                            instant: appList.scrolling
                            targetX: appList.hoverItem ? appList.hoverItem.x : 0
                            targetY: appList.hoverItem ? appList.hoverItem.y : 0
                            targetWidth: appList.hoverItem ? appList.hoverItem.width : 0
                            targetHeight: appList.hoverItem ? appList.hoverItem.height : 0
                            radius: ThemeBackend.borderRadius
                            tintColor: ThemeBackend.surface0
                            tintAmount: 0.3
                            shadow: 0
                            restPress: 0.2
                            magnify: launcherWindow.s(4)
                            press: appList.hoverItem && appList.hoverItem.pressed ? 0.8 : 0
                        }

                        Rectangle {
                            id: morphHighlight
                            parent: appList.contentItem
                            z: 0
                            visible: opacity > 0.001
                            opacity: (appList.count > 0 && appList.currentIndex >= 0)
                                     ? launcherWindow.getItemOpacity(appList.currentIndex)
                                     : 0.0
                            Behavior on opacity {
                                enabled: !itemsIntroSequence.running
                                NumberAnimation {
                                    duration: (170) * ThemeBackend.animScale
                                    easing.type: Easing.OutCubic
                                }
                            }
                            x: 0
                            width: appList.width
                            height: launcherWindow.s(44)
                            radius: ThemeBackend.pill ? height / 2 : ThemeBackend.borderRadius
                            color: ThemeBackend.liquidGlass ? "transparent" : (ThemeBackend.material ? ThemeBackend.secondaryContainer : Qt.alpha(ThemeBackend.mauve, 0.16))

                            // Monolith's selection spine (Material marks the row by filling it)
                            Rectangle {
                                visible: !ThemeBackend.material
                                x: I18n.rtl ? parent.width - width - launcherWindow.s(4) : launcherWindow.s(4)
                                anchors.verticalCenter: parent.verticalCenter
                                width: launcherWindow.s(3)
                                height: parent.height * 0.56
                                radius: ThemeBackend.rad(width / 2)
                                color: ThemeBackend.mauve
                            }

                            property real targetY: (appList.currentIndex >= 0 && appModel.count > 0)
                                                   ? appList.getItemY(appList.currentIndex)
                                                   : 0
                            y: targetY

                            transform: Translate {
                                x: launcherWindow.s(-20) * (1.0 - launcherWindow.getItemProgress(appList.currentIndex))
                            }

                            Behavior on y {
                                enabled: launcherWindow.isKeyboardNav
                                NumberAnimation {
                                    duration: (260) * ThemeBackend.animScale
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        delegate: Item {
                            id: delegateRoot
                            width: ListView.view ? ListView.view.width : 0
                            height: launcherWindow.s(44)
                            clip: false
                            z: 1
                            // the row being dragged fades; a line shows where it will go
                            opacity: (listDrag.active && listDrag.from === index) ? 0.35 : launcherWindow.getItemOpacity(index)

                            property bool isSelected: index === appList.currentIndex
                            readonly property bool pressed: ma.pressed
                            Component.onDestruction: {
                                if (appList.hoverItem === delegateRoot) appList.hoverItem = null;
                            }

                            Rectangle {
                                visible: listDrag.active && listDrag.to === index && listDrag.from !== index
                                z: 20
                                width: parent.width
                                height: launcherWindow.s(3)
                                radius: height / 2
                                color: ThemeBackend.mauve
                                y: listDrag.to > listDrag.from ? parent.height + appList.spacing / 2 - height / 2 : -appList.spacing / 2 - height / 2
                            }
                            transform: Translate {
                                x: launcherWindow.s(-20) * (1.0 - launcherWindow.getItemProgress(index))
                            }

                            Item {
                                id: delegateContent
                                anchors.fill: parent

                                scale: ma.pressed ? 0.98 : 1.0
                                Behavior on scale { NumberAnimation { duration: (180) * ThemeBackend.animScale; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }

                                Rectangle {
                                    anchors.fill: parent
                                    radius: ThemeBackend.borderRadius
                                    color: (ThemeBackend.liquidGlass || rowHoverGlass.active) ? "transparent" : ThemeBackend.surface0
                                    opacity: ma.containsMouse && !delegateRoot.isSelected ? (ThemeBackend.liquidGlass ? 1.0 : 0.45) : 0

                                    GlassFill {
                                        id: rowHoverGlass
                                        anchors.fill: parent
                                        radius: ThemeBackend.rad(parent.radius)
                                        allowed: ma.containsMouse && !delegateRoot.isSelected && !rowHoverLens.glassActive
                                        tintColor: ThemeBackend.surface0
                                        tintAmount: 0.3
                                        press: ma.pressed ? 0.8 : 0.2
                                    }
                                    Behavior on opacity { NumberAnimation { duration: (120) * ThemeBackend.animScale; easing.type: Easing.OutSine } }
                                }

                                RowLayout {
                                    layoutDirection: I18n.layoutDirection
                                    anchors.fill: parent
                                    anchors.margins: launcherWindow.s(6)
                                    anchors.leftMargin: I18n.rtl ? launcherWindow.s(10) : (launcherWindow.s(10) + (delegateRoot.isSelected ? launcherWindow.s(2) : 0))
                                    anchors.rightMargin: I18n.rtl ? (launcherWindow.s(10) + (delegateRoot.isSelected ? launcherWindow.s(2) : 0)) : launcherWindow.s(10)
                                    spacing: launcherWindow.s(10)

                                    Behavior on anchors.leftMargin {
                                        NumberAnimation { duration: (220) * ThemeBackend.animScale; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                    }
                                    Behavior on anchors.rightMargin {
                                        NumberAnimation { duration: (220) * ThemeBackend.animScale; easing.type: Easing.OutBack; easing.overshoot: 1.15 }
                                    }

                                    Item {
                                        id: delegateIconArea
                                        Layout.preferredWidth: launcherWindow.s(32)
                                        Layout.preferredHeight: launcherWindow.s(32)
                                        Layout.alignment: Qt.AlignVCenter

                                        readonly property real boxRadius: launcherWindow.s(8)
                                        readonly property real boxPadding: launcherWindow.s(4)

                                        Rectangle {
                                            anchors.fill: parent
                                            anchors.topMargin: launcherWindow.s(1.5)
                                            anchors.bottomMargin: -launcherWindow.s(1.5)
                                            radius: ThemeBackend.rad(parent.boxRadius)
                                            color: Qt.rgba(0, 0, 0, 0.12)
                                            visible: !iconBoxGlass.active
                                        }

                                        Rectangle {
                                            anchors.fill: parent
                                            radius: ThemeBackend.rad(parent.boxRadius)
                                            color: iconBoxGlass.active ? "transparent" : (delegateRoot.isSelected ? Qt.tint(ThemeBackend.surface2, Qt.rgba(ThemeBackend.mauve.r, ThemeBackend.mauve.g, ThemeBackend.mauve.b, 0.2)) : ThemeBackend.surface2)

                                            GlassFill {
                                                id: iconBoxGlass
                                                anchors.fill: parent
                                                radius: ThemeBackend.rad(parent.radius)
                                                forceClear: delegateRoot.isSelected
                                                tintColor: delegateRoot.isSelected ? ThemeBackend.text : ThemeBackend.surface2
                                                tintAmount: delegateRoot.isSelected ? 0.1 : 0.3
                                            }

                                            Behavior on color { ColorAnimation { duration: (150) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
                                        }

                                        Rectangle {
                                            id: iconContainer
                                            anchors.fill: parent
                                            anchors.margins: parent.boxPadding
                                            radius: ThemeBackend.rad(Math.max(0, parent.boxRadius - parent.boxPadding))
                                            color: "transparent"
                                            clip: true

                                            Image {
                                                id: delegateIcon
                                                anchors.fill: parent
                                                property bool failedLoad: false
                                                cache: false

                                                visible: (!model.fontIcon || model.fontIcon === "") && source !== "" && status === Image.Ready && !failedLoad

                                                source: {
                                                    if (model.fontIcon && model.fontIcon !== "") return "";
                                                    let ic = model.icon || "";
                                                    if (!ic) return "";
                                                    if (ic.startsWith("file://") || ic.startsWith("image://") || ic.startsWith("http://") || ic.startsWith("https://")) return ic;
                                                    if (ic.startsWith("/")) return "file://" + ic;

                                                    let baseName = ic.replace(/\.(png|svg|xpm|ico)$/i, "");
                                                    if (typeof Quickshell !== "undefined" && typeof Quickshell.iconPath === "function") {
                                                        let resolved = Quickshell.iconPath(ic) || Quickshell.iconPath(baseName);
                                                        if (resolved && resolved.length > 0) {
                                                            return resolved.startsWith("/") ? ("file://" + resolved) : resolved;
                                                        }
                                                    }

                                                    return "image://icon/" + baseName;
                                                }

                                                sourceSize: Qt.size(64, 64)
                                                fillMode: Image.PreserveAspectFit
                                                asynchronous: true
                                                smooth: true
                                                mipmap: true

                                                onStatusChanged: {
                                                    if (status === Image.Error) {
                                                        failedLoad = true;
                                                    }
                                                }
                                            }

                                            Text {
                                                id: delegateFontIcon
                                                anchors.centerIn: parent
                                                visible: !delegateIcon.visible
                                                text: {
                                                    if (model.fontIcon && model.fontIcon !== "") return model.fontIcon;
                                                    if (model.isCalc) return "󰃬";
                                                    if (model.isCommand) return "󰆍";
                                                    return "󰵆";
                                                }
                                                font.family: ThemeBackend.fontFamily
                                                font.pixelSize: launcherWindow.s(16)
                                                color: delegateRoot.isSelected ? ThemeBackend.mauve : ThemeBackend.subtext0
                                                verticalAlignment: Text.AlignVCenter
                                                horizontalAlignment: Text.AlignHCenter

                                                Behavior on color { ColorAnimation { duration: (150) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
                                            }
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignVCenter
                                        spacing: launcherWindow.s(1)

                                        Text {
                                            id: delegateText
                                            Layout.fillWidth: true
                                            text: model.name
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: launcherWindow.s(12)
                                            font.weight: delegateRoot.isSelected ? Font.Bold : Font.Medium
                                            color: ThemeBackend.text
                                            horizontalAlignment: I18n.textAlignment
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter

                                            Behavior on color { ColorAnimation { duration: (150) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
                                        }

                                        Text {
                                            id: delegateDesc
                                            Layout.fillWidth: true
                                            visible: launcherWindow.showDescriptions && model.description !== undefined && model.description !== null && model.description !== ""
                                            text: model.description || ""
                                            font.family: ThemeBackend.fontFamily
                                            font.pixelSize: launcherWindow.s(10)
                                            font.weight: Font.Normal
                                            color: delegateRoot.isSelected ? ThemeBackend.subtext1 : ThemeBackend.subtext0
                                            horizontalAlignment: I18n.textAlignment
                                            opacity: delegateRoot.isSelected ? 0.9 : 0.85
                                            elide: Text.ElideRight
                                            verticalAlignment: Text.AlignVCenter

                                            Behavior on color { ColorAnimation { duration: (150) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
                                        }
                                    }
                                }

                                // pinned to favourites
                                Text {
                                    anchors.right: parent.right
                                    anchors.rightMargin: launcherWindow.s(12)
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: launcherWindow.showRail && launcherWindow.isFavorite(model.desktop_id || "")
                                    text: "󰐃"
                                    font.family: ThemeBackend.iconFont
                                    font.pixelSize: launcherWindow.s(12)
                                    color: ThemeBackend.subtext0
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
                                    onReleased: {
                                        if (listDrag.active) listDrag.finish();
                                    }
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
                    }

                    // apps as a grid (Settings -> Launcher -> Grid view); shares appList's selection
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
                        highlightFollowsCurrentItem: true
                        highlightMoveDuration: (160) * ThemeBackend.animScale
                        highlight: Rectangle {
                            radius: ThemeBackend.pill ? launcherWindow.s(22) : ThemeBackend.borderRadius
                            color: ThemeBackend.material ? ThemeBackend.secondaryContainer : Qt.alpha(ThemeBackend.mauve, 0.16)
                        }
                        Keys.forwardTo: [searchInput]

                        delegate: Item {
                            id: gridCell
                            width: appGrid.cellWidth
                            height: appGrid.cellHeight
                            readonly property bool selected: index === appList.currentIndex

                            Rectangle {
                                anchors.fill: parent
                                radius: ThemeBackend.pill ? launcherWindow.s(22) : ThemeBackend.borderRadius
                                color: Qt.alpha(ThemeBackend.surface1, 0.6)
                                visible: gma.containsMouse && !gridCell.selected
                            }

                            Column {
                                anchors.centerIn: parent
                                width: parent.width - launcherWindow.s(10)
                                spacing: launcherWindow.s(6)

                                Item {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    width: launcherWindow.s(44)
                                    height: width
                                    Image {
                                        id: gridIcon
                                        anchors.fill: parent
                                        visible: (!model.fontIcon || model.fontIcon === "") && status === Image.Ready
                                        source: (model.fontIcon && model.fontIcon !== "") ? "" : launcherWindow.iconUrl(model.icon || "")
                                        sourceSize: Qt.size(96, 96)
                                        asynchronous: true
                                        smooth: true
                                        mipmap: true
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        visible: !gridIcon.visible
                                        text: (model.fontIcon && model.fontIcon !== "") ? model.fontIcon : (model.isCalc ? "󰃬" : (model.isCommand ? "󰆍" : "󰵆"))
                                        font.family: ThemeBackend.iconFont
                                        font.pixelSize: launcherWindow.s(26)
                                        color: ThemeBackend.subtext0
                                    }
                                    Text {
                                        anchors.right: parent.right
                                        anchors.top: parent.top
                                        anchors.margins: -launcherWindow.s(4)
                                        visible: launcherWindow.showRail && launcherWindow.isFavorite(model.desktop_id || "")
                                        text: "󰐃"
                                        font.family: ThemeBackend.iconFont
                                        font.pixelSize: launcherWindow.s(11)
                                        color: ThemeBackend.subtext0
                                    }
                                }
                                Text {
                                    width: parent.width
                                    horizontalAlignment: Text.AlignHCenter
                                    text: model.name
                                    elide: Text.ElideRight
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: launcherWindow.s(11)
                                    font.weight: gridCell.selected ? Font.DemiBold : Font.Normal
                                    color: gridCell.selected && ThemeBackend.material ? ThemeBackend.onSecondaryContainer : ThemeBackend.text
                                }
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
                    }

                    GridView {
                        id: emojiGrid
                        anchors.fill: parent
                        visible: launcherWindow.currentTabIndex === 2
                        clip: true
                        model: emojiModel
                        cellWidth: width / 5
                        cellHeight: launcherWindow.s(60)
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
                            if (contentY < 0 && !moving && !flicking) {
                                contentY = 0;
                            }
                        }

                        function ensureVisible(idx, animated) {
                            if (idx < 0 || emojiModel.count === 0) return;
                            let row = Math.floor(idx / 5);
                            let rowH = cellHeight;
                            let itemTop = row * rowH;
                            let itemBottom = itemTop + rowH;

                            let curContentY = emojiScrollAnim.running ? emojiScrollAnim.to : contentY;
                            let totalRows = Math.ceil(emojiModel.count / 5);
                            let totalH = Math.max(0, totalRows * rowH);
                            let maxScroll = Math.max(0, totalH - height);
                            let newContentY = curContentY;

                            if (itemTop < curContentY) {
                                newContentY = itemTop;
                            } else if (itemBottom > curContentY + height) {
                                newContentY = itemBottom - height;
                            }

                            newContentY = Math.max(0, Math.min(maxScroll, newContentY));

                            if (Math.abs(newContentY - contentY) > 0.5) {
                                if (animated) {
                                    emojiScrollAnim.stop();
                                    emojiScrollAnim.from = contentY;
                                    emojiScrollAnim.to = newContentY;
                                    emojiScrollAnim.start();
                                } else {
                                    emojiScrollAnim.stop();
                                    contentY = newContentY;
                                }
                            }
                        }

                        onCurrentIndexChanged: {
                            if (currentIndex >= 0) {
                                ensureVisible(currentIndex, launcherWindow.isKeyboardNav);
                            }
                        }

                        GlassLens {
                            id: emojiLens
                            z: -1
                            readonly property bool valid: emojiGrid.currentIndex >= 0 && emojiGrid.currentIndex < emojiGrid.count
                            targetX: valid ? (emojiGrid.currentIndex % 5) * emojiGrid.cellWidth + launcherWindow.s(3) : 0
                            targetY: valid ? Math.floor(emojiGrid.currentIndex / 5) * emojiGrid.cellHeight + launcherWindow.s(3) : 0
                            targetWidth: valid ? Math.max(0, emojiGrid.cellWidth - launcherWindow.s(6)) : 0
                            targetHeight: valid ? Math.max(0, emojiGrid.cellHeight - launcherWindow.s(6)) : 0
                            radius: ThemeBackend.borderRadius
                            forceOpaque: true
                            tintColor: ThemeBackend.text
                            tintAmount: 0
                            tintStrength: 1.0
                            shadow: 0
                            restPress: 0.6
                            followBackdropHover: false
                            fastDuration: 260
                            slowDuration: 260
                        }

                        NumberAnimation {
                            id: emojiScrollAnim
                            target: emojiGrid
                            property: "contentY"
                            duration: (220) * ThemeBackend.animScale
                            easing.type: Easing.OutCubic
                        }

                        delegate: Item {
                            id: emojiDelegateRoot
                            width: emojiGrid.cellWidth
                            height: emojiGrid.cellHeight
                            clip: false

                            readonly property bool isSelected: index === emojiGrid.currentIndex
                            readonly property bool lensHandled: isSelected && emojiLens.glassActive

                            opacity: launcherWindow.getItemOpacity(Math.floor(index / 5))
                            transform: Translate {
                                y: launcherWindow.s(15) * (1.0 - launcherWindow.getItemProgress(Math.floor(index / 5)))
                            }

                            Item {
                                id: emojiDelegateContent
                                anchors.fill: parent
                                anchors.margins: launcherWindow.s(3)

                                scale: emojiMa.pressed ? 0.92 : (emojiDelegateRoot.isSelected ? 1.04 : (emojiMa.containsMouse ? 1.02 : 1.0))
                                Behavior on scale {
                                    NumberAnimation { duration: (160) * ThemeBackend.animScale; easing.type: Easing.OutBack; easing.overshoot: 1.25 }
                                }

                                Rectangle {
                                    id: emojiBg
                                    anchors.fill: parent
                                    radius: ThemeBackend.borderRadius
                                    color: (emojiGlass.active || emojiDelegateRoot.lensHandled) ? "transparent" : (emojiDelegateRoot.isSelected
                                           ? ThemeBackend.mauve
                                           : (emojiMa.containsMouse ? Qt.alpha(ThemeBackend.surface1, 0.7) : Qt.alpha(ThemeBackend.surface0, 0.45)))
                                    border.width: (emojiDelegateRoot.isSelected || ThemeBackend.liquidGlass) ? 0 : 1

                                    GlassFill {
                                        id: emojiGlass
                                        anchors.fill: parent
                                        radius: ThemeBackend.rad(parent.radius)
                                        allowed: !emojiDelegateRoot.lensHandled
                                        forceOpaque: emojiDelegateRoot.isSelected
                                        tintColor: emojiDelegateRoot.isSelected ? ThemeBackend.text : ThemeBackend.surface0
                                        tintStrength: emojiDelegateRoot.isSelected ? 1.0 : 0.5
                                        tintAmount: emojiDelegateRoot.isSelected ? 0 : 0.25
                                        press: emojiMa.pressed ? 0.8 : (emojiDelegateRoot.isSelected ? 0.6 : (emojiMa.containsMouse ? 0.25 : 0))
                                    }
                                    border.color: emojiDelegateRoot.isSelected ? "transparent" : Qt.alpha(ThemeBackend.surface2, 0.3)

                                    Behavior on color {
                                        ColorAnimation { duration: (140) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
                                    }
                                }

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: launcherWindow.s(4)
                                    spacing: launcherWindow.s(1)

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                                        text: model.emoji
                                        font.pixelSize: launcherWindow.s(22)
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    Text {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignHCenter | Qt.AlignBottom
                                        text: model.name
                                        font.family: ThemeBackend.fontFamily
                                        font.pixelSize: launcherWindow.s(9)
                                        font.weight: emojiDelegateRoot.isSelected ? Font.Bold : Font.Normal
                                        color: emojiDelegateRoot.isSelected ? ((emojiGlass.active || emojiDelegateRoot.lensHandled) ? ThemeBackend.text : ThemeBackend.crust) : ThemeBackend.subtext0
                                        elide: Text.ElideRight
                                        horizontalAlignment: Text.AlignHCenter
                                        maximumLineCount: 1

                                        Behavior on color {
                                            ColorAnimation { duration: (140) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
                                        }
                                    }
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
                                        if (!launcherWindow.isKeyboardNav) {
                                            emojiGrid.currentIndex = index;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        anchors.centerIn: parent
                        visible: launcherWindow.currentTabIndex === 2 && emojiModel.count === 0
                        width: parent.width
                        height: launcherWindow.s(60)

                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: launcherWindow.s(6)
                            Text {
                                Layout.alignment: Qt.AlignHCenter
                                text: "🔍"
                                font.pixelSize: launcherWindow.s(24)
                            }
                            Text {
                                Layout.alignment: Qt.AlignHCenter
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
}
