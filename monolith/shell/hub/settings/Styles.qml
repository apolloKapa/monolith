import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Theme → Style: the whole look (18 styles, each previewed), then its colours: the wallpaper's,
// the style's own, or one of the colour themes.
ColumnLayout {
    id: sec
    spacing: 8

    // every colour theme with its palette, for the swatches
    property var themes: []
    Process {
        running: true
        command: ["sh", "-c", "cd \"$1\" && for f in *.json; do [ \"$f\" = Matugen.json ] && continue; printf '%s\\t' \"${f%.json}\"; tr -d '\\n' < \"$f\"; echo; done", "_", Look.themesDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.split("\n")) {
                    const i = l.indexOf("\t");
                    if (i < 0) continue;
                    try { out.push({ name: l.substring(0, i), colors: JSON.parse(l.substring(i + 1)).colors || {} }); } catch (e) {}
                }
                sec.themes = out;
            }
        }
    }

    // a style: its colours as a little window, with its corners, outline and font
    component StyleCard: Pressable {
        id: sc
        property var st: ({})
        readonly property bool on: Look.styleId === st.id
        // its look: its own colours, else the wallpaper's (as they are now)
        readonly property var pc: st.colors || null
        readonly property color bg: st.oled ? "#000000" : (pc ? pc.base : Theme.m("surface", "#16161c"))
        readonly property color panel: st.oled ? "#141414" : (pc ? pc.surface0 : Theme.m("surface_container_high", "#26262e"))
        readonly property color acc: pc ? pc.mauve : Theme.m("primary", "#b6c4ff")
        readonly property color ink: pc ? pc.text : Theme.m("on_surface", "#e6e6ee")
        readonly property real rad: st.square ? 0 : Math.min(14, 6 * (st.radiusScale || 1))
        Layout.fillWidth: true
        Layout.preferredHeight: 138
        radius: Theme.corner(138, 6)
        color: on ? Theme.accentContainer : Theme.containerHigh
        onClicked: Look.pickStyle(st.id)
        Rectangle {
            x: 10; y: 10
            width: parent.width - 20; height: 74
            radius: sc.rad + 4
            color: sc.bg
            opacity: sc.st.opaque === false ? 0.8 : 1
            border.width: sc.st.outline ? sc.st.outline[0] : 0
            border.color: sc.st.outlineRole === "accent" || sc.st.outlineRole === "accentSoft" ? sc.acc : (sc.st.outlineRole === "ink" || sc.st.outlineRole === "text" ? sc.ink : Qt.alpha(sc.ink, 0.25))
            // a hard shadow, for the styles that have one
            Rectangle {
                visible: (sc.st.hardShadow || 0) > 0
                z: -1
                x: sc.st.hardShadow || 0; y: sc.st.hardShadow || 0
                width: parent.width; height: parent.height
                radius: parent.radius
                color: sc.ink
            }
            Row {
                anchors.centerIn: parent
                spacing: 8
                Rectangle { width: 44; height: 44; radius: Math.min(22, sc.rad * 1.5); color: sc.acc
                    Text { anchors.centerIn: parent; text: "Aa"; color: sc.bg; font.family: sc.st.font || Theme.fontFamily; font.pixelSize: 17; font.bold: true } }
                Column {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter
                    Rectangle { width: 80; height: 10; radius: Math.min(5, sc.rad); color: sc.panel }
                    Rectangle { width: 56; height: 10; radius: Math.min(5, sc.rad); color: sc.panel }
                    Rectangle { width: 68; height: 10; radius: Math.min(5, sc.rad); color: Qt.alpha(sc.acc, 0.6) }
                }
            }
        }
        Label { x: 12; y: 92; width: parent.width - 40; text: sc.st.name; strong: true; color: sc.on ? Theme.onAccentContainer : Theme.text }
        Label { x: 12; y: 110; width: parent.width - 24; text: sc.st.desc || ""; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
        Icon { visible: sc.on; x: parent.width - 28; y: 92; name: "check_circle"; filled: true; size: 18; color: Theme.accent }
    }

    SettingRow { icon: "style"; title: "Style"; desc: "The whole look: shapes, outlines, shadows, type and its colours. Now " + Look.style.name }
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 8; columnSpacing: 8
        Repeater {
            model: Look.styles
            StyleCard { required property var modelData; st: modelData }
        }
    }

    // ── colours ──
    SettingRow {
        icon: "palette"; title: "Colours"
        desc: "Now: " + (Look.paletteName === "wallpaper" ? "from your wallpaper" : (Look.paletteName === "style" ? Look.style.name + "'s own" : Look.paletteName))
        Row {
            spacing: 6
            Button { text: "Wallpaper"; primary: Look.paletteName === "wallpaper"; onClicked: Look.pickPalette("wallpaper") }
            Button { visible: !!Look.style.colors; text: Look.style.name + "'s own"; primary: Look.paletteName === "style"; onClicked: Look.pickPalette("style") }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: flow.implicitHeight + 20
        radius: Theme.corner(56, 2)
        color: Theme.containerHigh
        Flow {
            id: flow
            x: 10; y: 10
            width: parent.width - 20
            spacing: 6
            Repeater {
                model: sec.themes
                Pressable {
                    required property var modelData
                    readonly property bool on: Look.paletteName === modelData.name
                    height: 34
                    width: tn.implicitWidth + 74
                    color: on ? Theme.accentContainer : Theme.control
                    onClicked: Look.pickPalette(modelData.name)
                    // its colours: background, panel, accent, text
                    Row {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: -5
                        Repeater {
                            model: ["base", "surface1", "mauve", "text"]
                            Rectangle { required property string modelData; width: 16; height: 16; radius: 8; color: parent.parent.modelData.colors[modelData] || "#888"; border.width: 1; border.color: Qt.alpha("#000", 0.3) }
                        }
                    }
                    Label { id: tn; x: 58; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.name; strong: parent.on; font.pixelSize: Theme.sizeSmall }
                }
            }
        }
    }
}
