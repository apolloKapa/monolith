import QtQuick
import "../../"

// Monolith's caption: a small, spaced-out, UPPERCASE label for sections and breadcrumbs
// ("THEME / APPEARANCE"). Set `accent` to tint it with the theme's accent. Material writes it
// as a plain title in sentence case instead.
Text {
    property bool accent: false
    font.family: ThemeBackend.fontFamily
    font.pixelSize: ThemeBackend.material ? Scaler.s(13) : Scaler.s(10)
    font.weight: ThemeBackend.material ? Font.Medium : Font.DemiBold
    font.letterSpacing: ThemeBackend.material ? 0 : Scaler.s(1.6)
    font.capitalization: ThemeBackend.material ? Font.MixedCase : Font.AllUppercase
    color: accent ? ThemeBackend.mauve : (ThemeBackend.material ? ThemeBackend.subtext0 : Qt.alpha(ThemeBackend.subtext0, 0.9))
    elide: Text.ElideRight
}
