import QtQuick
import "../core"
import "../ui"

// The desktop's widgets on this screen, where the widget editor put them
// (Settings → Desktop → Edit the desktop, or `monolith widgets`).
Item {
    id: desk
    anchors.fill: parent
    property string screenName: ""
    readonly property var list: WidgetLayout.on("desktop", screenName)
    // hidden while the editor shows its own copy
    visible: HubState.editWidgets === ""

    Repeater {
        model: desk.list
        WidgetFace {
            required property var modelData
            type: modelData.type
            face: modelData.face || ""
            scale: modelData.scale || 1
            transformOrigin: Item.TopLeft
            x: Math.max(0, Math.min(modelData.x * desk.width, desk.width - width * scale))
            y: Math.max(0, Math.min(modelData.y * desk.height, desk.height - height * scale))
        }
    }
}
