import QtQuick
import "../../core"

// The welcome is its own full-screen tour now (apps/Welcome.qml); this section just opens it.
Item {
    Component.onCompleted: Qt.callLater(() => { HubState.close(); HubState.openWelcome(); })
}
