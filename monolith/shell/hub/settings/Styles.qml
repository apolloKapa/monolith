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

    // ── your changes to the theme's colours, kept per theme: the whole theme turned at once
    // (Look.adjust: hue, saturation, brightness, contrast) and single colours (Look.overrides).
    // The shell's own colours first, then the ones other apps get (the terminal's, GTK and Qt apps') ──
    property bool editing: false
    readonly property var shellKeys: [["base", "Background"], ["mantle", "Cards and panels"], ["surface0", "Rows and tiles"],
        ["surface1", "Buttons and tracks"], ["surface2", "Raised buttons"], ["text", "Text"], ["subtext0", "Quieter text"],
        ["mauve", "Accent"], ["red", "Warnings and errors"]]
    // (in this order: the greys from dark to light, then the colours round the wheel)
    readonly property var appOrder: [["crust", "Darkest shade"], ["overlay0", "Outlines"], ["overlay1", "Dim lines"], ["overlay2", "Faint text"],
        ["subtext1", "Second text"], ["maroon", "Deep red"], ["peach", "Orange"], ["yellow", "Yellow"], ["green", "Green"], ["teal", "Teal"],
        ["sky", "Sky"], ["sapphire", "Sapphire"], ["blue", "Blue"], ["lavender", "Lavender"], ["pink", "Pink"], ["flamingo", "Flamingo"],
        ["rosewater", "Rosewater"]]
    readonly property var appKeys: {
        const b = Look.baseColors || {};
        const ok = k => /^#[0-9a-fA-F]{6,8}$/.test(String(b[k] || ""));
        const known = shellKeys.map(k => k[0]).concat(appOrder.map(k => k[0]));
        return appOrder.filter(k => ok(k[0])).concat(Object.keys(b).filter(k => known.indexOf(k) === -1 && ok(k)).sort().map(k => [k, k]));
    }
    readonly property int changedCount: Object.keys(Look.overrides).length
    readonly property string editName: Look.paletteName === "style" ? Look.style.name + "'s colours" : "the " + Look.paletteName + " theme"
    SettingRow {
        show: !!Look.baseColors
        icon: "format_color_fill"; title: "Edit colours"
        desc: (sec.changedCount > 0 || Look.adjusted
               ? [Look.adjusted ? "the whole theme adjusted" : "", sec.changedCount > 0 ? sec.changedCount + (sec.changedCount === 1 ? " colour" : " colours") + " changed" : ""].filter(x => x).join(", ").replace(/^t/, "T") + " in " + sec.editName
               : "Change " + sec.editName + ": its hue, saturation, brightness and contrast, or any single colour") + ". Each theme keeps its own changes"
        Row {
            spacing: 6
            Button { visible: sec.changedCount > 0 || Look.adjusted; text: "Reset all"; icon: "undo"; onClicked: { Look.resetColours(); Look.resetAdjust(); } }
            Button { text: sec.editing ? "Done" : "Edit"; icon: sec.editing ? "check" : "edit"; primary: sec.editing; onClicked: sec.editing = !sec.editing }
        }
    }
    Label { visible: !Look.baseColors && sec.editing; text: "Pick a colour theme below to edit its colours (the wallpaper's come from the wallpaper)"; muted: true; Layout.leftMargin: 6 }

    // one of the four whole-theme sliders: a track that shows what it does, 0 in the middle
    // (it catches there), the number at its end and ↺ once it's moved
    component Adjust: Item {
        id: ad
        property string key: ""
        property string label: ""
        property string icon: "tune"
        property real most: 100
        property string unit: "%"
        // the track's seven colours, left to right
        property var stops: ["#000", "#000", "#000", "#000", "#000", "#000", "#000"]
        readonly property real value: Look.adjust[key] || 0
        property bool dragging: false
        property real dragValue: 0
        readonly property real shown: dragging ? dragValue : value
        Layout.fillWidth: true
        Layout.preferredHeight: 62
        function put(v) { dragValue = v; write.restart(); }
        // (written a moment after it stops moving: every change recolours the whole shell and the apps)
        Timer { id: write; interval: 90; onTriggered: Look.setAdjust(ad.key, ad.dragValue) }
        Icon { id: adIcon; x: 2; y: 4; name: ad.icon; size: 18; color: ad.shown !== 0 ? Theme.accent : Theme.subtext }
        Label { anchors.left: adIcon.right; anchors.leftMargin: 8; anchors.verticalCenter: adIcon.verticalCenter; text: ad.label; strong: ad.shown !== 0 }
        Label {
            anchors.right: adBack.visible ? adBack.left : parent.right; anchors.rightMargin: adBack.visible ? 4 : 2
            anchors.verticalCenter: adIcon.verticalCenter
            text: (ad.shown > 0 ? "+" : "") + Math.round(ad.shown) + (ad.unit === "°" ? "°" : " " + ad.unit)
            font.family: "monospace"; font.pixelSize: Theme.sizeSmall + 1
            color: ad.shown !== 0 ? Theme.accent : Theme.subtext
        }
        Pressable {
            id: adBack
            visible: ad.shown !== 0
            anchors.right: parent.right; anchors.verticalCenter: adIcon.verticalCenter
            width: 26; height: 26
            color: hovered ? Theme.control : "transparent"
            onClicked: { write.stop(); ad.dragging = false; Look.setAdjust(ad.key, 0); }
            Icon { anchors.centerIn: parent; name: "undo"; size: 16; color: Theme.accent }
        }
        Item {
            id: adTrack
            x: 2; y: 34
            width: parent.width - 4; height: 18
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 12
                radius: (Theme.chamfer || Theme.square) ? 0 : 6
                border.width: 1; border.color: Qt.alpha(Theme.text, 0.14)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: ad.stops[0] } GradientStop { position: 0.167; color: ad.stops[1] }
                    GradientStop { position: 0.333; color: ad.stops[2] } GradientStop { position: 0.5; color: ad.stops[3] }
                    GradientStop { position: 0.667; color: ad.stops[4] } GradientStop { position: 0.833; color: ad.stops[5] }
                    GradientStop { position: 1.0; color: ad.stops[6] }
                }
            }
            // the middle: as the theme has it
            Rectangle { x: parent.width / 2 - 0.5; y: -3; width: 1; height: parent.height + 6; color: Qt.alpha(Theme.text, 0.35) }
            Rectangle {
                x: Math.max(0, Math.min(parent.width - width, (ad.shown + ad.most) / (2 * ad.most) * parent.width - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: 10; height: 22
                radius: (Theme.chamfer || Theme.square) ? 0 : 5
                color: "white"; border.width: 1; border.color: "#000000"
                scale: adArea.pressed ? 1.12 : 1
                Behavior on scale { NumberAnimation { duration: Theme.fastMs } }
            }
            MouseArea {
                id: adArea
                anchors.fill: parent; anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                function at(m) {
                    let v = Math.round(((m.x - 6) / adTrack.width * 2 - 1) * ad.most);
                    v = Math.max(-ad.most, Math.min(ad.most, v));
                    if (Math.abs(v) <= ad.most * 0.03) v = 0;
                    ad.dragging = true;
                    ad.put(v);
                }
                onPressed: m => at(m)
                onPositionChanged: m => { if (pressed) at(m); }
                onReleased: { write.stop(); Look.setAdjust(ad.key, ad.dragValue); ad.dragging = false; }
                onCanceled: ad.dragging = false
                onDoubleClicked: { write.stop(); ad.dragging = false; Look.setAdjust(ad.key, 0); }
                onWheel: w => { write.stop(); ad.dragging = false; Look.setAdjust(ad.key, Math.max(-ad.most, Math.min(ad.most, ad.value + (w.angleDelta.y > 0 ? 1 : -1) * (ad.most > 100 ? 5 : 2)))); }
            }
        }
    }
    // one colour: its swatch, what it colours and its code; anywhere on it opens the picker, and
    // ↺ puts it back once it's changed
    component ColourEdit: SmoothRect {
        id: ce
        property string key: ""
        property string label: ""
        property bool small: false
        readonly property string now: Look.rawColors ? String(Look.rawColors[key] || "") : ""
        readonly property bool changed: Look.overrides[key] !== undefined
        Layout.fillWidth: true
        // (all the same width: a long name doesn't make its column wider)
        Layout.preferredWidth: 100
        Layout.preferredHeight: small ? 50 : 58
        radius: Theme.corner(height, 2)
        color: pick.open ? Theme.control : Theme.containerHigh
        border.width: ce.changed ? Math.max(1, Theme.outlineW) : Theme.outlineW
        border.color: ce.changed ? Theme.accent : Theme.outlineColor
        ColourPick {
            id: pick
            anchors.fill: parent
            plain: true
            swatch: ce.small ? 28 : 36
            swatchX: ce.small ? 10 : 11
            alpha: false
            value: ce.now
            // (dragging in the picker: saved a moment after it stops, not on every move)
            onPicked: c => { later.v = c; later.restart(); }
            Timer { id: later; property string v: ""; interval: 140; onTriggered: Look.setColour(ce.key, v) }
        }
        Column {
            x: pick.swatchX + pick.swatch + (ce.small ? 10 : 12)
            width: parent.width - x - (back.visible ? back.width + 10 : 10)
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Label { width: parent.width; elide: Text.ElideRight; text: ce.label; strong: ce.changed; font.pixelSize: ce.small ? Theme.sizeBody - 1 : Theme.sizeBody }
            Label { width: parent.width; elide: Text.ElideRight; text: ce.now.toUpperCase(); font.family: "monospace"; font.pixelSize: Theme.sizeSmall; color: ce.changed ? Theme.accent : Theme.subtext }
        }
        // (the picker keeps its own value once used: a reset, or another theme, shows here too)
        onNowChanged: if (pick.value.toLowerCase() !== now.toLowerCase()) pick.value = now
        Pressable {
            id: back
            anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
            width: 30; height: 30
            visible: ce.changed
            color: hovered ? Theme.control : "transparent"
            onClicked: Look.resetColour(ce.key)
            Icon { anchors.centerIn: parent; name: "undo"; size: 17; color: Theme.accent }
        }
    }
    ColumnLayout {
        visible: sec.editing && !!Look.baseColors
        Layout.fillWidth: true
        spacing: 8
        // the whole theme: its colours in a strip (as they are now), and the four sliders
        SmoothRect {
            id: whole
            Layout.fillWidth: true
            Layout.preferredHeight: wholeCol.implicitHeight + 28
            radius: Theme.corner(120, 3)
            color: Theme.containerHigh
            border.width: Theme.outlineW; border.color: Theme.outlineColor
            readonly property color acc: Qt.color(Look.rawColors ? (Look.rawColors.mauve || "#8888ff") : "#8888ff")
            readonly property real accHue: Math.max(0, acc.hslHue)
            ColumnLayout {
                id: wholeCol
                x: 16; y: 14
                width: parent.width - 32
                spacing: 12
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Icon { name: "tune"; size: 20; color: Theme.accent }
                    Column {
                        Layout.fillWidth: true
                        Label { text: "The whole theme"; strong: true }
                        Label { width: parent.width; wrapMode: Text.Wrap; text: "Turns every colour at once. A colour you set yourself below stays as you set it"; muted: true; font.pixelSize: Theme.sizeSmall }
                    }
                    Button { visible: Look.adjusted; text: "Reset"; icon: "undo"; onClicked: Look.resetAdjust() }
                }
                // every colour of the theme side by side
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 26
                    Row {
                        id: strip
                        anchors.fill: parent
                        readonly property var keys: sec.shellKeys.concat(sec.appKeys).map(k => k[0]).filter(k => Look.rawColors && Look.rawColors[k])
                        Repeater {
                            model: strip.keys
                            Rectangle {
                                required property string modelData
                                required property int index
                                width: strip.width / Math.max(1, strip.keys.length); height: strip.height
                                color: Look.rawColors ? (Look.rawColors[modelData] || "transparent") : "transparent"
                            }
                        }
                    }
                    // (its outline, and the corners cut to the shell's roundness by the card's colour)
                    Rectangle { anchors.fill: parent; color: "transparent"; border.width: 1; border.color: Qt.alpha(Theme.text, 0.18) }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2; rowSpacing: 6; columnSpacing: 28
                    Adjust {
                        key: "hue"; label: "Hue"; icon: "palette"; most: 180; unit: "°"
                        stops: [0, 1, 2, 3, 4, 5, 6].map(i => String(Qt.hsla((((whole.accHue + (i / 6 - 0.5)) % 1) + 1) % 1, 0.8, 0.55, 1)))
                    }
                    Adjust {
                        key: "saturation"; label: "Saturation"; icon: "water_drop"
                        stops: [0, 1, 2, 3, 4, 5, 6].map(i => String(Qt.hsla(whole.accHue, i / 6, 0.55, 1)))
                    }
                    Adjust {
                        key: "brightness"; label: "Brightness"; icon: "light_mode"
                        stops: [0, 1, 2, 3, 4, 5, 6].map(i => String(Qt.hsla(0, 0, 0.04 + 0.92 * i / 6, 1)))
                    }
                    Adjust {
                        key: "contrast"; label: "Contrast"; icon: "contrast"
                        // (greys that swing further apart towards the right)
                        stops: [0.5, 0.47, 0.55, 0.4, 0.68, 0.2, 0.96].map(l => String(Qt.hsla(0, 0, l, 1)))
                    }
                }
            }
        }
        Label { text: "The shell"; muted: true; strong: true; font.pixelSize: Theme.sizeSmall + 1; Layout.leftMargin: 6; Layout.topMargin: 6 }
        GridLayout {
            Layout.fillWidth: true
            columns: 3; rowSpacing: 8; columnSpacing: 8
            Repeater { model: sec.shellKeys.filter(k => Look.baseColors && Look.baseColors[k[0]]); ColourEdit { required property var modelData; key: modelData[0]; label: modelData[1] } }
        }
        Label { visible: sec.appKeys.length > 0; text: "Other apps: the terminal, GTK and Qt apps"; muted: true; strong: true; font.pixelSize: Theme.sizeSmall + 1; Layout.leftMargin: 6; Layout.topMargin: 6 }
        GridLayout {
            Layout.fillWidth: true
            columns: 4; rowSpacing: 8; columnSpacing: 8
            Repeater { model: sec.appKeys; ColourEdit { required property var modelData; key: modelData[0]; label: modelData[1]; small: true } }
        }
    }

    // a colour theme: a little window in its colours, named in its own text colour
    component ThemeCard: Pressable {
        id: tc
        property var th: ({ name: "", colors: {} })
        // (with your changes to it, if any)
        readonly property var k: Object.assign({}, Look.tune(th.colors, Look.adjustOf(th.name)), (Store.get("theme.overrides", {}) || {})[th.name] || {})
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
