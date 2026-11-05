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
    SettingRow { icon: "keyboard"; title: "Keys"; desc: "Print: the capture menu (freezes the screen; pick an area, then save, copy, edit, read the text or a QR code, or record it)  ·  Ctrl+Print: the whole screen at once  ·  Shift+Print: the menu, Enter opens the editor  ·  Alt+Print: the whole screen in the menu, Enter opens the editor" }
    SettingRow { icon: "ads_click"; title: "In the menu"; desc: "Drag: an area  ·  drag inside it: move  ·  corners: resize  ·  F: whole screen  ·  Tab: photo / video  ·  Enter: save (or record)  ·  Ctrl+C: copy  ·  E: edit  ·  T: text  ·  Q: QR code  ·  Esc: cancel" }
}
