import QtQuick
import QtQuick.Controls as QQC
import "../core"

// A font drop-down: shows the font in use (written in it); click it for every font, each
// written in itself, with a search. Rows are a fixed height, so hovering never moves anything.
Rectangle {
    id: fp
    property var families: []
    property string value: ""            // "" = the default
    property string defaultName: "Default"
    signal picked(string family)
    property string filter: ""
    readonly property var shown: [""].concat(families.filter(f => filter === "" || f.toLowerCase().includes(filter.toLowerCase())))

    width: 300
    height: 40
    radius: Theme.corner(height)
    color: area.containsMouse || pop.visible ? Theme.containerHigh : Theme.container
    border.width: pop.visible ? 2 : Math.max(Theme.outlineW, 1)
    border.color: pop.visible ? Theme.accent : (Theme.outlineW > 0 ? Theme.outlineColor : Theme.ringTrack)

    Text {
        anchors.left: parent.left; anchors.leftMargin: 16
        anchors.right: arrow.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: fp.value === "" ? fp.defaultName : fp.value
        font.family: fp.value === "" ? Theme.fontFamily : fp.value
        font.pixelSize: Theme.sizeBody + 1
        color: Theme.text
        elide: Text.ElideRight
    }
    Icon { id: arrow; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; name: "expand_more"; size: 20; rotation: pop.visible ? 180 : 0; Behavior on rotation { NumberAnimation { duration: 160 } } }
    MouseArea { id: area; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.visible ? pop.close() : pop.open() }

    QQC.Popup {
        id: pop
        y: fp.height + 4
        width: Math.max(fp.width, 360)
        height: 380
        padding: 8
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside
        onOpened: { fp.filter = ""; search.text = ""; search.forceActiveFocus(); list.positionViewAtIndex(Math.max(0, fp.shown.indexOf(fp.value)), ListView.Center); }
        background: Rectangle {
            radius: Theme.corner(48, 6)
            color: Theme.frame
            border.width: Math.max(1, Theme.outlineW)
            border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        }
        contentItem: Column {
            spacing: 6
            Rectangle {
                width: parent.width; height: 38
                radius: Theme.corner(38)
                color: Theme.containerHigh
                Icon { id: si; x: 12; anchors.verticalCenter: parent.verticalCenter; name: "search"; size: 18; color: Theme.subtext }
                TextInput {
                    id: search
                    anchors.left: si.right; anchors.leftMargin: 8; anchors.right: parent.right; anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody
                    clip: true
                    onTextChanged: fp.filter = text
                    Keys.onDownPressed: list.incrementCurrentIndex()
                    Keys.onUpPressed: list.decrementCurrentIndex()
                    Keys.onReturnPressed: if (list.currentIndex >= 0) { fp.picked(fp.shown[list.currentIndex]); pop.close(); }
                    Text { visible: search.text === ""; anchors.verticalCenter: parent.verticalCenter; text: "Search " + fp.families.length + " fonts"; color: Theme.subtext; font: search.font }
                }
            }
            ListView {
                id: list
                width: parent.width
                height: pop.height - pop.padding * 2 - 44
                clip: true
                model: fp.shown
                currentIndex: 0
                boundsBehavior: Flickable.StopAtBounds
                SmoothWheel {}
                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    readonly property bool on: modelData === fp.value
                    width: list.width; height: 40
                    radius: Theme.corner(40, 2)
                    color: on ? Theme.accentContainer : (rowArea.containsMouse || list.currentIndex === index ? Theme.containerHigh : "transparent")
                    Text {
                        x: 12; anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 48
                        text: modelData === "" ? fp.defaultName : modelData
                        font.family: modelData === "" ? Theme.fontFamily : modelData
                        font.pixelSize: 16
                        elide: Text.ElideRight
                        color: parent.on ? Theme.onAccentContainer : Theme.text
                    }
                    Icon { visible: parent.on; anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 18; color: Theme.onAccentContainer }
                    MouseArea { id: rowArea; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { fp.picked(parent.modelData); pop.close(); } }
                }
            }
        }
    }
}
