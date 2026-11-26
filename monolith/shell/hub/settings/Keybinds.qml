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
    property string loadError: ""       // the keys couldn't be read
    property string filter: ""
    property string recording: ""      // the key being changed ("+" while adding a new one)
    property string newKey: ""          // the key picked for a new shortcut…
    property bool newReplaces: false    // …which another shortcut has, and loses when this one is added
    property bool busy: false
    // What a change has to say is said where it was made: under the row of the key being changed
    // (`at`: that key; "+" is "Add a shortcut"). It used to be at the top of the page, which with
    // 150 rows was nearly always scrolled away: a taken key looked like nothing had happened,
    // and each line coming or going there moved every row.
    property string at: ""
    readonly property string atN: at === "" || at === "+" ? at : norm(at)
    // a key that's taken, waiting for "Replace?": { key, other (its item), from (the key being
    // changed, or "+" for a new one) }
    property var clash: null
    property string error: ""           // a change that didn't work
    property string note: ""            // what a change did, when the row doesn't show it all
    readonly property bool said: clash !== null || error !== "" || note !== ""
    readonly property string group: HubState.settingsSection.startsWith("keys-") ? HubState.settingsSection.slice(5) : ""
    readonly property var groups: ["apps", "monolith", "windows", "sizes", "workspaces", "monitors", "media", "screenshots", "zoom", "session"]
    function inGroup(section) {
        const s = section.toLowerCase();
        if (group === "") return true;
        if (group === "other") return !groups.some(g => s.startsWith(g));
        return s.startsWith(group);
    }
    // what each key's row shows, by its place in items: { show, head } (shown on this tab and for
    // the search; a section heading above it). Rows are made once and only shown or hidden: making
    // all 148 again on every tab switch, search letter and change was the lag
    readonly property var view: {
        const out = [];
        let last = null;
        for (const it of items) {
            const show = inGroup(it.section) && (!filter || (it.label + " " + it.title + " " + it.section).toLowerCase().indexOf(filter) >= 0);
            // (a tab of one purpose has its name as the page title already)
            out.push({ show: show, head: show && it.section !== last && (group === "" || group === "other") });
            if (show) last = it.section;
        }
        return out;
    }
    readonly property int shownCount: view.reduce((n, v) => n + (v.show ? 1 : 0), 0)
    // Rows are made a few per frame, this tab's first, then the other tabs' in the background so
    // switching finds them ready. (Loader's asynchronous doesn't spread the work here: all 148
    // were made in one frame of 140 ms. Ten rows take about 10 ms.)
    property int slots: 0               // rows there are (see the Repeater): at least one per key
    onItemsChanged: if (items.length > slots) slots = Math.ceil((items.length + 4) / 16) * 16
    property var built: []              // by place in items: made yet
    property int builtCount: 0
    function buildSome() {
        const b = built.slice();
        let n = 0;
        for (let pass = 0; pass < 2 && n < 10; pass++)
            for (let i = 0; i < items.length && n < 10; i++)
                if (!b[i] && (pass === 1 || (view[i] && view[i].show))) { b[i] = true; n++; }
        built = b;
        builtCount += n;
    }
    Timer {
        interval: 16; repeat: true
        running: sec.builtCount < sec.items.length
        triggeredOnStart: true
        onTriggered: sec.buildSome()
    }

    function load() { reader.running = true; }
    Component.onCompleted: load()
    Process {
        id: reader
        command: ["python3", sec.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const d = JSON.parse(text); sec.items = d.items || []; sec.loadError = d.ok ? "" : (d.error || ""); } catch (e) { sec.loadError = "Couldn't read the keys"; }
                // a change just made: its row has its new key now, so what it did goes under it
                if (sec.after) {
                    const a = sec.after; sec.after = null; sec.at = a.at; sec.note = a.note;
                    if (sec.holdN !== "" && a.at) { sec.holdN = sec.norm(a.at); const d = sec.slotOf(sec.holdN); if (d) sec.held(d); holdOff.restart(); }
                } else sec.holdN = "";
                sec.busy = false;
            }
        }
    }
    Process {
        id: writer
        stdout: StdioCollector {
            onStreamFinished: {
                let d = null;
                try { d = JSON.parse(text); } catch (e) {}
                const plan = sec.plan;
                sec.plan = null;
                if (d && d.ok) {
                    sec.after = { at: plan.then !== undefined ? plan.then : plan.at, note: plan.note || "" };
                    if (plan.done) plan.done();
                } else sec.error = d && d.error ? d.error : "That didn't work, so nothing changed";
                sec.load();
            }
        }
    }
    // Replacing takes the other shortcut's row away. When that's above the row being changed,
    // everything under it moves up, that row too (out from under the pointer): the list is
    // scrolled by as much, so the row stays where it is on screen.
    property string holdN: ""           // the row to hold still (its key, as norm has it)
    property real holdY: 0              // where it is on screen: its place in the list less the scroll
    function scroller() { for (let p = sec.parent; p; p = p.parent) if (p.contentY !== undefined && p.contentHeight !== undefined) return p; return null; }
    function slotOf(kN) { for (const c of sec.children) if (c.keyN !== undefined && c.keyN === kN && c.visible) return c; return null; }
    function hold(k) { const f = scroller(), d = k ? slotOf(norm(k)) : null; holdN = f && d ? norm(k) : ""; if (holdN !== "") holdY = d.y - f.contentY; }
    function held(d) { const f = scroller(); if (!f) return; const y = Math.max(0, d.y - holdY); if (Math.abs(y - f.contentY) > 0.5) f.contentY = y; }
    Timer { id: holdOff; interval: 400; onTriggered: sec.holdN = "" }
    property var plan: null             // the change being made (see run)
    property var after: null            // what to say once the keys are read again: { at, note }
    // One change: keys.py's arguments, and `o`: `at` (the row it's made on, where an error
    // shows), `then` (the row's key afterwards, if it changes), `note` (said there when it
    // worked), `done` (called when it worked). Rows stay as they are until the keys are read again.
    function run(args, o) {
        busy = true; clash = null; error = ""; note = "";
        at = o.at; after = null; plan = o;
        hold(o.then ? o.at : "");
        writer.command = ["python3", script].concat(args);
        writer.running = true;
    }
    // the same key, however it's written ("Super+Shift+s" / "Shift+Super+S")
    function norm(k) {
        const p = String(k).split("+");
        const order = ["Super", "Ctrl", "Alt", "Shift"];
        const mods = p.slice(0, -1).map(m => m.charAt(0).toUpperCase() + m.slice(1).toLowerCase()).sort((a, b) => order.indexOf(a) - order.indexOf(b));
        return mods.concat([String(p[p.length - 1]).toLowerCase()]).join("+");
    }
    function pretty(k) { return String(k).replace(/_/g, " ").replace(/\+/g, " + "); }
    // a row's key was clicked ("+": the new shortcut's): wait for the new key, or stop waiting
    function pick(k) {
        if (busy) return;
        const stop = recording === k;
        clash = null; error = ""; note = "";
        at = k;
        recording = stop ? "" : k;
    }
    // a key was pressed while picking: use it, or ask first when another shortcut has it
    function picked(k) {
        const from = recording;
        recording = "";
        clash = null; error = ""; note = "";
        at = from;
        if (from !== "+" && norm(from) === norm(k)) return;            // the same key again: nothing to do
        const other = items.find(it => norm(it.key) === norm(k) && (from === "+" || norm(it.key) !== norm(from)));
        if (other) { clash = { key: k, other: other, from: from }; return; }
        use(from, k, null);
    }
    // `from` gets the key `k`; `other`: the shortcut that has it now and loses it (keys.py does
    // both in one step, so a change that isn't accepted leaves both as they were)
    function use(from, k, other) {
        if (from === "+") {
            // (a new shortcut is only made by Add: until then the other one keeps its key)
            newKey = k; newReplaces = other !== null;
            if (other) note = "\u201c" + other.title + "\u201d loses " + pretty(k) + " when you press Add";
            return;
        }
        run(["change", from, k].concat(other ? ["--replace"] : []),
            { at: from, then: k, note: other ? "\u201c" + other.title + "\u201d has no key now" : "" });
    }
    function replace() {
        const c = clash; clash = null;
        if (c) use(c.from, c.key, c.other);
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
        [Qt.Key_QuoteLeft]: "Grave", [Qt.Key_Pause]: "Pause", [Qt.Key_ScrollLock]: "Scroll_Lock", [Qt.Key_Menu]: "Menu",
        // the media keys (they were ignored: a volume key couldn't be given another job)
        [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume", [Qt.Key_VolumeDown]: "XF86AudioLowerVolume", [Qt.Key_VolumeMute]: "XF86AudioMute",
        [Qt.Key_MicMute]: "XF86AudioMicMute", [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay",
        [Qt.Key_MediaPause]: "XF86AudioPause", [Qt.Key_MediaStop]: "XF86AudioStop", [Qt.Key_MediaNext]: "XF86AudioNext",
        [Qt.Key_MediaPrevious]: "XF86AudioPrev", [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp", [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown",
        [Qt.Key_Calculator]: "XF86Calculator", [Qt.Key_Search]: "XF86Search", [Qt.Key_HomePage]: "XF86HomePage", [Qt.Key_LaunchMail]: "XF86Mail"
    })
    readonly property var modKeys: [Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R, Qt.Key_AltGr]
    function keyName(e) {
        if (modKeys.indexOf(e.key) >= 0) return "";
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
            if (e.key === Qt.Key_Escape && e.modifiers === Qt.NoModifier) { sec.recording = ""; sec.error = ""; return; }
            const k = sec.keyName(e);
            // (a key with no name here: say so, instead of looking as if nothing was pressed)
            if (!k) { if (sec.modKeys.indexOf(e.key) < 0) { sec.at = sec.recording; sec.error = "That key can't be used for a shortcut here: press another (Esc cancels)"; } return; }
            sec.picked(k);
        }
        // The keys went somewhere else (a click into the search box, another window): stop
        // waiting. It kept showing "Press a key…" with nothing able to arrive, and on Hyprland
        // every shortcut stayed held back for the 30 seconds. (After a moment: focus that's back
        // at once, as when the compositor's shortcuts are taken hold of, isn't a reason.)
        onActiveFocusChanged: { if (!activeFocus && sec.recording !== "") lostFocus.restart(); else lostFocus.stop(); }
        Timer { id: lostFocus; interval: 600; onTriggered: if (!catcher.activeFocus) sec.recording = "" }
    }
    onRecordingChanged: if (recording !== "") catcher.forceActiveFocus(); else lostFocus.stop()
    // while picking, every key comes here, even ones niri / Hyprland use for themselves (it asks
    // the compositor to hold its own shortcuts back): those never arrived, so pressing one did nothing
    ShortcutInhibitor {
        window: sec.Window.window
        enabled: sec.recording !== ""
    }
    // Hyprland doesn't hold its shortcuts back for the shell's own panels (the inhibitor above is
    // for windows there), so pressing a key it used ran that instead, and you never got asked
    // about the clash. While picking, it's put in an empty keymap of its own ("submap": just
    // Super+Escape to leave it), then back to the usual one: on a key, on Esc, when this page
    // goes, and after 30 seconds whatever happens
    readonly property bool hyprHold: Niri.hyprland && recording !== ""
    onHyprHoldChanged: {
        if (hyprHold) {
            Quickshell.execDetached(["hyprctl", "eval", 'hl.define_submap("monolith-keys", function() hl.bind("SUPER + Escape", hl.dsp.submap("reset")) end); hl.dispatch(hl.dsp.submap("monolith-keys"))']);
            hyprRelease.restart();
        } else hyprBack();
    }
    function hyprBack() { hyprRelease.stop(); if (Niri.hyprland) Quickshell.execDetached(["hyprctl", "eval", 'hl.dispatch(hl.dsp.submap("reset"))']); }
    Timer { id: hyprRelease; interval: 30000; onTriggered: { sec.recording = ""; sec.hyprBack(); } }
    Component.onDestruction: if (hyprHold) hyprBack()
    // (the menu closed while waiting for a key: stop waiting, the shortcuts come back)
    Connections { target: HubState; function onOpenChanged() { if (!HubState.open) sec.recording = ""; } }

    Label {
        Layout.fillWidth: true; wrapMode: Text.Wrap; muted: true
        text: (sec.group === "" ? "Every keyboard shortcut, and what it does; the tabs show them by purpose. " : "") + "Click a key to change it, then press the new one (Esc cancels)."
            + (Niri.hyprland ? " On Hyprland your changes stay after updates. Keys in your own my-keys file (~/.config/hypr/monolith/my-keys) are changed there." : " niri checks every change; one it doesn't accept is undone.")
    }
    Label { visible: sec.loadError !== ""; Layout.fillWidth: true; wrapMode: Text.Wrap; text: sec.loadError; color: Theme.danger }

    // What's said under a row (see `at`): the key is taken (Replace, another key, or leave it), a
    // change that didn't work, or what a change did.
    Component {
        id: saidC
        SmoothRect {
            smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
            implicitHeight: saidCol.implicitHeight + 24
            radius: Theme.corner(56, 10)
            color: Theme.containerHigh
            border.width: 1; border.color: Qt.alpha(sec.clash !== null || sec.error !== "" ? Theme.danger : Theme.accent, 0.6)
            opacity: 0
            Component.onCompleted: opacity = 1
            Behavior on opacity { NumberAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
            ColumnLayout {
                id: saidCol
                x: 14; y: 12; width: parent.width - 28
                spacing: 8
                Label {
                    Layout.fillWidth: true; wrapMode: Text.Wrap; strong: true
                    color: sec.clash === null && sec.error !== "" ? Theme.danger : Theme.text
                    text: sec.clash ? sec.pretty(sec.clash.key) + " is already used in \u201c" + sec.clash.other.title + "\u201d"
                        : sec.error !== "" ? sec.error : sec.note
                }
                Label {
                    visible: sec.clash !== null
                    Layout.fillWidth: true; wrapMode: Text.Wrap; muted: true
                    text: !sec.clash ? "" : sec.clash.other.mine
                        ? "That shortcut is in your own config (" + sec.clash.other.section + "), so it can't be replaced from here: change it there, or pick another key."
                        : "It's under " + sec.clash.other.section + ". Replace it? \u201c" + sec.clash.other.title + "\u201d will have no key then."
                }
                RowLayout {
                    visible: sec.clash !== null
                    spacing: 8
                    Button { visible: sec.clash !== null && !sec.clash.other.mine; text: "Replace"; primary: true; enabled: !sec.busy; onClicked: sec.replace() }
                    Button { text: "Pick another key"; onClicked: { const f = sec.clash.from; sec.clash = null; sec.recording = f; } }
                    Button { text: "Cancel"; onClicked: sec.clash = null }
                }
            }
        }
    }

    // add one
    SettingRow {
        id: addRow
        show: sec.group === "" || sec.group === "apps"
        Layout.fillWidth: true
        icon: "add"
        title: "Add a shortcut"
        desc: "A key that runs a program or command"
        RowLayout {
            id: addCtl
            spacing: 8
            // what the row has beside its name (150 kept for that): a long key gets smaller text
            // first, then the command field narrows. The key used to widen over the field.
            readonly property real room: Math.max(330, addRow.width - 62 - 150 - 26)
            Button {
                id: pickB
                text: sec.recording === "+" ? "Press a key…" : sec.newKey !== "" ? sec.pretty(sec.newKey) : "Pick a key"
                primary: sec.recording === "+"
                maxWidth: Math.max(96, addCtl.room - 110 - addB.width - 16)
                enabled: !sec.busy
                onClicked: sec.pick("+")
            }
            Field { id: cmd; Layout.preferredWidth: Math.max(110, Math.min(200, addCtl.room - pickB.width - addB.width - 16)); placeholder: "Command, e.g. firefox" }
            Button {
                id: addB
                text: "Add"; primary: true
                enabled: sec.newKey !== "" && cmd.text.trim() !== "" && !sec.busy
                // (the key and the command stay in the row until it's really added)
                onClicked: sec.run(["add", sec.newKey, JSON.stringify({ type: "app", cmd: cmd.text.trim() })].concat(sec.newReplaces ? ["--replace"] : []),
                    { at: "+", note: sec.pretty(sec.newKey) + " now runs " + cmd.text.trim(), done: () => { sec.newKey = ""; sec.newReplaces = false; cmd.text = ""; } })
            }
        }
    }
    Loader {
        Layout.fillWidth: true
        active: sec.said && sec.at === "+" && addRow.show
        visible: active
        sourceComponent: saidC
    }
    Field { id: search; visible: sec.group === ""; Layout.fillWidth: true; placeholder: "Search keys or what they do"; onTextChanged: sec.filter = text.toLowerCase() }

    Repeater {
        // (a count, not the list: a new list after every change remade every row. And a count
        // that only grows, a batch at a time: a Repeater remakes every row when its number
        // changes too, so removing or adding one key did just that. Rows past the last key are
        // empty and hidden.)
        model: sec.slots
        delegate: Column {
            id: slotD
            required property int index
            readonly property var modelData: sec.items[index] || ({ key: "", label: "", title: "", action: "", section: "", mine: false })
            readonly property var v: sec.view[index] || ({ show: false, head: false })
            readonly property string keyN: sec.norm(modelData.key)
            onYChanged: if (sec.holdN !== "" && keyN === sec.holdN) sec.held(slotD)
            // the shortcut that has the key just pressed for another one
            readonly property bool taken: sec.clash !== null && sec.clash.other.key === modelData.key
            Layout.fillWidth: true
            visible: v.show
            spacing: 8
            Loader {
                width: parent.width
                active: slotD.v.head
                // (a Loader keeps its last height when it empties: a row that stopped being its
                // section's first, as rows move up after a removal, kept a heading's gap)
                visible: active
                height: active ? 36 : 0
                // (its size, as a layout gives it: 32 high, 4 above)
                sourceComponent: Component { Item { implicitHeight: 36; SectionHead { y: 4; width: parent.width; height: 32; text: slotD.modelData.section } } }
            }
            Loader {
                width: parent.width
                active: sec.built[slotD.index] === true
                sourceComponent: Component {
                    SettingRow {
                        id: keyRow
                        icon: "keyboard"
                        title: slotD.modelData.title
                        desc: slotD.modelData.action.length > 70 ? slotD.modelData.action.slice(0, 70) + "…" : slotD.modelData.action
                        RowLayout {
                            spacing: 6
                            Button {
                                text: sec.recording === slotD.modelData.key ? "Press a key…" : slotD.modelData.label
                                primary: sec.recording === slotD.modelData.key
                                // (a long key: its text gets smaller before the shortcut's name
                                // has less than about 170 px; it never reaches the next button)
                                maxWidth: Math.max(120, keyRow.width - 300)
                                color: slotD.taken ? Theme.mix(Theme.control, Theme.danger, 0.45) : primary ? Theme.accent : Theme.control
                                enabled: !slotD.modelData.mine && !sec.busy
                                onClicked: sec.pick(slotD.modelData.key)
                            }
                            Button {
                                icon: "delete"; minWidth: 40
                                enabled: !slotD.modelData.mine && !sec.busy
                                onClicked: sec.run(["remove", slotD.modelData.key], { at: slotD.modelData.key, then: "" })
                            }
                        }
                    }
                }
            }
            // what's said about this key (taken, not accepted, done)
            Loader {
                width: parent.width
                active: sec.said && sec.atN === slotD.keyN
                visible: active
                height: item ? item.implicitHeight : 0
                sourceComponent: saidC
            }
        }
    }
    Label {
        visible: sec.items.length > 0 && sec.shownCount === 0
        Layout.fillWidth: true; muted: true; wrapMode: Text.Wrap
        text: sec.filter ? "Nothing matches." : "No shortcuts here."
    }
}
