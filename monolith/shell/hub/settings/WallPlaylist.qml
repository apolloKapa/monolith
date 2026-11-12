import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Wallpaper → Playlist: the wallpaper changes on its own, every few minutes from a set of them,
// or at times of day you choose. Settings live in wallpaper.playlist (core/Wall.qml runs it).
ColumnLayout {
    id: sec
    spacing: 8
    readonly property var pl: Wall.playlist
    function put(k, v) { const o = Object.assign({}, Store.get("wallpaper.playlist", ({})) || ({})); o[k] = v; Store.set("wallpaper.playlist", o); }
    readonly property bool timed: (pl.mode || "every") === "times"
    readonly property var times: pl.times || []

    SettingRow {
        key: "wallpaper.playlist";
        icon: "slideshow"; title: "Change the wallpaper by itself"
        desc: Wall.playlistOn ? (sec.timed ? "At the times below" : "Every " + (pl.minutes || 30) + " min, from " + Wall.playlistPool().length + " wallpapers") + "   ·   not during Game mode" : "Off"
        Toggle { checked: Wall.playlistOn; onToggled: on => sec.put("on", on) }
    }
    SettingRow {
        visible: Wall.playlistOn
        icon: "schedule"; title: "When"; desc: "Every few minutes, or at set times of day (a morning and an evening wallpaper)"
        Segmented { width: 260; opts: [["every", "Every few minutes"], ["times", "Times of day"]]; value: pl.mode || "every"; onPicked: v => sec.put("mode", v) }
    }

    // ── every few minutes ──
    SettingRow {
        visible: Wall.playlistOn && !sec.timed
        icon: "timer"; title: "Every"
        NumberBox { from: 1; to: 1440; slideTo: 240; step: 1; unit: " min"; value: pl.minutes || 30; onMoved: v => sec.put("minutes", v) }
    }
    SettingRow {
        visible: Wall.playlistOn && !sec.timed
        icon: "photo_library"; title: "From"; desc: sec.pl.from === "favourites" && Wall.favourites.length === 0 ? "No favourites yet: star wallpapers in the picker (the star on a card, or S)" : Wall.playlistPool().length + " wallpapers"
        Dropdown {
            opts: [["pictures", "Pictures"], ["live", "Live wallpapers"], ["all", "Pictures and live"], ["favourites", "Favourites (" + Wall.favourites.length + ")"]]
            value: sec.pl.from || "pictures"
            onPicked: v => sec.put("from", v)
        }
    }
    SettingRow {
        visible: Wall.playlistOn && !sec.timed
        icon: "shuffle"; title: "Order"
        Segmented { width: 220; opts: [["random", "Shuffled"], ["order", "In order"]]; value: sec.pl.order || "random"; onPicked: v => sec.put("order", v) }
    }
    SettingRow {
        visible: Wall.playlistOn && !sec.timed && Quickshell.screens.length > 1
        icon: "monitor"; title: "A different one on each screen"; desc: "Each screen gets its own pick from the set"
        Toggle { checked: sec.pl.perScreen === true; onToggled: on => sec.put("perScreen", on) }
    }
    SettingRow {
        visible: Wall.playlistOn && !sec.timed
        icon: "skip_next"; title: "Next wallpaper"; desc: "Move on now (the timer starts again)"
        Button { text: "Next"; icon: "skip_next"; onClicked: Wall.playlistNext() }
    }

    // ── times of day ──
    SettingRow {
        visible: Wall.playlistOn && sec.timed
        icon: "add_alarm"; title: "Add a time"; desc: "Uses the wallpaper you have now; pick another one first to use that"
        Button { text: "Add"; icon: "add"; primary: true; onClicked: sec.put("times", sec.times.concat([{ at: Qt.formatTime(new Date(), "hh:mm"), path: Wall.path }])) }
    }
    Repeater {
        model: Wall.playlistOn && sec.timed ? sec.times : []
        SettingRow {
            id: tr
            required property var modelData
            required property int index
            icon: "alarm"; title: tr.modelData.at || "—"
            desc: (tr.modelData.path || "").replace(/^.*\//, "")
            RowLayout {
                spacing: 6
                Field {
                    width: 90; text: tr.modelData.at || ""; placeholder: "07:30"
                    onAccepted: v => {
                        const t = v.trim();
                        if (!/^\d{1,2}:\d{2}$/.test(t) || t === tr.modelData.at) return;
                        const l = sec.times.slice(); l[tr.index] = Object.assign({}, l[tr.index], { at: t }); sec.put("times", l);
                    }
                }
                Button { text: "Use current"; onClicked: { const l = sec.times.slice(); l[tr.index] = Object.assign({}, l[tr.index], { path: Wall.path }); sec.put("times", l); } }
                Pressable {
                    width: 36; height: 36
                    color: hovered ? Qt.alpha(Theme.danger, 0.2) : "transparent"
                    onClicked: sec.put("times", sec.times.filter((_, i) => i !== tr.index))
                    Icon { anchors.centerIn: parent; name: "delete"; size: 20 }
                }
            }
        }
    }
    SettingRow {
        icon: "star"; title: "Favourites"; desc: Wall.favourites.length + " starred. Star wallpapers in the picker: the star on a card (on hover), or S on the one in the middle"
        Button { text: "Open picker"; onClicked: HubState.show("wallpaper") }
    }
}
