import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Sounds: the notification sound, and the interface's own: which pack, how loud, and which
// kinds of things make a sound.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property string style: { Store.revision; return Notifs.soundStyle(); }

    SettingRow {
        key: "notifications.sound"; def: true;
        icon: "volume_up"; title: "Notification sound"; desc: "A short sound when a notification arrives"
        Toggle { checked: Store.get("notifications.sound", true); onToggled: on => Store.set("notifications.sound", on) }
    }
    SettingRow {
        key: "notifications.soundStyle"; def: "system";
        visible: Store.get("notifications.sound", true)
        icon: "music_note"; title: "Which sound"
        desc: sec.style === "pack" ? "The chime of the interface sound pack below (" + (Sounds.packs.find(p => p[0] === Sounds.pack) || ["", "Soft"])[1] + ")" : sec.style === "file" ? "A sound file of your own" : "The system's message sound"
        RowLayout {
            spacing: 6
            Segmented { width: 260; opts: [["system", "System"], ["pack", "Sound pack"], ["file", "Your file"]]; value: sec.style; onPicked: v => Store.set("notifications.soundStyle", v) }
            Button { text: "Play"; icon: "play_arrow"; onClicked: Notifs.playSound(false) }
        }
    }
    SettingRow {
        key: "notifications.soundFile"; def: "";
        visible: Store.get("notifications.sound", true) && sec.style === "file"
        icon: "audio_file"; title: "Your own sound"; desc: "A sound file (.oga, .wav, .mp3)"
        Field { width: 280; text: Store.get("notifications.soundFile", ""); placeholder: "/path/to/sound.oga"; onAccepted: v => { const p = v.trim().replace(/^~/, Wall.home); if (p !== Store.get("notifications.soundFile", "")) Store.set("notifications.soundFile", p); } }
    }

    SettingRow {
        key: "sounds.enabled"; def: false;
        icon: "graphic_eq"; title: "Interface sounds"; desc: "Little sounds for clicks, switches, menus, volume, workspaces, screenshots, locking…"
        Toggle { checked: Sounds.on; onToggled: on => { Store.set("sounds.enabled", on); if (on) Qt.callLater(() => Sounds.play("toggle-on")); } }
    }
    SettingRow {
        key: "sounds.volume"; def: 0.5;
        visible: Sounds.on
        icon: "volume_down"; title: "Interface volume"
        NumberBox { from: 0; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Sounds.volume; onMoved: v => { Store.set("sounds.volume", v); Sounds.play("click"); } }
    }

    // ── the pack: one card each; a click picks it and plays a little of it ──
    SectionHead { visible: Sounds.on; text: "Sound pack" }
    Flow {
        visible: Sounds.on
        Layout.fillWidth: true
        spacing: 8
        Repeater {
            model: Sounds.packs
            Pressable {
                id: pc
                required property var modelData
                readonly property bool cur: Sounds.pack === modelData[0]
                width: (parent.width - 16) / 3
                height: 74
                radius: Theme.corner(56, 2)
                color: cur ? Theme.accentContainer : (hovered ? Theme.mix(Theme.containerHigh, Theme.control, 0.55) : Theme.containerHigh)
                border.width: cur ? 2 : Theme.outlineW
                border.color: cur ? Theme.accent : Theme.outlineColor
                onClicked: { Store.set("sounds.pack", modelData[0]); Sounds.demo(modelData[0]); }
                Icon { id: pi; x: 14; anchors.verticalCenter: parent.verticalCenter; name: pc.cur ? "check_circle" : "graphic_eq"; filled: pc.cur; size: 24; color: pc.cur ? Theme.accent : Theme.subtext }
                Column {
                    anchors.left: pi.right; anchors.leftMargin: 12; anchors.right: parent.right; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Label { width: parent.width; text: pc.modelData[1]; strong: true; elide: Text.ElideRight }
                    Label { width: parent.width; text: pc.modelData[2]; muted: true; font.pixelSize: Theme.sizeSmall; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap }
                }
            }
        }
    }
    SettingRow {
        key: "sounds.customDir"; def: "";
        visible: Sounds.on && Sounds.pack === "custom"
        icon: "folder"; title: "Your sounds folder"; desc: "Missing files are silent. Names: " + Sounds.kinds.map(k => k.slice(2).join(", ")).join(", ")
        Field { width: 280; text: Store.get("sounds.customDir", ""); placeholder: "~/Music/ui-sounds"; onAccepted: v => { if (v.trim() !== Store.get("sounds.customDir", "")) Store.set("sounds.customDir", v.trim()); } }
    }

    // ── which kinds make a sound ──
    SectionHead { visible: Sounds.on; text: "What makes a sound" }
    Repeater {
        model: Sounds.on ? Sounds.kinds : []
        SettingRow {
            id: kr
            required property var modelData
            key: "sounds.events." + modelData[0]; def: true
            icon: ({ clicks: "ads_click", switches: "toggle_on", menus: "menu_open", drops: "drag_pan", volume: "volume_up", workspaces: "view_carousel", screenshots: "screenshot_region", lock: "lock", wallpaper: "wallpaper", errors: "error" })[modelData[0]] || "graphic_eq"
            title: modelData[1]
            RowLayout {
                spacing: 6
                Pressable {
                    width: 36; height: 36
                    color: hovered ? Theme.containerHigh : "transparent"
                    onClicked: Sounds.playFile(Sounds.dir + "/" + kr.modelData[2] + ".wav", Math.max(0.1, Sounds.volume))
                    Icon { anchors.centerIn: parent; name: "play_arrow"; size: 20 }
                }
                Toggle {
                    checked: Sounds.kindOn(kr.modelData[0])
                    onToggled: on => { const e = Object.assign({}, Store.get("sounds.events", ({})) || ({})); e[kr.modelData[0]] = on; Store.set("sounds.events", e); }
                }
            }
        }
    }
}
