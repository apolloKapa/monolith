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
        id: iconList
        running: true
        command: ["python3", sec.script, "icons"]
        stdout: StdioCollector { onStreamFinished: { try { sec.iconThemes = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        id: cursorList
        running: true
        command: ["python3", sec.script, "cursors"]
        stdout: StdioCollector { onStreamFinished: { try { sec.cursorThemes = JSON.parse(text); } catch (e) {} } }
    }
    Process {
        running: true
        command: ["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"]
        stdout: StdioCollector { onStreamFinished: sec.iconTheme = text.trim().replace(/'/g, "") }
    }

    // ── + : a theme from a folder (a download, unpacked), copied in and made one of the choices
    // (scripts/themes.py add). Several themes in the folder: all of them ──
    property string adding: ""
    function addTheme(kind) {
        if (adding !== "" || Pictures.picking) return;
        const home = Quickshell.env("HOME") || "";
        // (Pictures.pick: Settings steps aside while the chooser is open, or it's underneath)
        Pictures.pick(["--directory", "--title=" + (kind === "icons" ? "Pick an icon pack's folder" : "Pick a cursor theme's folder"), "--filename=" + home + "/Downloads/"], d => {
            d = String(d || "").trim();
            if (d === "") return;
            sec.adding = kind;
            addProc.command = ["python3", sec.script, "add", kind, d];
            addProc.running = true;
        });
    }
    Process {
        id: addProc
        stdout: StdioCollector {
            onStreamFinished: {
                const kind = sec.adding;
                sec.adding = "";
                let r = null;
                try { r = JSON.parse(text); } catch (e) { return; }   // (the picker was closed)
                const what = kind === "icons" ? "icon pack" : "cursor theme";
                if (r.error) { Quickshell.execDetached(["notify-send", "-a", "Monolith", "-i", "dialog-warning", "Couldn't add that " + what, r.error]); return; }
                const n = (r.added || []).length;
                if (!n) return;
                Quickshell.execDetached(["notify-send", "-a", "Monolith", "-i", kind === "icons" ? "preferences-desktop-icons" : "input-mouse",
                    n === 1 ? "Added " + r.added[0] : "Added " + n + " " + what + "s",
                    (n === 1 ? "It's" : "They're") + " in Settings → Appearance now: pick " + (n === 1 ? "it" : "one") + " to use it"]);
                if (kind === "icons") iconList.running = true; else cursorList.running = true;
            }
        }
        onExited: if (sec.adding !== "" && !running) Qt.callLater(() => sec.adding = "")
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
        // (in from the corners as far as their roundness needs: Theme.inset)
        readonly property real pad: Theme.inset(radius, 14)
        Label { x: tc.pad; y: 10; width: parent.width - 2 * tc.pad - 20; text: tc.title; strong: true; color: tc.on ? Theme.onAccentContainer : Theme.text }
        Icon { visible: tc.on; x: parent.width - tc.pad - 16; y: 9; name: "check_circle"; size: 18; filled: true; color: Theme.accent }
        SmoothRect {
            smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
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

    // (Hyprland: its cursor, set with hyprctl and kept in Monolith's own file: scripts/hypr_cursor.sh)
    readonly property string hyprCursor: sec.script.replace("themes.py", "hypr_cursor.sh")
    Process {
        running: Niri.hyprland
        command: ["sh", sec.hyprCursor, "read"]
        stdout: StdioCollector { onStreamFinished: { const p = text.trim().split(" "); if (p[0]) sec.cursorTheme = p[0]; sec.cursorSize = Number(p[1] || 24); } }
    }
    Component.onCompleted: if (!Niri.hyprland) NiriConf.read(["cursor|xcursor-theme", "cursor|xcursor-size"], v => {
        cursorTheme = NiriConf.unquote(v["cursor|xcursor-theme"]);
        cursorSize = Number(v["cursor|xcursor-size"] || 24);
    })
    function setCursor(name, size) {
        cursorTheme = name; cursorSize = size;
        if (Niri.hyprland) { Quickshell.execDetached(["sh", sec.hyprCursor, name, String(size)]); return; }
        NiriConf.set("cursor", "xcursor-theme", NiriConf.quote(name));
        NiriConf.set("cursor", "xcursor-size", size);
        Quickshell.execDetached(["sh", "-c", "gsettings set org.gnome.desktop.interface cursor-theme \"$1\"; gsettings set org.gnome.desktop.interface cursor-size \"$2\"", "_", name, String(size)]);
    }

    SettingRow {
        key: "theme.mode";
        icon: "dark_mode"; title: "Dark or light"; desc: "The shell's colours in dark or light (the style and colour theme are in Style & colours)"
        Segmented {
            opts: [["dark", "Dark"], ["light", "Light"]]; value: Look.mode
            onPicked: v => {
                Look.setMode(v);
            }
        }
    }
    SettingRow {
        key: "theme.appsFollow"; def: true;
        icon: "apps"; title: "Apps follow dark or light"; desc: "GTK apps, browsers and Qt apps (through the portal) switch with the shell"
        Toggle { checked: Store.get("theme.appsFollow", true) !== false; onToggled: on => { Store.set("theme.appsFollow", on); if (on) Wall.followApps(); } }
    }
    // ── font: every family by name; the preview shows the one under the pointer (or the
    // one in use) ──
    // ── + fonts: font files (from a download…) copied into ~/.local/share/fonts/monolith-added
    // (so every app has them; fc-cache told), and loaded here at once so they're in the list now ──
    property int fontRev: 0
    property var fontLoaders: []
    function addFonts() {
        if (Pictures.picking) return;
        const home = Quickshell.env("HOME") || "";
        Pictures.pick(["--multiple", "--separator=\n", "--title=Pick font files (.ttf, .otf)", "--filename=" + home + "/Downloads/",
                       "--file-filter=Fonts | *.ttf *.otf *.ttc *.TTF *.OTF *.TTC"], txt => {
            const files = String(txt || "").split("\n").map(f => f.trim()).filter(f => f !== "");
            if (!files.length) return;
            fontProc.command = ["sh", "-c",
                "d=\"${XDG_DATA_HOME:-$HOME/.local/share}/fonts/monolith-added\"; mkdir -p \"$d\"; " +
                "for f in \"$@\"; do b=$(basename \"$f\"); cp -f -- \"$f\" \"$d/$b\" && echo \"$d/$b\"; done; " +
                "command -v fc-cache >/dev/null && fc-cache -f \"$d\" >/dev/null 2>&1", "_"].concat(files);
            fontProc.running = true;
        });
    }
    Process {
        id: fontProc
        stdout: StdioCollector {
            onStreamFinished: {
                const paths = text.split("\n").filter(l => l !== "");
                const before = Qt.fontFamilies().length;
                for (const p of paths) {
                    const l = Qt.createQmlObject('import QtQuick; FontLoader {}', Pictures, "AddedFont");   // (kept for the session, not just while this page is open)
                    l.statusChanged.connect(() => { if (l.status === FontLoader.Ready) sec.fontRev++; });
                    l.source = "file://" + p;
                    sec.fontLoaders = sec.fontLoaders.concat([l]);
                }
                Quickshell.execDetached(["notify-send", "-a", "Monolith", "-i", "preferences-desktop-font",
                    paths.length === 1 ? "Added a font" : "Added " + paths.length + " fonts",
                    paths.length ? "Pick it in Settings → Appearance → Font" : "Nothing could be copied"]);
            }
        }
    }
    readonly property var families: {
        const _ = sec.fontRev;
        // one entry per family (no "… Bold", "… NL" variants) and no symbol fonts
        const all = Qt.fontFamilies().filter(n => !/ (Thin|Light|ExtraLight|Medium|SemiBold|Bold|ExtraBold|Black|Heavy|Obl|Italic|NL)\b/.test(n)
            && !/Material Symbols|Noto Color|Emoji|Awesome|Symbol|Dingbat|D050000L|Math|Nerd Font Propo|Nerd Font Mono|^Iosevka N?F$/.test(n));
        return all;
    }
    SettingRow {
        icon: "font_download"; title: "Font"
        key: "theme.font"; def: ""
        desc: "Used everywhere in the shell" + (Store.get("theme.font", "") === "" ? " (the style's own, " + Theme.fontFamily + ")" : "") + ". + adds fonts from files"
        Row {
        spacing: 8
        FontPicker {
            anchors.verticalCenter: parent.verticalCenter
            width: 300
            families: sec.families
            value: Store.get("theme.font", "")
            defaultName: "Default (" + (Theme.styleFont || Theme.defaultFont) + ")"
            onPicked: f => f === "" ? Store.unset("theme.font") : Store.set("theme.font", f)
        }
        Button { anchors.verticalCenter: parent.verticalCenter; icon: "add"; width: 40; onClicked: sec.addFonts() }
        }
    }
    // what it looks like
    SmoothRect {
        smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
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
    SettingRow {
        icon: "interests"; title: "Icons"; desc: "The icon pack apps and the shell use" + (sec.iconTheme ? " (now " + sec.iconTheme + ")" : "") + ". The shell restarts for a moment to load a new one. + adds one from a folder"
        Button { icon: "add"; width: 40; onClicked: sec.addTheme("icons") }
    }
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
        icon: "arrow_selector_tool"; title: "Cursor"; desc: "Theme and size, for " + (Niri.hyprland ? "Hyprland" : "niri") + " and apps" + (sec.cursorTheme ? " (now " + sec.cursorTheme + ")" : "") + ". + adds one from a folder"
        Row {
            spacing: 8
            // applied once you stop dragging
            NumberBox {
                anchors.verticalCenter: parent.verticalCenter
                from: 8; to: 128; slideTo: 96; step: 2; unit: "px"; value: sec.cursorSize
                onMoved: v => { sec.cursorSize = v; cursorLater.restart(); }
                Timer { id: cursorLater; interval: 500; onTriggered: sec.setCursor(sec.cursorTheme || "default", sec.cursorSize) }
            }
            Button { anchors.verticalCenter: parent.verticalCenter; icon: "add"; width: 40; onClicked: sec.addTheme("cursors") }
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
