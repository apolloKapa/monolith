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

    // themes in the usual folders: icon themes have an index.theme, cursor themes a cursors/ folder
    Process {
        running: true
        command: ["sh", "-c", "for d in /usr/share/icons \"$HOME/.local/share/icons\" \"$HOME/.icons\"; do for t in \"$d\"/*/; do n=$(basename \"$t\"); [ -d \"$t/cursors\" ] && echo \"c $n\"; [ -f \"$t/index.theme\" ] && grep -q '^Directories=' \"$t/index.theme\" && [ \"$n\" != hicolor ] && echo \"i $n\"; done; done 2>/dev/null | sort -u; echo \"cur $(gsettings get org.gnome.desktop.interface icon-theme)\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                sec.iconThemes = l.filter(x => x.startsWith("i ")).map(x => x.slice(2));
                sec.cursorThemes = l.filter(x => x.startsWith("c ")).map(x => x.slice(2));
                const cur = l.find(x => x.startsWith("cur "));
                if (cur) sec.iconTheme = cur.slice(4).replace(/'/g, "");
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
        Slider {
            width: 220; implicitHeight: 36
            icon: "rounded_corner"
            value: Theme.radiusSetting / 32
            label: Math.round(Theme.radiusSetting) + " px"
            onMoved: v => Store.set("theme.radius", Math.round(v * 32))
        }
    }
    SettingRow {
        icon: "font_download"; title: "Font"; desc: "Empty: " + Theme.defaultFont
        Field { text: Store.get("theme.font", ""); placeholder: Theme.defaultFont; onAccepted: v => Store.set("theme.font", v.trim()) }
    }

    SettingRow { icon: "interests"; title: "Icons"; desc: "The icon theme apps use" + (sec.iconTheme ? " (now " + sec.iconTheme + ")" : "") }
    ChipFlow {
        opts: sec.iconThemes; value: sec.iconTheme
        onPicked: v => { sec.iconTheme = v; Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", v]); }
    }
    SettingRow {
        icon: "arrow_selector_tool"; title: "Cursor"; desc: "Theme and size, for niri and apps"
        Segmented {
            width: 240
            opts: [["24", "24"], ["32", "32"], ["40", "40"], ["48", "48"]]
            value: String(sec.cursorSize)
            onPicked: v => sec.setCursor(sec.cursorTheme || "default", Number(v))
        }
    }
    ChipFlow { opts: sec.cursorThemes; value: sec.cursorTheme; onPicked: v => sec.setCursor(v, sec.cursorSize) }
}
