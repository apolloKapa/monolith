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
        icon: "trending_up"; title: "Usage ranking"; desc: "Apps you open often come first"
        Toggle { checked: Store.get("search.ranking", true) !== false; onToggled: on => Store.set("search.ranking", on) }
    }
    SettingRow {
        icon: "delete_sweep"; title: "Forget what it learned"; desc: "Start the ranking over"
        Button { text: "Reset"; onClicked: Store.set("launches", {}) }
    }
    SettingRow {
        icon: "format_list_numbered"; title: "Results shown"
        NumberBox { from: 1; to: 30; slideTo: 20; value: Number(Store.get("search.rows", 7)); onMoved: v => Store.set("search.rows", v) }
    }
    SettingRow {
        icon: "keyboard"; title: "Typing"
        desc: "Search: apps.  > runs a command.  : emojis.  / or ~ files.  Any page: just type to search."
    }
}
