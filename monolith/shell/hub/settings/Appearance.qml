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
        icon: "dark_mode"; title: "Colours"; desc: "Made from your wallpaper, dark or light"
        Segmented {
            opts: [["dark", "Dark"], ["light", "Light"]]; value: Theme.modeName
            onPicked: v => {
                Store.set("theme.mode", v);
                if (Store.get("theme.appsFollow", true)) Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", v === "dark" ? "prefer-dark" : "prefer-light"]);
            }
        }
    }
    SettingRow {
        icon: "apps"; title: "Apps follow"; desc: "Tell apps (GTK, Qt with a portal, browsers) to be dark or light with the shell"
        Toggle { checked: Store.get("theme.appsFollow", true) !== false; onToggled: on => Store.set("theme.appsFollow", on) }
    }
    SettingRow {
        icon: "rounded_corner"; title: "Corner radius"; desc: "How round everything is"
        NumberBox { from: 0; to: 60; unit: "px"; value: Math.round(Theme.radiusSetting); onMoved: v => Store.set("theme.radius", v) }
    }
    // ── font: the families rendered in themselves ──
    property string fontFilter: ""
    readonly property var families: {
        const f = fontFilter.toLowerCase();
        // one entry per family (no "… Bold", "… NL" variants), the chosen one first
        const all = Qt.fontFamilies().filter(n => !/ (Thin|Light|ExtraLight|Medium|SemiBold|Bold|ExtraBold|Black|Heavy|Obl|Italic|NL)\b/.test(n) && !/Material Symbols|Noto Color|Emoji|Awesome|Symbol|Dingbat|D050000L|Math|Nerd Font Propo|^Iosevka N?F/.test(n));
        return all.filter(n => f === "" || n.toLowerCase().includes(f)).slice(0, f === "" ? 14 : 40);
    }
    SettingRow {
        icon: "font_download"; title: "Font"; desc: "Now " + Theme.fontFamily + (Store.get("theme.font", "") === "" ? " (the default)" : "")
        Field { width: 200; placeholder: "Find a font"; onAccepted: v => sec.fontFilter = v.trim() }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: fontFlow.implicitHeight + 20
        radius: Theme.corner(56, 2)
        color: Theme.containerHigh
        Flow {
            id: fontFlow
            x: 10; y: 10
            width: parent.width - 20
            spacing: 6
            Pressable {
                height: 40; width: dl.implicitWidth + 28
                color: Store.get("theme.font", "") === "" ? Theme.accentContainer : Theme.control
                onClicked: Store.set("theme.font", "")
                Label { id: dl; anchors.centerIn: parent; text: "Default"; strong: true; font.family: Theme.defaultFont }
            }
            Repeater {
                model: sec.families
                Pressable {
                    required property string modelData
                    readonly property bool on: Store.get("theme.font", "") === modelData
                    height: 40
                    width: Math.min(fontFlow.width, fl.implicitWidth + 28)
                    color: on ? Theme.accentContainer : Theme.control
                    onClicked: Store.set("theme.font", modelData)
                    Label { id: fl; anchors.centerIn: parent; text: parent.modelData; font.family: parent.modelData; font.pixelSize: Theme.sizeBody + 1; color: parent.on ? Theme.onAccentContainer : Theme.text }
                }
            }
        }
    }

    // ── icons ──
    SettingRow { icon: "interests"; title: "Icons"; desc: "The icon pack apps and the shell use" + (sec.iconTheme ? " (now " + sec.iconTheme + ")" : "") }
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
                onClicked: { sec.iconTheme = modelData.name; Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", modelData.name]); }
            }
        }
    }
    Label { visible: sec.iconThemes.length === 0; text: "Looking for icon packs…"; muted: true; Layout.leftMargin: 6 }

    // ── cursors: the pointers on a light tile, so dark and light themes both show ──
    SettingRow {
        icon: "arrow_selector_tool"; title: "Cursor"; desc: "Theme and size, for niri and apps" + (sec.cursorTheme ? " (now " + sec.cursorTheme + ")" : "")
        NumberBox { from: 8; to: 128; step: 2; unit: "px"; value: sec.cursorSize; onMoved: v => sec.setCursor(sec.cursorTheme || "default", v) }
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
