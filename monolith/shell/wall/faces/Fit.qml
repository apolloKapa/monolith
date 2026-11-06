import QtQuick

// Lays a look out at its design size (dw × dh) and scales it to the widget, using the widget's
// whole shape: the content gets the widget's aspect, at the design's scale.
Item {
    id: fit
    anchors.fill: parent
    property real dw: 300
    property real dh: 150
    default property alias content: inner.data
    readonly property real k: Math.max(0.05, Math.min(width / dw, height / dh))
    Item {
        id: inner
        width: fit.width / fit.k
        height: fit.height / fit.k
        scale: fit.k
        transformOrigin: Item.TopLeft
    }
}
