import QtQuick
Rectangle {
    id: b
    property string label: ""
    property bool active: false
    signal clicked()
    implicitWidth: t.implicitWidth + 24
    implicitHeight: 28
    color: active ? "#ffffff" : (m.containsMouse ? "#2a2a2a" : "#111111")
    border.color: "#ffffff"
    border.width: 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Text {
        id: t
        anchors.centerIn: parent
        text: b.label
        color: b.active ? "#000000" : "#ffffff"
        font.family: "JetBrains Mono"
        font.pixelSize: 13
    }
    MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: b.clicked() }
}
