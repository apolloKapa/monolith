import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Theme → Style: the whole look (17 styles, each previewed; blur is a toggle under them), then its colours: the wallpaper's,
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

    Label { text: "Style"; strong: true; font.pixelSize: Theme.sizeTitle; Layout.leftMargin: 4 }
    SettingRow { keys: ["theme.style", "theme.palette"]; icon: "style"; title: "The shell's look"; desc: "Shapes, outlines, shadows and type, with colours to match. Now " + Look.style.name + ". You can still pick other colours below" }
    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 8; columnSpacing: 8
        Repeater {
            model: Look.styles
            StyleCard { required property var modelData; st: modelData }
        }
    }
    SettingRow {
        keys: ["theme.blur", "theme.panelOpacity"]
        icon: "blur_on"; title: "Blur behind panels"
        desc: Theme.liquid ? "Liquid glass is glass already: it bends and frosts what's behind it by itself, so blur is off with it"
            : "With any style: the bar, menus, dock and pop-ups turn see-through and blur what's behind them"
        Toggle {
            enabled: !Theme.liquid
            opacity: enabled ? 1 : 0.4
            checked: Theme.blur
            onToggled: on => { Store.set("theme.blur", on); if (on && Theme.panelOpacity > 0.95) Store.set("theme.panelOpacity", 0.75); }
        }
    }

    // ── colours ──
    function lum(hex) { const c = Qt.color(hex || "#000"); return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }
    // the search above the themes: by name or description, any order of words ("light twi")
    property string themeFilter: ""
    function matches(t) {
        const words = themeFilter.toLowerCase().split(/\s+/).filter(w => w);
        const hay = (t.name + " " + (t.desc || "") + " " + (lum(t.colors.base) < 0.5 ? "dark" : "light")).toLowerCase();
        return words.every(w => hay.indexOf(w) !== -1);
    }
    readonly property var shownThemes: themeFilter.trim() === "" ? themes : themes.filter(t => matches(t))
    readonly property var darkThemes: shownThemes.filter(t => lum(t.colors.base) < 0.5)
    readonly property var lightThemes: shownThemes.filter(t => lum(t.colors.base) >= 0.5)

    Label { text: "Colours"; strong: true; font.pixelSize: Theme.sizeTitle; Layout.leftMargin: 4; Layout.topMargin: 10 }
    SettingRow {
        key: "theme.palette"
        icon: "palette"; title: "Where the colours come from"
        desc: "Now: " + (Look.paletteName === "wallpaper" ? "your wallpaper" : (Look.paletteName === "style" ? "the " + Look.style.name + " style" : "the " + Look.paletteName + " theme")) + ". A colour theme below works with any style"
        Row {
            spacing: 6
            Button { text: "From the wallpaper"; icon: "wallpaper"; primary: Look.paletteName === "wallpaper"; onClicked: Look.pickPalette("wallpaper") }
            Button { visible: !!Look.style.colors; text: Look.style.name + "'s colours"; primary: Look.paletteName === "style"; onClicked: Look.pickPalette("style") }
        }
    }

    // a colour theme: a little window in its colours, named in its own text colour
    component ThemeCard: Pressable {
        id: tc
        property var th: ({ name: "", colors: {} })
        readonly property var k: th.colors
        readonly property bool on: Look.paletteName === th.name
        // a quarter of the row, also when a search leaves only one or two (they stretched)
        Layout.preferredWidth: (sec.width - 24) / 4
        Layout.preferredHeight: 92
        radius: Theme.corner(92, 4)
        color: k.base || Theme.containerHigh
        border.width: on ? 3 : 1
        border.color: on ? Theme.accent : Qt.alpha(k.text || Theme.text, 0.15)
        onClicked: Look.pickPalette(th.name)
        Column {
            x: 12; y: 10
            width: parent.width - 24
            spacing: 6
            Row {
                width: parent.width
                spacing: 6
                Text { width: parent.width - 30; text: tc.th.name; elide: Text.ElideRight; color: tc.k.text || Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeBody; font.weight: Font.DemiBold }
                Icon { visible: tc.on; name: "check_circle"; filled: true; size: 18; color: tc.k.mauve || Theme.accent }
            }
            // a panel with an accent button and a line of text (a theme with apps colours of its
            // own, like Twilight's light windows in a dark shell: the panel is an app in those)
            Rectangle {
                readonly property var a: tc.th.apps || tc.k
                width: parent.width; height: 26
                radius: 6
                color: (tc.th.apps ? a.base : a.surface0) || Theme.container
                Rectangle { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 34; height: 14; radius: 7; color: parent.a.mauve || Theme.accent }
                Rectangle { x: 48; anchors.verticalCenter: parent.verticalCenter; width: parent.width * 0.4; height: 5; radius: 2.5; color: Qt.alpha(parent.a.text || Theme.text, 0.6) }
            }
            // its accents
            Row {
                spacing: 4
                Repeater {
                    model: ["red", "peach", "yellow", "green", "teal", "blue", "pink"]
                    Rectangle { required property string modelData; width: 12; height: 12; radius: 6; color: tc.k[modelData] || "transparent" }
                }
            }
        }
    }
    Field {
        id: themeSearch
        Layout.fillWidth: true
        placeholder: "Find a colour theme (" + sec.themes.length + ")"
        onTextChanged: sec.themeFilter = text
    }
    Label {
        visible: sec.themeFilter.trim() !== "" && sec.shownThemes.length === 0
        text: "No colour theme matches \u201c" + sec.themeFilter.trim() + "\u201d"
        muted: true; Layout.leftMargin: 6
    }
    Label { visible: sec.darkThemes.length > 0; text: "Dark themes  ·  " + sec.darkThemes.length; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6 }
    GridLayout {
        visible: sec.darkThemes.length > 0
        Layout.fillWidth: true
        columns: 4
        rowSpacing: 8; columnSpacing: 8
        Repeater { model: sec.darkThemes; ThemeCard { required property var modelData; th: modelData } }
    }
    Label { visible: sec.lightThemes.length > 0; text: "Light themes  ·  " + sec.lightThemes.length; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 6 }
    GridLayout {
        visible: sec.lightThemes.length > 0
        Layout.fillWidth: true
        columns: 4
        rowSpacing: 8; columnSpacing: 8
        Repeater { model: sec.lightThemes; ThemeCard { required property var modelData; th: modelData } }
    }
}
