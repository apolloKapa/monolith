import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

ColumnLayout {
    id: favSec
    spacing: 8
    SettingRow {
        key: "search.terminal";
        icon: "terminal"; title: "Terminal app"; desc: "What `> command` runs in, and terminal apps open with"
        Field { text: Prefs.terminal; placeholder: "kitty -e"; onAccepted: v => { if (v.trim() !== "" && v.trim() !== Prefs.terminal) Store.set("search.terminal", v.trim()); } }
    }
    SettingRow {
        key: "search.ranking"; def: true;
        icon: "trending_up"; title: "Usage ranking"; desc: "Apps you open often come first"
        Toggle { checked: Store.get("search.ranking", true) !== false; onToggled: on => Store.set("search.ranking", on) }
    }
    SettingRow {
        key: "launches";
        icon: "delete_sweep"; title: "Forget what it learned"; desc: "Start the ranking over"
        Button { text: "Reset"; onClicked: Store.set("launches", {}) }
    }
    SettingRow {
        key: "search.width"; def: 640;
        icon: "width"; title: "Width"
        NumberBox { from: 400; to: 1400; slideTo: 1100; step: 10; unit: "px"; value: Number(Store.get("search.width", 640)); onMoved: v => Store.set("search.width", v) }
    }
    SettingRow {
        key: "search.grid"; def: false;
        icon: "apps"; title: "All apps as a grid"; desc: "While nothing is typed: icons instead of a list"
        Toggle { checked: Store.get("search.grid", false) === true; onToggled: on => Store.set("search.grid", on) }
    }
    SettingRow {
        key: "search.gridColumns"; def: 6;
        visible: Store.get("search.grid", false) === true
        icon: "grid_view"; title: "Grid columns"
        NumberBox { from: 3; to: 12; value: Number(Store.get("search.gridColumns", 6)); onMoved: v => Store.set("search.gridColumns", v) }
    }
    SettingRow {
        key: "search.categories"; def: false;
        icon: "category"; title: "Category tabs"; desc: "Internet, Games, Media, Office… over the apps while nothing is typed (Alt+←/→ switches)"
        Toggle { checked: Store.get("search.categories", false) === true; onToggled: on => Store.set("search.categories", on) }
    }
    SettingRow {
        key: "search.rows"; def: 7;
        icon: "format_list_numbered"; title: "Results shown"
        NumberBox { from: 1; to: 30; slideTo: 20; value: Number(Store.get("search.rows", 7)); onMoved: v => Store.set("search.rows", v) }
    }
    SettingRow {
        icon: "keyboard"; title: "What you can type"
        desc: "Search: apps.  > runs a command.  : emojis.  / or ~ files.  Any page: just type to search."
    }

    // ── favourites ──
    readonly property var favIds: Store.get("search.favorites", null) || Prefs.favorites
    function moveFav(i, d) {
        const l = favIds.slice();
        const j = i + d;
        if (j < 0 || j >= l.length) return;
        const t = l[i]; l[i] = l[j]; l[j] = t;
        Store.set("search.favorites", l);
    }
    Label { text: "Favourites"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 8 }
    SettingRow {
        key: "search.showFavorites"; def: true;
        icon: "star"; title: "Favourite apps"; desc: "A grid above the list while nothing is typed. Right-click any app in the launcher to pin or unpin it"
        Toggle { checked: Store.get("search.showFavorites", true) !== false; onToggled: on => Store.set("search.showFavorites", on) }
    }
    SettingRow {
        key: "search.favColumns"; def: 6;
        icon: "grid_view"; title: "Favourites per row"
        NumberBox { from: 2; to: 12; value: Number(Store.get("search.favColumns", 6)); onMoved: v => Store.set("search.favColumns", v) }
    }
    Repeater {
        model: favSec.favIds
        Rectangle {
            required property var modelData
            required property int index
            readonly property var entry: DesktopEntries.byId(modelData) || DesktopEntries.byId(modelData + ".desktop")
            Layout.fillWidth: true
            implicitHeight: 48
            radius: Theme.corner(48, 2)
            color: Theme.containerHigh
            Image { id: fi; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; sourceSize: Qt.size(56, 56); source: parent.entry ? Quickshell.iconPath(parent.entry.icon, "application-x-executable") : "" }
            Label { anchors.left: fi.right; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: parent.entry ? parent.entry.name : parent.modelData + " (not installed)" }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Pressable { width: 34; height: 34; color: hovered ? Theme.control : "transparent"; onClicked: favSec.moveFav(index, -1); Icon { anchors.centerIn: parent; name: "arrow_upward"; size: 18 } }
                Pressable { width: 34; height: 34; color: hovered ? Theme.control : "transparent"; onClicked: favSec.moveFav(index, 1); Icon { anchors.centerIn: parent; name: "arrow_downward"; size: 18 } }
                Pressable { width: 34; height: 34; color: hovered ? Qt.alpha(Theme.danger, 0.2) : "transparent"; onClicked: Store.set("search.favorites", favSec.favIds.filter((x, i) => i !== index)); Icon { anchors.centerIn: parent; name: "close"; size: 18 } }
            }
        }
    }
}
