import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../core"
import "../ui"

// One widget, drawn in one of its looks ("faces"). Used on the desktop, on the lock screen and
// in the widget editor. Sizes itself; the caller scales it.
Item {
    id: w
    property string type: "clock"
    property string face: ""
    property bool live: true                  // false in the editor's palette: no timers
    // the faces each type has (first = default), with names for the editor
    readonly property var faces: WidgetLayout.faces[type] || [["default", "Default"]]
    readonly property string f: faces.some(x => x[0] === face) ? face : faces[0][0]
    implicitWidth: body.item ? body.item.implicitWidth : 100
    implicitHeight: body.item ? body.item.implicitHeight : 60

    SystemClock { id: clock; precision: SystemClock.Seconds; enabled: w.live }
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
    // text straight on the wallpaper: white with a soft shadow, readable on any picture
    readonly property color ink: "#ffffff"
    readonly property color inkSoft: Qt.rgba(1, 1, 1, 0.75)

    component Plain: Text { color: w.ink; font.family: Theme.fontFamily; style: Text.Raised; styleColor: Qt.rgba(0, 0, 0, 0.25) }
    // an analog clock's hand, turning about the clock's centre (110, 110)
    component Hand: Rectangle {
        id: hand
        property real angle: 0
        property real len: 70
        x: 110 - width / 2; y: 110 - len
        height: len; radius: width / 2
        transform: Rotation { origin.x: hand.width / 2; origin.y: hand.len; angle: hand.angle }
    }
    component CardBg: Rectangle { radius: Theme.corner(80, 10); color: Qt.alpha(Theme.card, 0.82); border.width: Theme.outlineW; border.color: Theme.outlineColor }

    Loader {
        id: body
        sourceComponent: ({
            "clock/digital": clockDigital, "clock/stacked": clockStacked, "clock/analog": clockAnalog, "clock/minimal": clockMinimal,
            "date/full": dateFull, "date/compact": dateCompact,
            "weather/pill": weatherPill, "weather/full": weatherFull,
            "media/card": mediaCard, "media/cover": mediaCover,
            "calendar/month": calMonth,
            "usage/rings": usageRings, "usage/bars": usageBars,
            "notes/card": notesCard,
            "image/rounded": imageRounded, "image/circle": imageCircle,
            "greeting/text": greeting,
            "notifications/list": notifList
        })[w.type + "/" + w.f] || null
    }

    // ── clocks ──
    Component { id: clockDigital
        Column {
            Plain { text: Qt.formatDate(clock.date, "dddd, d MMMM"); font.pixelSize: 24 }
            Plain { text: Qt.formatTime(clock.date, "HH:mm"); font.pixelSize: 120; font.weight: Font.Light }
        } }
    Component { id: clockStacked
        Column {
            spacing: -30
            Plain { text: Qt.formatTime(clock.date, "HH"); font.pixelSize: 130; font.weight: Font.Bold }
            Plain { text: Qt.formatTime(clock.date, "mm"); font.pixelSize: 130; font.weight: Font.Bold; color: Theme.accent }
        } }
    Component { id: clockMinimal
        Plain { text: Qt.formatTime(clock.date, "HH:mm"); font.pixelSize: 54; font.weight: Font.DemiBold } }
    Component { id: clockAnalog
        Item {
            implicitWidth: 220; implicitHeight: 220
            Rectangle { anchors.fill: parent; radius: width / 2; color: Qt.alpha(Theme.card, 0.82); border.width: Math.max(2, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.ringTrack }
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    width: index % 3 === 0 ? 4 : 2; height: index % 3 === 0 ? 14 : 8
                    radius: width / 2
                    color: index % 3 === 0 ? Theme.text : Theme.subtext
                    x: 110 - width / 2 + Math.sin(index * Math.PI / 6) * 92
                    y: 110 - height / 2 - Math.cos(index * Math.PI / 6) * 92
                    rotation: index * 30
                }
            }
            Hand { width: 6; len: 58; color: Theme.text; angle: (clock.hours % 12 + clock.minutes / 60) * 30 }
            Hand { width: 4; len: 82; color: Theme.text; angle: (clock.minutes + clock.seconds / 60) * 6 }
            Hand { width: 2; len: 90; color: Theme.accent; angle: clock.seconds * 6 }
            Rectangle { x: 104; y: 104; width: 12; height: 12; radius: 6; color: Theme.accent }
        } }

    // ── date ──
    Component { id: dateFull
        Column {
            Plain { text: Qt.formatDate(clock.date, "dddd"); font.pixelSize: 44; font.weight: Font.Bold }
            Plain { text: Qt.formatDate(clock.date, "d MMMM yyyy"); font.pixelSize: 22; color: w.inkSoft }
        } }
    Component { id: dateCompact
        Plain { text: Qt.formatDate(clock.date, "ddd d MMM"); font.pixelSize: 26; font.weight: Font.DemiBold } }

    // ── weather ──
    Component { id: weatherPill
        CardBg {
            implicitWidth: wr.implicitWidth + 28; implicitHeight: 72
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
        } }
    Component { id: weatherFull
        CardBg {
            implicitWidth: 360; implicitHeight: 170
            Column {
                x: 16; y: 14; width: parent.width - 32
                spacing: 10
                Row {
                    spacing: 12
                    Icon { name: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : "cloud"; size: 46; filled: true; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: Weather.ready ? Math.round(Weather.current.temp) + Weather.unit : "—"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 30; font.weight: Font.Medium }
                        Label { text: (Weather.ready ? Weather.describe(Weather.current.code) : "") + (Weather.city ? "  ·  " + Weather.city : ""); muted: true; font.pixelSize: Theme.sizeSmall }
                    }
                }
                Row {
                    width: parent.width
                    Repeater {
                        model: Weather.hours.filter((h, i) => i % 3 === 0).slice(1, 6)
                        Column {
                            required property var modelData
                            width: parent.width / 5
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.time; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Weather.icon(modelData.code, true); size: 18; color: Theme.subtext }
                            Label { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.temp) + "°"; font.pixelSize: Theme.sizeSmall; strong: true }
                        }
                    }
                }
            }
        } }

    // ── now playing ──
    Component { id: mediaCard
        CardBg {
            implicitWidth: 340; implicitHeight: 84
            Row {
                anchors.fill: parent; anchors.margins: 10
                spacing: 12
                Rectangle {
                    width: 64; height: 64; radius: Theme.corner(64, 4); color: Theme.control; clip: true
                    Icon { anchors.centerIn: parent; name: "music_note"; size: 28; color: Theme.faint }
                    Image { anchors.fill: parent; source: w.player ? (w.player.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop }
                }
                Column {
                    width: parent.width - 64 - 12 - 52
                    anchors.verticalCenter: parent.verticalCenter
                    Label { width: parent.width; text: w.player ? w.player.trackTitle : "Nothing playing"; strong: true }
                    Label { width: parent.width; text: w.player ? w.player.trackArtist : ""; muted: true; font.pixelSize: Theme.sizeSmall }
                }
                Pressable {
                    width: 40; height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent; ink: Theme.onAccent
                    enabledInput: !!w.player
                    onClicked: w.player.togglePlaying()
                    Icon { anchors.centerIn: parent; name: w.player && w.player.isPlaying ? "pause" : "play_arrow"; size: 22; filled: true; color: Theme.onAccent }
                }
            }
        } }
    Component { id: mediaCover
        Rectangle {
            implicitWidth: 220; implicitHeight: 220
            radius: Theme.corner(220, 10)
            color: Theme.control
            clip: true
            Icon { anchors.centerIn: parent; name: "music_note"; size: 64; color: Theme.faint }
            Image { anchors.fill: parent; source: w.player ? (w.player.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                height: 64
                gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.7) } }
                Column {
                    x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; width: parent.width - 24
                    Text { width: parent.width; text: w.player ? w.player.trackTitle : "Nothing playing"; color: "white"; elide: Text.ElideRight; font.family: Theme.fontFamily; font.bold: true }
                    Text { width: parent.width; text: w.player ? w.player.trackArtist : ""; color: Qt.rgba(1, 1, 1, 0.75); elide: Text.ElideRight; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeSmall }
                }
            }
            MouseArea { anchors.fill: parent; enabled: !!w.player; cursorShape: Qt.PointingHandCursor; onClicked: w.player.togglePlaying() }
        } }

    // ── calendar ──
    Component { id: calMonth
        CardBg {
            readonly property date now: clock.date
            readonly property int first: (new Date(now.getFullYear(), now.getMonth(), 1).getDay() + 6) % 7
            readonly property int days: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
            implicitWidth: 7 * 34 + 28
            implicitHeight: grid.y + grid.height + 14
            Label { x: 16; y: 12; text: Qt.formatDate(parent.now, "MMMM yyyy"); strong: true }
            Grid {
                id: grid
                x: 14; y: 40
                columns: 7
                Repeater { model: ["M", "T", "W", "T", "F", "S", "S"]; Label { required property string modelData; width: 34; height: 22; horizontalAlignment: Text.AlignHCenter; text: modelData; muted: true; font.pixelSize: Theme.sizeSmall } }
                Repeater {
                    model: grid.parent.first + grid.parent.days
                    Rectangle {
                        required property int index
                        readonly property int day: index - grid.parent.first + 1
                        readonly property bool today: day === grid.parent.now.getDate()
                        width: 34; height: 30; radius: Theme.corner(30)
                        color: today ? Theme.accent : "transparent"
                        Label { anchors.centerIn: parent; visible: parent.day > 0; text: parent.day; color: parent.today ? Theme.onAccent : Theme.text; strong: parent.today; font.pixelSize: Theme.sizeSmall + 1 }
                    }
                }
            }
        } }

    // ── system usage ──
    Component { id: usageRings
        CardBg {
            implicitWidth: ur.implicitWidth + 32; implicitHeight: 118
            Row {
                id: ur
                anchors.centerIn: parent
                spacing: 18
                Repeater {
                    model: [[Stats.cpu, Math.round(Stats.cpu * 100) + "%", "CPU"], [Stats.mem, Math.round(Stats.mem * 100) + "%", "Memory"], [Math.min(1, Stats.temp / 100), Math.round(Stats.temp) + "°", "Temp"]]
                    Ring { required property var modelData; width: 80; height: 80; thickness: 7; value: modelData[0]; text: modelData[1]; caption: modelData[2] }
                }
            }
        } }
    Component { id: usageBars
        CardBg {
            implicitWidth: 300; implicitHeight: bc.implicitHeight + 28
            Column {
                id: bc
                x: 14; y: 14; width: parent.width - 28
                spacing: 10
                Repeater {
                    model: [["CPU", Stats.cpu], ["Memory", Stats.mem], ["GPU", Stats.gpu], ["Temperature", Math.min(1, Stats.temp / 100)]]
                    Column {
                        required property var modelData
                        width: bc.width
                        spacing: 4
                        Label { text: modelData[0] + "  ·  " + Math.round(modelData[1] * 100) + (modelData[0] === "Temperature" ? "°" : "%"); font.pixelSize: Theme.sizeSmall }
                        Rectangle { width: parent.width; height: 8; radius: 4; color: Theme.ringTrack
                            Rectangle { height: parent.height; radius: 4; width: Math.max(8, parent.width * modelData[1]); color: Theme.accent } }
                    }
                }
            }
        } }

    // ── notes ──
    Component { id: notesCard
        CardBg {
            implicitWidth: 300; implicitHeight: 220
            Row { x: 16; y: 12; spacing: 6; Icon { name: "sticky_note_2"; size: 18; color: Theme.accent } Label { text: "Notes"; strong: true } }
            TextEdit {
                id: nt
                x: 16; y: 42; width: parent.width - 32; height: parent.height - 56
                text: Store.get("notes.text", "")
                wrapMode: TextEdit.Wrap
                color: Theme.text
                selectionColor: Theme.selected
                font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody
                clip: true
                readOnly: !w.live
                onTextChanged: if (w.live) saveNt.restart()
                Timer { id: saveNt; interval: 600; onTriggered: if (Store.get("notes.text", "") !== nt.text) Store.set("notes.text", nt.text) }
                Label { visible: nt.text === ""; text: "Write something…"; muted: true }
            }
        } }

    // ── a picture ──
    readonly property string imagePath: Store.get("widgets.imagePath", "")
    Component { id: imageRounded
        Rectangle {
            implicitWidth: 260
            implicitHeight: img.status === Image.Ready ? Math.round(260 * img.implicitHeight / Math.max(1, img.implicitWidth)) : 160
            radius: Theme.corner(80, 10); color: Qt.alpha(Theme.card, 0.82); clip: true
            Image { id: img; anchors.fill: parent; source: w.imagePath !== "" ? Wall.url(w.imagePath) : ""; sourceSize.width: 520; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            Label { anchors.centerIn: parent; visible: w.imagePath === ""; width: parent.width - 20; wrapMode: Text.Wrap; horizontalAlignment: Text.AlignHCenter; text: "Pick a picture in Settings → Desktop"; muted: true; font.pixelSize: Theme.sizeSmall }
        } }
    Component { id: imageCircle
        Rectangle {
            implicitWidth: 200; implicitHeight: 200
            radius: 100; color: Qt.alpha(Theme.card, 0.82); clip: true
            border.width: 3; border.color: Theme.accent
            Image { anchors.fill: parent; anchors.margins: 3; source: w.imagePath !== "" ? Wall.url(w.imagePath) : ""; sourceSize.width: 400; fillMode: Image.PreserveAspectCrop; asynchronous: true; layer.enabled: true }
            Icon { anchors.centerIn: parent; visible: w.imagePath === ""; name: "image"; size: 48; color: Theme.faint }
        } }

    // ── greeting ──
    Component { id: greeting
        Column {
            readonly property int h: clock.hours
            Plain { text: (h < 5 ? "Good night" : (h < 12 ? "Good morning" : (h < 18 ? "Good afternoon" : "Good evening"))) + ", " + (Quickshell.env("USER") || ""); font.pixelSize: 34; font.weight: Font.DemiBold }
            Plain { text: Notifs.list.length > 0 ? Notifs.list.length + " notifications waiting" : "Nothing waiting"; font.pixelSize: 18; color: w.inkSoft }
        } }

    // ── notifications (the lock screen) ──
    Component { id: notifList
        Column {
            spacing: 8
            width: 360
            Repeater {
                model: Notifs.list.slice(0, 3)
                Rectangle {
                    required property var modelData
                    width: 360; height: 54
                    radius: Theme.corner(54, 6)
                    color: Qt.alpha(Theme.frame, 0.82)
                    Rectangle { id: nb; x: 8; width: 38; height: 38; radius: 19; anchors.verticalCenter: parent.verticalCenter; color: Theme.accentContainer
                        Icon { anchors.centerIn: parent; name: "notifications"; size: 19; filled: true; color: Theme.onAccentContainer } }
                    Column {
                        anchors.left: nb.right; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        Label { width: parent.width; text: modelData.appName || "Notification"; muted: true; font.pixelSize: Theme.sizeSmall }
                        Label { width: parent.width; text: modelData.summary || ""; strong: true }
                    }
                }
            }
            Plain { visible: Notifs.list.length === 0; text: "No notifications"; font.pixelSize: 16; color: w.inkSoft }
        } }
}
