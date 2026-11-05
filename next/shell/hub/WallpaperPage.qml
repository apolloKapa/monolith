import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Wallpaper: the pictures in your wallpaper folder; picking one sets it everywhere and makes
// the shell's colours from it. Light / dark switches the palette's mode.
Page {
    id: page
    pageId: "wallpaper"
    implicitHeight: 520
    onCurrentChanged: if (current) Wall.rescan()

    RowLayout {
        id: head
        width: parent.width
        height: 44
        Label { Layout.leftMargin: 6; text: Wall.dir.replace(Wall.home, "~") + "   ·   right-click: only this screen"; muted: true; Layout.fillWidth: true }
        Rectangle {
            Layout.preferredWidth: 200
            Layout.preferredHeight: 40
            radius: Theme.corner(height)
            color: Theme.container
            Rectangle {
                y: 4
                x: Theme.modeName === "dark" ? 4 : parent.width / 2
                width: parent.width / 2 - 4
                height: parent.height - 8
                radius: Theme.corner(height)
                color: Theme.selected
                Behavior on x { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
            }
            Row {
                anchors.fill: parent
                anchors.margins: 4
                Repeater {
                    model: [["dark", "Dark", "dark_mode"], ["light", "Light", "light_mode"]]
                    Pressable {
                        required property var modelData
                        width: parent.width / 2
                        height: parent.height
                        color: "transparent"
                        onClicked: Store.set("theme.mode", modelData[0])
                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Icon { name: modelData[2]; size: 18; filled: Theme.modeName === modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                            Label { text: modelData[1]; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
            }
        }
    }

    GridView {
        id: grid
        y: head.height + 8
        width: parent.width
        height: page.implicitHeight - y
        clip: true
        cellWidth: width / 4
        cellHeight: cellWidth * 0.66
        model: Wall.images
        boundsBehavior: Flickable.StopAtBounds
        delegate: Item {
            id: cell
            required property string modelData
            readonly property bool isCurrent: modelData === Wall.pathFor(HubState.screenName !== "" ? HubState.screenName : Quickshell.screens[0].name)
            width: grid.cellWidth
            height: grid.cellHeight
            Pressable {
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.corner(height, 2)
                color: Theme.container
                clip: true
                onClicked: Wall.set(cell.modelData)
                // right-click: only the screen the hub is on
                onRightClicked: Wall.setFor(HubState.screenName !== "" ? HubState.screenName : Quickshell.screens[0].name, cell.modelData)
                Icon { anchors.centerIn: parent; visible: Wall.isVideo(cell.modelData); name: "movie"; size: 36; color: Theme.subtext }
                Image {
                    anchors.fill: parent
                    visible: !Wall.isVideo(cell.modelData)
                    source: Wall.isVideo(cell.modelData) ? "" : Wall.url(cell.modelData)
                    sourceSize: Qt.size(320, 200)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 240 } }
                }
                // the current one: an accent ring and a check bubble
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: cell.isCurrent ? 3 : 0
                    border.color: Theme.accent
                }
                Bubble { visible: cell.isCurrent; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8; size: 26; icon: "check"; on: true }
            }
        }
    }
}
