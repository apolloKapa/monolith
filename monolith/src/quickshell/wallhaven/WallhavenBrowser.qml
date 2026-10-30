import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"

// Wallhaven browser (monolith msg toggle wallhaven): search wallhaven.cc and set a wallpaper.
// Off until you turn it on (it talks to wallhaven.cc); safe-for-work results only. Picked
// wallpapers are saved to <your wallpaper folder>/wallhaven/.
PopupShell {
    id: root

    readonly property bool allowed: (Config.getSetting("online", {}) || {}).wallhaven === true
    property string sorting: "toplist"
    property var results: []
    property int page: 1
    property bool loading: false
    property bool failed: false
    property string busyId: ""
    readonly property string wallDir: Config.getSetting("wallpaperDir", "") || (Quickshell.env("HOME") + "/Pictures/Wallpapers")
    focusTarget: search.field

    onOpened: {
        if (root.allowed && root.results.length === 0) root.fetch(true);
    }

    function enable() {
        let o = Config.getSetting("online", {}) || {};
        o.wallhaven = true;
        Config.setSetting("online", o);
        Qt.callLater(() => root.fetch(true));
    }

    function fetch(reset) {
        if (!root.allowed) return;
        if (reset) { root.page = 1; root.results = []; }
        root.loading = true;
        root.failed = false;
        let q = encodeURIComponent(search.text.trim());
        let scr = Quickshell.screens.length > 0 ? Quickshell.screens[0] : null;
        let atleast = scr ? (scr.width + "x" + scr.height) : "1920x1080";
        let url = "https://wallhaven.cc/api/v1/search?categories=110&purity=100&sorting=" + root.sorting
            + (root.sorting === "toplist" ? "&topRange=1M" : "") + "&atleast=" + atleast + "&page=" + root.page + (q ? "&q=" + q : "");
        searchProc.command = ["curl", "-fsS", "-m", "15", "-A", "Monolith", url];
        searchProc.running = true;
    }

    function pick(item) {
        root.busyId = item.id;
        let ext = item.path.substring(item.path.lastIndexOf("."));
        let dest = root.wallDir + "/wallhaven/wallhaven-" + item.id + ext;
        downloadProc.dest = dest;
        downloadProc.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && curl -fsSL -m 120 -A Monolith -o \"$1.part\" \"$2\" && mv \"$1.part\" \"$1\"", "sh", dest, item.path];
        downloadProc.running = true;
    }

    Process {
        id: searchProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    let d = JSON.parse(this.text);
                    root.results = root.results.concat(d.data || []);
                } catch (e) {
                    root.failed = true;
                }
            }
        }
        onExited: (code) => { if (code !== 0) { root.loading = false; root.failed = true; } }
    }

    Process {
        id: downloadProc
        property string dest: ""
        onExited: (code) => {
            root.busyId = "";
            if (code === 0) {
                Wallpaper.setWallpaper("all", downloadProc.dest, "fade");
            } else {
                Quickshell.execDetached(["notify-send", "-a", "Wallhaven", "Couldn't download the wallpaper"]);
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.s(14)

        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignTop
            spacing: root.s(12)
            Text {
                text: "Wallhaven"
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(22)
                font.weight: ThemeBackend.weightBold
            }
            SearchBox {
                id: search
                Layout.fillWidth: true
                enabled: root.allowed
                placeholderText: I18n.t("wallhaven.search", "Search wallhaven.cc (empty = popular)")
                onAccepted: root.fetch(true)
            }
            Repeater {
                model: [
                    { id: "toplist", label: I18n.t("wallhaven.top", "Top") },
                    { id: "date_added", label: I18n.t("wallhaven.latest", "Latest") },
                    { id: "random", label: I18n.t("wallhaven.random", "Random") }
                ]
                Rectangle {
                    required property var modelData
                    implicitWidth: sortText.implicitWidth + root.s(22)
                    implicitHeight: root.s(36)
                    radius: ThemeBackend.rad(root.s(10))
                    color: root.sorting === modelData.id ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.surface0, 0.8)
                    opacity: root.allowed ? 1 : 0.4
                    Text {
                        id: sortText
                        anchors.centerIn: parent
                        text: parent.modelData.label
                        color: root.sorting === parent.modelData.id ? ThemeBackend.crust : ThemeBackend.text
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: root.s(12)
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: root.allowed
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { root.sorting = parent.modelData.id; root.fetch(true); }
                    }
                }
            }
        }

        // off until turned on
        ColumnLayout {
            Layout.alignment: Qt.AlignCenter
            Layout.fillHeight: true
            visible: !root.allowed
            spacing: root.s(12)
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: root.s(520)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: I18n.t("wallhaven.offline", "Browsing Wallhaven talks to wallhaven.cc (searches and image downloads), so it's off until you turn it on. Only safe-for-work wallpapers are shown.")
                color: ThemeBackend.subtext1
                font.family: ThemeBackend.fontFamily
                font.pixelSize: root.s(13)
            }
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: onText.implicitWidth + root.s(30)
                implicitHeight: root.s(38)
                radius: ThemeBackend.rad(root.s(12))
                color: ThemeBackend.mauve
                Text {
                    id: onText
                    anchors.centerIn: parent
                    text: I18n.t("wallhaven.enable", "Turn on Wallhaven")
                    color: ThemeBackend.crust
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: root.s(13)
                    font.weight: ThemeBackend.weightBold
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.enable() }
            }
        }

        GridView {
            id: grid
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.allowed
            clip: true
            readonly property int cols: Math.max(2, Math.floor(width / root.s(250)))
            cellWidth: width / cols
            cellHeight: cellWidth * 0.62
            model: root.results
            onAtYEndChanged: if (atYEnd && !root.loading && root.results.length > 0) { root.page += 1; root.fetch(false); }

            delegate: Item {
                id: cell
                required property var modelData
                width: grid.cellWidth
                height: grid.cellHeight
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: root.s(5)
                    radius: ThemeBackend.rad(root.s(10))
                    color: ThemeBackend.surface0
                    clip: true
                    border.width: cellMa.containsMouse ? 2 : 0
                    border.color: ThemeBackend.mauve
                    Image {
                        anchors.fill: parent
                        anchors.margins: parent.border.width
                        source: cell.modelData.thumbs ? cell.modelData.thumbs.small : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                    Rectangle {
                        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                        height: root.s(22)
                        color: Qt.alpha("#000000", 0.55)
                        visible: cellMa.containsMouse || root.busyId === cell.modelData.id
                        Text {
                            anchors.centerIn: parent
                            text: root.busyId === cell.modelData.id ? I18n.t("wallhaven.downloading", "Downloading…") : cell.modelData.resolution
                            color: "#ffffff"
                            font.family: ThemeBackend.fontFamily
                            font.pixelSize: root.s(11)
                        }
                    }
                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: root.busyId === ""
                        onClicked: root.pick(cell.modelData)
                    }
                }
            }

            WheelScroll {}
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            visible: root.allowed && (root.loading || root.failed || (root.results.length === 0))
            text: root.loading ? I18n.t("wallhaven.loading", "Loading…") : (root.failed ? I18n.t("wallhaven.failed", "Couldn't reach wallhaven.cc") : I18n.t("wallhaven.none", "No wallpapers found"))
            color: ThemeBackend.subtext0
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.s(12)
        }
    }
}
