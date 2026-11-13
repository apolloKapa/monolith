import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Fastfetch: your presets (~/.config/monolith/fastfetch), each with a live preview in the
// shell's colours. Use one, edit it in a terminal, copy, delete, or start a new one; give one
// a picture as its logo (shown with kitty's image support), sized small, medium or large.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property string script: Qt.resolvedUrl("../../scripts/fastfetch.py").toString().replace("file://", "")
    property var list: []
    property bool loaded: false
    function load() { lister.running = true; supportCheck.running = true; }
    // can this fastfetch show pictures at all (distributions may build it without)
    property bool pictures: true
    Process { id: supportCheck; command: ["python3", sec.script, "support"]; stdout: StdioCollector { onStreamFinished: sec.pictures = text.trim() !== "no" } }
    readonly property string fixCommand: "echo 'app-misc/fastfetch imagemagick' | sudo tee -a /etc/portage/package.use/monolith && sudo emerge --oneshot app-misc/fastfetch"
    Component.onCompleted: load()
    // the setting goes to the script directly (the settings file may not be written yet)
    readonly property var ffEnv: ({ MONOLITH_FF_DEFAULTS: Store.get("fastfetch.defaultColors", false) === true ? "1" : "0" })
    Process { id: lister; environment: sec.ffEnv; command: ["python3", sec.script, "list"]; stdout: StdioCollector { onStreamFinished: { try { sec.list = JSON.parse(text); } catch (e) {} sec.loaded = true; } } }
    Process { id: act; environment: sec.ffEnv; onExited: sec.load() }
    function run(args) { act.command = ["python3", sec.script].concat(args); act.running = true; }
    // a picture for a preset: the file picker, then the script fits and sets it
    Process {
        id: picker
        property string preset: ""
        command: ["zenity", "--file-selection", "--title=A picture for the " + preset + " preset",
                  "--file-filter=Pictures | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.PNG *.JPG *.JPEG *.WEBP *.GIF", "--file-filter=All files | *"]
        stdout: StdioCollector { onStreamFinished: { const f = text.trim(); if (f !== "") sec.run(["picture", picker.preset, f]); } }
    }
    function pickPicture(name) { picker.preset = name; picker.running = true; }
    function edit(name) {
        HubState.close();
        Quickshell.execDetached(["sh", "-c", Prefs.terminal + " sh -c '${EDITOR:-nano} \"$1\"' _ \"$1\"", "_", Quickshell.env("HOME") + "/.config/monolith/fastfetch/" + name + ".jsonc"]);
    }

    SettingRow {
        icon: "terminal"; title: "Fastfetchlings"; desc: "The system info a new terminal shows (fastfetch). Pick a preset below; New makes your own. It takes the wallpaper's colours unless you keep fastfetch's own"
        Row {
            spacing: 6
            Button { text: "New"; icon: "add"; onClicked: sec.run(["new"]) }
            Button { text: "Reload"; icon: "refresh"; onClicked: sec.load() }
        }
    }
    SettingRow {
        key: "fastfetch.defaultColors"; def: false;
        icon: "format_color_reset"; title: "Fastfetch's own colours"
        desc: Store.get("fastfetch.defaultColors", false) === true
            ? "On: the greeting keeps fastfetch's normal colours (your distribution's logo colours), not the shell's"
            : "Off: the greeting takes the shell's colours. On: it keeps fastfetch's normal ones"
        Toggle {
            checked: Store.get("fastfetch.defaultColors", false) === true
            // written again in the new colours, and the previews made again
            onToggled: on => { Store.set("fastfetch.defaultColors", on); sec.run(["render"]); }
        }
    }
    // pictures need a fastfetch built with them
    Rectangle {
        visible: !sec.pictures
        Layout.fillWidth: true
        implicitHeight: warnCol.implicitHeight + 28
        radius: Theme.corner(80, 6)
        color: Qt.alpha(Theme.danger, 0.14)
        border.width: 1
        border.color: Qt.alpha(Theme.danger, 0.4)
        Rise {}
        ColumnLayout {
            id: warnCol
            x: 16; y: 14
            width: parent.width - 32
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Icon { name: "warning"; filled: true; size: 20; color: Theme.danger }
                Label { Layout.fillWidth: true; text: "This fastfetch can't show pictures"; strong: true }
            }
            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                muted: true
                text: "It was built without picture support, so a preset with a picture only shows an error. To add it, run this in a terminal (it rebuilds fastfetch with ImageMagick, which you already have), then press Reload:"
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: cmd.implicitHeight + 16
                    radius: Theme.corner(40)
                    color: Theme.m("surface_container_lowest", "#0d0e13")
                    Text { id: cmd; x: 12; y: 8; width: parent.width - 24; text: sec.fixCommand; color: Theme.text; font.family: "monospace"; font.pixelSize: 11; wrapMode: Text.WrapAnywhere }
                }
                Button {
                    id: copyCmd
                    text: "Copy"; icon: "content_copy"
                    onClicked: { Quickshell.execDetached(["wl-copy", sec.fixCommand]); text = "Copied"; resetCopy.restart(); }
                    Timer { id: resetCopy; interval: 1600; onTriggered: copyCmd.text = "Copy" }
                }
            }
        }
    }
    Label { visible: sec.list.length === 0; text: sec.loaded ? "No presets yet: New makes one" : "Loading the previews…"; muted: true; Layout.leftMargin: 6 }
    Repeater {
        model: sec.list
        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: head.height + pv.height + 30
            radius: Theme.corner(80, 6)
            color: modelData.active ? Theme.accentContainer : Theme.container
            border.width: modelData.active ? 2 : 0
            border.color: Theme.accent
            RowLayout {
                id: head
                x: 14; y: 10
                width: parent.width - 28
                height: 40
                Label { text: modelData.name; strong: true; font.pixelSize: Theme.sizeTitle; color: modelData.active ? Theme.onAccentContainer : Theme.text; Layout.fillWidth: true }
                Button { visible: !modelData.active; text: "Use"; primary: true; onClicked: sec.run(["apply", modelData.name]) }
                Button { text: modelData.image ? "Change picture" : "Picture…"; icon: "image"; onClicked: sec.pickPicture(modelData.name) }
                Button { text: "Edit"; icon: "edit"; onClicked: sec.edit(modelData.name) }
                Button { text: "Copy"; icon: "content_copy"; onClicked: sec.run(["duplicate", modelData.name]) }
                Button {
                    id: del
                    visible: !modelData.active
                    property bool armed: false
                    text: armed ? "Sure?" : "Delete"
                    onClicked: { if (armed) sec.run(["delete", modelData.name]); else { armed = true; disarm.restart(); } }
                    Timer { id: disarm; interval: 4000; onTriggered: del.armed = false }
                }
            }
            // a picture preset: its size, and back to the text logo
            RowLayout {
                id: picRow
                visible: !!modelData.image
                x: 14; y: head.y + head.height + 4
                width: parent.width - 28
                height: visible ? 40 : 0
                Icon { name: "image"; size: 18; color: modelData.active ? Theme.onAccentContainer : Theme.subtext }
                Label { text: "Picture logo"; muted: !modelData.active; color: modelData.active ? Theme.onAccentContainer : Theme.subtext; Layout.fillWidth: true }
                Segmented {
                    width: 260
                    opts: [["small", "Small"], ["medium", "Medium"], ["large", "Large"]]
                    value: modelData.size || ""
                    onPicked: v => sec.run(["picsize", modelData.name, v])
                }
                Button { text: "Back to text"; icon: "text_fields"; onClicked: sec.run(["text", modelData.name]) }
            }
            // the preview: fastfetch's output, coloured, on a terminal-like tile
            Rectangle {
                id: pv
                x: 14; y: (picRow.visible ? picRow.y + picRow.height : head.y + head.height) + 8
                width: parent.width - 28
                height: Math.min(360, Math.max(out.implicitHeight, pic.visible ? pic.y + pic.height : 0) + 24)
                radius: Theme.corner(60, 2)
                color: Theme.m("surface_container_lowest", "#0d0e13")
                clip: true
                // where kitty draws the picture (fastfetch can't draw it outside a terminal)
                FontMetrics { id: cellFm; font.family: out.font.family; font.pixelSize: out.font.pixelSize }
                Image {
                    id: pic
                    visible: !!modelData.image
                    x: 12 + (modelData.padLeft || 0) * cellFm.averageCharacterWidth
                    y: 12 + (modelData.padTop || 0) * cellFm.height
                    width: (modelData.cols || 0) * cellFm.averageCharacterWidth
                    height: (modelData.rows || 0) * cellFm.height
                    fillMode: Image.PreserveAspectFit
                    source: modelData.image ? "file://" + modelData.image + "?" + Date.now() : ""
                    sourceSize.width: 400
                    cache: false
                    smooth: true; mipmap: true
                }
                Text {
                    id: out
                    // after the picture, the way fastfetch lays the lines out beside it
                    x: 12 + (pic.visible ? pic.x - 12 + pic.width + 3 * cellFm.averageCharacterWidth : 0)
                    y: 12
                    textFormat: Text.RichText
                    // (no output: fastfetch missing, or the preset doesn't load)
                    text: modelData.html || "<span style='color:" + Theme.subtext + "'>No preview: fastfetch isn't installed, or this preset has an error (Edit it to see)</span>"
                    color: Theme.text
                    font.family: "monospace"
                    font.pixelSize: 11
                }
            }
        }
    }
}
