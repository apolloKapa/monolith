import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Sound effects: every little sound Monolith makes, in one place. Switched on as a whole (and how
// loud), the pack they're played in, then each one on its own, by where it comes from: clicking
// around, menus and typing, windows and apps, notifications (with their own tone) and the system.
// Each row plays its sound.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property string nstyle: { Store.revision; return Notifs.soundStyle(); }
    readonly property bool notifOn: Store.get("notifications.sound", true) !== false
    function hear(name) { Sounds.playFile(Sounds.dir + "/" + name + ".wav", Math.max(0.15, Sounds.volume) * (Sounds.gain[name] || 1)); }

    // ── on, how loud, how they're played ──
    SettingRow {
        key: "sounds.enabled"; def: false;
        icon: "graphic_eq"; title: "Sound effects"; desc: "Little sounds as you use Monolith. Pick which below; notifications have their own switch"
        Toggle { checked: Sounds.on; onToggled: on => { Store.set("sounds.enabled", on); if (on) Qt.callLater(() => Sounds.play("toggle-on")); } }
    }
    SettingRow {
        key: "sounds.volume"; def: 0.5;
        visible: Sounds.on
        icon: "volume_down"; title: "Volume"; desc: "How loud the effects are, next to everything else"
        NumberBox { from: 0; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Sounds.volume; onMoved: v => { Store.set("sounds.volume", v); Sounds.play("click"); } }
    }
    SettingRow {
        key: "sounds.player"; def: "auto";
        icon: "speaker"; title: "How they're played"
        desc: Sounds.engine === "" ? "Nothing on this system can play sounds: install PipeWire (pw-play) or PulseAudio (paplay)"
            : "Now with " + Sounds.engine + (Sounds.how === "auto" ? ". Automatic: Qt's own audio, or the system's player when there's no sound server for Qt" : "")
        Dropdown {
            width: 200; height: 36
            opts: [["auto", "Automatic"], ["qt", "Qt's audio"], ["system", "System player"]]
            value: Sounds.how
            onPicked: v => { Store.set("sounds.player", v); Qt.callLater(() => sec.hear("click")); }
        }
    }

    // ── the pack: one card each; a click picks it and plays a little of it ──
    SectionHead { visible: Sounds.on; text: "Sound pack" }
    SettingRow {
        key: "sounds.followStyle"; def: true;
        visible: Sounds.on && Sounds.stylePack !== ""
        icon: "palette"; title: "Use the style's sounds"; desc: Look.style.name + " has its own sounds; they play instead of the pack you picked"
        Toggle { checked: Sounds.followStyle; onToggled: on => { Store.set("sounds.followStyle", on); Qt.callLater(() => Sounds.demo(Sounds.pack)); } }
    }
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
                onClicked: { Store.set("sounds.pack", modelData[0]); if (modelData[0] !== Sounds.stylePack) Store.set("sounds.followStyle", false); Sounds.demo(modelData[0]); }
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
        icon: "folder"; title: "Your sounds folder"; desc: "One .wav for each sound; missing ones are silent. Names: " + Sounds.list.map(e => e[0]).join(", ") + ", notify"
        Field { width: 280; text: Store.get("sounds.customDir", ""); placeholder: "~/Music/ui-sounds"; onAccepted: v => { if (v.trim() !== Store.get("sounds.customDir", "")) Store.set("sounds.customDir", v.trim()); } }
    }

    // ── every sound, by where it comes from ──
    Repeater {
        model: Sounds.groups
        ColumnLayout {
            id: grp
            required property var modelData
            readonly property var evs: Sounds.list.filter(e => e[1] === grp.modelData[0])
            readonly property bool anyOn: { Store.revision; return evs.some(e => Sounds.eventOn(e[0])); }
            // (notifications show even with the effects off: their sound has its own switch)
            visible: Sounds.on || grp.modelData[0] === "notifications"
            Layout.fillWidth: true
            spacing: 8
            SectionHead {
                text: grp.modelData[1]
                action: Sounds.on ? (grp.anyOn ? "toggle_on" : "toggle_off") : ""
                hint: grp.anyOn ? "All off" : "All on"
                onActed: Sounds.setGroup(grp.modelData[0], !grp.anyOn)
            }
            // notifications: the sound one makes arriving
            SettingRow {
                visible: grp.modelData[0] === "notifications"
                Layout.fillWidth: true
                key: "notifications.sound"; def: true;
                icon: "notifications_active"; title: "A notification arriving"; desc: "Plays even with the effects off; not for apps that ask for quiet"
                Toggle { checked: sec.notifOn; onToggled: on => Store.set("notifications.sound", on) }
            }
            SettingRow {
                visible: grp.modelData[0] === "notifications" && sec.notifOn
                Layout.fillWidth: true
                key: "notifications.soundStyle"; def: "tone";
                icon: "music_note"; title: "Its sound"
                desc: sec.nstyle === "tone" ? "One of Monolith's tones (urgent ones get an alert)" : sec.nstyle === "pack" ? "The sound pack's chime (" + ((Sounds.packs.find(p => p[0] === Sounds.pack) || ["", "Soft"])[1]) + ")" : sec.nstyle === "file" ? "A sound file of your own" : "The system's message sound (Monolith's tone when it has none)"
                RowLayout {
                    spacing: 6
                    Segmented { width: 300; opts: [["tone", "Monolith"], ["pack", "Pack"], ["system", "System"], ["file", "Your file"]]; value: sec.nstyle; onPicked: v => { Store.set("notifications.soundStyle", v); Qt.callLater(() => Notifs.playSound(false)); } }
                    Button { text: "Play"; icon: "play_arrow"; onClicked: Notifs.playSound(false) }
                }
            }
            SettingRow {
                visible: grp.modelData[0] === "notifications" && sec.notifOn && sec.nstyle === "tone"
                Layout.fillWidth: true
                key: "notifications.tone"; def: "chime";
                icon: "library_music"; title: "Tone"; desc: "Urgent notifications play an alert instead"
                RowLayout {
                    spacing: 6
                    Dropdown {
                        width: 180; height: 36
                        opts: Notifs.tones
                        value: Store.get("notifications.tone", "chime") || "chime"
                        onPicked: v => { Store.set("notifications.tone", v); Qt.callLater(() => Notifs.playSound(false)); }
                    }
                    Button { text: "Urgent"; icon: "priority_high"; onClicked: Notifs.playSound(true) }
                }
            }
            SettingRow {
                visible: grp.modelData[0] === "notifications" && sec.notifOn && sec.nstyle === "file"
                Layout.fillWidth: true
                key: "notifications.soundFile"; def: "";
                icon: "audio_file"; title: "Your own sound"; desc: "A sound file (.oga, .wav, .mp3)"
                Field { width: 280; text: Store.get("notifications.soundFile", ""); placeholder: "/path/to/sound.oga"; onAccepted: v => { const p = v.trim().replace(/^~/, Wall.home); if (p !== Store.get("notifications.soundFile", "")) Store.set("notifications.soundFile", p); } }
            }
            SettingRow {
                visible: grp.modelData[0] === "notifications" && sec.notifOn
                Layout.fillWidth: true
                key: "notifications.soundVolume"; def: 0.8;
                icon: "volume_up"; title: "Its volume"
                NumberBox { from: 0.05; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Number(Store.get("notifications.soundVolume", 0.8)); onMoved: v => Store.set("notifications.soundVolume", v) }
            }
            Repeater {
                model: Sounds.on ? grp.evs : []
                SettingRow {
                    id: er
                    required property var modelData
                    Layout.fillWidth: true
                    key: "sounds.events." + modelData[0]; def: true
                    icon: modelData[3]; title: modelData[2]; desc: modelData[4]
                    RowLayout {
                        spacing: 6
                        Pressable {
                            width: 36; height: 36
                            color: hovered ? Theme.containerHigh : "transparent"
                            onClicked: sec.hear(er.modelData[0])
                            Icon { anchors.centerIn: parent; name: "play_arrow"; size: 20 }
                        }
                        Toggle {
                            checked: { Store.revision; return Sounds.eventOn(er.modelData[0]); }
                            onToggled: on => Sounds.setEvent(er.modelData[0], on)
                        }
                    }
                }
            }
        }
    }
}
