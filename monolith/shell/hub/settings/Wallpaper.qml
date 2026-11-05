import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "folder"; title: "Folder"; desc: "Where the wallpaper picker looks"
        Field { text: Wall.dir; onAccepted: v => { if (v.trim() !== "" && v.trim() !== Wall.dir) Store.set("wallpaper.dir", v.trim()); } }
    }
    SettingRow {
        icon: "wallpaper"; title: "Pick a wallpaper"; desc: Wall.images.length + " pictures and videos. Right-click one there to set it for one screen only"
        Button { text: "Open"; primary: true; onClicked: HubState.page = "wallpaper" }
    }
}
