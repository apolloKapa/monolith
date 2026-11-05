import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    // the wallpaper now, at the screen's shape
    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: width * 9 / 16 * 0.62
        radius: Theme.corner(80, 6)
        color: Theme.container
        clip: true
        Image {
            anchors.fill: parent
            source: Wall.path !== "" && !Wall.isVideo(Wall.path) ? Wall.url(Wall.path) : ""
            sourceSize.width: 1200
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Rectangle {
            anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 12
            width: wn.implicitWidth + 20; height: 28; radius: 14
            color: Qt.alpha(Theme.frame, 0.85)
            Label { id: wn; anchors.centerIn: parent; text: Wall.path.replace(/^.*\//, "") || "No wallpaper"; font.pixelSize: Theme.sizeSmall }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: HubState.show("wallpaper") }
    }
    SettingRow {
        icon: "folder"; title: "Folder"; desc: "Where the wallpaper picker looks"
        Field { text: Wall.dir; onAccepted: v => { if (v.trim() !== "" && v.trim() !== Wall.dir) Store.set("wallpaper.dir", v.trim()); } }
    }
    SettingRow {
        icon: "wallpaper"; title: "Pick a wallpaper"; desc: Wall.images.length + " pictures and videos. Right-click one there to set it for one screen only"
        Button { text: "Open"; primary: true; onClicked: HubState.show("wallpaper") }
    }
}
