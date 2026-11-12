import QtQuick
import QtQuick.Layouts
import Quickshell
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
        key: "wallpaper.dir";
        icon: "folder"; title: "Wallpaper folder"; desc: "Where the wallpaper picker looks"
        Field { text: Wall.dir; onAccepted: v => { if (v.trim() !== "" && v.trim() !== Wall.dir) Store.set("wallpaper.dir", v.trim()); } }
    }
    SettingRow {
        icon: "wallpaper"; title: "Pick a wallpaper"; desc: Wall.images.length + " pictures and videos, for every screen"
        Button { text: "Open"; primary: true; onClicked: { Wall.aim = ""; HubState.show("wallpaper"); } }
    }
    // each screen can have its own (picture or live); else it shows the one above
    Repeater {
        model: Quickshell.screens.length > 1 ? Quickshell.screens : []
        SettingRow {
            id: sr
            required property var modelData
            readonly property string own: Store.get("wallpaper.screens." + modelData.name.replace(/\./g, "_"), "") || ""
            icon: "monitor"; title: modelData.name + " (" + modelData.width + "×" + modelData.height + ")"
            desc: own !== "" ? "Its own: " + own.replace(/^.*\//, "") : "Same as every screen"
            RowLayout {
                spacing: 6
                Button { visible: sr.own !== ""; text: "Use the shared one"; onClicked: Wall.setFor(sr.modelData.name, "") }
                Button { text: "Pick"; onClicked: { Wall.aim = sr.modelData.name; HubState.show("wallpaper"); } }
            }
        }
    }
}
