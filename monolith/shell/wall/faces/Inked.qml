import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Text straight on the wallpaper: bold, with a soft drop shadow so it reads on any picture.
Text {
    property real shadowY: 2
    property real shadowStrength: 0.55
    font.family: Theme.fontFamily
    color: Theme.text
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#000000"
        shadowVerticalOffset: shadowY
        shadowBlur: 0.4
        shadowOpacity: shadowStrength
    }
}
