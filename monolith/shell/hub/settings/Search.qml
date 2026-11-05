import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "terminal"; title: "Terminal"; desc: "What `> command` runs in, and terminal apps open with"
        Field { text: Prefs.terminal; placeholder: "kitty -e"; onAccepted: v => { if (v.trim() !== "" && v.trim() !== Prefs.terminal) Store.set("search.terminal", v.trim()); } }
    }
    SettingRow {
        icon: "trending_up"; title: "Usage ranking"; desc: "Apps you open often come first. Forget what it has learned:"
        Button { text: "Reset"; onClicked: Store.set("launches", {}) }
    }
    SettingRow {
        icon: "keyboard"; title: "Typing"
        desc: "Search: apps.  > runs a command.  : emojis.  / or ~ files.  Any page: just type to search."
    }
}
