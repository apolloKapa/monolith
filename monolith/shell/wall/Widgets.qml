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
            item: modelData
            width: size[0]
            height: size[1]
            backdrop: desk.backdrop
            x: Math.max(0, Math.min(modelData.x * desk.width, desk.width - width))
            y: Math.max(0, Math.min(modelData.y * desk.height, desk.height - height))
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
