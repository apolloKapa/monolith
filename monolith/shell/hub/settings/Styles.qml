import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Theme → Style: the whole look (17 styles, each previewed) and how round its corners are, then its colours: the wallpaper's,
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
                    // (its description too, for the search: "red" finds the red ones; and its apps'
                    // own colours, which the card shows)
                    try { const d = JSON.parse(l.substring(i + 1)); out.push({ name: l.substring(0, i), desc: d.desc || "", colors: d.colors || {}, apps: d.apps || null }); } catch (e) {}
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
        readonly property color sink: pc ? pc.text : Theme.m("on_surface", "#e6e6ee")
        readonly property real rad: st.square ? 0 : Math.min(14, 6 * (st.radiusScale || 1))
        Layout.fillWidth: true
        Layout.preferredHeight: 138
        radius: Theme.corner(138, 6)
        color: on ? Theme.accentContainer : Theme.containerHigh
        onClicked: Look.pickStyle(st.id)
        // (in from the corners as far as their roundness needs: with round corners the preview and
        // the words ran into the curve)
        readonly property real pad: Theme.inset(radius, 10)
        Rectangle {
            x: sc.pad; y: Math.min(sc.pad, 14)
            width: parent.width - 2 * sc.pad; height: 74
            radius: sc.rad + 4
            color: sc.bg
            opacity: sc.st.opaque === false ? 0.8 : 1
            border.width: sc.st.outline ? sc.st.outline[0] : 0
            border.color: sc.st.outlineRole === "accent" || sc.st.outlineRole === "accentSoft" ? sc.acc : (sc.st.outlineRole === "ink" || sc.st.outlineRole === "text" ? sc.sink : Qt.alpha(sc.sink, 0.25))
            // a hard shadow, for the styles that have one
            Rectangle {
                visible: (sc.st.hardShadow || 0) > 0
                z: -1
                x: sc.st.hardShadow || 0; y: sc.st.hardShadow || 0
                width: parent.width; height: parent.height
                radius: parent.radius
                color: sc.sink
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
        Label { x: sc.pad; y: 92; width: parent.width - 2 * sc.pad - 24; text: sc.st.name; strong: true; color: sc.on ? Theme.onAccentContainer : Theme.text }
        Label { x: sc.pad; y: 110; width: parent.width - 2 * sc.pad; elide: Text.ElideRight; text: sc.st.desc || ""; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
        Icon { visible: sc.on; x: parent.width - sc.pad - 18; y: 92; name: "check_circle"; filled: true; size: 18; color: Theme.accent }
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
    // the shapes' corners (the style multiplies the roundness)
    SettingRow {
        key: "theme.radius";
        icon: "rounded_corner"; title: "Roundness"; desc: "How round the corners of everything are (the style multiplies it)"
        NumberBox { from: 0; to: 60; slideTo: 40; unit: "px"; value: Math.round(Theme.radiusSetting); onMoved: v => Store.set("theme.radius", v) }
    }
    SettingRow {
        key: "theme.wavyLines"; def: false;
        icon: "airwave"; title: "Wavy lines"; desc: "Sliders, progress bars, dividers and the frames you drag (a screenshot's area, a widget's border) wave instead of running straight"
        Toggle { checked: Theme.wavy; onToggled: on => Store.set("theme.wavyLines", on) }
    }
    SettingRow {
        key: "theme.continuousCorners"; def: true;
        icon: "rounded_corner"; title: "Continuous corners"; desc: "Corners ease out of the sides (like a squircle) instead of being quarter circles"
        Toggle { checked: Store.get("theme.continuousCorners", true) !== false; onToggled: on => Store.set("theme.continuousCorners", on) }
    }
    SettingRow {
        show: Store.get("theme.continuousCorners", true) !== false && !Theme.square
        key: "theme.cornerSmoothing"; def: 0.6;
        icon: "line_curve"; title: "Corner smoothing"; desc: "How gradually the corners ease in"
        NumberBox { from: 10; to: 100; unit: "%"; value: Math.round(Theme.cornerSmooth * 100); onMoved: v => Store.set("theme.cornerSmoothing", v / 100) }
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

    // ── your changes to the theme's colours (Look.overrides, kept per theme). The shell's own
    // colours first, then the ones other apps get (the terminal's, GTK and Qt apps') ──
    property bool editing: false
    readonly property var shellKeys: [["base", "Background"], ["mantle", "Cards and panels"], ["surface0", "Rows and tiles"],
        ["surface1", "Buttons and tracks"], ["surface2", "Raised buttons"], ["text", "Text"], ["subtext0", "Quieter text"],
        ["mauve", "Accent: buttons, switches, highlights"], ["red", "Warnings and errors"]]
    readonly property var appNames: ({ crust: "Darkest background", subtext1: "Secondary text", overlay0: "Outlines", overlay1: "Dim lines",
        overlay2: "Faint text", pink: "Pink", maroon: "Deep red", peach: "Orange", yellow: "Yellow", green: "Green", teal: "Teal",
        sapphire: "Sapphire", blue: "Blue", sky: "Sky", lavender: "Lavender", flamingo: "Flamingo", rosewater: "Rosewater" })
    readonly property var appKeys: {
        const b = Look.baseColors || {};
        const shell = shellKeys.map(k => k[0]);
        return Object.keys(b).filter(k => shell.indexOf(k) === -1 && /^#[0-9a-fA-F]{6,8}$/.test(String(b[k])))
            .sort((x, y) => (sec.appNames[x] ? 0 : 1) - (sec.appNames[y] ? 0 : 1) || x.localeCompare(y))
            .map(k => [k, sec.appNames[k] || k]);
    }
    readonly property int changedCount: Object.keys(Look.overrides).length
    SettingRow {
        show: !!Look.baseColors
        icon: "format_color_fill"; title: "Edit colours"
        desc: sec.changedCount > 0 ? sec.changedCount + (sec.changedCount === 1 ? " colour" : " colours") + " changed in " + (Look.paletteName === "style" ? Look.style.name + "'s colours" : Look.paletteName) + ". The arrow by one puts it back"
                                   : "Change any colour of " + (Look.paletteName === "style" ? Look.style.name + "'s colours" : "the " + Look.paletteName + " theme") + "; each theme keeps its own changes"
        Row {
            spacing: 6
            Button { visible: sec.changedCount > 0; text: "Reset all"; icon: "undo"; onClicked: Look.resetColours() }
            Button { text: sec.editing ? "Done" : "Edit"; icon: sec.editing ? "check" : "edit"; primary: sec.editing; onClicked: sec.editing = !sec.editing }
        }
    }
    Label { visible: !Look.baseColors && sec.editing; text: "Pick a colour theme below to edit its colours (the wallpaper's come from the wallpaper)"; muted: true; Layout.leftMargin: 6 }
    // one colour: its swatch (click to pick), what it colours, its code, and ↺ once changed
    component ColourEdit: SmoothRect {
        id: ce
        property string key: ""
        property string label: ""
        readonly property string now: Look.rawColors ? String(Look.rawColors[key] || "") : ""
        readonly property bool changed: Look.overrides[key] !== undefined
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        radius: Theme.corner(52, 2)
        color: Theme.containerHigh
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        ColourPick {
            id: pick
            x: 10; anchors.verticalCenter: parent.verticalCenter
            width: 124; height: 34
            alpha: false
            value: ce.now
            // (dragging in the picker: saved a moment after it stops, not on every move)
            onPicked: c => { later.v = c; later.restart(); }
            Timer { id: later; property string v: ""; interval: 140; onTriggered: Look.setColour(ce.key, v) }
        }
        Column {
            anchors.left: pick.right; anchors.leftMargin: 12
            anchors.right: back.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            Label { width: parent.width; elide: Text.ElideRight; text: ce.label; strong: ce.changed }
            Label { width: parent.width; elide: Text.ElideRight; text: ce.changed ? "Changed · the theme's is " + String(Look.baseColors[ce.key] || "") : "As the theme has it"; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
        }
        // (the picker keeps its own value once used: a reset, or another theme, shows here too)
        onNowChanged: if (pick.value.toLowerCase() !== now.toLowerCase()) pick.value = now
        Pressable {
            id: back
            anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter
            width: 34; height: 34
            visible: ce.changed
            color: hovered ? Theme.control : "transparent"
            onClicked: Look.resetColour(ce.key)
            Icon { anchors.centerIn: parent; name: "undo"; size: 19; color: Theme.accent }
        }
    }
    ColumnLayout {
        visible: sec.editing && !!Look.baseColors
        Layout.fillWidth: true
        spacing: 8
        Label { text: "The shell"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6 }
        GridLayout {
            Layout.fillWidth: true
            columns: 2; rowSpacing: 8; columnSpacing: 8
            Repeater { model: sec.shellKeys.filter(k => Look.baseColors && Look.baseColors[k[0]]); ColourEdit { required property var modelData; key: modelData[0]; label: modelData[1] } }
        }
        Label { visible: sec.appKeys.length > 0; text: "Other apps (the terminal, GTK and Qt apps)"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 4 }
        GridLayout {
            Layout.fillWidth: true
            columns: 3; rowSpacing: 8; columnSpacing: 8
            Repeater { model: sec.appKeys; ColourEdit { required property var modelData; key: modelData[0]; label: modelData[1] } }
        }
    }

    // a colour theme: a little window in its colours, named in its own text colour
    component ThemeCard: Pressable {
        id: tc
        property var th: ({ name: "", colors: {} })
        // (with your changes to it, if any)
        readonly property var k: Object.assign({}, th.colors, (Store.get("theme.overrides", {}) || {})[th.name] || {})
        readonly property bool on: Look.paletteName === th.name
        // a quarter of the row, also when a search leaves only one or two (they stretched)
        Layout.preferredWidth: (sec.width - 24) / 4
        Layout.preferredHeight: 92
        radius: Theme.corner(92, 4)
        color: k.base || Theme.containerHigh
        border.width: on ? 3 : 1
        border.color: on ? Theme.accent : Qt.alpha(k.text || Theme.text, 0.15)
        onClicked: Look.pickPalette(th.name)
        // (in from the corners as far as their roundness needs: a round card's name and dots ran
        // into its curved ends)
        readonly property real pad: Theme.inset(radius, 12)
        Column {
            x: tc.pad; y: 10
            width: parent.width - 2 * tc.pad
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
