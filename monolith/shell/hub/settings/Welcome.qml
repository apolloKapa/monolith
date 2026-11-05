import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// First launch: a few choices that make it yours, and how to get around.
ColumnLayout {
    spacing: 8
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: wcol.implicitHeight + 32
        radius: Theme.corner(96, 6)
        color: Theme.accentContainer
        Column {
            id: wcol
            x: 20
            width: parent.width - 40
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4
            Label { text: "Welcome to Monolith"; font.pixelSize: 22; strong: true; color: Theme.onAccentContainer }
            Label { width: parent.width; wrapMode: Text.Wrap; text: "Everything lives in this card. Press Super+Space anywhere and start typing."; color: Theme.onAccentContainer }
        }
    }
    SettingRow {
        icon: "dark_mode"; title: "Dark or light"
        Segmented {
            opts: [["dark", "Dark"], ["light", "Light"]]; value: Theme.modeName
            onPicked: v => { Store.set("theme.mode", v); Quickshell.execDetached(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", v === "dark" ? "prefer-dark" : "prefer-light"]); }
        }
    }
    SettingRow {
        icon: "wallpaper"; title: "A wallpaper"; desc: "The colours are made from it"
        Button { text: "Pick one"; onClicked: HubState.show("wallpaper") }
    }
    SettingRow {
        icon: "rounded_corner"; title: "Corners"
        NumberBox { from: 0; to: 60; slideTo: 40; unit: "px"; value: Math.round(Theme.radiusSetting); onMoved: v => Store.set("theme.radius", v) }
    }
    SettingRow {
        icon: "keyboard"; title: "Getting around"
        desc: "Tab and Shift+Tab move between pages, Esc closes. Everything on the status line opens its page. The Keys page lists every keybind."
    }
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
        Button { text: "Done"; primary: true; icon: "check"; onClicked: { Store.set("welcome.done", true); HubState.settingsSection = "appearance"; HubState.close(); } }
    }
}
