import QtQuick
import QtQuick.Effects
import "../core"

// A card's drop shadow, drawn under it: put it inside the card. Only this shape goes through
// the shadow effect, so the card's own content is drawn directly and stays sharp (a layered
// card gets resampled and goes soft when its size isn't whole pixels).
Rectangle {
    anchors.fill: parent
    z: -1
    radius: parent && parent.radius !== undefined ? parent.radius : 0
    color: parent && parent.color !== undefined ? parent.color : Theme.frame
    layer.enabled: true
    layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: Theme.shadowBlur; shadowColor: Theme.shadowColor; shadowVerticalOffset: Theme.shadowY; shadowHorizontalOffset: Theme.shadowX }
}
