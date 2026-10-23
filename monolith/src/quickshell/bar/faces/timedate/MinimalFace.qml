import QtQuick
import "../../../"

// Time & Date, Minimal: only the time, a little larger and light
Item {
    id: face
    property var widget: null
    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    implicitWidth: isVertical ? col.implicitWidth : t.implicitWidth
    implicitHeight: isVertical ? col.implicitHeight : t.implicitHeight

    Text {
        id: t
        visible: !face.isVertical
        anchors.centerIn: parent
        text: typeof DateTime !== "undefined" ? DateTime.hour + ":" + DateTime.minute + (DateTime.amPm !== "" ? " " + DateTime.amPm : "") : ""
        font.family: ThemeBackend.fontFamily
        font.pixelSize: widget ? widget.s(17) : 17
        font.weight: Font.Light
        color: ThemeBackend.text
    }
    Column {
        id: col
        visible: face.isVertical
        anchors.centerIn: parent
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: typeof DateTime !== "undefined" ? DateTime.hour : ""; font.family: ThemeBackend.fontFamily; font.pixelSize: widget ? widget.s(16) : 16; font.weight: Font.Light; color: ThemeBackend.text }
        Text { anchors.horizontalCenter: parent.horizontalCenter; text: typeof DateTime !== "undefined" ? DateTime.minute : ""; font.family: ThemeBackend.fontFamily; font.pixelSize: widget ? widget.s(16) : 16; font.weight: Font.Light; color: ThemeBackend.text }
    }
}
