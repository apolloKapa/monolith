import QtQuick
import QtQuick.Layouts
import "../../"
import "../../reusables"

// A slider for one input setting: follows `current` (what niri's config says) and sends
// `commit` once the value has stopped changing for a moment, so dragging writes the config
// once instead of on every step.
Draggable {
    id: slider

    required property var rootObj
    property real current: 0
    signal commit(real val)

    Layout.rightMargin: rootObj.s(8)
    implicitWidth: rootObj.s(180)
    implicitHeight: rootObj.s(18)
    showValueBubble: true
    backgroundColor: ThemeBackend.surface0
    accentColor: ThemeBackend.mauve
    handleColor: ThemeBackend.text
    handleBorderColor: ThemeBackend.mantle

    value: current
    onCurrentChanged: if (!isDragging && !settle.running) value = current

    onMoved: function(val) {
        value = val;
        settle.restart();
    }

    Timer {
        id: settle
        interval: 350
        onTriggered: {
            if (slider.isDragging) { restart(); return; }
            if (slider.value !== slider.current) slider.commit(slider.value);
        }
    }
}
