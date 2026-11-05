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
    implicitHeight: Math.max(1, Math.min(results.length, maxRows)) * rowH

    // how often each app was opened from here, for the order
    // how often each app was opened (ranks them first), unless that's switched off
    function uses(id) { return Store.get("search.ranking", true) === false ? 0 : Number(Store.get("launches." + id.replace(/\./g, "_"), 0)); }
    readonly property var apps: { let _ = Store.revision; return DesktopEntries.applications.values.filter(a => !a.noDisplay)
        .slice().sort((a, b) => (uses(b.id) - uses(a.id)) || a.name.localeCompare(b.name)); }

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
    onQueryChanged: { const q = query.trim(); if (q.startsWith("/") || q.startsWith("~")) fileQuery(q); }

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
            const e = q.substring(1).trim();
            const hits = Emoji.list.filter(x => e === "" || x[1].indexOf(e) !== -1).slice(0, 60);
            return hits.map(x => ({ kind: "emoji", name: x[1], sub: Emoji.groups[x[2]] + " · Enter copies", glyph: x[0] }));
        }
        if (q.startsWith("/") || q.startsWith("~")) {
            return files.map(f => ({ kind: "file", name: f.replace(/\/$/, "").split("/").pop(), sub: f.replace(Quickshell.env("HOME"), "~"), path: f, icon: f.endsWith("/") ? "folder" : "draft" }));
        }
        const out = [];
        const r = calc(q);
        if (r !== null) out.push({ kind: "calc", name: r, sub: "Copy the result", icon: "calculate", value: r });
        if (q === "") return out.concat(apps.map(a => ({ kind: "app", entry: a })));
        const scored = apps.map(a => ({ a: a, s: score(a, q) })).filter(x => x.s > 0).sort((x, y) => y.s - x.s);
        return out.concat(scored.map(x => ({ kind: "app", entry: x.a })));
    }
    onResultsChanged: list.currentIndex = 0

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
    Keys.onEnterPressed: activate(list.currentIndex)

    ListView {
        id: list
        anchors.fill: parent
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
                Label { width: parent.width; text: row.title; strong: row.index === list.currentIndex }
                Label { width: parent.width; text: row.sub; muted: true; font.pixelSize: Theme.sizeSmall; visible: text !== "" }
            }
        }
    }
}
