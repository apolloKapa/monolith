import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// The bar's behaviour: auto-hide.
ColumnLayout {
    spacing: 8
    SettingRow {
        key: "status.autohide"; def: false;
        icon: "visibility_off"; title: "Auto-hide"; desc: "The island slides up; touch the top edge to bring it back (Super+A switches this)"
        Toggle { checked: Store.get("status.autohide", false) === true; onToggled: on => Store.set("status.autohide", on) }
    }
}
