import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    id: idleSec
    spacing: 8
    SettingRow {
        key: "idle.enabled";
        icon: "timer"; title: "Lock when idle"; desc: "Lock, then turn the screens off, when you're away (videos and Stay awake pause this)"
        Toggle { checked: Idle.enabled; onToggled: on => Store.set("idle.enabled", on) }
    }
    SettingRow {
        key: "idle.lockAfter";
        icon: "lock"; title: "Lock after"
        NumberBox { from: 1; to: 1440; slideTo: 60; unit: "min"; value: Math.round(Idle.lockAfter / 60); onMoved: v => Store.set("idle.lockAfter", v * 60) }
    }
    SettingRow {
        key: "idle.screenOffAfter";
        icon: "desktop_access_disabled"; title: "Screens off after"
        NumberBox { from: 0; to: 1440; slideTo: 120; unit: "min"; zeroText: "Never"; value: Math.round(Idle.screenOffAfter / 60); onMoved: v => Store.set("idle.screenOffAfter", v * 60) }
    }
    SettingRow {
        key: "idle.dimBefore";
        icon: "brightness_low"; title: "Dim first"; desc: "The screens darken this long before locking (move to stop it)"
        NumberBox { from: 0; to: 600; slideTo: 120; step: 5; unit: "s"; zeroText: "Off"; value: Idle.dimBefore; onMoved: v => Store.set("idle.dimBefore", v) }
    }
    SettingRow {
        key: "idle.suspendAfter";
        icon: "bedtime"; title: "Suspend after"; desc: "Put the PC to sleep when you've been away this long"
        NumberBox { from: 0; to: 1440; slideTo: 240; step: 5; unit: "min"; zeroText: "Never"; value: Idle.suspendAfter / 60; onMoved: v => Store.set("idle.suspendAfter", Math.round(v * 60)) }
    }
    SettingRow {
        key: "idle.mediaPauses";
        icon: "play_circle"; title: "Not while playing"; desc: "Music or video playing counts as being here"
        Toggle { checked: Idle.mediaPauses; onToggled: on => Store.set("idle.mediaPauses", on) }
    }
    SettingRow {
        key: "lock.media"; def: true;
        icon: "music_note"; title: "Media on the lock screen"; desc: "Show what's playing, with play/pause"
        Toggle { checked: Store.get("lock.media", true) !== false; onToggled: on => Store.set("lock.media", on) }
    }
    SettingRow {
        icon: "lock"; title: "Lock now"
        Button { text: "Lock"; onClicked: { HubState.close(); LockState.lock(); } }
    }

    // ── your own idle actions ──
    readonly property var acts: Store.get("idle.actions", [])
    function setAct(i, k, v) { const l = acts.map(x => Object.assign({}, x)); l[i][k] = v; Store.set("idle.actions", l); }
    Label { text: "Your own actions"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 8 }
    SettingRow {
        key: "idle.actions";
        icon: "terminal"; title: "Run a command when you're away"; desc: "After the time you set; the second command runs when you're back (optional)"
        Button { text: "Add"; icon: "add"; onClicked: Store.set("idle.actions", idleSec.acts.concat([{ name: "Action " + (idleSec.acts.length + 1), after: 600, command: "", resume: "" }])) }
    }
    Repeater {
        model: idleSec.acts
        Card {
            required property var modelData
            required property int index
            Layout.fillWidth: true
            Layout.preferredHeight: 196
            icon: "bolt"; title: modelData.name || "Action"
            Column {
                width: parent.width
                spacing: 8
                Row {
                    spacing: 8
                    Label { width: 90; text: "After"; anchors.verticalCenter: parent.verticalCenter; muted: true }
                    NumberBox { width: 320; from: 5; to: 86400; slideTo: 3600; step: 5; unit: "s"; value: Number(modelData.after); onMoved: v => idleSec.setAct(index, "after", v) }
                    Pressable { width: 36; height: 36; color: hovered ? Qt.alpha(Theme.danger, 0.2) : "transparent"; onClicked: Store.set("idle.actions", idleSec.acts.filter((x, i) => i !== index)); Icon { anchors.centerIn: parent; name: "delete"; size: 19; color: Theme.danger } }
                }
                Row { spacing: 8; Label { width: 90; text: "Command"; anchors.verticalCenter: parent.verticalCenter; muted: true } Field { width: 420; text: modelData.command || ""; placeholder: "e.g. playerctl pause"; onAccepted: v => idleSec.setAct(index, "command", v) } }
                Row { spacing: 8; Label { width: 90; text: "When back"; anchors.verticalCenter: parent.verticalCenter; muted: true } Field { width: 420; text: modelData.resume || ""; placeholder: "optional"; onAccepted: v => idleSec.setAct(index, "resume", v) } }
            }
        }
    }
}
