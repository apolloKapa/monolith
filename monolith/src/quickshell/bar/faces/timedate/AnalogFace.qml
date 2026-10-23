import QtQuick
import "../../../"

// Time & Date, Analog: a small clock face with hands, then the time (vertical bars: just the dial)
Item {
    id: face
    property var widget: null
    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    readonly property real dial: widget ? widget.s(20) : 20
    property var now: new Date()
    Timer { interval: 1000; running: face.visible; repeat: true; triggeredOnStart: true; onTriggered: face.now = new Date() }

    implicitWidth: isVertical ? dial : row.implicitWidth
    implicitHeight: isVertical ? dial : row.implicitHeight

    component Dial: Item {
        id: dialRoot
        // given from outside: inline components can't see the face's own properties
        property real size: 20
        property var time: new Date()
        width: size
        height: size
        Rectangle { anchors.fill: parent; radius: width / 2; color: "transparent"; border.width: Math.max(1.5, width * 0.08); border.color: ThemeBackend.text }
        Rectangle {
            id: hourHand
            // hour hand
            width: Math.max(1.5, dialRoot.size * 0.09); height: dialRoot.size * 0.28; radius: width / 2
            color: ThemeBackend.text
            x: (parent.width - width) / 2; y: parent.height / 2 - height
            transform: Rotation { origin.x: hourHand.width / 2; origin.y: hourHand.height; angle: (dialRoot.time.getHours() % 12 + dialRoot.time.getMinutes() / 60) * 30 }
        }
        Rectangle {
            id: minuteHand
            // minute hand
            width: Math.max(1.2, dialRoot.size * 0.07); height: dialRoot.size * 0.38; radius: width / 2
            color: ThemeBackend.mauve
            x: (parent.width - width) / 2; y: parent.height / 2 - height
            transform: Rotation { origin.x: minuteHand.width / 2; origin.y: minuteHand.height; angle: dialRoot.time.getMinutes() * 6 }
        }
    }

    Row {
        id: row
        visible: !face.isVertical
        anchors.centerIn: parent
        spacing: widget ? widget.s(8) : 8
        Dial { anchors.verticalCenter: parent.verticalCenter; size: face.dial; time: face.now }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: typeof DateTime !== "undefined" ? DateTime.hour + ":" + DateTime.minute : ""
            font.family: ThemeBackend.fontFamily
            font.pixelSize: widget ? widget.s(14) : 14
            font.weight: Font.Medium
            color: ThemeBackend.text
        }
    }
    Dial { visible: face.isVertical; anchors.centerIn: parent; size: face.dial; time: face.now }
}
