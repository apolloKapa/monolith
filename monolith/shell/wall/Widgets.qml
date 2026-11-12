import QtQuick
import "../core"
import "../ui"

// The desktop's widgets on this screen, where the widget editor put them
// (Settings → Desktop → Edit the desktop, or `monolith widgets`).
Item {
    id: desk
    anchors.fill: parent
    property string screenName: ""
    property Item backdrop: null          // the wallpaper, for the widgets' glass
    readonly property var list: WidgetLayout.on("desktop", screenName)
    // hidden while the editor shows its own copy
    visible: HubState.editWidgets === ""

    // right-click on the empty desktop: the desktop menu
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.RightButton
        onClicked: mouse => HubState.openDeskMenu(desk.screenName, mouse.x, mouse.y, "")
    }
    Repeater {
        model: desk.list
        WidgetFace {
            required property var modelData
            item: WidgetLayout.fitted(modelData, desk.height)
            width: implicitWidth
            height: implicitHeight
            backdrop: desk.backdrop
            x: Math.max(0, Math.min(modelData.x * desk.width, desk.width - width))
            y: Math.max(0, Math.min(modelData.y * desk.height, desk.height - height))
            // drop a picture (from the file manager) on a picture widget: it shows that one
            DropArea {
                id: drop
                anchors.fill: parent
                enabled: parent.modelData.type === "image"
                onEntered: d => { d.accepted = d.hasUrls; }
                onDropped: d => { const f = Pictures.fromDrop(d.urls); if (f !== "") { WidgetLayout.setOpt("desktop", parent.modelData.id, "imagePath", f); d.accept(); } }
                Rectangle { anchors.fill: parent; visible: drop.containsDrag; radius: 12; color: Qt.alpha(Theme.accent, 0.18); border.width: 2; border.color: Theme.accent }
            }
            // right-click: this widget's menu (its style, the editor, remove)
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.RightButton
                onClicked: mouse => {
                    const p = mapToItem(desk, mouse.x, mouse.y);
                    HubState.openDeskMenu(desk.screenName, p.x, p.y, parent.modelData.id);
                }
            }
        }
    }
}
