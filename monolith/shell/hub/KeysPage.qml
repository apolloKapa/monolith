import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"
import "../ui"

// Keys: your niri keybinds (from ~/.config/niri/config.kdl), the keys as chips and what they do;
// the search field filters them.
Page {
    id: page
    pageId: "keys"
    readonly property bool usesQuery: true
    property string query: ""
    property var binds: []
    readonly property var shown: query.trim() === "" ? binds
        : binds.filter(b => (b.keys + " " + b.what).toLowerCase().indexOf(query.trim().toLowerCase()) !== -1)
    implicitHeight: 540

    // config.kdl and the files it includes (binds often live in their own file)
    onCurrentChanged: if (current) readProc.running = true
    Component.onCompleted: readProc.running = true
    Process {
        id: readProc
        command: ["sh", "-c", "d=\"${XDG_CONFIG_HOME:-$HOME/.config}/niri\"; cd \"$d\" && cat config.kdl $(grep -o 'include \"[^\"]*\"' config.kdl | cut -d'\"' -f2) 2>/dev/null"]
        stdout: StdioCollector { onStreamFinished: page.binds = page.parse(text) }
    }

    // the binds { … } block: "Mod+T hotkey-overlay-title=\"…\" { spawn \"kitty\"; }"
    function parse(src) {
        const out = [];
        let depth = 0, inBinds = false;
        for (const raw of src.split("\n")) {
            const l = raw.replace(/\/\/.*$/, "").trim();
            if (l === "") continue;
            if (!inBinds) {
                if (/^binds\s*\{/.test(l)) { inBinds = true; depth = 1; }
                continue;
            }
            if (depth === 1 && l === "}") { inBinds = false; continue; }
            const m = l.match(/^([A-Za-z0-9_+]+)((?:\s+[a-z-]+=(?:"[^"]*"|\S+))*)\s*\{\s*(.*?)\s*;?\s*\}?\s*$/);
            if (depth === 1 && m) {
                const title = (m[2].match(/hotkey-overlay-title="([^"]*)"/) || [])[1];
                let action = m[3].replace(/;\s*\}?$/, "").replace(/"/g, "");
                out.push({ keys: m[1], what: title || page.humanise(action) });
            }
            depth += (l.match(/\{/g) || []).length - (l.match(/\}/g) || []).length;
        }
        return out;
    }
    function humanise(a) {
        if (a.startsWith("spawn-sh ")) return "Run " + a.substring(9);
        if (a.startsWith("spawn ")) return "Run " + a.substring(6);
        a = a.replace(/-/g, " ");
        return a.charAt(0).toUpperCase() + a.substring(1);
    }

    Empty {
        anchors.centerIn: parent
        width: parent.width
        visible: page.shown.length === 0
        icon: page.binds.length === 0 ? "keyboard" : "search_off"
        title: page.binds.length === 0 ? "No keybinds found" : "Nothing matches"
        sub: page.binds.length === 0 ? "niri's keybinds file couldn't be read." : "Try fewer letters."
    }

    GridView {
        SmoothWheel {}
        anchors.fill: parent
        clip: true
        cellWidth: width / 2
        cellHeight: 52
        model: page.shown
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            required property var modelData
            width: GridView.view.cellWidth
            height: 52
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: Theme.corner(height)
                color: Theme.containerHigh
                Row {
                    id: chips
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: modelData.keys.split("+")
                        Rectangle {
                            required property string modelData
                            height: 28
                            width: Math.max(28, kl.implicitWidth + 16)
                            radius: Theme.corner(height, -2)
                            color: Theme.control
                            Label { id: kl; anchors.centerIn: parent; text: modelData === "Mod" ? "Super" : modelData; font.pixelSize: Theme.sizeSmall; strong: true }
                        }
                    }
                }
                Label {
                    anchors.left: chips.right; anchors.leftMargin: 10
                    anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.what
                    font.pixelSize: Theme.sizeSmall
                    muted: true
                }
            }
        }
    }
}
