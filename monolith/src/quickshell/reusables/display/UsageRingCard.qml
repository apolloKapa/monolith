import QtQuick
import "../"
import "../../"

// A flat card: the value big at the bottom left, its label under it, and a thin ring with an
// icon in the top right corner. Used by the desktop widgets' "Card" variant of CPU, RAM, temperature and disk.
Item {
    id: card
    anchors.fill: parent

    property real value: 0          // 0..1, fills the ring
    property string valueText: ""
    property string label: ""
    property string icon: ""

    Behavior on value { NumberAnimation { duration: 800 * ThemeBackend.animScale; easing.type: Easing.OutQuint } }

    readonly property real pad: Math.min(width, height) * 0.13

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
        radius: ThemeBackend.rad(ThemeBackend.clampedBorderRadius)
        clip: true

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: ThemeBackend.rad(parent.radius)
        }
    }

    Item {
        id: ring
        readonly property real side: Math.min(card.width, card.height) * 0.38
        width: side
        height: side
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: card.pad

        Canvas {
            id: arc
            anchors.fill: parent
            readonly property real v: Math.max(0, Math.min(1, card.value))
            readonly property color track: ThemeBackend.surface1
            readonly property color fill: ThemeBackend.text
            onVChanged: requestPaint()
            onTrackChanged: requestPaint()
            onFillChanged: requestPaint()
            onWidthChanged: requestPaint()
            onPaint: {
                let ctx = getContext("2d");
                ctx.reset();
                let lw = Math.max(2, width * 0.07);
                let r = width / 2 - lw / 2;
                ctx.lineWidth = lw;
                ctx.lineCap = "round";
                ctx.strokeStyle = track;
                ctx.beginPath();
                ctx.arc(width / 2, height / 2, r, 0, 2 * Math.PI);
                ctx.stroke();
                if (v > 0.001) {
                    ctx.strokeStyle = fill;
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, r, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * v);
                    ctx.stroke();
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: card.icon
            font.family: ThemeBackend.iconFont
            font.pixelSize: ring.side * 0.34
            color: ThemeBackend.subtext1
        }
    }

    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: card.pad
        spacing: 0

        Text {
            text: card.valueText
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.min(card.width, card.height) * 0.2
            font.weight: Font.DemiBold
            color: ThemeBackend.text
        }
        Text {
            text: card.label
            font.family: ThemeBackend.fontFamily
            font.pixelSize: Math.min(card.width, card.height) * 0.085
            color: ThemeBackend.subtext0
        }
    }
}
