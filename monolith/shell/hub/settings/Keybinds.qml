import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Devices → Keyboard shortcuts: every key, in the keymap's sections, with what it does. Change a
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
                sec.busy = false;
                try { const d = JSON.parse(text); sec.error = d.ok ? "" : d.error; } catch (e) { sec.error = "Something went wrong"; }
                sec.load();
            }
        }
    }
    function run(args) {
        busy = true; error = "";
        writer.command = ["python3", script].concat(args);
        writer.running = true;
    }

    // a pressed key, in niri's words ("Super+Shift+S"); "" for a lone modifier
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
        let k = names[e.key];
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
            if (e.key === Qt.Key_Escape && !(e.modifiers & Qt.MetaModifier)) { sec.recording = ""; return; }
            const k = sec.keyName(e);
            if (!k) return;
            if (sec.recording === "+") sec.newKey = k;
            else sec.run(["change", sec.recording, k]);
            sec.recording = "";
        }
    }
    onRecordingChanged: if (recording !== "") catcher.forceActiveFocus()

    Label {
        Layout.fillWidth: true; wrapMode: Text.Wrap; muted: true
        text: "Every keyboard shortcut, and what it does. Click a key to change it, then press the new one (Esc cancels)."
            + (Niri.hyprland ? " On Hyprland your changes stay after updates. Keys in your own my-keys file (~/.config/hypr/monolith/my-keys) are changed there." : " niri checks every change; one it doesn't accept is undone.")
    }
    Label { visible: sec.error !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap; text: sec.error; color: Theme.danger }
    Label { visible: sec.recording !== ""; Layout.fillWidth: true; strong: true; color: Theme.accent; text: "Press the new key… (Esc cancels)" }

    // add one
    SettingRow {
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
    Field { id: search; Layout.fillWidth: true; placeholder: "Search keys or what they do"; onTextChanged: sec.filter = text.toLowerCase() }

    Repeater {
        model: {
            const out = [];
            let last = null;
            for (const it of sec.items) {
                if (sec.filter && (it.label + " " + it.title + " " + it.section).toLowerCase().indexOf(sec.filter) < 0) continue;
                if (it.section !== last) { out.push({ head: it.section }); last = it.section; }
                out.push(it);
            }
            return out;
        }
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
}
