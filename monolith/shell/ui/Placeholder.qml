import QtQuick
import "../core"

// A BlurHash placeholder: the picture's colours as a soft blur, shown while the picture itself
// loads (put it under the Image and set `loading` until the Image is Ready; it fades out by
// itself). Give it `source` (a file: its code comes from core/Placeholders) or a `hash`. It leans
// a little towards the theme's surface so it sits in the palette, and a soft sheen crosses it
// while loading. Until its code is known it's a quietly breathing theme-coloured card.
// `radius` cuts it to the theme's continuous corners (0: leave it square, e.g. inside a parent
// that already clips).
Item {
    id: ph
    property string source: ""
    property string hash: source !== "" ? Placeholders.hash(source) : ""
    property bool loading: true
    property real radius: 0
    property real tintAmount: 0.12
    opacity: loading ? 1 : 0
    visible: opacity > 0.01
    Behavior on opacity { NumberAnimation { duration: Theme.ms(320); easing.type: Easing.OutCubic } }

    readonly property var comps: decode(hash)

    readonly property string chars: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz#$%*+,-.:;=?@[]^_{|}~"
    function d83(s) { let v = 0; for (let i = 0; i < s.length; i++) v = v * 83 + chars.indexOf(s[i]); return v; }
    function lin(v) { v /= 255; return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
    function sp(v, e) { return (v < 0 ? -1 : 1) * Math.pow(Math.abs(v), e); }
    // the 4x3 grid of colours (missing ones black); null if it isn't a valid code
    function decode(h) {
        if (!h || h.length < 6) return null;
        const size = d83(h[0]);
        const ny = Math.floor(size / 9) + 1, nx = size % 9 + 1;
        if (h.length !== 4 + 2 * nx * ny) return null;
        // ("punch" a little under 1: softens the code's strongest swings, which otherwise
        // overshoot into odd colours in the corners of high-contrast pictures)
        const maxv = (d83(h[1]) + 1) / 166 * 0.75;
        const out = [];
        for (let k = 0; k < 12; k++) out.push(Qt.vector4d(0, 0, 0, 0));
        for (let j = 0; j < ny; j++) for (let i = 0; i < nx; i++) {
            if (i > 3 || j > 2) continue;
            const n = j * nx + i;
            let c;
            if (n === 0) { const v = d83(h.substr(2, 4)); c = [lin(v >> 16), lin((v >> 8) & 255), lin(v & 255)]; }
            else {
                const v = d83(h.substr(4 + n * 2, 2));
                c = [sp((Math.floor(v / 361) - 9) / 9, 2) * maxv, sp((Math.floor(v / 19) % 19 - 9) / 9, 2) * maxv, sp((v % 19 - 9) / 9, 2) * maxv];
            }
            out[j * 4 + i] = Qt.vector4d(c[0], c[1], c[2], 1);
        }
        return out;
    }

    // the corner shape (same maths as every SmoothRect), never drawn
    SmoothRect { id: shape; visible: false; width: ph.width; height: ph.height; radius: ph.radius; color: "transparent" }

    // no code yet: the theme's card colour, breathing
    SmoothRect {
        anchors.fill: parent
        visible: !ph.comps
        radius: ph.radius
        color: Theme.containerHigh
        SequentialAnimation on opacity {
            running: !ph.comps && ph.visible && ph.loading && Theme.animOn
            loops: Animation.Infinite
            NumberAnimation { to: 0.45; duration: Theme.ms(700); easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.9; duration: Theme.ms(700); easing.type: Easing.InOutSine }
        }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: !!ph.comps
        readonly property var cs: ph.comps || []
        property vector4d c0: cs[0] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c1: cs[1] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c2: cs[2] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c3: cs[3] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c4: cs[4] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c5: cs[5] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c6: cs[6] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c7: cs[7] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c8: cs[8] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c9: cs[9] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c10: cs[10] || Qt.vector4d(0, 0, 0, 0)
        property vector4d c11: cs[11] || Qt.vector4d(0, 0, 0, 0)
        property color tint: Theme.container
        property real tintAmount: ph.tintAmount
        property real sheen: ph.loading && Theme.animOn ? sweep : -1
        property real sweep: 0
        property color sheenColor: Qt.alpha(Theme.text, 0.10)
        property vector2d itemSize: Qt.vector2d(width, height)
        property real extent: ph.radius > 0 ? (shape.curved ? shape.extent : shape.r) : 0
        property real expo: shape.curved ? shape.expo : 2
        NumberAnimation on sweep {
            running: ph.loading && ph.visible && !!ph.comps && Theme.animOn
            from: 0; to: 1; duration: Theme.ms(1400); loops: Animation.Infinite; easing.type: Easing.InOutSine
        }
        fragmentShader: Qt.resolvedUrl("shaders/blurhash.frag.qsb")
    }
}
