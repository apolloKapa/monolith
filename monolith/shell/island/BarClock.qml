import QtQuick
import "../core"

// The bar clock's time in one of its themes (Settings → Bar → Clock → Theme). "digital" isn't
// here: that's the plain text IslandBar draws itself. Each theme takes the time, whether to show
// seconds and 12-hour time, and whether the bar runs down the screen (then they stack), and sizes
// itself to `room` (the height a module has on the bar). Colours, roundness and type come from
// the style, so they look like the rest of the bar.
Item {
    id: bc
    property string theme: "pill"
    property date now: new Date()
    property bool seconds: false
    property bool h12: false
    property bool vertical: false
    property real room: 26

    implicitWidth: shown.item ? shown.item.implicitWidth : 0
    implicitHeight: shown.item ? shown.item.implicitHeight : 0

    // the time's parts as text: hours (12- or 24-hour), minutes, seconds, AM/PM
    readonly property int hr: now.getHours()
    readonly property string hh: h12 ? String(hr % 12 === 0 ? 12 : hr % 12) : pad2(hr)
    readonly property string mm: pad2(now.getMinutes())
    readonly property string ss: pad2(now.getSeconds())
    readonly property string ap: hr < 12 ? "AM" : "PM"
    function pad2(n) { return n < 10 ? "0" + n : String(n); }
    // (a 12-hour hour is one digit or two; the digit themes always show two places)
    readonly property string hh2: hh.length < 2 ? "0" + hh : hh
    readonly property color lit: Theme.accent
    readonly property color unlit: Qt.alpha(Theme.text, 0.12)
    // what capsules, cards and the face sit on: a tint of the text, so it shows on any bar (the
    // palette's container colour can be the bar's own)
    readonly property color well: Qt.alpha(Theme.text, 0.11)
    readonly property int flipMs: Theme.animOn ? Math.max(120, Math.round(170 * Theme.animScale)) : 0

    Loader {
        id: shown
        anchors.centerIn: parent
        sourceComponent: ({ pill: pillC, segment: segC, flip: flipC, analog: analogC, words: wordsC, binary: binC })[bc.theme] || pillC
    }

    // AM / PM, small, after the time (or under it on a side bar)
    component Meridiem: Text {
        visible: bc.h12
        text: bc.ap
        color: Theme.subtext
        font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: Theme.sizeTiny
    }

    // ── Pill: the hours on an accent capsule, the minutes on a quiet one (seconds smaller) ──
    component Capsule: Rectangle {
        id: cap
        property string label: ""
        property bool strong: false
        property real size: 1
        height: Math.round(bc.room * 0.78 * size)
        width: Math.max(height * 1.25, capText.implicitWidth + height * 0.6)
        radius: Theme.corner(height, 99)
        color: strong ? Theme.accent : bc.well
        Text {
            id: capText
            anchors.centerIn: parent
            text: cap.label
            color: cap.strong ? Theme.onAccent : Theme.text
            font.family: Theme.fontFamily; font.weight: Font.Bold
            font.pixelSize: Math.round(cap.height * 0.6)
        }
    }
    Component {
        id: pillC
        Grid {
            flow: bc.vertical ? Grid.TopToBottom : Grid.LeftToRight
            columns: bc.vertical ? 1 : 4
            spacing: 3
            horizontalItemAlignment: Grid.AlignHCenter; verticalItemAlignment: Grid.AlignVCenter
            Capsule { label: bc.hh; strong: true }
            Capsule { label: bc.mm }
            Capsule { visible: bc.seconds; label: bc.ss; size: 0.78 }
            Meridiem {}
        }
    }

    // ── Segment: an LCD's seven-segment digits, the off segments faintly there ──
    // one segment of a digit, lit when its letter is in `on`
    component Seg: Rectangle {
        property string k
        property string on
        color: on.indexOf(k) >= 0 ? bc.lit : bc.unlit
        radius: Theme.square ? 0 : width < height ? width / 2 : height / 2
    }
    component SegDigit: Item {
        id: sd
        property int d: 0
        readonly property real t: Math.max(2, Math.round(height * 0.13))   // a segment's thickness
        height: Math.round(bc.room * 0.72)
        width: Math.round(height * 0.55)
        // which of a b c d e f g are on (a top, b top right, c bottom right, d bottom, e bottom
        // left, f top left, g middle)
        readonly property string on: ["abcdef", "bc", "abdeg", "abcdg", "bcfg", "acdfg", "acdefg", "abc", "abcdefg", "abcdfg"][d] || ""
        Seg { on: sd.on; k: "a"; x: sd.t * 0.6; y: 0; width: sd.width - sd.t * 1.2; height: sd.t }
        Seg { on: sd.on; k: "g"; x: sd.t * 0.6; y: (sd.height - sd.t) / 2; width: sd.width - sd.t * 1.2; height: sd.t }
        Seg { on: sd.on; k: "d"; x: sd.t * 0.6; y: sd.height - sd.t; width: sd.width - sd.t * 1.2; height: sd.t }
        Seg { on: sd.on; k: "f"; x: 0; y: sd.t * 0.6; width: sd.t; height: sd.height / 2 - sd.t * 0.9 }
        Seg { on: sd.on; k: "b"; x: sd.width - sd.t; y: sd.t * 0.6; width: sd.t; height: sd.height / 2 - sd.t * 0.9 }
        Seg { on: sd.on; k: "e"; x: 0; y: sd.height / 2 + sd.t * 0.3; width: sd.t; height: sd.height / 2 - sd.t * 0.9 }
        Seg { on: sd.on; k: "c"; x: sd.width - sd.t; y: sd.height / 2 + sd.t * 0.3; width: sd.t; height: sd.height / 2 - sd.t * 0.9 }
    }
    component SegPair: Row {
        property string v: "00"
        spacing: 2
        SegDigit { d: Number(parent.v[0]) }
        SegDigit { d: Number(parent.v[1]) }
    }
    component SegColon: Item {
        readonly property real t: Math.max(2, Math.round(bc.room * 0.72 * 0.13))
        width: bc.vertical ? Math.round(bc.room * 0.72 * 0.55) * 2 : t
        height: bc.vertical ? t : Math.round(bc.room * 0.72)
        Rectangle { width: parent.t; height: parent.t; radius: Theme.rnd(width / 2); color: bc.lit
                    x: bc.vertical ? parent.width * 0.3 - width / 2 : 0; y: bc.vertical ? 0 : parent.height * 0.3 - height / 2 }
        Rectangle { width: parent.t; height: parent.t; radius: Theme.rnd(width / 2); color: bc.lit
                    x: bc.vertical ? parent.width * 0.7 - width / 2 : 0; y: bc.vertical ? 0 : parent.height * 0.7 - height / 2 }
    }
    Component {
        id: segC
        Grid {
            flow: bc.vertical ? Grid.TopToBottom : Grid.LeftToRight
            columns: bc.vertical ? 1 : 6
            spacing: 3
            horizontalItemAlignment: Grid.AlignHCenter; verticalItemAlignment: Grid.AlignVCenter
            SegPair { v: bc.hh2 }
            SegColon {}
            SegPair { v: bc.mm }
            SegColon { visible: bc.seconds }
            SegPair { visible: bc.seconds; v: bc.ss }
            Meridiem {}
        }
    }

    // ── Flip: split-flap cards; when a number changes its top half folds down over it ──
    // half a flip card (the top or the bottom), turning about the card's middle by `angle`
    component Half: Item {
        id: half
        property var fc
        property string label
        property bool upper: true
        property real angle: 0
        y: upper ? 0 : fc.height / 2
        width: fc.width; height: fc.height / 2
        clip: true
        transform: Rotation { origin.x: half.width / 2; origin.y: half.upper ? half.height : 0; axis { x: 1; y: 0; z: 0 } angle: half.angle }
        Rectangle {
            y: half.upper ? 0 : -fc.height / 2
            width: fc.width; height: fc.height
            radius: fc.r
            color: bc.well
            Text {
                anchors.centerIn: parent
                text: half.label
                color: Theme.text
                font.family: Theme.fontFamily; font.weight: Font.Bold
                font.pixelSize: Math.round(fc.height * 0.62)
            }
        }
    }
    component FlipCard: Item {
        id: fc
        property string v: "00"
        // what it showed before the change (its lower half stays until the new one folds over)
        property string was: ""
        Component.onCompleted: was = v
        property real fold: 1          // 0 … 1: the old top half folding down, then the new bottom half
        height: Math.round(bc.room * 0.84)
        width: Math.round(height * 1.05)
        onVChanged: {
            if (bc.flipMs <= 0 || !fc.visible) { was = v; fold = 1; return; }
            flip.stop(); fold = 0; flip.start();
        }
        NumberAnimation { id: flip; target: fc; property: "fold"; from: 0; to: 1; duration: bc.flipMs * 2; easing.type: Easing.InOutQuad
                          onFinished: fc.was = fc.v }
        readonly property real r: Theme.corner(height, Math.max(2, height * 0.18))
        // behind: the new top, the old bottom (until the new bottom has folded down over it)
        Half { fc: fc; label: fc.v; upper: true }
        Half { fc: fc; label: fc.fold >= 1 ? fc.v : fc.was; upper: false }
        // folding: the old top going down (first half of the way), the new bottom coming down after
        Half { fc: fc; visible: fc.fold < 0.5; label: fc.was; upper: true; angle: -180 * fc.fold }
        Half { fc: fc; visible: fc.fold >= 0.5 && fc.fold < 1; label: fc.v; upper: false; angle: 180 * (1 - fc.fold) }
        // the split across the middle
        Rectangle { y: Math.round(fc.height / 2) - 0.5; width: fc.width; height: 1; color: Qt.alpha(Theme.frame, 0.9) }
    }
    Component {
        id: flipC
        Grid {
            flow: bc.vertical ? Grid.TopToBottom : Grid.LeftToRight
            columns: bc.vertical ? 1 : 4
            spacing: 3
            horizontalItemAlignment: Grid.AlignHCenter; verticalItemAlignment: Grid.AlignVCenter
            FlipCard { v: bc.hh2 }
            FlipCard { v: bc.mm }
            FlipCard { visible: bc.seconds; v: bc.ss }
            Meridiem {}
        }
    }

    // a hand of the analog face (of size `s`), `turn` degrees round from twelve
    component Hand: Rectangle {
        property real s: 24
        property real len: 0.3
        property real turn: 0
        width: 2; height: s * len
        radius: Theme.rnd(1)
        x: (s - width) / 2; y: s / 2 - height
        antialiasing: true
        transform: Rotation { origin.x: width / 2; origin.y: s * len; angle: turn
            Behavior on angle { enabled: Theme.animOn; RotationAnimation { duration: Theme.shortMs; direction: RotationAnimation.Shortest; easing.type: Easing.OutBack } } }
    }

    // ── Analog: a small face with hands (a seconds hand with seconds on) ──
    Component {
        id: analogC
        Item {
            id: face
            readonly property real s: Math.round(bc.room * 1.0)
            implicitWidth: s; implicitHeight: s
            readonly property real mins: bc.now.getMinutes() + (bc.seconds ? bc.now.getSeconds() / 60 : 0)
            Rectangle {
                anchors.fill: parent
                radius: Theme.square ? 0 : (Theme.chamfer ? 2 : face.s / 2)
                color: bc.well
                border.width: Theme.outlineW; border.color: Theme.outlineColor
            }
            // the four quarter marks
            Repeater {
                model: 4
                Rectangle {
                    required property int index
                    width: 1.5; height: Math.max(2, face.s * 0.12)
                    x: (face.s - width) / 2; y: face.s * 0.08
                    color: Theme.subtext
                    transform: Rotation { origin.x: 0.75; origin.y: face.s / 2 - face.s * 0.08; angle: index * 90 }
                }
            }
            Hand { s: face.s; len: 0.25; width: 2.5; color: Theme.text; turn: (bc.now.getHours() % 12 + face.mins / 60) * 30 }
            Hand { s: face.s; len: 0.37; width: 1.6; color: Theme.accent; turn: face.mins * 6 }
            Hand { s: face.s; visible: bc.seconds; len: 0.4; width: 1; color: Theme.danger; turn: bc.now.getSeconds() * 6 }
            Rectangle { width: 3; height: 3; radius: Theme.rnd(1.5); color: Theme.text; anchors.centerIn: parent }
        }
    }

    // ── Words: the time as you'd say it, to the nearest five minutes ("quarter past ten") ──
    readonly property var hourNames: ["twelve", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "eleven"]
    // [the words before the hour, the hour, the words after it]
    readonly property var spoken: {
        let m = Math.round((now.getMinutes() + now.getSeconds() / 60) / 5) * 5, h = now.getHours();
        if (m === 60) { m = 0; h++; }
        const lead = ({ 5: "five past", 10: "ten past", 15: "quarter past", 20: "twenty past", 25: "twenty-five past", 30: "half past",
                        35: "twenty-five to", 40: "twenty to", 45: "quarter to", 50: "ten to", 55: "five to" })[m] || "";
        if (m > 30) h++;
        const name = hourNames[h % 12];
        return m === 0 ? ["", name, "o'clock"] : [lead, name, ""];
    }
    component Word: Text {
        property bool strong: false
        visible: text !== ""
        color: strong ? Theme.accent : Theme.subtext
        font.family: Theme.fontFamily; font.weight: strong ? Font.Bold : Font.Medium
        font.pixelSize: bc.vertical ? Theme.sizeTiny : (strong ? 14 : 13)
        horizontalAlignment: Text.AlignHCenter
        wrapMode: bc.vertical ? Text.WordWrap : Text.NoWrap
        width: bc.vertical ? bc.room : implicitWidth
    }
    Component {
        id: wordsC
        Grid {
            flow: bc.vertical ? Grid.TopToBottom : Grid.LeftToRight
            columns: bc.vertical ? 1 : 3
            spacing: 4
            horizontalItemAlignment: Grid.AlignHCenter; verticalItemAlignment: Grid.AlignVCenter
            Word { text: bc.spoken[0] }
            Word { text: bc.spoken[1]; strong: true }
            Word { text: bc.spoken[2] }
        }
    }

    // ── Binary: each digit a column of dots, the lit ones adding up to it (8 4 2 1, top to bottom) ──
    component BitColumn: Column {
        id: col
        property int d: 0
        property int bits: 4
        readonly property real dot: Math.max(3, Math.floor((bc.room * 0.86 - 3 * 2) / 4))
        spacing: 2
        Repeater {
            model: 4
            Rectangle {
                required property int index
                readonly property int bit: 3 - index
                // (a digit that can't go that high leaves those places out, but keeps their room)
                opacity: bit < col.bits ? 1 : 0
                width: col.dot; height: col.dot
                radius: Theme.rnd(col.dot / 2)
                color: (col.d >> bit) & 1 ? bc.lit : bc.unlit
                Behavior on color { ColorAnimation { duration: Theme.shortMs } }
            }
        }
    }
    component BitPair: Row {
        property string v: "00"
        property int tensBits: 3
        spacing: 2
        BitColumn { d: Number(parent.v[0]); bits: parent.tensBits }
        BitColumn { d: Number(parent.v[1]) }
    }
    Component {
        id: binC
        Grid {
            flow: bc.vertical ? Grid.TopToBottom : Grid.LeftToRight
            columns: bc.vertical ? 1 : 4
            spacing: 5
            horizontalItemAlignment: Grid.AlignHCenter; verticalItemAlignment: Grid.AlignVCenter
            BitPair { v: bc.hh2; tensBits: bc.h12 ? 1 : 2 }
            BitPair { v: bc.mm }
            BitPair { visible: bc.seconds; v: bc.ss }
            Meridiem {}
        }
    }
}
