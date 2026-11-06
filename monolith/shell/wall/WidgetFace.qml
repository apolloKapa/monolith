import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Services.UPower
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
    // a playing track's position only updates when asked
    Timer { interval: 500; repeat: true; running: w.live && !!w.player && w.player.isPlaying && (w.type === "media"); onTriggered: w.player.positionChanged() }
    function mmss(t) { t = Math.max(0, Math.floor(t || 0)); return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0"); }

    // CPU / memory / temperature / disk: [value 0..1, big text, name, detail, history, icon]
    readonly property var metric: ({
        cpu: [Stats.cpu, Math.round(Stats.cpu * 100) + "%", "CPU", Stats.cpuHist.length ? "average " + Math.round(Stats.cpuHist.reduce((a, b) => a + b, 0) / Stats.cpuHist.length * 100) + "%" : "", Stats.cpuHist, "developer_board"],
        ram: [Stats.mem, Math.round(Stats.mem * 100) + "%", "Memory", Stats.bytes(Stats.memUsed) + " of " + Stats.bytes(Stats.memTotal), Stats.memHist, "memory_alt"],
        temp: [Math.min(1, Stats.temp / 100), Math.round(Stats.temp) + "°", "Temperature", Stats.gpuTemp > 0 ? "GPU " + Math.round(Stats.gpuTemp) + "°" : "CPU", Stats.tempHist, "device_thermostat"],
        disk: [Stats.disk, Math.round(Stats.disk * 100) + "%", "Disk", Stats.bytes(Stats.diskUsed) + " of " + Stats.bytes(Stats.diskTotal), [], "hard_drive"]
    })[w.type] || [0, "", "", "", [], "help"]

    // the battery: the laptop's, else the first device that reports one (a mouse, a headset)
    readonly property var battery: {
        const d = UPower.displayDevice;
        if (d && d.isPresent && d.isLaptopBattery) return d;
        return UPower.devices.values.find(x => x.isPresent && x.percentage > 0) || null;
    }
    readonly property real batteryLevel: battery ? (battery.percentage > 1 ? battery.percentage / 100 : battery.percentage) : 0
    readonly property bool batteryCharging: !!battery && (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)
    readonly property string batteryName: battery ? (battery.isLaptopBattery ? "Battery" : (battery.model || "Battery")) : "No battery"
    readonly property string avatar: Store.get("general.avatar", "") || ((Prefs.raw.general && Prefs.raw.general.avatarPath) ? Prefs.raw.general.avatarPath : (Quickshell.env("HOME") + "/.face"))

    component CardBg: Rectangle { radius: Theme.corner(80, 10); color: Qt.alpha(Theme.card, 0.82); border.width: Theme.outlineW; border.color: Theme.outlineColor }

    Loader {
        id: body
        sourceComponent: ({
            "clock/digital": clockDigital, "clock/stacked": clockStacked, "clock/analog": clockAnalog, "clock/minimal": clockMinimal,
            "clock/stretched": clockStretched, "clock/big": clockBig, "clock/material": clockMaterial, "clock/materialAnalog": clockMaterialAnalog, "clock/lumen": clockLumen,
            "date/full": dateFull, "date/compact": dateCompact,
            "weather/pill": weatherPill, "weather/full": weatherFull, "weather/round": weatherRound,
            "media/card": mediaCard, "media/cover": mediaCover, "media/controls": mediaControls, "media/lyrics": mediaLyrics, "media/lyricLine": mediaLyricLine, "media/round": mediaRound,
            "visualizer/bars": visBars, "visualizer/wave": visWave,
            "calendar/month": calMonth,
            "usage/rings": usageRings, "usage/bars": usageBars,
            "cpu/number": metricNumber, "ram/number": metricNumber, "temp/number": metricNumber, "disk/number": metricNumber,
            "cpu/circle": metricCircle, "ram/circle": metricCircle, "temp/circle": metricCircle, "disk/circle": metricCircle,
            "cpu/card": metricCard, "ram/card": metricCard, "temp/card": metricCard, "disk/card": metricCard,
            "battery/card": batteryCard, "battery/circle": batteryCircle,
            "github/grid": githubGrid,
            "notes/card": notesCard,
            "image/rounded": imageRounded, "image/circle": imageCircle, "image/rect": imageRect,
            "user/card": userCard,
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

    // ── more clocks ──
    Component { id: clockStretched
        Item {
            implicitWidth: st.implicitWidth * 1.7; implicitHeight: st.implicitHeight
            Plain {
                id: st
                text: Qt.formatTime(clock.date, "HH:mm"); font.pixelSize: 110; font.weight: Font.Black
                transform: Scale { xScale: 1.7 }
            }
        } }
    Component { id: clockBig
        Column {
            spacing: -10
            Plain { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatTime(clock.date, "HH:mm"); font.pixelSize: 168; font.weight: Font.Thin }
            Plain { anchors.horizontalCenter: parent.horizontalCenter; text: Qt.formatDate(clock.date, "dddd d MMMM"); font.pixelSize: 26; color: w.inkSoft }
        } }
    Component { id: clockMaterial
        Row {
            spacing: 10
            Repeater {
                model: [Qt.formatTime(clock.date, "HH"), Qt.formatTime(clock.date, "mm")]
                Rectangle {
                    required property string modelData
                    required property int index
                    width: 150; height: 170
                    radius: Theme.corner(170, 14)
                    color: index === 0 ? Theme.accentContainer : Qt.alpha(Theme.card, 0.85)
                    Text { anchors.centerIn: parent; text: parent.modelData; font.family: Theme.fontFamily; font.pixelSize: 108; font.weight: Font.Medium; color: parent.index === 0 ? Theme.onAccentContainer : Theme.text }
                }
            }
        } }
    Component { id: clockMaterialAnalog
        Item {
            implicitWidth: 220; implicitHeight: 220
            Rectangle { anchors.fill: parent; radius: width / 2; color: Theme.accentContainer }
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    width: 8; height: 8; radius: 4
                    color: Qt.alpha(Theme.onAccentContainer, index % 3 === 0 ? 0.8 : 0.35)
                    x: 110 - 4 + Math.sin(index * Math.PI / 6) * 90
                    y: 110 - 4 - Math.cos(index * Math.PI / 6) * 90
                }
            }
            Hand { width: 16; len: 56; color: Theme.onAccentContainer; angle: (clock.hours % 12 + clock.minutes / 60) * 30 }
            Hand { width: 10; len: 80; color: Theme.accent; angle: (clock.minutes + clock.seconds / 60) * 6 }
            Rectangle { x: 102; y: 102; width: 16; height: 16; radius: 8; color: Theme.onAccentContainer }
        } }
    Component { id: clockLumen
        Item {
            implicitWidth: lt.implicitWidth + 40; implicitHeight: lt.implicitHeight + 40
            Text {
                id: lt
                anchors.centerIn: parent
                text: Qt.formatTime(clock.date, "HH:mm")
                font.family: Theme.fontFamily; font.pixelSize: 120; font.weight: Font.ExtraLight
                color: Qt.lighter(Theme.accent, 1.35)
                layer.enabled: true
                layer.effect: MultiEffect { shadowEnabled: true; shadowColor: Theme.accent; shadowBlur: 1.0; shadowVerticalOffset: 0; shadowHorizontalOffset: 0; blurMax: 48 }
            }
        } }

    // ── weather, round ──
    Component { id: weatherRound
        Rectangle {
            implicitWidth: 180; implicitHeight: 180
            radius: 90; color: Qt.alpha(Theme.card, 0.82)
            border.width: Theme.outlineW; border.color: Theme.outlineColor
            Column {
                anchors.centerIn: parent
                spacing: 2
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : "cloud"; size: 48; filled: true; color: Theme.accent }
                Text { anchors.horizontalCenter: parent.horizontalCenter; text: Weather.ready ? Math.round(Weather.current.temp) + Weather.unit : "—"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 34; font.weight: Font.Medium }
                Label { anchors.horizontalCenter: parent.horizontalCenter; width: 140; horizontalAlignment: Text.AlignHCenter; text: Weather.city; muted: true; font.pixelSize: Theme.sizeSmall }
            }
        } }

    // ── now playing: controls, lyrics, round ──
    Component { id: mediaControls
        CardBg {
            implicitWidth: 380; implicitHeight: 158
            Rectangle {
                id: mcArt
                x: 14; y: 14; width: 88; height: 88; radius: Theme.corner(88, 6); color: Theme.control; clip: true
                Icon { anchors.centerIn: parent; name: "music_note"; size: 34; color: Theme.faint }
                Image { anchors.fill: parent; source: w.player ? (w.player.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop }
            }
            Column {
                anchors.left: mcArt.right; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 14
                y: 18
                Label { width: parent.width; text: w.player ? w.player.trackTitle : "Nothing playing"; strong: true; font.pixelSize: Theme.sizeTitle }
                Label { width: parent.width; text: w.player ? w.player.trackArtist : ""; muted: true }
                Item { width: 1; height: 10 }
                Row {
                    spacing: 6
                    Repeater {
                        model: [["skip_previous", 0], [w.player && w.player.isPlaying ? "pause" : "play_arrow", 1], ["skip_next", 2]]
                        Pressable {
                            required property var modelData
                            width: modelData[1] === 1 ? 44 : 36; height: width
                            anchors.verticalCenter: parent.verticalCenter
                            color: modelData[1] === 1 ? Theme.accent : (hovered ? Theme.containerHigh : "transparent")
                            ink: modelData[1] === 1 ? Theme.onAccent : Theme.text
                            enabledInput: !!w.player
                            onClicked: modelData[1] === 0 ? w.player.previous() : (modelData[1] === 1 ? w.player.togglePlaying() : w.player.next())
                            Icon { anchors.centerIn: parent; name: parent.modelData[0]; size: 22; filled: true; color: parent.modelData[1] === 1 ? Theme.onAccent : Theme.text }
                        }
                    }
                }
            }
            Item {
                x: 14; y: 118; width: parent.width - 28; height: 26
                readonly property real len: w.player && w.player.lengthSupported ? w.player.length : 0
                readonly property real pos: w.player && w.player.positionSupported ? w.player.position : 0
                Rectangle { y: 4; width: parent.width; height: 5; radius: 3; color: Theme.ringTrack
                    Rectangle { height: parent.height; radius: 3; color: Theme.accent; width: parent.parent.len > 0 ? parent.width * Math.min(1, parent.parent.pos / parent.parent.len) : 0 } }
                Label { y: 12; text: w.mmss(parent.pos); muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                Label { y: 12; anchors.right: parent.right; text: w.mmss(parent.len); muted: true; font.pixelSize: Theme.sizeSmall - 1 }
            }
        } }
    Component { id: mediaLyrics
        CardBg {
            implicitWidth: 440; implicitHeight: 220
            Row { x: 16; y: 12; spacing: 6
                Icon { name: "lyrics"; size: 18; color: Theme.accent }
                Label { width: 380; text: w.player ? w.player.trackTitle + " · " + w.player.trackArtist : "Nothing playing"; strong: true; font.pixelSize: Theme.sizeSmall + 1 } }
            Column {
                x: 16; y: 46; width: parent.width - 32
                spacing: 6
                Repeater {
                    model: 5
                    Text {
                        required property int index
                        readonly property int at: Lyrics.currentIndex + index - 1
                        width: parent.width
                        elide: Text.ElideRight
                        text: at >= 0 && at < Lyrics.lines.length ? Lyrics.lines[at].text : ""
                        font.family: Theme.fontFamily
                        font.pixelSize: index === 1 ? 20 : 15
                        font.weight: index === 1 ? Font.Bold : Font.Normal
                        color: index === 1 ? Theme.text : Theme.faint
                    }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: Lyrics.lines.length === 0
                text: !w.player ? "Play something to see its lyrics" : (Lyrics.state === "loading" ? "Looking for lyrics…" : "No synced lyrics for this song")
                muted: true
            }
        } }
    Component { id: mediaLyricLine
        Plain {
            width: 700
            wrapMode: Text.Wrap
            text: Lyrics.currentIndex >= 0 && Lyrics.currentIndex < Lyrics.lines.length ? Lyrics.lines[Lyrics.currentIndex].text
                  : (w.player ? w.player.trackTitle + " — " + w.player.trackArtist : "♪  Nothing playing")
            font.pixelSize: 30; font.weight: Font.DemiBold
        } }
    Component { id: mediaRound
        Item {
            implicitWidth: 220; implicitHeight: 220
            Rectangle {
                id: disc
                anchors.fill: parent
                radius: width / 2; color: Theme.control; clip: true
                border.width: 4; border.color: Theme.accent
                Icon { anchors.centerIn: parent; name: "album"; size: 80; color: Theme.faint }
                Image { anchors.fill: parent; anchors.margins: 4; source: w.player ? (w.player.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: roundMask } }
                RotationAnimation on rotation { from: 0; to: 360; duration: 20000; loops: Animation.Infinite; running: w.live && !!w.player && w.player.isPlaying }
            }
            Rectangle { id: roundMask; visible: false; width: 212; height: 212; radius: 106; layer.enabled: true }
            Pressable {
                anchors.centerIn: parent
                width: 54; height: 54; radius: 27
                color: Qt.alpha(Theme.frame, 0.85)
                enabledInput: !!w.player
                onClicked: w.player.togglePlaying()
                Icon { anchors.centerIn: parent; name: w.player && w.player.isPlaying ? "pause" : "play_arrow"; size: 28; filled: true }
            }
        } }

    // ── visualiser (cava) ──
    Component { id: visBars
        Item {
            implicitWidth: 520; implicitHeight: 140
            Component.onCompleted: if (w.live) Cava.hold()
            Component.onDestruction: if (w.live) Cava.release()
            Row {
                anchors.bottom: parent.bottom
                spacing: 4
                Repeater {
                    model: Cava.count
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: (520 - 4 * (Cava.count - 1)) / Cava.count
                        height: Math.max(4, 140 * (Cava.bars[index] || (w.live ? 0 : 0.2 + 0.6 * Math.abs(Math.sin(index / 3)))))
                        radius: width / 2
                        color: Theme.accent
                        opacity: 0.55 + 0.45 * (height / 140)
                        Behavior on height { NumberAnimation { duration: 60 } }
                    }
                }
            }
        } }
    Component { id: visWave
        Canvas {
            id: wave
            implicitWidth: 520; implicitHeight: 140
            Component.onCompleted: if (w.live) Cava.hold()
            Component.onDestruction: if (w.live) Cava.release()
            Connections { target: Cava; function onBarsChanged() { wave.requestPaint(); } }
            onPaint: {
                const c = getContext("2d");
                c.reset();
                const v = Cava.bars.length ? Cava.bars : Array.from({ length: Cava.count }, (_, i) => 0.2 + 0.5 * Math.abs(Math.sin(i / 4)));
                const n = v.length, step = width / (n - 1);
                const y = i => height - 6 - v[i] * (height - 12);
                c.beginPath();
                c.moveTo(0, height);
                c.lineTo(0, y(0));
                for (let i = 1; i < n; i++) {
                    const mx = (i - 0.5) * step;
                    c.bezierCurveTo(mx, y(i - 1), mx, y(i), i * step, y(i));
                }
                c.lineTo(width, height);
                c.closePath();
                const g = c.createLinearGradient(0, 0, 0, height);
                g.addColorStop(0, Qt.alpha(Theme.accent, 0.85));
                g.addColorStop(1, Qt.alpha(Theme.accent, 0.1));
                c.fillStyle = g;
                c.fill();
            }
        } }

    // ── CPU / memory / temperature / disk ──
    Component { id: metricNumber
        Row {
            spacing: 12
            Icon { anchors.verticalCenter: parent.verticalCenter; name: w.metric[5]; size: 40; color: w.ink }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                Plain { text: w.metric[1]; font.pixelSize: 54; font.weight: Font.DemiBold }
                Plain { text: w.metric[2]; font.pixelSize: 17; color: w.inkSoft }
            }
        } }
    Component { id: metricCircle
        Rectangle {
            implicitWidth: 150; implicitHeight: 150
            radius: 75; color: Qt.alpha(Theme.card, 0.82)
            border.width: Theme.outlineW; border.color: Theme.outlineColor
            Ring { anchors.centerIn: parent; width: 126; height: 126; thickness: 10; value: w.metric[0]; text: w.metric[1]; caption: w.metric[2] }
        } }
    Component { id: metricCard
        CardBg {
            implicitWidth: 280; implicitHeight: 130
            Row { x: 16; y: 14; spacing: 8
                Bubble { size: 34; icon: w.metric[5] }
                Column { anchors.verticalCenter: parent.verticalCenter
                    Label { text: w.metric[2]; strong: true }
                    Label { text: w.metric[3]; muted: true; font.pixelSize: Theme.sizeSmall } } }
            Text { anchors.right: parent.right; anchors.rightMargin: 16; y: 12; text: w.metric[1]; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 30; font.weight: Font.Medium }
            Spark { visible: w.metric[4].length > 1; x: 16; y: 66; width: parent.width - 32; height: 48; values: w.metric[4] }
            Rectangle { visible: w.metric[4].length <= 1; x: 16; y: 88; width: parent.width - 32; height: 10; radius: 5; color: Theme.ringTrack
                Rectangle { height: parent.height; radius: 5; color: Theme.accent; width: Math.max(10, parent.width * w.metric[0]) } }
        } }

    // ── battery ──
    Component { id: batteryCard
        CardBg {
            implicitWidth: 280; implicitHeight: 96
            Row {
                anchors.verticalCenter: parent.verticalCenter; x: 16; spacing: 14
                Icon { anchors.verticalCenter: parent.verticalCenter; size: 44; filled: true; color: w.batteryLevel < 0.2 && !w.batteryCharging ? Theme.danger : Theme.accent
                    name: w.batteryCharging ? "battery_charging_full" : (w.batteryLevel > 0.9 ? "battery_full" : (w.batteryLevel > 0.6 ? "battery_5_bar" : (w.batteryLevel > 0.35 ? "battery_3_bar" : "battery_1_bar"))) }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: w.battery ? Math.round(w.batteryLevel * 100) + "%" : "—"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 30; font.weight: Font.Medium }
                    Label { text: w.batteryName + (w.batteryCharging ? "  ·  charging" : ""); muted: true; font.pixelSize: Theme.sizeSmall }
                }
            }
        } }
    Component { id: batteryCircle
        Rectangle {
            implicitWidth: 150; implicitHeight: 150
            radius: 75; color: Qt.alpha(Theme.card, 0.82)
            border.width: Theme.outlineW; border.color: Theme.outlineColor
            Ring { anchors.centerIn: parent; width: 126; height: 126; thickness: 10; value: w.batteryLevel
                color: w.batteryLevel < 0.2 && !w.batteryCharging ? Theme.danger : Theme.accent
                text: w.battery ? Math.round(w.batteryLevel * 100) + "%" : "—"; caption: w.batteryCharging ? "Charging" : w.batteryName }
        } }

    // ── GitHub contributions ──
    Component { id: githubGrid
        CardBg {
            implicitWidth: 53 * 11 + 32; implicitHeight: 7 * 11 + 76
            Component.onCompleted: if (w.live) GitHub.hold()
            Component.onDestruction: if (w.live) GitHub.release()
            Row { x: 16; y: 12; spacing: 8
                Icon { name: "commit"; size: 18; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Label { text: GitHub.user !== "" ? GitHub.user : "GitHub"; strong: true; anchors.verticalCenter: parent.verticalCenter }
                Label { visible: GitHub.state === "ok"; text: GitHub.total + " contributions in the last year"; muted: true; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter } }
            Grid {
                x: 16; y: 44
                rows: 7; flow: Grid.TopToBottom
                spacing: 2
                Repeater {
                    // pad the first week so rows are weekdays (Sunday on top, like GitHub)
                    model: GitHub.days.length ? new Date(GitHub.days[0].date).getDay() + GitHub.days.length : (w.live ? 0 : 7 * 53)
                    Rectangle {
                        required property int index
                        readonly property int pad: GitHub.days.length ? new Date(GitHub.days[0].date).getDay() : 0
                        readonly property var day: GitHub.days[index - pad]
                        width: 9; height: 9; radius: 2
                        visible: index >= pad
                        color: day && day.level > 0 ? Qt.alpha(Theme.accent, 0.25 + 0.1875 * day.level) : Theme.ringTrack
                    }
                }
            }
            Label {
                anchors.centerIn: parent
                visible: w.live && GitHub.state !== "ok"
                text: GitHub.user === "" ? "Set your GitHub name in Settings → Desktop" : (GitHub.state === "error" ? "Couldn't load " + GitHub.user + "'s contributions" : "Loading…")
                muted: true
            }
        } }

    // ── a picture with square corners, and you ──
    Component { id: imageRect
        Rectangle {
            implicitWidth: 260
            implicitHeight: rimg.status === Image.Ready ? Math.round(260 * rimg.implicitHeight / Math.max(1, rimg.implicitWidth)) : 160
            radius: 3; color: Qt.alpha(Theme.card, 0.82); clip: true
            Image { id: rimg; anchors.fill: parent; source: w.imagePath !== "" ? Wall.url(w.imagePath) : ""; sourceSize.width: 520; fillMode: Image.PreserveAspectCrop; asynchronous: true }
            Icon { anchors.centerIn: parent; visible: w.imagePath === ""; name: "image"; size: 48; color: Theme.faint }
        } }
    Component { id: userCard
        CardBg {
            implicitWidth: Math.max(260, uc.implicitWidth + 120); implicitHeight: 96
            FileView { id: hostF; path: "/etc/hostname" }
            Rectangle {
                id: ua
                x: 16; anchors.verticalCenter: parent.verticalCenter
                width: 64; height: 64; radius: 32; color: Theme.accentContainer; clip: true
                Image { id: uimg; anchors.fill: parent; source: Wall.url(w.avatar); fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(128, 128); layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: uaMask } }
                Rectangle { id: uaMask; visible: false; width: 64; height: 64; radius: 32; layer.enabled: true }
                Icon { anchors.centerIn: parent; visible: uimg.status !== Image.Ready; name: "person"; size: 34; filled: true; color: Theme.onAccentContainer }
            }
            Column {
                id: uc
                anchors.left: ua.right; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter
                Text { text: Quickshell.env("USER") || ""; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 24; font.weight: Font.DemiBold }
                Label { text: "@" + ((hostF.text() || "").trim() || "localhost") + "  ·  up " + w.uptime; muted: true; font.pixelSize: Theme.sizeSmall }
            }
        } }
    property string uptime: ""
    FileView { id: upF; path: "/proc/uptime" }
    Timer {
        interval: 60000; repeat: true; triggeredOnStart: true
        running: w.live && w.type === "user"
        onTriggered: {
            upF.reload();
            const s = Math.floor(parseFloat((upF.text() || "0").split(" ")[0]));
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
            w.uptime = (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "m";
        }
    }

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
