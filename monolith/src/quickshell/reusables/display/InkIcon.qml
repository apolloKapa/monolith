import QtQuick
import "../../"

// App icons on light backgrounds: icon packs made of plain white glyphs (YAMIS etc.) vanish
// there, so those icons are drawn in the theme's ink instead; colourful icons stay as they are.
// Use on an Image:
//   layer.enabled: !ThemeBackend.darkMode
//   layer.mipmap: true
//   layer.effect: InkIcon {}
ShaderEffect {
    property color ink: ThemeBackend.text
    property real strength: 1.0
    fragmentShader: "file://" + Caching.monolithDir + "/assets/shaders/ui/ink_icon.frag.qsb"
}
