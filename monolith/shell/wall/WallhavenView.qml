import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import "../core"
import "../ui"

// Wallhaven in the wallpaper picker (its Wallhaven button): search wallhaven.cc (safe-for-work
// only, no account), and a card's download button saves the picture into your wallpaper folder
// and puts it on straight away. Only what you type goes to Wallhaven, with the picture sizes
// your screens need; nothing about you.
Item {
    id: wh
    // the picker puts it on (on every screen, or on the one "Set on" picks)
    signal chosen(string path)
    signal back()
    property bool active: false
    function focusSearch() { search.forceInput(); }

    readonly property string query: Store.get("wallpaper.whQuery", "")
    readonly property string sort: Store.get("wallpaper.whSort", "toplist")
    // General (photos, art, landscapes…), Anime, or both
    readonly property string cats: { const c = Store.get("wallpaper.whCats", "100"); return c === "010" || c === "110" ? c : "100"; }
    // only pictures at least as big as your biggest screen (so none of them look soft)
    readonly property bool fit: Store.get("wallpaper.whFit", true) !== false
    readonly property string screenSize: {
        let w = 0, h = 0;
        for (const s of Quickshell.screens) {
            const r = s.devicePixelRatio || 1;
            if (s.width * r * s.height * r > w * h) { w = Math.round(s.width * r); h = Math.round(s.height * r); }
        }
        return w > 0 ? w + "x" + h : "";
    }

    property var results: []
    property int page: 0
    property int lastPage: 1
    property string phase: "idle"     // idle, loading, more (next page), done, error
    property string error: ""
    // a picture's id -> "loading" | "done" | "failed"
    property var downloads: ({})

    function url(p) {
        const q = [
            "q=" + encodeURIComponent(query.trim()),
            "categories=" + cats, "purity=100",
            "sorting=" + (query.trim() !== "" && sort === "toplist" ? "relevance" : sort),
            "order=desc", "page=" + p
        ];
        if (sort === "toplist") q.push("topRange=1y");
        if (fit && screenSize !== "") q.push("atleast=" + screenSize);
        return "https://wallhaven.cc/api/v1/search?" + q.join("&");
    }
    function load(fresh) {
        if (fetch.running) return;
        if (fresh) { page = 0; lastPage = 1; results = []; grid.contentY = 0; }
        if (page >= lastPage) return;
        phase = fresh ? "loading" : "more";
        fetch.command = ["curl", "-fsS", "--max-time", "20", "-A", "Monolith", url(page + 1)];
        fetch.running = true;
    }
    Process {
        id: fetch
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "") return;      // (failed: onExited says why)
                try {
                    const d = JSON.parse(text);
                    const seen = {};
                    for (const r of wh.results) seen[r.id] = true;
                    wh.results = wh.results.concat((d.data || []).filter(r => !seen[r.id] && /^[a-z0-9]+$/.test(r.id) && String(r.path).startsWith("https://w.wallhaven.cc/")));
                    wh.page = d.meta ? d.meta.current_page : wh.page + 1;
                    wh.lastPage = d.meta ? d.meta.last_page : wh.page;
                    wh.phase = "done";
                } catch (e) {
                    wh.phase = "error";
                    wh.error = "Wallhaven sent something unexpected. Try again in a moment.";
                }
            }
        }
        onExited: code => {
            if (code === 0) return;
            wh.phase = "error";
            // (22: an HTTP error, which is mostly Wallhaven's limit of 45 searches a minute)
            wh.error = code === 22 ? "Wallhaven is busy or limiting searches. Try again in a minute." : "Couldn't reach Wallhaven. Check your connection.";
        }
    }
    onActiveChanged: if (active && results.length === 0 && phase !== "loading") load(true)

    // ── downloads: one at a time, in the order asked ──
    property var queue: []
    function mark(id, s) { downloads = Object.assign({}, downloads, { [id]: s }); }
    function download(r) {
        const s = downloads[r.id];
        if (s === "loading") return;
        mark(r.id, "loading");
        queue = queue.concat([r]);
        nextDownload();
    }
    function nextDownload() {
        if (dl.running || queue.length === 0) return;
        const r = queue[0];
        queue = queue.slice(1);
        const ext = (String(r.path).match(/\.(jpg|jpeg|png|webp)$/i) || [".jpg", "jpg"])[1].toLowerCase();
        dl.id = r.id;
        // (already there: it's just put on. Downloaded to a .part file first, so a picture cut
        // short never shows up in the folder)
        dl.command = ["sh", "-c",
            "mkdir -p \"$1\" && f=\"$1/$2\" && { [ -s \"$f\" ] || { curl -fsSL --max-time 180 -A Monolith -o \"$f.part\" \"$3\" && mv \"$f.part\" \"$f\"; }; } && printf %s \"$f\" || { rm -f \"$f.part\"; exit 1; }",
            "_", Wall.dir, "wallhaven-" + r.id + "." + ext, r.path];
        dl.running = true;
    }
    Process {
        id: dl
        property string id: ""
        stdout: StdioCollector {
            id: dlOut
            onStreamFinished: {
                const p = text.trim();
                if (p === "") return;
                wh.mark(dl.id, "done");
                Wall.rescan();
                wh.chosen(p);
            }
        }
        onExited: code => { if (code !== 0) wh.mark(dl.id, "failed"); Qt.callLater(wh.nextDownload); }
    }

    Keys.onEscapePressed: wh.back()

    // ── search, order, size ──
    Row {
        id: bar
        width: parent.width
        height: 40
        spacing: 10
        Field {
            id: search
            width: Math.max(200, bar.width - 360 - 270 - fitBtn.width - 30)
            height: 40
            placeholder: "Search Wallhaven: forest, city at night, minimal…"
            text: wh.query
            onAccepted: v => { if (v.trim() !== wh.query.trim()) { Store.set("wallpaper.whQuery", v.trim()); Qt.callLater(() => wh.load(true)); } }
        }
        Segmented {
            width: 360; height: 40
            opts: [["toplist", "Top"], ["date_added", "Latest"], ["views", "Most viewed"], ["random", "Random"]]
            value: wh.sort
            onPicked: v => { Store.set("wallpaper.whSort", v); Qt.callLater(() => wh.load(true)); }
        }
        Segmented {
            width: 270; height: 40
            opts: [["100", "General"], ["010", "Anime"], ["110", "Both"]]
            value: wh.cats
            onPicked: v => { Store.set("wallpaper.whCats", v); Qt.callLater(() => wh.load(true)); }
        }
        Pressable {
            id: fitBtn
            width: fitRow.implicitWidth + 24; height: 40
            color: wh.fit ? Theme.selected : Theme.container
            onClicked: { Store.set("wallpaper.whFit", !wh.fit); Qt.callLater(() => wh.load(true)); }
            Row {
                id: fitRow
                anchors.centerIn: parent
                spacing: 6
                Icon { name: wh.fit ? "check" : "fit_screen"; size: 18; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Sharp on my screen"; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    // ── the pictures ──
    GridView {
        SmoothWheel {}
        id: grid
        y: bar.height + 14
        width: parent.width
        height: parent.height - y
        clip: true
        cellWidth: width / 4
        cellHeight: cellWidth * 0.62
        cacheBuffer: Math.max(0, height)
        boundsBehavior: Flickable.StopAtBounds
        model: wh.results
        // near the end: the next page
        onContentYChanged: if (wh.phase === "done" && contentHeight > 0 && contentY + height > contentHeight - cellHeight * 1.5) wh.load(false)
        footer: Item {
            width: grid.width
            height: wh.phase === "more" ? 60 : 10
            Icon {
                anchors.centerIn: parent; visible: wh.phase === "more"; name: "progress_activity"; size: 26; color: Theme.accent
                RotationAnimator on rotation { running: wh.phase === "more" && wh.active; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
            }
        }
        delegate: Item {
            id: cell
            required property var modelData
            required property int index
            readonly property string st: wh.downloads[modelData.id] || ""
            width: grid.cellWidth
            height: grid.cellHeight
            ClippingRectangle {
                id: frame
                anchors.fill: parent
                anchors.margins: 6
                radius: Theme.corner(height, 12)
                color: Theme.container
                Image {
                    anchors.fill: parent
                    source: cell.modelData.thumbs ? cell.modelData.thumbs.large : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    sourceSize.width: Math.round(frame.width * 1.5)
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(220) } }
                    scale: hov.hovered ? 1.04 : 1
                    Behavior on scale { NumberAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
                }
                // its size, bottom left
                Rectangle {
                    anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 10
                    width: res.implicitWidth + 16; height: 24; radius: Theme.corner(height)
                    color: Qt.rgba(0, 0, 0, 0.55)
                    Label { id: res; anchors.centerIn: parent; text: String(cell.modelData.resolution || "").replace("x", " × "); color: "white"; font.pixelSize: Theme.sizeSmall - 1 }
                }
            }
            HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
            // anywhere on it: download and put it on
            TapHandler { onTapped: wh.download(cell.modelData) }
            // the download button, bottom right: a spinner while it comes, a tick once it's on
            Pressable {
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 14
                width: 40; height: 40
                color: cell.st === "done" ? Theme.accent : cell.st === "failed" ? Theme.danger : Qt.rgba(0, 0, 0, 0.6)
                opacity: hov.hovered || cell.st !== "" ? 1 : 0.85
                onClicked: wh.download(cell.modelData)
                Icon {
                    anchors.centerIn: parent; size: 22
                    name: cell.st === "loading" ? "progress_activity" : cell.st === "done" ? "check" : cell.st === "failed" ? "refresh" : "download"
                    color: cell.st === "done" ? Theme.onAccent : "white"
                    RotationAnimator on rotation { running: cell.st === "loading"; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
                    rotation: 0
                }
            }
        }
    }

    // ── nothing to show (yet) ──
    Empty {
        anchors.centerIn: grid
        width: grid.width
        visible: wh.results.length === 0
        spinning: wh.phase === "loading"
        icon: wh.phase === "loading" ? "progress_activity" : wh.phase === "error" ? "cloud_off" : "image_search"
        title: wh.phase === "loading" ? "Searching Wallhaven…" : wh.phase === "error" ? "Wallhaven didn't answer" : "Nothing found"
        sub: wh.phase === "error" ? wh.error : wh.phase === "loading" ? "" : (wh.fit ? "Try other words, or turn off \"Sharp on my screen\" to see smaller pictures too." : "Try other words.")
        button: wh.phase === "error" ? "Try again" : ""
        buttonIcon: "refresh"
        onActed: wh.load(true)
    }
}
