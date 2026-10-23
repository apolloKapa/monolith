import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

// Time & Date, Google style: the time and a short date on one line, plain type, no accents
Item {
    id: googleFaceRoot
    property var widget: null

    readonly property bool isVertical: widget ? widget.orientation === "vertical" : false
    readonly property string hm: (typeof DateTime !== "undefined" && DateTime.hour !== "")
        ? DateTime.hour + ":" + DateTime.minute + (DateTime.amPm !== "" ? " " + DateTime.amPm : "")
        : (widget ? widget.timeStr : "")
    readonly property string shortDate: (typeof DateTime !== "undefined" && DateTime.now)
        ? Qt.locale(I18n.qtLocaleName || "en").toString(DateTime.now, "ddd, MMM d")
        : ""

    implicitWidth: isVertical ? sideCol.implicitWidth : topRow.implicitWidth
    implicitHeight: isVertical ? sideCol.implicitHeight : topRow.implicitHeight

    Row {
        id: topRow
        visible: !googleFaceRoot.isVertical
        anchors.centerIn: parent
        spacing: widget ? widget.s(8) : 8

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: googleFaceRoot.hm
            font.family: ThemeBackend.fontFamily
            font.pixelSize: widget ? widget.s(15) : 15
            font.weight: Font.DemiBold
            color: ThemeBackend.text
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: widget ? widget.showDate : true
            text: googleFaceRoot.shortDate
            font.family: ThemeBackend.fontFamily
            font.pixelSize: widget ? widget.s(13) : 13
            font.weight: Font.Medium
            color: ThemeBackend.subtext0
        }
    }

    Column {
        id: sideCol
        visible: googleFaceRoot.isVertical
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: typeof DateTime !== "undefined" ? DateTime.hour : ""
            font.family: ThemeBackend.fontFamily
            font.pixelSize: widget ? widget.s(15) : 15
            font.weight: Font.DemiBold
            color: ThemeBackend.text
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: typeof DateTime !== "undefined" ? DateTime.minute : ""
            font.family: ThemeBackend.fontFamily
            font.pixelSize: widget ? widget.s(15) : 15
            font.weight: Font.Normal
            color: ThemeBackend.subtext0
        }
    }
}
