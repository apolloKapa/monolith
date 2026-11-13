import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Colours, corners, font, icon and cursor themes, and whether apps follow dark/light.
ColumnLayout {
    id: sec
    spacing: 8
    property var iconThemes: []
    property var cursorThemes: []
    property string iconTheme: ""
    property string cursorTheme: ""
    property int cursorSize: 24

    // the packs and cursor themes with their previews (scripts/themes.py; cached after the first time)
    readonly property string script: Qt.resolvedUrl("../../scripts/themes.py").toString().replace("file://", "")
    Process {
        running: true
        command: ["python3", sec.script, "icons"]
        stdout: StdioCollector { onStreamFinished: { try { sec.iconThemes = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        running: true
        command: ["python3", sec.script, "cursors"]
        stdout: StdioCollector { onStreamFinished: { try { sec.cursorThemes = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"]
        stdout: StdioCollector { onStreamFinished: sec.iconTheme = text.trim().replace(/'/g, "") }
    }

    // a theme as a card: its name, and its samples on a tile
    component ThemeCard: Pressable {
        id: tc
        property string title: ""
        property var samples: []
        property bool on: false
        property real iconSize: 30
        property color tile: Theme.container
        Layout.fillWidth: true
        Layout.preferredHeight: 96
        radius: Theme.corner(96, 4)
        color: on ? Theme.accentContainer : Theme.containerHigh
        border.width: on ? 2 : 0
        border.color: Theme.accent
        Label { x: 14; y: 10; text: tc.title; strong: true; color: tc.on ? Theme.onAccentContainer : Theme.text }
        Icon { visible: tc.on; x: parent.width - 30; y: 9; name: "check_circle"; size: 18; filled: true; color: Theme.accent }
        Rectangle {
            x: 10; y: 36
            width: parent.width - 20; height: 50
            radius: Theme.corner(50, 2)
            color: tc.tile
            Row {
                anchors.centerIn: parent
                spacing: 10
                Repeater {
                    model: tc.samples
                    Image {
                        required property string modelData
                        width: tc.iconSize; height: tc.iconSize
                        source: "file://" + modelData
                        sourceSize: Qt.size(tc.iconSize * 2, tc.iconSize * 2)
                        fillMode: Image.PreserveAspectFit
                        smooth: true
                        asynchronous: true
                    }
                }
            }
        }
    }

    Component.onCompleted: NiriConf.read(["cursor|xcursor-theme", "cursor|xcursor-size"], v => {
        cursorTheme = NiriConf.unquote(v["cursor|xcursor-theme"]);
        cursorSize = Number(v["cursor|xcursor-size"] || 24);
    })
    function setCursor(name, size) {
        cursorTheme = name; cursorSize = size;
        NiriConf.set("cursor", "xcursor-theme", NiriConf.quote(name));
        NiriConf.set("cursor", "xcursor-size", size);
        Quickshell.execDetached(["sh", "-c", "gsettings set org.gnome.desktop.interface cursor-theme \"$1\"; gsettings set org.gnome.desktop.interface cursor-size \"$2\"", "_", name, String(size)]);
    }

    SettingRow {
        key: "theme.mode";
        icon: "dark_mode"; title: "Dark or light"; desc: "The shell's colours in dark or light (the style and colour theme are in Style & colours)"
        Segmented {
            opts: [["dark", "Dark"], ["light", "Light"]]; value: Theme.modeName
            onPicked: v => {
                Store.set("theme.mode", v);
            }
        }
    }
    SettingRow {
        key: "theme.appsFollow"; def: true;
        icon: "apps"; title: "Apps follow dark or light"; desc: "GTK apps, browsers and Qt apps (through the portal) switch with the shell"
        Toggle { checked: Store.get("theme.appsFollow", true) !== false; onToggled: on => { Store.set("theme.appsFollow", on); if (on) Wall.followApps(); } }
    }
    SettingRow {
        key: "theme.radius";
        icon: "rounded_corner"; title: "Roundness"; desc: "How round the corners of everything are (the style multiplies it)"
        NumberBox { from: 0; to: 60; slideTo: 40; unit: "px"; value: Math.round(Theme.radiusSetting); onMoved: v => Store.set("theme.radius", v) }
    }
    SettingRow {
        key: "theme.continuousCorners"; def: true;
        icon: "rounded_corner"; title: "Continuous corners"; desc: "Corners ease out of the sides (like a squircle) instead of being quarter circles"
        Toggle { checked: Store.get("theme.continuousCorners", true) !== false; onToggled: on => Store.set("theme.continuousCorners", on) }
    }
    SettingRow {
        visible: Store.get("theme.continuousCorners", true) !== false && !Theme.square
        key: "theme.cornerSmoothing"; def: 0.6;
        icon: "line_curve"; title: "Corner smoothing"; desc: "How gradually the corners ease in"
        NumberBox { from: 10; to: 100; unit: "%"; value: Math.round(Theme.cornerSmooth * 100); onMoved: v => Store.set("theme.cornerSmoothing", v / 100) }
    }
    // ── font: every family by name; the preview shows the one under the pointer (or the
    // one in use) ──
    readonly property var families: {
        // one entry per family (no "… Bold", "… NL" variants) and no symbol fonts
        const all = Qt.fontFamilies().filter(n => !/ (Thin|Light|ExtraLight|Medium|SemiBold|Bold|ExtraBold|Black|Heavy|Obl|Italic|NL)\b/.test(n)
            && !/Material Symbols|Noto Color|Emoji|Awesome|Symbol|Dingbat|D050000L|Math|Nerd Font Propo|Nerd Font Mono|^Iosevka N?F$/.test(n));
        return all;
    }
    SettingRow {
        icon: "font_download"; title: "Font"
        key: "theme.font"
        desc: "Used everywhere in the shell" + (Store.get("theme.font", "") === "" ? " (the style's own, " + Theme.fontFamily + ")" : "")
        FontPicker {
            width: 300
            families: sec.families
            value: Store.get("theme.font", "")
            defaultName: "Default (" + (Theme.styleFont || Theme.defaultFont) + ")"
            onPicked: f => f === "" ? Store.unset("theme.font") : Store.set("theme.font", f)
        }
    }
    // what it looks like
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: pcol.implicitHeight + 28
        radius: Theme.corner(80, 6)
        color: Theme.container
        border.width: Theme.outlineW
        border.color: Theme.outlineColor
        Column {
            id: pcol
            x: 18; y: 14
            width: parent.width - 36
            spacing: 4
            Label { text: "Preview: " + Theme.fontFamily; muted: true; font.pixelSize: Theme.sizeSmall }
            Text { width: parent.width; text: "The quick brown fox jumps over the lazy dog"; elide: Text.ElideRight; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 26 }
            Text { width: parent.width; text: "Settings  ·  21:47  ·  Wi-Fi on  ·  0123456789  ·  Àéîõü"; elide: Text.ElideRight; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 15 }
        }
    }

    // ── icons ──
    SettingRow { icon: "interests"; title: "Icons"; desc: "The icon pack apps and the shell use" + (sec.iconTheme ? " (now " + sec.iconTheme + ")" : "") + ". The shell restarts for a moment to load a new one" }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 8; columnSpacing: 8
        Repeater {
            model: sec.iconThemes
            ThemeCard {
                required property var modelData
                title: modelData.title
                samples: modelData.samples
                on: sec.iconTheme === modelData.name
                // (everywhere: GTK, Qt and KDE apps and the shell; the shell restarts to load
                // them, Qt reads icons once, and comes back here)
                onClicked: if (!sec.iconTheme || sec.iconTheme !== modelData.name) { sec.iconTheme = modelData.name; Quickshell.execDetached(["sh", sec.script.replace("themes.py", "icon_theme.sh"), modelData.name]); }
            }
        }
    }
    Label { visible: sec.iconThemes.length === 0; text: "Looking for icon packs…"; muted: true; Layout.leftMargin: 6 }

    // ── cursors: the pointers on a light tile, so dark and light themes both show ──
    SettingRow {
        icon: "arrow_selector_tool"; title: "Cursor"; desc: "Theme and size, for niri and apps" + (sec.cursorTheme ? " (now " + sec.cursorTheme + ")" : "")
        // applied once you stop dragging
        NumberBox {
            from: 8; to: 128; slideTo: 96; step: 2; unit: "px"; value: sec.cursorSize
            onMoved: v => { sec.cursorSize = v; cursorLater.restart(); }
            Timer { id: cursorLater; interval: 500; onTriggered: sec.setCursor(sec.cursorTheme || "default", sec.cursorSize) }
        }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 8; columnSpacing: 8
        Repeater {
            model: sec.cursorThemes
            ThemeCard {
                required property var modelData
                title: modelData.title
                samples: modelData.samples
                iconSize: 32
                tile: Theme.mix(Theme.containerHigh, Qt.color("#a4a4ac"), 0.6)
                on: sec.cursorTheme === modelData.name
                onClicked: sec.setCursor(modelData.name, sec.cursorSize)
            }
        }
    }
}
