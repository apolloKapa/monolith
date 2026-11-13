import QtQuick

// Balanced headline (like CSS `text-wrap: balance`): put one inside a wrapping Text or Label and
// its lines come out about the same length, instead of a full line with one word left over
// below. It narrows the text's wrap width (through its padding, so the item keeps its size and
// place) to the narrowest that still needs the same number of lines. Centred text gives half
// to each side; right-aligned text takes it on the left. For short text (headlines, hints),
// not paragraphs.
Item {
    id: b
    property Item target: parent
    property bool on: true
    visible: false
    width: 0; height: 0

    property real pad: 0
    readonly property int align: target ? target.horizontalAlignment : Text.AlignLeft
    readonly property bool centred: align === Text.AlignHCenter
    Binding { target: b.target; property: "rightPadding"; value: b.align === Text.AlignRight ? 0 : (b.centred ? b.pad / 2 : b.pad); when: b.on && !!b.target }
    Binding { target: b.target; property: "leftPadding"; value: b.align === Text.AlignRight ? b.pad : (b.centred ? b.pad / 2 : 0); when: b.on && !!b.target }

    // lays the same text out at trial widths (never shown)
    Text {
        id: meas
        visible: false
        text: b.target ? b.target.text : ""
        textFormat: b.target ? b.target.textFormat : Text.PlainText
        font: b.target ? b.target.font : Qt.font({})
        wrapMode: b.target ? b.target.wrapMode : Text.WordWrap
    }

    function run() {
        const t = target;
        if (!on || !t || t.wrapMode === Text.NoWrap || t.text === "" || t.width <= 0) { pad = 0; return; }
        const full = t.width;
        meas.width = full;
        const lines = meas.lineCount;
        // one line needs nothing; past the line limit it's cut off anyway
        if (lines < 2 || (t.maximumLineCount > 0 && t.maximumLineCount < 1000 && lines > t.maximumLineCount)) { pad = 0; return; }
        let lo = full / lines * 0.8, hi = full;
        for (let i = 0; i < 12 && hi - lo > 0.5; i++) {
            const mid = (lo + hi) / 2;
            meas.width = mid;
            if (meas.lineCount > lines) lo = mid; else hi = mid;
        }
        pad = Math.max(0, Math.floor(full - Math.ceil(hi) - 1));
    }
    function later() { Qt.callLater(b.run); }
    Component.onCompleted: later()
    onOnChanged: later()
    Connections {
        target: b.target
        function onWidthChanged() { b.later(); }
        function onTextChanged() { b.later(); }
        function onFontChanged() { b.later(); }
    }
}
