import QtQuick
import QtQuick.Controls as QQC
import "../core"
import "popfit.js" as PopFit

// A drop-down choice: shows the picked option; click it for the list. Options are
// [value, label] pairs (a label can be followed by a description as a third item).
Rectangle {
    id: dd
    property var opts: []
    property string value: ""
    signal picked(string v)
    readonly property var cur: opts.find(o => String(o[0]) === value) || null
    width: 240
    height: 40
    radius: Theme.corner(height)
    color: area.containsMouse || menu.visible ? Theme.containerHigh : Theme.container
    Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
    border.width: menu.visible ? 2 : Math.max(Theme.outlineW, 1)
    border.color: menu.visible ? Theme.accent : (Theme.outlineW > 0 ? Theme.outlineColor : Theme.ringTrack)

    Label {
        anchors.left: parent.left; anchors.leftMargin: 16
        anchors.right: arrow.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: dd.cur ? dd.cur[1] : "Choose…"
        strong: true
        font.pixelSize: Theme.sizeSmall + 1
    }
    Icon {
        id: arrow
        anchors.right: parent.right; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        name: "expand_more"; size: 20
        rotation: menu.visible ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
    }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: menu.visible ? menu.close() : dd.openList() }

    // the list's full height, and where it goes (see popfit.js: inside the card or page)
    readonly property real listH: listCol.implicitHeight + 12
    property var fit: ({ y: height + 4, h: listH, up: false })
    function openList() {
        fit = PopFit.place(dd, listH, 4);
        menu.open();
    }

    QQC.Popup {
        id: menu
        y: dd.fit.y
        width: dd.width
        height: dd.fit.h
        padding: 6
        modal: false
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside
        // fades in with a little zoom from the field, and out the same way
        transformOrigin: dd.fit.up ? QQC.Popup.Bottom : QQC.Popup.Top
        enter: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.popInMs; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: Theme.popScale; to: 1; duration: Theme.popInMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve }
        }
        exit: Transition {
            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: Theme.popOutMs; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 1; to: Theme.popScale; duration: Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve }
        }
        background: Rectangle {
            radius: Theme.corner(48, 6)
            color: Theme.frame
            border.width: Math.max(1, Theme.outlineW)
            border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        }
        onOpened: {
            // the picked one in view
            const i = dd.opts.findIndex(o => String(o[0]) === dd.value);
            if (i >= 0 && listCol.children[i]) {
                const c = listCol.children[i];
                scroller.contentY = Math.max(0, Math.min(scroller.contentHeight - scroller.height, c.y + c.height / 2 - scroller.height / 2));
            } else scroller.contentY = 0;
        }
        contentItem: Flickable {
            id: scroller
            clip: true
            contentHeight: listCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            SmoothWheel {}
          Column {
            id: listCol
            spacing: 2
            Repeater {
                model: dd.opts
                Pressable {
                    required property var modelData
                    readonly property bool on: String(modelData[0]) === dd.value
                    width: dd.width - 12
                    height: modelData.length > 2 ? 52 : 38
                    color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : "transparent")
                    onClicked: { dd.picked(String(modelData[0])); menu.close(); }
                    Column {
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 44
                        Label { width: parent.width; text: parent.parent.modelData[1]; strong: parent.parent.on; color: parent.parent.on ? Theme.onAccentContainer : Theme.text; font.pixelSize: Theme.sizeSmall + 1 }
                        Label { visible: parent.parent.modelData.length > 2; width: parent.width; text: parent.parent.modelData[2] || ""; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                    }
                    Icon { visible: parent.on; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 18; color: Theme.onAccentContainer }
                }
            }
          }
        }
    }
}
