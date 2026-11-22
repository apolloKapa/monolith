import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Default apps: which app opens links, folders, text, videos, music, pictures, PDFs, mail and
// archives. Kept in ~/.config/mimeapps.list, where every app, the file manager and xdg-open look
// (scripts/default_apps.py). Each list has the installed apps that say they can open those.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property string script: Qt.resolvedUrl("../../scripts/default_apps.py").toString().replace("file://", "")
    property var roles: []
    property bool loaded: false
    function load() { listProc.running = true; }
    Component.onCompleted: load()
    Process {
        id: listProc
        command: ["python3", sec.script, "list"]
        stdout: StdioCollector { onStreamFinished: { try { sec.roles = JSON.parse(text); sec.loaded = true; } catch (e) {} } }
    }
    Process { id: setProc; onExited: sec.load() }
    function roleOf(id) { return roles.find(r => r.id === id) || null; }
    function set(id, app) {
        if (app === "" || setProc.running) return;
        // (shown at once; the list is read again once it's saved)
        roles = roles.map(r => r.id === id ? Object.assign({}, r, { current: app }) : r);
        setProc.command = ["python3", script, "set", id, app];
        setProc.running = true;
    }

    // the app for one kind of file: every app that can open it
    component Pick: Dropdown {
        property string role: ""
        readonly property var r: sec.roleOf(role)
        readonly property bool none: !!r && r.apps.length === 0
        width: 280; height: 36
        opts: !r ? [["", sec.loaded ? "None installed" : "Looking…"]] : none ? [["", "None installed"]] : r.apps.map(a => [a.id, a.name])
        value: r ? r.current : ""
        onPicked: v => sec.set(role, v)
    }

    Label {
        Layout.fillWidth: true; Layout.bottomMargin: 4
        wrapMode: Text.WordWrap; muted: true; font.pixelSize: Theme.sizeSmall
        text: "The app that opens each kind of file or link, for every app and the file manager. Only apps that say they can open it are listed."
    }
    SettingRow { icon: "language"; title: "Web browser"; desc: "Links and web pages"; Pick { role: "browser" } }
    SettingRow { icon: "folder_open"; title: "File manager"; desc: "Folders, and \"Show in folder\""; Pick { role: "files" } }
    SettingRow { icon: "edit_note"; title: "Text editor"; desc: "Plain text, notes, logs, scripts and settings files"; Pick { role: "editor" } }
    SettingRow { icon: "movie"; title: "Video player"; desc: "MP4, MKV, WebM and other videos"; Pick { role: "video" } }
    SettingRow { icon: "music_note"; title: "Music player"; desc: "MP3, FLAC, Ogg and other audio files"; Pick { role: "music" } }
    SettingRow { icon: "image"; title: "Image viewer"; desc: "PNG, JPEG, WebP, GIF and other pictures"; Pick { role: "images" } }
    SettingRow { icon: "picture_as_pdf"; title: "PDF viewer"; desc: "PDF documents"; Pick { role: "pdf" } }
    SettingRow { icon: "mail"; title: "Email"; desc: "Email links (mailto:)"; Pick { role: "mail" } }
    SettingRow { icon: "folder_zip"; title: "Archive manager"; desc: "ZIP, 7z, RAR and tar archives"; Pick { role: "archives" } }
}
