import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Calendar: the time, how far through the day and year we are, and a month you can page.
Page {
    id: page
    pageId: "calendar"
    implicitHeight: Weather.loc ? 330 + 10 + 150 : 330

    SystemClock { id: clock; precision: SystemClock.Seconds }
    property int monthOffset: 0
    onCurrentChanged: if (current) monthOffset = 0

    readonly property date shownMonth: new Date(clock.date.getFullYear(), clock.date.getMonth() + monthOffset, 1)
    readonly property var cells: {
        const first = shownMonth;
        const startDay = (first.getDay() + 6) % 7;            // weeks start on Monday
        const out = [];
        for (let i = 0; i < 42; i++) out.push(new Date(first.getFullYear(), first.getMonth(), 1 - startDay + i));
        return out;
    }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate(); }

    readonly property real dayFrac: (clock.date.getHours() * 3600 + clock.date.getMinutes() * 60 + clock.date.getSeconds()) / 86400
    readonly property int dayOfYear: Math.floor((clock.date - new Date(clock.date.getFullYear(), 0, 0)) / 86400000)
    readonly property int yearDays: new Date(clock.date.getFullYear(), 1, 29).getDate() === 29 ? 366 : 365

    RowLayout {
        id: topRow
        width: parent.width
        height: 330
        spacing: 12

        // the time card
        Rectangle {
            Rise {}
            Layout.preferredWidth: 300
            Layout.fillHeight: true
            radius: Theme.corner(80, 10)
            color: Theme.container
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 2
                Label { text: Qt.formatDate(clock.date, "dddd"); muted: true }
                Label { text: Qt.formatTime(clock.date, "HH:mm"); font.pixelSize: 64; font.weight: Font.Light }
                Label { text: Qt.formatDate(clock.date, "d MMMM yyyy"); font.pixelSize: Theme.sizeTitle }
                Item { Layout.fillHeight: true }
                Repeater {
                    model: [
                        { label: "Day", v: page.dayFrac, note: Math.round(page.dayFrac * 100) + "%" },
                        { label: "Year", v: page.dayOfYear / page.yearDays, note: page.dayOfYear + " / " + page.yearDays }
                    ]
                    ColumnLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.topMargin: 6
                        spacing: 4
                        RowLayout {
                            Label { text: modelData.label; muted: true; font.pixelSize: Theme.sizeSmall }
                            Item { Layout.fillWidth: true }
                            Label { text: modelData.note; muted: true; font.pixelSize: Theme.sizeSmall }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 6
                            radius: 3
                            color: Theme.control
                            Rectangle { width: parent.width * modelData.v; height: parent.height; radius: 3; color: Theme.accent }
                        }
                    }
                }
            }
        }

        // the month
        Rectangle {
            Rise {}
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.corner(80, 10)
            color: Theme.container
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Label { Layout.leftMargin: 6; text: Qt.formatDate(page.shownMonth, "MMMM yyyy"); strong: true; font.pixelSize: Theme.sizeTitle }
                    Item { Layout.fillWidth: true }
                    Pressable { width: 34; height: 34; onClicked: page.monthOffset--; Icon { anchors.centerIn: parent; name: "chevron_left"; size: 20 } }
                    Pressable { width: 34; height: 34; onClicked: page.monthOffset++; Icon { anchors.centerIn: parent; name: "chevron_right"; size: 20 } }
                }
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 2
                    columnSpacing: 2
                    Repeater {
                        model: ["M", "T", "W", "T", "F", "S", "S"]
                        Label { required property string modelData; Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter; text: modelData; muted: true; font.pixelSize: Theme.sizeSmall }
                    }
                    Repeater {
                        model: page.cells
                        Rectangle {
                            required property var modelData
                            readonly property bool today: page.sameDay(modelData, clock.date)
                            readonly property bool inMonth: modelData.getMonth() === page.shownMonth.getMonth()
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: Theme.corner(height, 2)
                            color: today ? Theme.accent : "transparent"
                            Label {
                                anchors.centerIn: parent
                                text: parent.modelData.getDate()
                                color: parent.today ? Theme.onAccent : (parent.inMonth ? Theme.text : Theme.faint)
                                strong: parent.today
                            }
                        }
                    }
                }
            }
        }
    }

    // the weather: now, then the next hours, then the next days
    Rectangle {
        Rise {}
        visible: !!Weather.loc
        y: topRow.height + 10
        width: parent.width
        height: 150
        radius: Theme.corner(80, 10)
        color: Theme.container
        Label { anchors.centerIn: parent; visible: !Weather.ready; text: "Getting the weather…"; muted: true }
        RowLayout {
            visible: Weather.ready
            anchors.fill: parent
            anchors.margins: 16
            spacing: 16
            Column {
                Layout.preferredWidth: 170
                spacing: 2
                Row {
                    spacing: 8
                    Icon { name: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : ""; size: 44; color: Theme.accent; filled: true }
                    Label { text: Weather.ready ? Math.round(Weather.current.temp) + Weather.unit : ""; font.pixelSize: 38; font.weight: Font.Light; anchors.verticalCenter: parent.verticalCenter }
                }
                Label { text: Weather.ready ? Weather.describe(Weather.current.code) : ""; strong: true }
                Label { text: Weather.city; muted: true; font.pixelSize: Theme.sizeSmall }
            }
            Row {
                id: hoursRow
                Layout.fillWidth: true
                spacing: 6
                clip: true
                // as many 3-hour steps as fit (it ran under the days list on narrower pages)
                readonly property int fits: Math.max(1, Math.min(8, Math.floor((width + spacing) / (54 + spacing))))
                Repeater {
                    model: Weather.hours.filter((h, i) => i % 3 === 0).slice(0, hoursRow.fits)
                    Rectangle {
                        required property var modelData
                        width: 54
                        height: 112
                        radius: Theme.corner(54, 4)
                        color: Theme.containerHigh
                        Column {
                            anchors.centerIn: parent
                            spacing: 4
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.time; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Weather.icon(modelData.code, true); size: 22 }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.temp) + "°"; strong: true }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.rain + "%"; muted: true; font.pixelSize: Theme.sizeSmall - 1; visible: modelData.rain > 0 }
                        }
                    }
                }
            }
            Column {
                Layout.preferredWidth: 150
                spacing: 4
                Repeater {
                    model: Weather.days.slice(1, 5)
                    Row {
                        required property var modelData
                        spacing: 8
                        Label { width: 36; text: Qt.formatDate(new Date(modelData.date + "T12:00"), "ddd"); muted: true; font.pixelSize: Theme.sizeSmall }
                        Icon { name: Weather.icon(modelData.code, true); size: 18 }
                        Label { text: Math.round(modelData.max) + "° / " + Math.round(modelData.min) + "°"; font.pixelSize: Theme.sizeSmall }
                    }
                }
            }
        }
    }
}
