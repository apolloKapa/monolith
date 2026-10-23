import QtQuick
import "../../../"

// Time & Date, Seconds: hours and minutes, with the seconds ticking in the accent colour
Item {
    id: face
    property var widget: null
    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    property var now: new Date()
    Timer { interval: 1000; running: face.visible; repeat: true; triggeredOnStart: true; onTriggered: face.now = new Date() }
    readonly property string hm: typeof DateTime !== "undefined" ? DateTime.hour + ":" + DateTime.minute : ""
    readonly property string sec: Qt.formatDateTime(face.now, "ss")

    implicitWidth: isVertical ? col.implicitWidth : row.implicitWidth
    implicitHeight: isVertical ? col.implicitHeight : row.implicitHeight

    Row {
        id: row
        visible: !face.isVertical
        anchors.centerIn: parent
        spacing: widget ? widget.s(3) : 3
        Text { anchors.baseline: secText.baseline; text: face.hm; font.family: ThemeBackend.fontFamily; font.pixelSize: widget ? widget.s(15) : 15; font.weight: Font.DemiBold; color: ThemeBackend.text }
        Text { id: secText; text: face.sec; font.family: ThemeBackend.fontFamily; font.pixelSize: widget ? widget.s(11) : 11; font.weight: Font.Medium; color: ThemeBackend.mauve; font.features: { "tnum": 1 } }
    }
    Column {
        id: col
        visible: face.isVertical
        anchors.centerIn: parent
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: typeof DateTime !== "undefined" ? DateTime.hour : ""; font.family: ThemeBackend.fontFamily; font.pixelSize: widget ? widget.s(14) : 14; font.weight: Font.DemiBold; color: ThemeBackend.text }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: typeof DateTime !== "undefined" ? DateTime.minute : ""; font.family: ThemeBackend.fontFamily; font.pixelSize: widget ? widget.s(14) : 14; font.weight: Font.DemiBold; color: ThemeBackend.text }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: face.sec; font.family: ThemeBackend.fontFamily; font.pixelSize: widget ? widget.s(11) : 11; color: ThemeBackend.mauve }
    }
}
