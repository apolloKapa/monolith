import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"
import "../../reusables/guide"

// Settings -> Theme -> Style: every style as a small card drawn in that style (its colours,
// corners, outline, shadow and font), so the grid itself is the preview.
SettingsBlob {
    id: section
    required property var tab
    readonly property var rootObj: tab.rootObj

    SettingsRow {
        rootObj: section.tab.rootObj
        settingId: "style"
        icon: "󰸌"
        title: I18n.t("guide.theme.style.title", "Style")
        description: I18n.t("guide.theme.style.desc", "The look of every panel. Blur, Liquid glass and Bubbly keep your colours; the others bring their own colours and font, which you can still change below")
        searchKeywords: "style look blur liquid glass minimalist terminal brutal neo brutalism luxe poster bubbly round paper editorial serif arcade pixel neon retro"
    }

    GridLayout {
        id: grid
        Layout.fillWidth: true
        Layout.leftMargin: rootObj.s(14)
        Layout.rightMargin: rootObj.s(14)
        Layout.bottomMargin: rootObj.s(14)
        columns: Math.max(2, Math.floor((width + columnSpacing) / (rootObj.s(150) + columnSpacing)))
        columnSpacing: rootObj.s(10)
        rowSpacing: rootObj.s(10)

        Repeater {
            model: ThemeBackend.styleOrder

            Item {
                id: card
                required property string modelData
                readonly property var st: ThemeBackend.styles[modelData]
                readonly property bool selected: section.tab.currentBlurStyle === modelData
                readonly property var pal: st.colors ? st.colors
                    : (modelData === "minimalist" ? ThemeBackend.minimalistColors : null)
                readonly property color cBase: pal ? pal.base : ThemeBackend.base
                readonly property color cSurface: pal ? pal.surface0 : ThemeBackend.surface0
                readonly property color cText: pal ? pal.text : "#ffffff"
                readonly property color cSub: pal ? pal.subtext0 : Qt.alpha("#ffffff", 0.7)
                readonly property color cAccent: pal ? pal.mauve : ThemeBackend.mauve
                readonly property color cLine: {
                    if (!st.outline) return "transparent";
                    let p = pal || {};
                    switch (st.outlineRole) {
                        case "accent": return Qt.alpha(cAccent, 0.55);
                        case "accentSoft": return Qt.alpha(cAccent, 0.35);
                        case "ink": return p.crust || "#000000";
                        case "text": return cText;
                        default: return p.surface2 || "#555555";
                    }
                }
                readonly property real cardRadius: st.square ? 0 : rootObj.s(10) * (st.radiusScale !== undefined ? st.radiusScale : 1)
                readonly property bool seeThrough: st.opaque !== true && card.modelData !== "material"

                Layout.fillWidth: true
                Layout.preferredHeight: rootObj.s(92)

                // selection ring
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -rootObj.s(3)
                    radius: ThemeBackend.rad(rootObj.s(13))
                    color: "transparent"
                    border.width: 2
                    border.color: card.selected ? ThemeBackend.mauve : (cardMa.containsMouse ? Qt.alpha(ThemeBackend.text, 0.25) : "transparent")
                    Behavior on border.color { ColorAnimation { duration: (140) * ThemeBackend.animScale } }
                }

                // the "desktop" behind the preview panel
                Rectangle {
                    id: backdrop
                    anchors.fill: parent
                    radius: ThemeBackend.rad(rootObj.s(10))
                    clip: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: card.seeThrough ? Qt.darker(ThemeBackend.mauve, 2.2) : Qt.darker(card.cBase, 1.25) }
                        GradientStop { position: 1.0; color: card.seeThrough ? Qt.darker(ThemeBackend.blue, 2.6) : Qt.darker(card.cBase, 1.6) }
                    }

                    // hard shadow
                    Rectangle {
                        x: panel.x + (card.st.hardShadow || 0)
                        y: panel.y + (card.st.hardShadow || 0)
                        width: panel.width
                        height: panel.height
                        radius: panel.radius
                        visible: (card.st.hardShadow || 0) > 0
                        color: card.cLine
                    }

                    Rectangle {
                        id: panel
                        x: rootObj.s(10)
                        y: rootObj.s(10)
                        width: parent.width - rootObj.s(20) - (card.st.hardShadow || 0)
                        height: parent.height - rootObj.s(20) - (card.st.hardShadow || 0)
                        radius: card.cardRadius
                        color: card.seeThrough ? Qt.alpha(card.cSurface, card.modelData === "liquid" ? 0.25 : 0.6) : card.cBase
                        border.width: card.st.outline ? card.st.outline[0] : (card.modelData === "liquid" ? 1 : 0)
                        border.color: card.st.outline ? card.cLine : Qt.alpha("#ffffff", 0.35)

                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: rootObj.s(10)
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: rootObj.s(2)

                            Text {
                                text: card.st.name
                                color: card.cText
                                font.family: card.st.font || ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(14)
                                font.weight: (card.modelData === "brutal" || card.modelData === "poster") ? Font.Black : Font.DemiBold
                            }
                            Text {
                                text: card.st.desc || (card.modelData === "blur" ? "Frosted, your colours" : "Glass that bends light")
                                color: card.cSub
                                font.family: card.st.font || ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(9)
                                width: panel.width - rootObj.s(34)
                                elide: Text.ElideRight
                            }
                        }

                        Rectangle {
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: rootObj.s(8)
                            width: rootObj.s(10)
                            height: rootObj.s(10)
                            radius: card.st.square ? 0 : width / 2
                            color: card.cAccent
                        }
                    }
                }

                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: section.tab.applyStyle(card.modelData)
                }
            }
        }
    }
}
