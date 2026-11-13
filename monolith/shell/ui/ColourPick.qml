import QtQuick
import QtQuick.Controls as QQC
import "../core"

// A colour setting: a swatch that opens a picker (a saturation/brightness square, a hue strip,
// see-through, the hex code, and a few quick picks from the theme). `value` is "#rrggbb" or
// "#rrggbbaa"; `picked(c)` fires as it changes.
Item {
    id: cp
    property string value: "#ffffff"
    property bool alpha: true            // offer see-through (adds aa to the code)
    signal picked(string c)
    implicitWidth: 120; implicitHeight: 36

    // ── colour maths ──
    function parse(s) {
        const m = /^#?([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$/.exec(String(s || "").trim());
        if (!m) return { r: 1, g: 1, b: 1, a: 1 };
        const n = parseInt(m[1], 16);
        return { r: ((n >> 16) & 255) / 255, g: ((n >> 8) & 255) / 255, b: (n & 255) / 255, a: m[2] ? parseInt(m[2], 16) / 255 : 1 };
    }
    function hex2(x) { const v = Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16); return v.length < 2 ? "0" + v : v; }
    function code(r, g, b, a) { return "#" + hex2(r) + hex2(g) + hex2(b) + (cp.alpha && a < 0.999 ? hex2(a) : ""); }
    function toHsv(c) {
        const mx = Math.max(c.r, c.g, c.b), mn = Math.min(c.r, c.g, c.b), d = mx - mn;
        let h = 0;
        if (d > 0) h = mx === c.r ? ((c.g - c.b) / d) % 6 : (mx === c.g ? (c.b - c.r) / d + 2 : (c.r - c.g) / d + 4);
        return { h: ((h * 60) + 360) % 360 / 360, s: mx > 0 ? d / mx : 0, v: mx };
    }
    function fromHsv(h, s, v) {
        const c = Qt.hsva(h, s, v, 1);
        return { r: c.r, g: c.g, b: c.b };
    }

    // what's being edited (kept as hue/sat/value so the hue survives grey and black)
    property real hh: 0
    property real ss: 0
    property real vv: 1
    property real aa: 1
    function load() {
        const c = parse(value), h = toHsv(c);
        if (h.s > 0.001 && h.v > 0.001) hh = h.h;
        ss = h.s; vv = h.v; aa = c.a;
    }
    function emit() {
        const c = fromHsv(hh, ss, vv);
        const s = code(c.r, c.g, c.b, aa);
        if (s !== value) { value = s; picked(s); }
    }
    readonly property color shown: { const c = parse(value); return Qt.rgba(c.r, c.g, c.b, c.a); }

    // ── the swatch ──
    Pressable {
        anchors.fill: parent
        color: Theme.containerHigh
        onClicked: { cp.load(); pop.open(); }
        Row {
            anchors.centerIn: parent
            spacing: 8
            // (a checkerboard under it, so see-through shows)
            Item {
                width: 22; height: 22
                anchors.verticalCenter: parent.verticalCenter
                Grid {
                    anchors.fill: parent; columns: 4; clip: true
                    Repeater { model: 16; Rectangle { required property int index; width: 5.5; height: 5.5; color: (index + Math.floor(index / 4)) % 2 ? "#bbbbbb" : "#ffffff" } }
                }
                Rectangle { anchors.fill: parent; radius: 6; color: cp.shown; border.width: 1; border.color: Qt.alpha(Theme.text, 0.3) }
            }
            Label { text: cp.value.toUpperCase(); font.family: "monospace"; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    QQC.Popup {
        id: pop
        y: cp.height + 6
        x: Math.min(0, cp.width - width)
        width: 280
        padding: 14
        modal: false
        closePolicy: QQC.Popup.CloseOnEscape | QQC.Popup.CloseOnPressOutside
        background: SmoothRect {
            radius: Theme.corner(48, 6)
            color: Theme.frame
            border.width: Math.max(1, Theme.outlineW)
            border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        }
        contentItem: Column {
            spacing: 12
            // saturation (across) and brightness (down) at this hue
            Item {
                width: parent.width; height: 160
                Rectangle {
                    anchors.fill: parent; radius: 8
                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "white" } GradientStop { position: 1; color: Qt.hsva(cp.hh, 1, 1, 1) } }
                }
                Rectangle {
                    anchors.fill: parent; radius: 8
                    gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: "black" } }
                }
                Rectangle {
                    x: cp.ss * parent.width - 8; y: (1 - cp.vv) * parent.height - 8
                    width: 16; height: 16; radius: 8
                    color: "transparent"; border.width: 2; border.color: cp.vv > 0.5 ? "black" : "white"
                }
                MouseArea {
                    anchors.fill: parent
                    function at(m) { cp.ss = Math.max(0, Math.min(1, m.x / width)); cp.vv = Math.max(0, Math.min(1, 1 - m.y / height)); cp.emit(); }
                    onPressed: m => at(m)
                    onPositionChanged: m => { if (pressed) at(m); }
                }
            }
            // hue
            Item {
                width: parent.width; height: 16
                Rectangle {
                    anchors.fill: parent; radius: 8
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: "#ff0000" } GradientStop { position: 0.17; color: "#ffff00" }
                        GradientStop { position: 0.33; color: "#00ff00" } GradientStop { position: 0.5; color: "#00ffff" }
                        GradientStop { position: 0.67; color: "#0000ff" } GradientStop { position: 0.83; color: "#ff00ff" }
                        GradientStop { position: 1.0; color: "#ff0000" }
                    }
                }
                Rectangle { x: cp.hh * parent.width - 4; y: -2; width: 8; height: 20; radius: 4; color: "white"; border.width: 1; border.color: "black" }
                MouseArea {
                    anchors.fill: parent
                    function at(m) { cp.hh = Math.max(0, Math.min(0.999, m.x / width)); if (cp.ss < 0.02) cp.ss = 1; if (cp.vv < 0.02) cp.vv = 1; cp.emit(); }
                    onPressed: m => at(m)
                    onPositionChanged: m => { if (pressed) at(m); }
                }
            }
            // see-through
            Row {
                visible: cp.alpha
                width: parent.width; spacing: 10
                Label { text: "Opacity"; muted: true; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter; width: 58 }
                NumberBox { width: parent.width - 68; from: 0; to: 1; step: 0.01; decimals: 2; factor: 100; unit: "%"; value: cp.aa; onMoved: v => { cp.aa = v; cp.emit(); } }
            }
            // the code, typed
            Row {
                width: parent.width; spacing: 10
                Label { text: "Code"; muted: true; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter; width: 58 }
                Field {
                    id: hexField
                    width: parent.width - 68; height: 34
                    text: cp.value
                    onAccepted: v => { const c = cp.parse(v); if (/^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(String(v).trim())) { const h = cp.toHsv(c); if (h.s > 0.001) cp.hh = h.h; cp.ss = h.s; cp.vv = h.v; cp.aa = c.a; cp.emit(); } }
                }
            }
            // quick picks: the theme's colours and a few plain ones
            Flow {
                width: parent.width; spacing: 6
                Repeater {
                    model: [String(Theme.accent), String(Theme.text), String(Theme.subtext), "#ffffff", "#000000", "#ff5c5c", "#ffb84d", "#ffe066", "#5cd65c", "#4dd2ff", "#5c7cff", "#c45cff"]
                    Rectangle {
                        required property string modelData
                        width: 22; height: 22; radius: 11
                        color: modelData
                        border.width: 1; border.color: Qt.alpha(Theme.text, 0.3)
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { const c = cp.parse(String(parent.color).substring(0, 7)); const h = cp.toHsv(c); if (h.s > 0.001) cp.hh = h.h; cp.ss = h.s; cp.vv = h.v; cp.emit(); } }
                    }
                }
            }
        }
    }
}
