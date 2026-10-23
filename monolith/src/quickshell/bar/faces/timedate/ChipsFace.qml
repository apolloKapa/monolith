import QtQuick
import "../../../"

// Time & Date, Chips: the hours and the minutes each in a small pill
Item {
    id: face
    property var widget: null
    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    readonly property real h: widget ? widget.s(22) : 22

    implicitWidth: flow.implicitWidth
    implicitHeight: flow.implicitHeight

    component Chip: Rectangle {
        property string label: ""
        property bool accent: false
        width: Math.max(face.h, txt.implicitWidth + face.h * 0.6)
        height: face.h
        radius: ThemeBackend.square ? 0 : height / 2
        color: accent ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.text, 0.12)
        Text {
            id: txt
            anchors.centerIn: parent
            text: parent.label
            font.family: ThemeBackend.fontFamily
            font.pixelSize: face.h * 0.58
            font.weight: Font.DemiBold
            color: parent.accent ? ThemeBackend.onPrimary : ThemeBackend.text
        }
    }

    Grid {
        id: flow
        anchors.centerIn: parent
        columns: face.isVertical ? 1 : 3
        spacing: widget ? widget.s(3) : 3
        Chip { label: typeof DateTime !== "undefined" ? DateTime.hour : ""; accent: true }
        Chip { label: typeof DateTime !== "undefined" ? DateTime.minute : "" }
        Chip { visible: !face.isVertical && widget && widget.showDate; label: typeof DateTime !== "undefined" ? Qt.locale(I18n.qtLocaleName).toString(DateTime.now, "ddd d") : "" }
    }
}
