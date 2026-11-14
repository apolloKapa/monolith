import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../core"
import "../../ui"

// Keyboard shortcuts: every key, in the keymap's sections, with what it does. Each tab of the
// section is this page showing one purpose (HubState.settingsSection "keys-<word>": the keymap
// sections starting with that word; "keys-other": the ones no tab names; "keybinds": all). Change a
// key (press the new one), remove it, or add one that runs a program. scripts/keys.py does the
// work: niri's keybinds.kdl (checked by niri, undone if it isn't accepted), or on Hyprland
// Monolith's monolith/keybinds file (kept across updates; undone if Hyprland reports an error).
ColumnLayout {
    id: sec
    spacing: 8
    readonly property string script: Qt.resolvedUrl("../../scripts/keys.py").toString().replace("file://", "")
    property var items: []
    property string error: ""
    property string filter: ""
    property string recording: ""      // the key being changed ("+" while adding a new one)
    property string newKey: ""          // the key picked for a new shortcut
    property bool busy: false
    // a key that's taken, waiting for "Replace?": { key, label, other (its item), from (the key
    // being changed, or "+" for a new one) }
    property var clash: null
    property string note: ""            // a short "done" line after a change
    readonly property string group: HubState.settingsSection.startsWith("keys-") ? HubState.settingsSection.slice(5) : ""
    readonly property var groups: ["apps", "monolith", "windows", "sizes", "workspaces", "monitors", "media", "screenshots", "zoom", "session"]
    function inGroup(section) {
        const s = section.toLowerCase();
        if (group === "") return true;
        if (group === "other") return !groups.some(g => s.startsWith(g));
        return s.startsWith(group);
    }
    readonly property var shown: {
        const out = [];
        let last = null;
        for (const it of items) {
            if (!inGroup(it.section)) continue;
            if (filter && (it.label + " " + it.title + " " + it.section).toLowerCase().indexOf(filter) < 0) continue;
            // a tab of one purpose has its name as the page title already
            if (it.section !== last && (group === "" || group === "other")) out.push({ head: it.section });
            last = it.section;
            out.push(it);
        }
        return out;
    }

    function load() { reader.running = true; }
    Component.onCompleted: load()
    Process {
        id: reader
        command: ["python3", sec.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const d = JSON.parse(text); sec.items = d.items || []; if (!d.ok) sec.error = d.error || ""; } catch (e) { sec.error = "Couldn't read the keys"; }
            }
        }
    }
    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: {
                let ok = false;
                try { const d = JSON.parse(text); ok = d.ok; sec.error = d.ok ? "" : d.error; } catch (e) { sec.error = "Something went wrong"; }
                // the next step (Replace: the other key goes, then this one moves), or done
                if (ok && sec.queue.length) { const next = sec.queue[0]; sec.queue = sec.queue.slice(1); sec.start(next); return; }
                if (!ok) sec.queue = [];
                else if (sec.doneNote) sec.note = sec.doneNote;
                sec.busy = false;
                sec.load();
            }
        }
    }
    property var queue: []
    property string doneNote: ""
    function start(args) { writer.command = ["python3", script].concat(args); writer.running = true; }
    // one change, or several in a row (each only if the one before worked)
    function run(args, more, done) {
        busy = true; error = ""; note = "";
        queue = more || [];
        doneNote = done || "";
        start(args);
    }
    // the same key, however it's written ("Super+Shift+s" / "Shift+Super+S")
    function norm(k) {
        const p = String(k).split("+");
        const order = ["Super", "Ctrl", "Alt", "Shift"];
        const mods = p.slice(0, -1).map(m => m.charAt(0).toUpperCase() + m.slice(1).toLowerCase()).sort((a, b) => order.indexOf(a) - order.indexOf(b));
        return mods.concat([String(p[p.length - 1]).toLowerCase()]).join("+");
    }
    function pretty(k) { return String(k).replace(/_/g, " ").replace(/\+/g, " + "); }
    // a key was pressed while picking: use it, or ask first when another shortcut has it
    function picked(k) {
        const from = recording;
        recording = "";
        error = ""; note = "";
        if (from !== "+" && norm(from) === norm(k)) return;            // the same key again: nothing to do
        const other = items.find(it => norm(it.key) === norm(k) && (from === "+" || norm(it.key) !== norm(from)));
        if (other) { clash = { key: k, other: other, from: from }; return; }
        use(from, k);
    }
    function use(from, k) {
        if (from === "+") newKey = k;
        else run(["change", from, k], [], pretty(k) + " is set");
    }
    // Replace: the other shortcut goes, then this one takes its key
    function replace() {
        const c = clash; clash = null;
        if (!c) return;
        if (c.from === "+") { run(["remove", c.other.key], [], pretty(c.key) + " is free now: pick what it runs and press Add"); newKey = c.key; return; }
        run(["remove", c.other.key], [["change", c.from, c.key]], pretty(c.key) + " is set (it was " + c.other.title + ")");
    }

    // a pressed key, in niri's words ("Super+Shift+S"); "" for a lone modifier. By where the key
    // is on the keyboard (its scan code) first, so it's the same key whatever layout is on and
    // whether Shift is held: Greek letters and Shift+1's "!" weren't understood, and the press
    // was ignored
    readonly property var scan: ({
        10: "1", 11: "2", 12: "3", 13: "4", 14: "5", 15: "6", 16: "7", 17: "8", 18: "9", 19: "0", 20: "Minus", 21: "Equal",
        24: "Q", 25: "W", 26: "E", 27: "R", 28: "T", 29: "Y", 30: "U", 31: "I", 32: "O", 33: "P", 34: "BracketLeft", 35: "BracketRight",
        38: "A", 39: "S", 40: "D", 41: "F", 42: "G", 43: "H", 44: "J", 45: "K", 46: "L", 47: "Semicolon", 48: "Apostrophe", 49: "Grave",
        51: "Backslash", 52: "Z", 53: "X", 54: "C", 55: "V", 56: "B", 57: "N", 58: "M", 59: "Comma", 60: "Period", 61: "Slash",
        9: "Escape", 22: "BackSpace", 23: "Tab", 36: "Return", 65: "Space", 104: "Return", 107: "Print",
        67: "F1", 68: "F2", 69: "F3", 70: "F4", 71: "F5", 72: "F6", 73: "F7", 74: "F8", 75: "F9", 76: "F10", 95: "F11", 96: "F12",
        110: "Home", 111: "Up", 112: "Page_Up", 113: "Left", 114: "Right", 115: "End", 116: "Down", 117: "Page_Down", 118: "Insert", 119: "Delete"
    })
    readonly property var names: ({
        [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Escape]: "Escape", [Qt.Key_Tab]: "Tab", [Qt.Key_Space]: "Space",
        [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete", [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End",
        [Qt.Key_PageUp]: "Page_Up", [Qt.Key_PageDown]: "Page_Down", [Qt.Key_Left]: "Left", [Qt.Key_Right]: "Right", [Qt.Key_Up]: "Up",
        [Qt.Key_Down]: "Down", [Qt.Key_Print]: "Print", [Qt.Key_Slash]: "Slash", [Qt.Key_Question]: "Slash", [Qt.Key_Comma]: "Comma",
        [Qt.Key_Period]: "Period", [Qt.Key_Minus]: "Minus", [Qt.Key_Equal]: "Equal", [Qt.Key_Plus]: "Equal", [Qt.Key_BracketLeft]: "BracketLeft",
        [Qt.Key_BracketRight]: "BracketRight", [Qt.Key_Semicolon]: "Semicolon", [Qt.Key_Apostrophe]: "Apostrophe", [Qt.Key_Backslash]: "Backslash",
        [Qt.Key_QuoteLeft]: "Grave"
    })
    function keyName(e) {
        if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr].indexOf(e.key) >= 0) return "";
        let k = scan[e.nativeScanCode] || names[e.key];
        if (!k && e.key >= Qt.Key_F1 && e.key <= Qt.Key_F24) k = "F" + (e.key - Qt.Key_F1 + 1);
        if (!k && ((e.key >= Qt.Key_A && e.key <= Qt.Key_Z) || (e.key >= Qt.Key_0 && e.key <= Qt.Key_9))) k = String.fromCharCode(e.key);
        if (!k) return "";
        const m = [];
        if (e.modifiers & Qt.MetaModifier) m.push("Super");
        if (e.modifiers & Qt.ControlModifier) m.push("Ctrl");
        if (e.modifiers & Qt.AltModifier) m.push("Alt");
        if (e.modifiers & Qt.ShiftModifier) m.push("Shift");
        return m.concat([k]).join("+");
    }
    // catches the next key while recording
    Item {
        id: catcher
        focus: sec.recording !== ""
        Keys.onPressed: e => {
            e.accepted = true;
            if (e.isAutoRepeat) return;
            if (e.key === Qt.Key_Escape && e.modifiers === Qt.NoModifier) { sec.recording = ""; return; }
            const k = sec.keyName(e);
            if (!k) return;
            sec.picked(k);
        }
    }
    onRecordingChanged: if (recording !== "") { clash = null; catcher.forceActiveFocus(); }
    // while picking, every key comes here, even ones niri / Hyprland use for themselves (it asks
    // the compositor to hold its own shortcuts back): those never arrived, so pressing one did nothing
    ShortcutInhibitor {
        window: sec.Window.window
        enabled: sec.recording !== ""
    }

    Label {
        Layout.fillWidth: true; wrapMode: Text.Wrap; muted: true
        text: (sec.group === "" ? "Every keyboard shortcut, and what it does; the tabs show them by purpose. " : "") + "Click a key to change it, then press the new one (Esc cancels)."
            + (Niri.hyprland ? " On Hyprland your changes stay after updates. Keys in your own my-keys file (~/.config/hypr/monolith/my-keys) are changed there." : " niri checks every change; one it doesn't accept is undone.")
    }
    Label { visible: sec.error !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap; text: sec.error; color: Theme.danger }
    Label { visible: sec.note !== "" && sec.error === ""; Layout.fillWidth: true; wrapMode: Text.Wrap; text: sec.note; color: Theme.accent }
    Label { visible: sec.recording !== ""; Layout.fillWidth: true; strong: true; color: Theme.accent; text: "Press the new key… (Esc cancels)" }
    // the key is taken: replace the other shortcut, or keep it and pick another key
    Rectangle {
        visible: sec.clash !== null
        Layout.fillWidth: true
        implicitHeight: clashCol.implicitHeight + 24
        radius: Theme.corner(56, 10)
        color: Theme.containerHigh
        border.width: 1; border.color: Qt.alpha(Theme.danger, 0.6)
        ColumnLayout {
            id: clashCol
            x: 14; y: 12; width: parent.width - 28
            spacing: 8
            Label {
                Layout.fillWidth: true; wrapMode: Text.Wrap; strong: true
                text: sec.clash ? sec.pretty(sec.clash.key) + " is already used by \u201c" + sec.clash.other.title + "\u201d" : ""
            }
            Label {
                Layout.fillWidth: true; wrapMode: Text.Wrap; muted: true
                text: !sec.clash ? "" : sec.clash.other.mine
                    ? "That one is in your own my-keys file, so it can't be replaced from here: change it there, or pick another key."
                    : "Replace it? \u201c" + sec.clash.other.title + "\u201d will have no key then."
            }
            RowLayout {
                spacing: 8
                Button { visible: sec.clash && !sec.clash.other.mine; text: "Replace"; primary: true; enabled: !sec.busy; onClicked: sec.replace() }
                Button { text: "Pick another key"; onClicked: { const f = sec.clash.from; sec.clash = null; sec.recording = f; } }
                Button { text: "Cancel"; onClicked: sec.clash = null }
            }
        }
    }

    // add one
    SettingRow {
        visible: sec.group === "" || sec.group === "apps"
        Layout.fillWidth: true
        icon: "add"
        title: "Add a shortcut"
        desc: "A key that runs a program or command"
        RowLayout {
            spacing: 8
            Button { text: sec.newKey !== "" ? sec.newKey.replace(/\+/g, " + ") : "Pick a key"; onClicked: sec.recording = "+" }
            Field { id: cmd; Layout.preferredWidth: 200; placeholder: "Command, e.g. firefox" }
            Button {
                text: "Add"; primary: true
                enabled: sec.newKey !== "" && cmd.text.trim() !== "" && !sec.busy
                onClicked: { sec.run(["add", sec.newKey, JSON.stringify({ type: "app", cmd: cmd.text.trim() })]); sec.newKey = ""; cmd.text = ""; }
            }
        }
    }
    Field { id: search; visible: sec.group === ""; Layout.fillWidth: true; placeholder: "Search keys or what they do"; onTextChanged: sec.filter = text.toLowerCase() }

    Repeater {
        model: sec.shown
        delegate: Loader {
            required property var modelData
            Layout.fillWidth: true
            sourceComponent: modelData.head !== undefined ? headC : rowC
            Component { id: headC; SectionHead { text: modelData.head } }
            Component {
                id: rowC
                SettingRow {
                    icon: "keyboard"
                    title: modelData.title
                    desc: modelData.action.length > 70 ? modelData.action.slice(0, 70) + "…" : modelData.action
                    RowLayout {
                        spacing: 6
                        Button {
                            text: sec.recording === modelData.key ? "Press a key…" : modelData.label
                            primary: sec.recording === modelData.key
                            enabled: !modelData.mine && !sec.busy
                            onClicked: sec.recording = sec.recording === modelData.key ? "" : modelData.key
                        }
                        Button { icon: "delete"; enabled: !modelData.mine && !sec.busy; onClicked: sec.run(["remove", modelData.key]) }
                    }
                }
            }
        }
    }
    Label {
        visible: sec.items.length > 0 && sec.shown.length === 0
        Layout.fillWidth: true; muted: true; wrapMode: Text.Wrap
        text: sec.filter ? "Nothing matches." : "No shortcuts here."
    }
}
