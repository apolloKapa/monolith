import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../core"
import "../ui"

// Desktop widgets on the wallpaper: a clock, the weather and now playing. In edit mode
// (Settings → Desktop) they can be dragged; positions are saved as fractions of the screen.
Item {
    id: desk
    anchors.fill: parent
    property string screenName: ""
    readonly property bool editing: Store.get("widgets.editing", false) === true
    // every widget, where it starts and whether it's on until you choose (Settings → Desktop)
    readonly property var catalog: [
        { id: "clock", type: "clock", x: 0.05, y: 0.62, on: true },
        { id: "weather", type: "weather", x: 0.05, y: 0.84, on: true },
        { id: "media", type: "media", x: 0.72, y: 0.84, on: true },
        { id: "calendar", type: "calendar", x: 0.80, y: 0.08, on: false },
        { id: "usage", type: "usage", x: 0.05, y: 0.08, on: false },
        { id: "notes", type: "notes", x: 0.80, y: 0.42, on: false },
        { id: "image", type: "image", x: 0.42, y: 0.08, on: false }
    ]
    readonly property var list: {
        const saved = Store.get("widgets.list", []);
        return catalog.map(c => Object.assign({}, c, saved.find(w => w.id === c.id) || {}))
                      .filter(w => Store.get("widgets.hidden." + w.id, !w.on) !== true);
    }

    function move(id, fx, fy) {
        const l = Store.get("widgets.list", []).filter(w => w.id !== id).concat([{ id: id, x: fx, y: fy }]);
        Store.set("widgets.list", l);
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null

    Repeater {
        model: desk.list
        Item {
            id: w
            required property var modelData
            // kept inside the screen, whatever its size
            x: Math.max(16, Math.min(modelData.x * desk.width, desk.width - width - 16))
            y: Math.max(16, Math.min(modelData.y * desk.height, desk.height - height - 16))
            width: body.implicitWidth
            height: body.implicitHeight
            visible: modelData.type !== "media" || !!desk.player || desk.editing === true

            // the edit frame
            Rectangle {
                anchors.fill: parent
                anchors.margins: -8
                radius: Theme.corner(40, 8)
                color: "transparent"
                border.width: desk.editing ? 2 : 0
                border.color: Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -8
                enabled: desk.editing
                cursorShape: desk.editing ? Qt.SizeAllCursor : Qt.ArrowCursor
                drag.target: desk.editing ? w : null
                onReleased: desk.move(w.modelData.id, Math.max(0, Math.min(0.95, w.x / desk.width)), Math.max(0, Math.min(0.95, w.y / desk.height)))
            }

            Loader {
                id: body
                sourceComponent: ({ clock: clockW, weather: weatherW, media: mediaW, calendar: calendarW, usage: usageW, notes: notesW, image: imageW })[w.modelData.type] || null
            }
        }
    }

    // big time with the date over it, in the text colour with a soft shadow for any wallpaper
    Component {
        id: clockW
        Column {
            Label { text: Qt.formatDate(clock.date, "dddd, d MMMM"); font.pixelSize: 24; color: "#ffffff"; style: Text.Raised; styleColor: Qt.alpha("#000000", 0.25) }
            Label { text: Qt.formatTime(clock.date, "HH:mm"); font.pixelSize: 120; font.weight: Font.Light; color: "#ffffff"; style: Text.Raised; styleColor: Qt.alpha("#000000", 0.25) }
        }
    }
    Component {
        id: weatherW
        Rectangle {
            implicitWidth: wr.implicitWidth + 28
            implicitHeight: 72
            radius: Theme.corner(72, 8)
            color: Qt.alpha(Theme.card, 0.78)
            Row {
                id: wr
                anchors.centerIn: parent
                spacing: 12
                Icon { name: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : "cloud"; size: 36; filled: true; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Label { text: Weather.ready ? Math.round(Weather.current.temp) + Weather.unit + "  " + Weather.describe(Weather.current.code) : "Weather"; strong: true }
                    Label { text: Weather.city; muted: true; font.pixelSize: Theme.sizeSmall }
                }
            }
        }
    }
    Component {
        id: mediaW
        Rectangle {
            implicitWidth: 340
            implicitHeight: 84
            radius: Theme.corner(84, 8)
            color: Qt.alpha(Theme.card, 0.78)
            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12
                Rectangle {
                    width: 64; height: 64
                    radius: Theme.corner(64, 4)
                    color: Theme.control
                    clip: true
                    Icon { anchors.centerIn: parent; name: "music_note"; size: 28; color: Theme.faint }
                    Image { anchors.fill: parent; source: desk.player ? (desk.player.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop }
                }
                Column {
                    width: parent.width - 64 - 12 - 52
                    anchors.verticalCenter: parent.verticalCenter
                    Label { width: parent.width; text: desk.player ? desk.player.trackTitle : "Nothing playing"; strong: true }
                    Label { width: parent.width; text: desk.player ? desk.player.trackArtist : ""; muted: true; font.pixelSize: Theme.sizeSmall }
                }
                Pressable {
                    width: 40; height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent; ink: Theme.onAccent
                    enabledInput: !!desk.player
                    onClicked: desk.player.togglePlaying()
                    Icon { anchors.centerIn: parent; name: desk.player && desk.player.isPlaying ? "pause" : "play_arrow"; size: 22; filled: true; color: Theme.onAccent }
                }
            }
        }
    }

    // a month: today filled with the accent
    Component {
        id: calendarW
        Rectangle {
            readonly property date now: clock.date
            readonly property int first: (new Date(now.getFullYear(), now.getMonth(), 1).getDay() + 6) % 7
            readonly property int days: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
            implicitWidth: 7 * 34 + 28
            implicitHeight: grid.y + grid.height + 14
            radius: Theme.corner(80, 10)
            color: Qt.alpha(Theme.card, 0.78)
            Label { x: 16; y: 12; text: Qt.formatDate(parent.now, "MMMM yyyy"); strong: true }
            Grid {
                id: grid
                x: 14; y: 40
                columns: 7
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Label { required property string modelData; width: 34; height: 22; horizontalAlignment: Text.AlignHCenter; text: modelData; muted: true; font.pixelSize: Theme.sizeSmall }
                }
                Repeater {
                    model: parent.parent.first + parent.parent.days
                    Rectangle {
                        required property int index
                        readonly property int day: index - parent.parent.first + 1
                        readonly property bool today: day === parent.parent.now.getDate()
                        width: 34; height: 30
                        radius: Theme.corner(30)
                        color: today ? Theme.accent : "transparent"
                        Label { anchors.centerIn: parent; visible: parent.day > 0; text: parent.day; color: parent.today ? Theme.onAccent : Theme.text; strong: parent.today; font.pixelSize: Theme.sizeSmall + 1 }
                    }
                }
            }
        }
    }
    // CPU, memory and temperature as rings
    Component {
        id: usageW
        Rectangle {
            implicitWidth: ur.implicitWidth + 32
            implicitHeight: 118
            radius: Theme.corner(118, 10)
            color: Qt.alpha(Theme.card, 0.78)
            Row {
                id: ur
                anchors.centerIn: parent
                spacing: 18
                Repeater {
                    model: [["CPU", Stats.cpu, Math.round(Stats.cpu * 100) + "%"], ["Memory", Stats.mem, Math.round(Stats.mem * 100) + "%"], ["Temp", Math.min(1, Stats.temp / 100), Math.round(Stats.temp) + "°"]]
                    Column {
                        required property var modelData
                        spacing: 4
                        Canvas {
                            width: 64; height: 64
                            property real frac: modelData[1]
                            onFracChanged: requestPaint()
                            onPaint: {
                                const g = getContext("2d");
                                g.reset();
                                g.lineWidth = 7; g.lineCap = "round";
                                g.strokeStyle = Theme.control;
                                g.beginPath(); g.arc(32, 32, 27, 0, 2 * Math.PI); g.stroke();
                                g.strokeStyle = Theme.accent;
                                g.beginPath(); g.arc(32, 32, 27, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * Math.max(0.01, frac)); g.stroke();
                            }
                            Label { anchors.centerIn: parent; text: modelData[2]; font.pixelSize: Theme.sizeSmall; strong: true }
                        }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData[0]; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                    }
                }
            }
        }
    }
    // the notes from Tools, editable here too
    Component {
        id: notesW
        Rectangle {
            implicitWidth: 300
            implicitHeight: 220
            radius: Theme.corner(80, 10)
            color: Qt.alpha(Theme.card, 0.78)
            Row { x: 16; y: 12; spacing: 6; Icon { name: "sticky_note_2"; size: 18; color: Theme.accent } Label { text: "Notes"; strong: true } }
            TextEdit {
                id: nt
                x: 16; y: 42
                width: parent.width - 32; height: parent.height - 56
                text: Store.get("notes.text", "")
                wrapMode: TextEdit.Wrap
                color: Theme.text
                selectionColor: Theme.selected
                font.family: Theme.fontFamily
                font.pixelSize: Theme.sizeBody
                clip: true
                onTextChanged: saveNt.restart()
                Timer { id: saveNt; interval: 600; onTriggered: if (Store.get("notes.text", "") !== nt.text) Store.set("notes.text", nt.text) }
                Label { visible: nt.text === ""; text: "Write something…"; muted: true }
            }
        }
    }
    // a picture of yours (Settings → Desktop)
    Component {
        id: imageW
        Rectangle {
            readonly property string src: Store.get("widgets.imagePath", "")
            implicitWidth: 260
            implicitHeight: src !== "" && img.status === Image.Ready ? Math.round(260 * img.implicitHeight / Math.max(1, img.implicitWidth)) : 160
            radius: Theme.corner(80, 10)
            color: Qt.alpha(Theme.card, 0.78)
            clip: true
            Image { id: img; anchors.fill: parent; source: parent.src !== "" ? Wall.url(parent.src) : ""; sourceSize.width: 520; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            Label { anchors.centerIn: parent; visible: parent.src === ""; text: "Pick a picture in Settings → Desktop"; muted: true; font.pixelSize: Theme.sizeSmall }
        }
    }
}
