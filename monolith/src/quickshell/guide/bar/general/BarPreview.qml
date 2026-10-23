import QtQuick
import QtQuick.Window
import "../../../"

// A small picture of the screen with the bar drawn the way the settings describe it: style,
// position, width, thickness, the gaps between pills and sections, the Frame's border. Used as
// the live preview at the top of Settings -> Bar and in the style cards (with `style` set).
Item {
    id: prev

    property string style: "modular"
    property string position: "top"
    property real widthPct: 100
    property real thickness: 40
    property real pillGap: 2
    property real sectionGap: 10
    property real frameThickness: 8
    property bool distinctPills: false
    property bool autohide: false
    property bool showWindows: true

    // the screen the bar is on, in logical pixels; everything is scaled down from it
    // landscape: draw a 16:9 screen whatever this one is (the style cards)
    property bool landscape: false
    readonly property real screenW: landscape ? 1920 : (Screen.width > 0 ? Screen.width : 1920)
    readonly property real screenH: landscape ? 1080 : (Screen.height > 0 ? Screen.height : 1080)
    implicitHeight: width * screenH / screenW
    // exaggerated a little so thin bars and small gaps stay visible at this size
    // how much bigger than life the bar is drawn (the small style cards exaggerate more)
    property real zoom: 1.35
    readonly property real k: (width / screenW) * zoom

    readonly property bool vertical: position === "left" || position === "right"
    readonly property bool flush: style === "fill" || style === "frame"
    readonly property real barH: Math.max(4, thickness * k)
    readonly property real frameW: style === "frame" ? Math.max(1, frameThickness * k) : 0
    readonly property real edge: flush ? 0 : Math.max(2, 4 * k)
    readonly property real along: vertical ? height : width
    readonly property real span: flush ? along : along * Math.min(1, widthPct / 100)

    readonly property color pillColor: ThemeBackend.material ? ThemeBackend.surfaceContainerHigh : Qt.lighter(ThemeBackend.surface0, 1.25)
    readonly property color barColor: ThemeBackend.material ? ThemeBackend.surfaceContainer : ThemeBackend.base
    readonly property real r: ThemeBackend.square ? 0 : barH / 2

    // the bar's contents: left, centre and right groups of pills (lengths in screen pixels)
    readonly property var groups: [[64, 150], [130], [70, 46]]

    Rectangle {
        anchors.fill: parent
        radius: ThemeBackend.square ? 0 : Math.min(ThemeBackend.borderRadius, 14)
        clip: true
        gradient: Gradient {
            orientation: Gradient.Vertical
            GradientStop { position: 0.0; color: Qt.tint(ThemeBackend.surface1, Qt.alpha(ThemeBackend.mauve, 0.35)) }
            GradientStop { position: 1.0; color: Qt.tint(ThemeBackend.crust, Qt.alpha(ThemeBackend.blue, 0.25)) }
        }

        // your wallpaper, when there is one
        Image {
            anchors.fill: parent
            source: Caching.getCacheDir("wallpaper") ? "file://" + Caching.getCacheDir("wallpaper") + "/current_wallpaper.png" : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
            sourceSize.width: 640
            opacity: status === Image.Ready ? 1 : 0
        }

        // a couple of windows, so the space the bar takes reads as space
        Repeater {
            model: prev.showWindows ? 2 : 0
            Rectangle {
                readonly property real inL: prev.position === "left" ? prev.barH + prev.edge * 2 : prev.frameW + prev.width * 0.03
                readonly property real inR: prev.position === "right" ? prev.barH + prev.edge * 2 : prev.frameW + prev.width * 0.03
                readonly property real inT: prev.position === "top" ? prev.barH + prev.edge * 2 : prev.frameW + prev.height * 0.05
                readonly property real inB: prev.position === "bottom" ? prev.barH + prev.edge * 2 : prev.frameW + prev.height * 0.05
                readonly property real colW: (prev.width - inL - inR - prev.width * 0.02) / 2
                x: inL + index * (colW + prev.width * 0.02)
                y: inT
                width: colW
                height: prev.height - inT - inB
                radius: ThemeBackend.square ? 0 : 4
                color: Qt.alpha(ThemeBackend.base, 0.85)
                border.width: 1
                border.color: Qt.alpha(ThemeBackend.text, 0.12)
                Rectangle { x: 6; y: 6; width: parent.width * 0.5; height: 3; radius: 1.5; color: Qt.alpha(ThemeBackend.text, 0.25) }
                Rectangle { x: 6; y: 13; width: parent.width * 0.35; height: 3; radius: 1.5; color: Qt.alpha(ThemeBackend.text, 0.15) }
            }
        }

        // the Frame style's border round the screen
        Rectangle {
            visible: prev.frameW > 0
            anchors.fill: parent
            color: "transparent"
            border.width: prev.frameW
            border.color: prev.barColor
        }

        // the bar, drawn lying along the top, then turned to its edge
        Item {
            id: barLayer
            width: prev.along
            height: prev.barH + prev.edge
            opacity: prev.autohide ? 0.45 : 1.0
            transformOrigin: Item.TopLeft
            rotation: prev.position === "left" ? -90 : (prev.position === "right" ? 90 : (prev.position === "bottom" ? 180 : 0))
            x: prev.position === "right" ? prev.width : (prev.position === "bottom" ? prev.width : 0)
            y: prev.position === "left" ? prev.height : (prev.position === "bottom" ? prev.height : 0)

            // solid / fill / frame: one bar behind everything
            Rectangle {
                visible: prev.style === "solid" || prev.flush
                x: (prev.along - prev.span) / 2
                y: prev.edge
                width: prev.span
                height: prev.barH
                color: prev.barColor
                radius: prev.flush ? 0 : prev.r
            }

            // island: one pill in the middle
            Rectangle {
                visible: prev.style === "island"
                anchors.horizontalCenter: parent.horizontalCenter
                y: prev.edge
                width: 190 * prev.k
                height: prev.barH
                radius: prev.r
                color: prev.pillColor
            }

            // the pills: separate in Modular (and Solid with distinct pills), dots of content otherwise
            Repeater {
                model: prev.style === "island" ? 0 : 3
                Item {
                    id: grp
                    readonly property var lens: prev.groups[index]
                    readonly property real gap: prev.pillGap * prev.k
                    readonly property real len: {
                        let t = 0;
                        for (let i = 0; i < lens.length; i++) t += lens[i] * prev.k;
                        return t + gap * (lens.length - 1);
                    }
                    readonly property real inset: prev.flush ? 8 * prev.k : prev.edge + 4 * prev.k
                    readonly property real start: (prev.along - prev.span) / 2
                    x: index === 0 ? start + inset
                       : index === 2 ? start + prev.span - inset - len
                       : (prev.along - len) / 2
                    y: prev.edge
                    width: len
                    height: prev.barH

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: grp.gap
                        Repeater {
                            model: grp.lens
                            Rectangle {
                                readonly property bool separate: prev.style === "modular" || (prev.style === "solid" && prev.distinctPills)
                                width: modelData * prev.k
                                height: separate ? prev.barH : prev.barH * 0.34
                                radius: ThemeBackend.square ? 0 : height / 2
                                color: separate ? prev.pillColor : Qt.alpha(ThemeBackend.text, 0.35)
                                anchors.verticalCenter: parent.verticalCenter
                                // a hint of content inside each pill
                                Rectangle {
                                    visible: parent.separate
                                    anchors.centerIn: parent
                                    width: parent.width * 0.55
                                    height: Math.max(2, parent.height * 0.22)
                                    radius: height / 2
                                    color: Qt.alpha(ThemeBackend.text, 0.35)
                                }
                            }
                        }
                    }
                }
            }

            // the gap between sections, marked while it's wide enough to see
            Rectangle {
                visible: prev.style === "modular" && prev.sectionGap * prev.k > 6
                x: (prev.along - 130 * prev.k) / 2 - prev.sectionGap * prev.k
                y: prev.edge + prev.barH + 2
                width: prev.sectionGap * prev.k
                height: 2
                color: ThemeBackend.mauve
                opacity: 0.6
            }
        }

        Text {
            visible: prev.autohide
            anchors.centerIn: parent
            text: I18n.t("guide.bar.preview.autohide", "Hidden until you hover the edge")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: 11
            color: ThemeBackend.text
            style: Text.Outline
            styleColor: Qt.alpha(ThemeBackend.crust, 0.6)
        }
    }
}
