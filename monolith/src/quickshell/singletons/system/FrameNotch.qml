pragma Singleton
import QtQuick
import Quickshell

// A Frame-style bar narrower than its edge hangs from the frame as a notch. In the see-through
// styles the frame's one sheet of glass (frame/ScreenFrame.qml) draws it, so the bar and frame
// are one shape with rounded joins. The bar reports it here, per screen name:
//   { edge: "top"|"bottom"|"left"|"right", from, to (along the edge, in the bar window),
//     depth (out from the edge), radius (its own corners), fillet (where it meets the frame) }
Item {
    id: root

    property var notches: ({})

    function set(screenName, notch) {
        if (!screenName) return;
        const cur = root.notches[screenName];
        if (JSON.stringify(cur || null) === JSON.stringify(notch || null)) return;
        let m = Object.assign({}, root.notches);
        if (notch) m[screenName] = notch;
        else delete m[screenName];
        root.notches = m;
    }
}
