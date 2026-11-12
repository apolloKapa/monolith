import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// General → Profiles & backup: save all your settings under a name and switch between them
// (`monolith profile <name>` does it from a keybind), or back them up to a file and bring
// that back.
ColumnLayout {
    id: sec
    spacing: 8
    Component.onCompleted: Profiles.refresh()
    property bool withWall: true

    SettingRow {
        icon: "add_circle"; title: "Save these settings as a profile"
        desc: "Everything: style, bar, dock, widgets, menus, sounds… " + (sec.withWall ? "and the wallpaper" : "but not the wallpaper (switching keeps yours)")
        RowLayout {
            spacing: 6
            Field { id: nameField; width: 200; placeholder: "Gaming, Clean, Work…"; onAccepted: v => { if (v.trim() !== "") { Profiles.save(v, sec.withWall); nameField.text = ""; } } }
            Button { text: "Save"; icon: "save"; primary: true; onClicked: { if (nameField.text.trim() !== "") { Profiles.save(nameField.text, sec.withWall); nameField.text = ""; } } }
        }
    }
    SettingRow {
        icon: "wallpaper"; title: "Include the wallpaper"; desc: "Off: the profile leaves the wallpaper alone when you switch to it"
        Toggle { checked: sec.withWall; onToggled: on => sec.withWall = on }
    }
    Label { visible: Profiles.message !== ""; Layout.leftMargin: 6; text: Profiles.message; color: Theme.accent; font.pixelSize: Theme.sizeSmall }

    SectionHead { text: Profiles.list.length ? "Your profiles" : "No profiles yet" }
    Repeater {
        model: Profiles.list
        SettingRow {
            id: pr
            required property var modelData
            readonly property bool cur: Profiles.current === modelData.name
            icon: cur ? "check_circle" : "person_pin"
            title: modelData.name + (cur ? "  (the one you're on)" : "")
            desc: "Saved " + (modelData.saved ? Qt.formatDateTime(new Date(modelData.saved), "d MMM yyyy, hh:mm") : "") + (modelData.wallpaper === false ? "   ·   keeps your wallpaper" : "")
            RowLayout {
                spacing: 6
                Button { text: "Switch"; primary: !pr.cur; onClicked: Profiles.apply(pr.modelData.name) }
                Button { text: "Update"; onClicked: Profiles.save(pr.modelData.name, pr.modelData.wallpaper !== false) }
                Pressable {
                    width: 40; height: 40
                    color: hovered ? Qt.alpha(Theme.danger, 0.2) : "transparent"
                    onClicked: Profiles.remove(pr.modelData.name)
                    Icon { anchors.centerIn: parent; name: "delete"; size: 20 }
                }
            }
        }
    }
    SettingRow {
        icon: "keyboard"; title: "From a keybind"; desc: "monolith profile <name>   (e.g. in niri: Mod+F9 { spawn \"monolith\" \"profile\" \"Gaming\"; })"
    }

    SectionHead { text: "Backup" }
    SettingRow {
        icon: "upload_file"; title: "Back up to a file"; desc: "All your Monolith settings in one .json (to keep, or to take to another PC)"
        Button { text: "Back up…"; icon: "download"; onClicked: Profiles.exportTo() }
    }
    SettingRow {
        icon: "restore_page"; title: "Bring back from a file"; desc: "A backup, a profile or a next.json. What you have now is saved as a profile first"
        Button { text: "Open…"; icon: "folder_open"; onClicked: Profiles.importFrom() }
    }
}
