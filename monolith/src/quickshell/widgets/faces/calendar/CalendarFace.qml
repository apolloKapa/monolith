import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

// A month calendar card: month name with back/forward arrows, weekday initials, and a 6-week
// grid where today is a filled circle and days of other months are dimmed.
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 240
    property real minHeight: 240
    property real maxWidth: 700
    property real maxHeight: 700
    property real minAspect: 0.7
    property real maxAspect: 1.6
    property bool isRound: false

    // months away from the current one (the arrows); resets when the widget is recreated
    property int offset: 0
    readonly property date today: DateTime.now
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    // Monday first unless the locale starts the week on Sunday
    readonly property int firstDay: Qt.locale().firstDayOfWeek === Locale.Sunday ? 0 : 1
    readonly property real pad: Math.min(width, height) * 0.07

    readonly property var cells: {
        let y = shown.getFullYear(), m = shown.getMonth();
        let lead = (new Date(y, m, 1).getDay() - firstDay + 7) % 7;
        let out = [];
        for (let i = 0; i < 42; i++) {
            let d = new Date(y, m, 1 - lead + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === m,
                isToday: d.getFullYear() === today.getFullYear() && d.getMonth() === today.getMonth() && d.getDate() === today.getDate()
            });
        }
        return out;
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
        radius: ThemeBackend.rad(ThemeBackend.clampedBorderRadius)
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: ThemeBackend.rad(parent.radius)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.pad
        spacing: root.height * 0.02

        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: Qt.locale().standaloneMonthName(root.shown.getMonth(), Locale.LongFormat) + " " + root.shown.getFullYear()
                font.family: ThemeBackend.fontFamily
                font.pixelSize: Math.min(root.width, root.height) * 0.06
                font.weight: Font.DemiBold
                color: ThemeBackend.text
                elide: Text.ElideRight
            }
            Repeater {
                model: [{ glyph: "󰅁", step: -1 }, { glyph: "󰅂", step: 1 }]
                Rectangle {
                    required property var modelData
                    readonly property real side: Math.min(root.width, root.height) * 0.1
                    Layout.preferredWidth: side
                    Layout.preferredHeight: side
                    radius: side / 2
                    color: navArea.containsMouse ? ThemeBackend.surface2 : ThemeBackend.surface1
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.glyph
                        font.family: ThemeBackend.iconFont
                        font.pixelSize: parent.side * 0.5
                        color: ThemeBackend.text
                    }
                    MouseArea {
                        id: navArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.offset += parent.modelData.step
                    }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: 0
            columnSpacing: 0

            Repeater {
                model: 7
                Text {
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: Qt.locale().dayName((index + root.firstDay) % 7, Locale.ShortFormat).substring(0, 2)
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Math.min(root.width, root.height) * 0.04
                    color: ThemeBackend.overlay1
                }
            }

            Repeater {
                model: root.cells
                Item {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1

                    Rectangle {
                        anchors.centerIn: parent
                        readonly property real side: Math.min(parent.width, parent.height) * 0.86
                        width: side
                        height: side
                        radius: side / 2
                        color: ThemeBackend.text
                        visible: parent.modelData.isToday
                    }
                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.day
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.min(root.width, root.height) * 0.045
                        font.weight: parent.modelData.isToday ? Font.Bold : Font.Normal
                        color: parent.modelData.isToday ? ThemeBackend.base
                             : (parent.modelData.inMonth ? ThemeBackend.text : ThemeBackend.overlay0)
                    }
                }
            }
        }
    }
}
