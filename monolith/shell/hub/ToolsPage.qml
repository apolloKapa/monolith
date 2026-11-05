import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../ui"

// Tools: a timer (notifies when it's done), notes (saved as you type) and a unit converter.
Page {
    id: page
    pageId: "tools"
    implicitHeight: 400

    // ── converter ──
    readonly property var units: ({
        "Length": [["m", 1], ["km", 1000], ["cm", 0.01], ["mm", 0.001], ["mi", 1609.344], ["ft", 0.3048], ["in", 0.0254]],
        "Weight": [["kg", 1], ["g", 0.001], ["lb", 0.45359237], ["oz", 0.028349523]],
        "Temperature": [["°C", 0], ["°F", 0], ["K", 0]],
        "Data": [["MB", 1], ["GB", 1000], ["TB", 1e6], ["MiB", 1.048576], ["GiB", 1073.741824]]
    })
    property string kind: "Length"
    property int fromI: 0
    property int toI: 1
    property real amount: 1
    readonly property real converted: {
        const u = units[kind];
        if (kind === "Temperature") {
            const c = fromI === 0 ? amount : (fromI === 1 ? (amount - 32) * 5 / 9 : amount - 273.15);
            return toI === 0 ? c : (toI === 1 ? c * 9 / 5 + 32 : c + 273.15);
        }
        return amount * u[fromI][1] / u[toI][1];
    }

    component Card: Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        radius: Theme.corner(80, 10)
        color: Theme.container
    }
    component Chip: Pressable {
        property string text: ""
        property bool on: false
        height: 34
        width: cl.implicitWidth + 22
        color: on ? Theme.selected : Theme.containerHigh
        Label { id: cl; anchors.centerIn: parent; text: parent.text; font.pixelSize: Theme.sizeSmall; strong: parent.on }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 10

        Card {
            // a ring that empties as the time runs out
            Item {
                id: ring
                anchors.horizontalCenter: parent.horizontalCenter
                y: 20
                width: 170; height: 170
                Canvas {
                    id: arc
                    anchors.fill: parent
                    property real frac: Tasks.total > 0 ? Tasks.remaining / Tasks.total : 0
                    onFracChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.lineWidth = 10;
                        ctx.lineCap = "round";
                        ctx.strokeStyle = Theme.control;
                        ctx.beginPath(); ctx.arc(85, 85, 75, 0, Math.PI * 2); ctx.stroke();
                        if (frac > 0) {
                            ctx.strokeStyle = Theme.accent;
                            ctx.beginPath(); ctx.arc(85, 85, 75, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * frac); ctx.stroke();
                        }
                    }
                }
                Label { anchors.centerIn: parent; text: Tasks.total > 0 ? Tasks.fmt(Tasks.remaining) : "Timer"; font.pixelSize: Tasks.total > 0 ? 36 : 20; font.weight: Font.Light }
            }
            Flow {
                anchors.top: ring.bottom; anchors.topMargin: 16
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 24
                spacing: 6
                Repeater {
                    model: [1, 5, 10, 25, 45]
                    Chip { required property int modelData; text: modelData + " min"; onClicked: Tasks.startTimer(modelData) }
                }
                Chip {
                    visible: Tasks.total > 0
                    text: Tasks.timing ? "Pause" : (Tasks.remaining > 0 ? "Resume" : "Reset")
                    on: true
                    onClicked: { if (Tasks.remaining <= 0) { Tasks.total = 0; } else Tasks.timing = !Tasks.timing; }
                }
            }
        }

        Card {
            Label { x: 16; y: 14; text: "Notes"; strong: true }
            Flickable {
                x: 12; y: 40
                width: parent.width - 24
                height: parent.height - 52
                contentHeight: notes.implicitHeight
                clip: true
                TextEdit {
                    id: notes
                    width: parent.width
                    wrapMode: TextEdit.Wrap
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeBody
                    selectionColor: Theme.selected
                    text: Store.get("notes.text", "")
                    onTextChanged: saveNotes.restart()
                    Timer { id: saveNotes; interval: 600; onTriggered: if (Store.get("notes.text", "") !== notes.text) Store.set("notes.text", notes.text) }
                    Label { visible: notes.text === ""; text: "Write something…"; muted: true }
                }
            }
        }

        Card {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 14
                spacing: 8
                Label { text: "Convert"; strong: true }
                Flow {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: Object.keys(page.units)
                        Chip { required property string modelData; text: modelData; on: page.kind === modelData; onClicked: { page.kind = modelData; page.fromI = 0; page.toI = 1; } }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    radius: Theme.corner(height)
                    color: Theme.containerHigh
                    TextInput {
                        anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeTitle
                        text: "1"
                        validator: DoubleValidator {}
                        onTextChanged: page.amount = Number(text.replace(",", ".")) || 0
                    }
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: page.units[page.kind]
                        Chip { required property var modelData; required property int index; text: modelData[0]; on: page.fromI === index; onClicked: page.fromI = index }
                    }
                }
                Icon { Layout.alignment: Qt.AlignHCenter; name: "south"; size: 18; color: Theme.subtext }
                Flow {
                    Layout.fillWidth: true
                    spacing: 4
                    Repeater {
                        model: page.units[page.kind]
                        Chip { required property var modelData; required property int index; text: modelData[0]; on: page.toI === index; onClicked: page.toI = index }
                    }
                }
                Item { Layout.fillHeight: true }
                Label {
                    Layout.fillWidth: true
                    text: (Math.round(page.converted * 10000) / 10000) + " " + page.units[page.kind][page.toI][0]
                    font.pixelSize: 26
                    color: Theme.accent
                }
            }
        }
    }
}
