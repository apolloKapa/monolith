import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import "../"
import "../reusables"

ClickButton {
    required property var root
    property string name: ""
    // a chip: outlined, filled when it's the preset in use
    bgOpacity: ThemeBackend.elementOpacity
    implicitHeight: root.s(30)
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    cornerRadius: ThemeBackend.square ? 0 : root.s(15)
    buttonText: I18n.t("music.presets." + name.toLowerCase())
    textFontSize: root.s(12)
    horizontalPadding: root.s(14)
    property bool isActivePreset: root.eqData && root.eqData.preset === name
    accentColor: isActivePreset ? (ThemeBackend.mauve || "#cba6f7") : Qt.alpha(ThemeBackend.text, 0.07)
    textColor: isActivePreset ? ThemeBackend.onPrimary : (ThemeBackend.text || "#cdd6f4")
    onClicked: root.applyPresetOptimistically(name)
}
