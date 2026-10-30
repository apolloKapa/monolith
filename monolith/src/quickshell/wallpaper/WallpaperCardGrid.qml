import QtQuick
import Quickshell.Widgets
import "../"
import "../reusables"

// The wallpaper picker's grid: rounded 16:9 cards in rows, scrolling down. It replaced the
// honeycomb, which built a masked tile for every wallpaper up front and decoded each full-size
// image: this only makes the cards on screen, and they show the indexer's small thumbnails
// (scripts/wallpaper/indexer.py), so the picker fills in at once. The picker's ListView stays
// the source of truth for the selection (arrow keys, filters, search); this follows
// listView.currentIndex.
GridView {
    id: grid

    required property var picker
    required property var listView

    readonly property string thumbDir: Caching.getCacheDir("wallpaper") + "/cards/"
    readonly property real side: picker.s(40)
    readonly property real gap: picker.s(14)
    readonly property int columns: Math.max(2, Math.floor((width - 2 * side) / picker.s(300)))

    leftMargin: side
    rightMargin: side
    topMargin: picker.s(22)
    bottomMargin: picker.s(40)
    // end where the panel behind the cards (in the picker) ends, short of the screen's edge
    anchors.bottomMargin: picker.s(20)
    cellWidth: Math.floor((width - 2 * side) / columns)
    cellHeight: Math.round((cellWidth - gap) * 9 / 16) + gap

    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: !picker.isApplying
    cacheBuffer: cellHeight * 2
    reuseItems: true
    currentIndex: listView.currentIndex
    highlightFollowsCurrentItem: false
    keyNavigationEnabled: false

    // keep the selected card in view, gliding there instead of jumping
    function reveal(i, animate) {
        if (i < 0 || i >= count || height <= 0) return;
        const from = contentY;
        positionViewAtIndex(i, GridView.Contain);
        const to = contentY;
        if (!animate || from === to) return;
        contentY = from;
        scrollAnim.to = to;
        scrollAnim.restart();
    }
    NumberAnimation { id: scrollAnim; target: grid; property: "contentY"; duration: (320) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
    onMovementStarted: scrollAnim.stop()

    Connections {
        target: grid.listView
        function onCurrentIndexChanged() { grid.reveal(grid.listView.currentIndex, true); }
    }
    onCountChanged: Qt.callLater(() => grid.reveal(grid.listView.currentIndex, false))
    onVisibleChanged: if (visible) Qt.callLater(() => grid.reveal(grid.listView.currentIndex, false))

    delegate: Item {
        id: card
        required property int index
        required property var model

        readonly property string fileName: model.fileName !== undefined ? String(model.fileName) : ""
        readonly property string filePath: model.filePath !== undefined ? String(model.filePath) : ""
        readonly property string fileUrl: model.fileUrl !== undefined ? String(model.fileUrl) : ""
        readonly property string posterUrl: model.posterUrl !== undefined ? String(model.posterUrl) : ""
        readonly property bool isVideo: (model.isVideo !== undefined && model.isVideo !== null) ? !!model.isVideo : /\.(mp4|mkv|mov|webm)$/i.test(fileName)
        readonly property bool isCurrent: index === grid.listView.currentIndex
        readonly property string thumbUrl: filePath !== "" ? "file://" + grid.thumbDir + Qt.md5(filePath) + ".jpg" : ""
        // no thumbnail yet (the indexer hasn't reached it): the original, scaled down
        property bool thumbFailed: false
        onFilePathChanged: thumbFailed = false

        width: grid.cellWidth
        height: grid.cellHeight

        Item {
            id: face
            x: grid.gap / 2
            y: grid.gap / 2
            width: parent.width - grid.gap
            height: parent.height - grid.gap
            scale: card.isCurrent ? 1.0 : (hoverArea.containsMouse ? 1.03 : 0.97)
            Behavior on scale { NumberAnimation { duration: (160) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }

            // ring round the selected card
            Rectangle {
                anchors.fill: parent
                anchors.margins: -grid.picker.s(4)
                radius: ThemeBackend.rad(grid.picker.s(18))
                color: "transparent"
                border.width: grid.picker.s(3)
                border.color: ThemeBackend.mauve
                opacity: card.isCurrent ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: (160) * ThemeBackend.animScale } }
            }

            ClippingRectangle {
                anchors.fill: parent
                radius: ThemeBackend.rad(grid.picker.s(14))
                color: ThemeBackend.surface1

                Image {
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: Math.round(face.width * 1.25)
                    source: card.thumbFailed ? (card.isVideo ? card.posterUrl : card.fileUrl) : card.thumbUrl
                    onStatusChanged: if (status === Image.Error && !card.thumbFailed) card.thumbFailed = true
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#000000"
                    opacity: hoverArea.pressed ? 0.25 : 0
                }
            }

            Text {
                visible: card.isVideo
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.margins: grid.picker.s(10)
                text: "󰐊"
                font.family: ThemeBackend.iconFont
                font.pixelSize: grid.picker.s(22)
                color: "#ffffff"
                style: Text.Outline
                styleColor: Qt.rgba(0, 0, 0, 0.35)
            }
        }

        MouseArea {
            id: hoverArea
            anchors.fill: face
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            enabled: !grid.picker.isApplying
            onClicked: {
                grid.picker.initialFocusSet = true;
                grid.listView.currentIndex = card.index;
                grid.picker.applyWallpaper(card.fileName, card.isVideo);
            }
        }
    }
}
