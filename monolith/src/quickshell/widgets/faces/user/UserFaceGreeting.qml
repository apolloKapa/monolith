import QtQuick
import QtQuick.Layouts
import "../../../reusables"
import "../../../"

// A greeting card: the avatar, "Hi, <name>!", the part of the day and today's date.
Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 240
    property real minHeight: 80
    property real maxWidth: 700
    property real maxHeight: 260
    property real minAspect: 1.8
    property real maxAspect: 6.0
    property bool isRound: false

    readonly property string partOfDay: {
        let h = DateTime.now.getHours();
        if (h < 5) return I18n.t("widgets.greeting.night", "Good Night");
        if (h < 12) return I18n.t("widgets.greeting.morning", "Good Morning");
        if (h < 18) return I18n.t("widgets.greeting.afternoon", "Good Afternoon");
        if (h < 22) return I18n.t("widgets.greeting.evening", "Good Evening");
        return I18n.t("widgets.greeting.night", "Good Night");
    }

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

        RowLayout {
            anchors.fill: parent
            anchors.margins: Math.min(root.height * 0.16, Scaler.s(18))
            spacing: Scaler.s(14)

            ImageBox {
                readonly property real side: Math.min(root.height - 2 * Math.min(root.height * 0.16, Scaler.s(18)), Scaler.s(96))
                Layout.preferredWidth: side
                Layout.preferredHeight: side
                Layout.alignment: Qt.AlignVCenter
                size: side
                cornerRadius: ThemeBackend.rad(Math.min(ThemeBackend.borderRadius, side / 4))
                imageRadius: ThemeBackend.rad(cornerRadius)
                source: SystemInfo.avatarUrl
                backgroundColor: SystemInfo.avatarPath === "" ? ThemeBackend.surface1 : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: ""
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: parent.size * 0.45
                    color: ThemeBackend.text
                    visible: SystemInfo.avatarPath === ""
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: Scaler.s(3)

                Text {
                    Layout.fillWidth: true
                    text: I18n.t("widgets.greeting.hi", "Hi, %1!").replace("%1", SystemInfo.username)
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Scaler.s(18)
                    font.weight: Font.DemiBold
                    color: ThemeBackend.text
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: root.partOfDay
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Scaler.s(13)
                    color: ThemeBackend.subtext1
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: I18n.t("widgets.greeting.today", "Today") + " · " + Qt.locale().toString(DateTime.now, "dddd d MMM")
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: Scaler.s(11)
                    color: ThemeBackend.overlay1
                    elide: Text.ElideRight
                }
            }
        }
    }
}
