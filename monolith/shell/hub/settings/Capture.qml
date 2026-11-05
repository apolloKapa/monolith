import QtQuick
import QtQuick.Layouts
import Quickshell
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
    SettingRow { icon: "videocam"; title: "Recordings"; desc: "Screen recordings go to " + Tasks.recDir + ". While one runs, the island at the top shows it; click it to stop." }
    SettingRow { icon: "keyboard"; title: "Keys"; desc: "Print: the capture menu (freezes the screen; pick an area, then save, copy, edit, read the text or a QR code, or record it)  ·  Ctrl+Print: the whole screen at once  ·  Shift+Print: the menu, Enter opens the editor  ·  Alt+Print: the whole screen in the menu, Enter opens the editor" }
    SettingRow { icon: "ads_click"; title: "In the menu"; desc: "Drag: an area  ·  drag inside it: move  ·  corners: resize  ·  F: whole screen  ·  Tab: photo / video  ·  Enter: save (or record)  ·  Ctrl+C: copy  ·  E: edit  ·  T: text  ·  Q: QR code  ·  Esc: cancel" }
}
