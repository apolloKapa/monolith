import QtQuick
import "../core"

// Put one inside anything on a page: it comes up and fades in when it's made, the lower (and
// the further right) it sits, the later, so a page's parts arrive one after another.
Item {
    id: rise
    property Item target: parent
    property real delay: -1            // ms; -1: from where it sits
    property bool on: true
    property real t: on ? 0 : 1
    visible: false
    width: 0; height: 0
    Translate { id: lift; y: (1 - rise.t) * 16 }
    Binding { target: rise.target; property: "opacity"; value: rise.t; when: rise.on && rise.t < 1 }
    SequentialAnimation {
        id: go
        PauseAnimation { id: wait }
        NumberAnimation { target: rise; property: "t"; to: 1; duration: Theme.ms(360); easing.type: Easing.OutCubic }
    }
    // shown again (a tab switched back, a section appearing): it comes up again
    Connections {
        target: rise.target
        enabled: rise.on && !!rise.target
        function onVisibleChanged() {
            if (!rise.target.visible || go.running) return;
            go.stop(); rise.t = 0;
            wait.duration = Theme.ms(rise.delay >= 0 ? rise.delay : Math.min(240, Math.max(0, rise.target.y) * 0.3));
            go.start();
        }
    }
    Timer {
        interval: 1; running: rise.on
        onTriggered: {
            const it = rise.target;
            if (!it) { rise.t = 1; return; }
            it.transform = [lift];
            wait.duration = Theme.ms(rise.delay >= 0 ? rise.delay : Math.min(340, Math.max(0, it.y) * 0.4 + Math.max(0, it.x) * 0.12));
            go.start();
        }
    }
}
