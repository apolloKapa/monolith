import QtQuick
import "../../"

// Monolith's caption: a small, spaced-out, UPPERCASE label for sections and breadcrumbs
// ("THEME / APPEARANCE"). Set `accent` to tint it with the theme's accent.
Text {
    property bool accent: false
    font.family: ThemeBackend.fontFamily
    font.pixelSize: Scaler.s(10)
    font.weight: Font.DemiBold
    font.letterSpacing: Scaler.s(1.6)
    font.capitalization: Font.AllUppercase
    color: accent ? ThemeBackend.mauve : Qt.alpha(ThemeBackend.subtext0, 0.9)
    elide: Text.ElideRight
}
