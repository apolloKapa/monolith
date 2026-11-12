import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Screenshots: where niri saves them (its screenshot-path), and the keys.
ColumnLayout {
    id: sec
    spacing: 8
    property string path: ""
    Component.onCompleted: NiriConf.read(["-|screenshot-path"], v => sec.path = NiriConf.unquote(v["-|screenshot-path"]))
    readonly property string folder: path.replace(/\/[^\/]*$/, "")
    readonly property string pattern: path.replace(/^.*\//, "")

    SettingRow {
        icon: "folder"; title: "Screenshot folder"; desc: "niri saves screenshots here (and copies them)"
        Field {
            text: sec.folder
            placeholder: "~/Pictures/Screenshots"
            onAccepted: v => {
                const f = v.trim().replace(/\/$/, "");
                if (f === "" || f === sec.folder) return;
                sec.path = f + "/" + (sec.pattern || "Screenshot_%Y%m%d_%H%M%S.png");
                NiriConf.set("-", "screenshot-path", NiriConf.quote(sec.path));
            }
        }
    }
    // reading text (T in the capture menu): which languages tesseract looks for
    property var langs: []
    readonly property var picked: Store.get("capture.ocr", "eng").split("+")
    Process {
        running: true
        command: ["sh", "-c", "tesseract --list-langs 2>/dev/null | tail -n +2"]
        stdout: StdioCollector { onStreamFinished: sec.langs = text.split("\n").filter(l => l && l !== "osd") }
    }
    SettingRow {
        key: "capture.onRelease"; def: false;
        icon: "ads_click"; title: "Take it when you let go"; desc: "A drawn area is saved and copied (or opened in the editor with Shift+Print) as soon as you release the mouse, without Enter"
        Toggle { checked: Capture.onRelease; onToggled: on => Store.set("capture.onRelease", on) }
    }
    // ── after a shot ──
    SettingRow {
        key: "capture.preview"; def: true;
        icon: "picture_in_picture"; title: "Preview after a shot"; desc: "A small card in a corner for a few seconds: edit, copy, pin, open its folder or delete it. Off: a notification"
        Toggle { checked: Capture.previewOn; onToggled: on => Store.set("capture.preview", on) }
    }
    SettingRow {
        key: "capture.previewCorner"; def: "bottom-right";
        visible: Capture.previewOn
        icon: "position_bottom_right"; title: "Preview corner"
        Dropdown {
            opts: [["bottom-right", "Bottom right"], ["bottom-left", "Bottom left"], ["top-right", "Top right"], ["top-left", "Top left"]]
            value: Store.get("capture.previewCorner", "bottom-right")
            onPicked: v => Store.set("capture.previewCorner", v)
        }
    }
    SettingRow {
        key: "capture.previewTime"; def: 6;
        visible: Capture.previewOn
        icon: "timer"; title: "Preview stays for"; desc: "The pointer on it keeps it"
        NumberBox { from: 2; to: 60; slideTo: 20; unit: " s"; value: Number(Store.get("capture.previewTime", 6)); onMoved: v => Store.set("capture.previewTime", v) }
    }
    SettingRow {
        key: "capture.copyOnSave"; def: true;
        icon: "content_paste"; title: "Copy when saving"; desc: "Saved screenshots go on the clipboard too"
        Toggle { checked: Capture.copyOnSave; onToggled: on => Store.set("capture.copyOnSave", on) }
    }
    SettingRow {
        key: "capture.format"; def: "png";
        icon: "image"; title: "File type"; desc: Capture.format === "png" ? "PNG: exact, bigger files" : Capture.format === "jpg" ? "JPEG: small, slightly blurry text" : "WebP: small and sharp"
        Segmented { width: 220; opts: [["png", "PNG"], ["jpg", "JPEG"], ["webp", "WebP"]]; value: Capture.format; onPicked: v => Store.set("capture.format", v) }
    }
    SettingRow {
        key: "capture.quality"; def: 92;
        visible: Capture.format !== "png"
        icon: "high_quality"; title: "Quality"
        NumberBox { from: 40; to: 100; unit: "%"; value: Capture.quality; onMoved: v => Store.set("capture.quality", v) }
    }
    SettingRow {
        key: "capture.editor"; def: "builtin";
        icon: "edit"; title: "Editor"; desc: Capture.editor === "builtin" ? "Monolith's own: pen, highlighter, arrows, boxes, text, numbered steps, pixelate and crop" : "Opens in " + Capture.editor
        Segmented { width: 260; opts: [["builtin", "Monolith"], ["satty", "Satty"], ["swappy", "Swappy"]]; value: Capture.editor; onPicked: v => Store.set("capture.editor", v) }
    }
    // ── which tools the capture menu has ──
    SettingRow { key: "capture.tools"; icon: "handyman"; title: "Tools in the capture menu"; desc: "Save is always there; the ones switched off lose their key too" }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: toolFlow.implicitHeight + 20
        radius: Theme.corner(56, 2)
        color: Theme.containerHigh
        Flow {
            id: toolFlow
            x: 10; y: 10; width: parent.width - 20; spacing: 6
            Repeater {
                model: [["copy", "content_copy", "Copy  (Ctrl+C)"], ["edit", "edit", "Edit  (E)"], ["pin", "push_pin", "Pin on screen  (P)"], ["text", "document_scanner", "Read text  (T)"], ["qr", "qr_code_scanner", "QR code  (Q)"]]
                Pressable {
                    required property var modelData
                    readonly property bool on: Capture.toolOn(modelData[0])
                    height: 36; width: tr.implicitWidth + 28
                    color: on ? Theme.accentContainer : Theme.control
                    onClicked: { const t = Object.assign({}, Store.get("capture.tools", ({})) || ({})); t[modelData[0]] = !on; Store.set("capture.tools", t); }
                    Row {
                        id: tr; anchors.centerIn: parent; spacing: 6
                        Icon { name: parent.parent.on ? "check" : parent.parent.modelData[1]; size: 17; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: parent.parent.modelData[2]; strong: parent.parent.on; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
    SettingRow {
        key: "capture.delay"; def: 0;
        icon: "timer_3"; title: "Delay in the Capture page"; desc: "Region and Screen there wait this long first (a menu that has to be open). Also: monolith capture-in <seconds>"
        Segmented { width: 260; opts: [["0", "None"], ["3", "3 s"], ["5", "5 s"], ["10", "10 s"]]; value: String(Store.get("capture.delay", 0)); onPicked: v => Store.set("capture.delay", Number(v)) }
    }
    SettingRow {
        visible: Capture.pins.length > 0
        icon: "push_pin"; title: Capture.pins.length + (Capture.pins.length === 1 ? " pinned shot" : " pinned shots"); desc: "Double-click one to let it go"
        Button { text: "Unpin all"; onClicked: Capture.pins = [] }
    }
    SettingRow { icon: "translate"; title: "Text languages"; desc: "What reading text looks for (more is slower). Others come with tesseract's language packs" }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: langFlow.implicitHeight + 20
        radius: Theme.corner(56, 2)
        color: Theme.containerHigh
        Flow {
            id: langFlow
            x: 10; y: 10; width: parent.width - 20; spacing: 6
            Repeater {
                model: sec.langs
                Pressable {
                    required property string modelData
                    readonly property bool on: sec.picked.indexOf(modelData) !== -1
                    height: 32; width: ll.implicitWidth + 24
                    color: on ? Theme.accentContainer : Theme.control
                    onClicked: {
                        let p = sec.picked.filter(x => x !== modelData);
                        if (!on) p = p.concat([modelData]);
                        if (p.length > 0) Store.set("capture.ocr", p.join("+"));
                    }
                    Label { id: ll; anchors.centerIn: parent; text: parent.modelData; strong: parent.on; font.pixelSize: Theme.sizeSmall }
                }
            }
        }
    }
    SettingRow { icon: "videocam"; title: "Recordings"; desc: "Screen recordings go to " + Tasks.recDir + ". While one runs, the island at the top shows it; click it to stop." }
    SettingRow { icon: "keyboard"; title: "Keybinds"; desc: "Print: the capture menu (freezes the screen; pick an area, then save, copy, edit, read the text or a QR code, or record it)  ·  Ctrl+Print: the whole screen at once  ·  Shift+Print: the menu, Enter opens the editor  ·  Alt+Print: the whole screen in the menu, Enter opens the editor" }
    SettingRow { icon: "ads_click"; title: "In the capture menu"; desc: "Drag: an area  ·  drag inside it: move  ·  corners: resize  ·  F: whole screen  ·  Tab: photo / video  ·  Enter: save (or record)  ·  Ctrl+C: copy  ·  E: edit  ·  P: pin  ·  T: text  ·  Q: QR code  ·  Esc: cancel" }
}
