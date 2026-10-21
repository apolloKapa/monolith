import QtQuick
import QtQuick.Layouts
import Quickshell
import "../"
import "../reusables"
import "../reusables/guide"

// Settings -> Screenshots: the screenshot tool's keys. Stored as screenshot.keys; after a change
// niri_screenshot_keys.sh lets keys that niri already binds (like Meta+C) reach the tool.
GuideTab {
    id: shotTab

    readonly property var actions: [
        { id: "capture", icon: "󰄀", title: "Capture", desc: "Save the screenshot and copy it", def: "Return" },
        { id: "copy", icon: "󰆏", title: "Copy only", desc: "Copy to the clipboard without saving", def: "Meta+C" },
        { id: "edit", icon: "󰏫", title: "Edit", desc: "Open the selection in the editor", def: "Ctrl+E" },
        { id: "cancel", icon: "󰅖", title: "Cancel", desc: "Close the screenshot tool", def: "Escape" },
        { id: "mode", icon: "󰕧", title: "Photo / video", desc: "Switch between screenshot and recording", def: "Tab" },
        { id: "maximize", icon: "󰊓", title: "Whole screen", desc: "Select the whole screen", def: "F11" }
    ]

    property var keys: ({})
    property string editing: ""          // action being edited
    property var editMods: []            // modifiers picked in the editor
    property string editKey: ""          // key pressed in the editor

    function load() {
        const saved = (Config.getSetting("screenshot", {}).keys) || {};
        let k = {};
        for (const a of actions) k[a.id] = saved[a.id] || a.def;
        keys = k;
    }

    function save(id, seq) {
        let k = Object.assign({}, keys);
        k[id] = seq;
        keys = k;
        Config.setSetting("screenshot", Object.assign({}, Config.getSetting("screenshot", {}), { "keys": k }));
        if (Caching.monolithDir)
            Quickshell.execDetached(["bash", Caching.monolithDir + "/scripts/niri_screenshot_keys.sh"]);
    }

    function startEdit(id) {
        const parts = String(keys[id] || "").split("+");
        editKey = parts.length ? parts[parts.length - 1] : "";
        editMods = parts.slice(0, -1);
        editing = id;
    }

    function toggleMod(m) {
        let mods = editMods.slice();
        const i = mods.indexOf(m);
        if (i >= 0) mods.splice(i, 1); else mods.push(m);
        // keep a stable order: Meta, Ctrl, Alt, Shift
        editMods = ["Meta", "Ctrl", "Alt", "Shift"].filter(x => mods.indexOf(x) >= 0);
    }

    function editedSequence() {
        return editKey === "" ? "" : editMods.concat([editKey]).join("+");
    }

    // a Qt key code to the name used in key sequences
    function keyName(event) {
        const k = event.key;
        if (k >= Qt.Key_A && k <= Qt.Key_Z) return String.fromCharCode(k);
        if (k >= Qt.Key_0 && k <= Qt.Key_9) return String.fromCharCode(k);
        if (k >= Qt.Key_F1 && k <= Qt.Key_F24) return "F" + (k - Qt.Key_F1 + 1);
        const named = {};
        named[Qt.Key_Return] = "Return"; named[Qt.Key_Enter] = "Return"; named[Qt.Key_Escape] = "Escape";
        named[Qt.Key_Tab] = "Tab"; named[Qt.Key_Backspace] = "Backspace"; named[Qt.Key_Delete] = "Delete";
        named[Qt.Key_Space] = "Space"; named[Qt.Key_Left] = "Left"; named[Qt.Key_Right] = "Right";
        named[Qt.Key_Up] = "Up"; named[Qt.Key_Down] = "Down"; named[Qt.Key_Print] = "Print";
        named[Qt.Key_Home] = "Home"; named[Qt.Key_End] = "End"; named[Qt.Key_PageUp] = "PgUp";
        named[Qt.Key_PageDown] = "PgDown"; named[Qt.Key_Insert] = "Ins";
        if (named[k]) return named[k];
        const t = event.text;
        return (t && t.trim() !== "") ? t.toUpperCase() : "";
    }

    function isModifierOnly(k) {
        return k === Qt.Key_Shift || k === Qt.Key_Control || k === Qt.Key_Alt || k === Qt.Key_Meta
            || k === Qt.Key_Super_L || k === Qt.Key_Super_R || k === Qt.Key_AltGr;
    }

    Component.onCompleted: load()
    Connections {
        target: Config
        function onSettingsLoaded() { shotTab.load(); }
    }

    component KeyChip: Rectangle {
        id: chip
        property string label: ""
        property bool active: false
        property bool accent: false
        signal clicked()
        implicitWidth: chipText.implicitWidth + rootObj.s(18)
        implicitHeight: rootObj.s(30)
        radius: ThemeBackend.borderRadius
        color: active ? ThemeBackend.mauve : (chipMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
        border.width: 1
        border.color: accent ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface2, 0.6)
        Behavior on color { ColorAnimation { duration: 120 * ThemeBackend.animScale } }
        Text {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            color: chip.active ? ThemeBackend.crust : ThemeBackend.text
            font.family: ThemeBackend.fontFamily
            font.pixelSize: rootObj.s(12)
            font.bold: chip.active
        }
        MouseArea {
            id: chipMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: col.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: col
            width: parent.width
            spacing: rootObj.s(6)

            SettingsBlob {
                Layout.fillWidth: true

                Text {
                    Layout.fillWidth: true
                    Layout.margins: rootObj.s(12)
                    wrapMode: Text.WordWrap
                    text: "Keys used while the screenshot tool is open (Print, Shift+Print, Mod+Shift+S...). "
                        + "Click a shortcut to change it: pick the modifiers, then press the key. "
                        + "Keys niri already uses, like Meta+C for the terminal, still do their normal thing "
                        + "when the screenshot tool isn't open."
                    color: ThemeBackend.subtext0
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(12)
                }
            }

            SettingsBlob {
                Layout.fillWidth: true

                Repeater {
                    model: shotTab.actions

                    ColumnLayout {
                        id: actionCol
                        required property var modelData
                        readonly property bool open: shotTab.editing === modelData.id
                        Layout.fillWidth: true
                        spacing: 0

                        SettingsRow {
                            Layout.fillWidth: true
                            rootObj: shotTab.rootObj
                            settingId: "screenshot_key_" + actionCol.modelData.id
                            icon: actionCol.modelData.icon
                            title: actionCol.modelData.title
                            description: actionCol.modelData.desc
                            searchKeywords: "screenshot key shortcut keybind " + actionCol.modelData.title.toLowerCase()

                            KeyChip {
                                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                                label: shotTab.keys[actionCol.modelData.id] || "-"
                                accent: actionCol.open
                                onClicked: actionCol.open ? (shotTab.editing = "") : shotTab.startEdit(actionCol.modelData.id)
                            }
                        }

                        // inline editor: modifiers + "press a key"
                        Item {
                            Layout.fillWidth: true
                            clip: true
                            implicitHeight: actionCol.open ? editorRow.implicitHeight + rootObj.s(16) : 0
                            visible: implicitHeight > 0.5
                            Behavior on implicitHeight { NumberAnimation { duration: 180 * ThemeBackend.animScale; easing.type: Easing.OutCubic } }

                            RowLayout {
                                id: editorRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.leftMargin: rootObj.s(52)
                                anchors.rightMargin: rootObj.s(12)
                                spacing: rootObj.s(6)

                                Repeater {
                                    model: ["Meta", "Ctrl", "Alt", "Shift"]
                                    KeyChip {
                                        required property string modelData
                                        label: modelData
                                        active: shotTab.editMods.indexOf(modelData) >= 0
                                        onClicked: shotTab.toggleMod(modelData)
                                    }
                                }

                                Text { text: "+"; color: ThemeBackend.subtext0; font.pixelSize: rootObj.s(13) }

                                KeyChip {
                                    id: keyGrab
                                    label: activeFocus ? "press a key…" : (shotTab.editKey || "click, then press a key")
                                    accent: activeFocus
                                    onClicked: forceActiveFocus()
                                    Keys.onPressed: function(event) {
                                        if (shotTab.isModifierOnly(event.key)) return;
                                        const name = shotTab.keyName(event);
                                        if (name !== "") shotTab.editKey = name;
                                        event.accepted = true;
                                        keyGrab.focus = false;
                                    }
                                }

                                Item { Layout.fillWidth: true }

                                KeyChip {
                                    label: "Default"
                                    onClicked: {
                                        shotTab.save(actionCol.modelData.id, actionCol.modelData.def);
                                        shotTab.editing = "";
                                    }
                                }
                                KeyChip {
                                    label: "Save " + (shotTab.editedSequence() || "")
                                    active: shotTab.editedSequence() !== ""
                                    onClicked: {
                                        if (shotTab.editedSequence() === "") return;
                                        shotTab.save(actionCol.modelData.id, shotTab.editedSequence());
                                        shotTab.editing = "";
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
