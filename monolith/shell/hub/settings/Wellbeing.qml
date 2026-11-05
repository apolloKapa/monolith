import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "self_improvement"; title: "Track screen time"; desc: "How long each app is focused (not while you're away). Kept two weeks, only on this PC"
        Toggle { checked: Store.get("wellbeing.track", true) !== false; onToggled: on => Store.set("wellbeing.track", on) }
    }
    SettingRow {
        icon: "hourglass"; title: "Limits"; desc: "Right-click an app on the Wellbeing page to give it a daily limit"
        Button { text: "Open"; onClicked: HubState.page = "wellbeing" }
    }
    SettingRow {
        icon: "delete"; title: "Forget screen time"; desc: "Delete what has been tracked so far"
        Button { id: clr; property bool armed: false; text: armed ? "Sure?" : "Delete"; onClicked: { if (armed) { Wellbeing.clear(); armed = false; } else { armed = true; disarm.restart(); } } Timer { id: disarm; interval: 4000; onTriggered: clr.armed = false } }
    }
}
