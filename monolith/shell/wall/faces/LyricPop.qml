import QtQuick
import "../../core"

// Synced lyrics one line at a time, for the simple lyrics widget's other ways in ("How lines
// come in"): the line being sung alone in the middle, and when the next one comes
//   pop    it pops in with a little bounce, the last one floating up and away
//   slide  it slides in from the side, the last one sliding off the other way
//   words  its words rise in one by one as they're sung (spread over the line's time)
// The scrolling column is LyricLines; it also says when there are no lyrics.
Item {
    id: lp
    property string mode: "pop"
    property string align: "left"
    property color ink: "#ffffff"
    property real size: 16
    property real side: 4
    readonly property int hAlign: align === "center" ? Text.AlignHCenter : (align === "right" ? Text.AlignRight : Text.AlignLeft)
    readonly property int cur: Lyrics.currentIndex
    readonly property bool anim: Theme.animOn
    function ms(v) { return anim ? Theme.ms(v) : 0; }
    clip: true

    // the line shown, and the one on its way out
    property string shownText: ""
    property string leavingText: ""
    property int shownIndex: -2
    property real shownAt: 0          // when the shown line starts, in the song (seconds)
    property real shownEnd: 0         // when the next one starts
    function lineText(i) { return i >= 0 && i < Lyrics.lines.length ? (Lyrics.lines[i].text !== "" ? Lyrics.lines[i].text : "♪") : ""; }
    function swap(quiet) {
        if (cur === shownIndex) return;
        leavingText = quiet ? "" : shownText;
        shownIndex = cur;
        shownText = lineText(cur);
        const L = Lyrics.lines;
        shownAt = cur >= 0 && cur < L.length ? L[cur].t : 0;
        shownEnd = cur >= 0 && cur + 1 < L.length ? L[cur + 1].t : shownAt + 4;
        outAnim.restart();
        inAnim.restart();
    }
    onCurChanged: swap(false)
    // (another song: its first line can have the same number as the last song's)
    Connections { target: Lyrics; function onLinesChanged() { lp.shownIndex = -2; lp.swap(true); } }
    Component.onCompleted: swap(true)

    // ── word by word: when each word of the line comes in ──
    readonly property var words: shownText === "" ? [] : shownText.split(/\s+/).filter(w => w !== "")
    function wordAt(i) {
        const n = Math.max(1, words.length);
        // over most of the line's time, but no slower than about a third of a second a word
        const span = Math.max(0.2, Math.min((shownEnd - shownAt) * 0.85, n * 0.35));
        return shownAt + span * i / n;
    }

    // where the text goes: left, centre or right, inside the margins
    readonly property real boxW: Math.max(10, width - 2 * side)
    component Line: Text {
        renderType: Text.CurveRendering
        x: lp.side
        width: lp.boxW
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: lp.hAlign
        wrapMode: Text.WordWrap
        color: lp.ink
        font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: lp.size
        transformOrigin: lp.hAlign === Text.AlignHCenter ? Item.Center : (lp.hAlign === Text.AlignRight ? Item.Right : Item.Left)
    }

    // the last line, on its way out: up and away (pop, words) or off to the left (slide)
    Line {
        id: leaving
        text: lp.leavingText
        opacity: 0
        transform: Translate { id: leaveT }
    }
    ParallelAnimation {
        id: outAnim
        NumberAnimation { target: leaving; property: "opacity"; from: 1; to: 0; duration: lp.ms(lp.mode === "slide" ? 320 : 280); easing.type: Easing.OutCubic }
        NumberAnimation { target: leaving; property: "scale"; from: 1; to: lp.mode === "slide" ? 1 : 1.05; duration: lp.ms(320); easing.type: Easing.OutCubic }
        NumberAnimation { target: leaveT; property: "x"; from: 0; to: lp.mode === "slide" ? -lp.size * 3 : 0; duration: lp.ms(360); easing.type: Easing.InCubic }
        NumberAnimation { target: leaveT; property: "y"; from: 0; to: lp.mode === "slide" ? 0 : -lp.size * 0.9; duration: lp.ms(340); easing.type: Easing.OutCubic }
    }

    // the line being sung (pop and slide: all of it at once)
    Line {
        id: incoming
        visible: lp.mode !== "words"
        text: lp.shownText
        transform: Translate { id: inT }
    }
    ParallelAnimation {
        id: inAnim
        NumberAnimation { target: incoming; property: "opacity"; from: 0; to: 1; duration: lp.ms(260); easing.type: Easing.OutCubic }
        NumberAnimation { target: incoming; property: "scale"; from: lp.mode === "pop" ? 0.8 : 1; to: 1; duration: lp.ms(460); easing.type: Easing.OutBack; easing.overshoot: 1.8 }
        NumberAnimation { target: inT; property: "x"; from: lp.mode === "slide" ? lp.size * 3 : 0; to: 0; duration: lp.ms(420); easing.type: Easing.OutCubic }
        NumberAnimation { target: inT; property: "y"; from: lp.mode === "pop" ? lp.size * 0.5 : 0; to: 0; duration: lp.ms(420); easing.type: Easing.OutCubic }
    }

    // word by word: the words laid out like the line would be (wrapped, aligned), each rising in
    Item {
        id: wordBox
        visible: lp.mode === "words"
        x: lp.side
        width: lp.boxW
        height: rows * lp.size * 1.3
        anchors.verticalCenter: parent.verticalCenter
        property int rows: 1
        // (greedy wrapping, then each row moved for the alignment)
        function layout() {
            const gap = lp.size * 0.3, lineH = lp.size * 1.3;
            const items = [];
            for (let i = 0; i < wordRep.count; i++) { const it = wordRep.itemAt(i); if (it) items.push(it); }
            const rowsOf = [[]];
            let x = 0;
            for (const it of items) {
                const w = it.implicitWidth;
                if (x > 0 && x + w > width) { rowsOf.push([]); x = 0; }
                rowsOf[rowsOf.length - 1].push(it);
                x += w + gap;
            }
            rowsOf.forEach((row, r) => {
                const used = row.reduce((s, it) => s + it.implicitWidth, 0) + gap * Math.max(0, row.length - 1);
                let px = lp.hAlign === Text.AlignHCenter ? (width - used) / 2 : (lp.hAlign === Text.AlignRight ? width - used : 0);
                for (const it of row) { it.x = Math.round(px); it.y = Math.round(r * lineH); px += it.implicitWidth + gap; }
            });
            rows = Math.max(1, rowsOf.length);
        }
        onWidthChanged: Qt.callLater(layout)
        Repeater {
            id: wordRep
            model: lp.mode === "words" ? lp.words : []
            onCountChanged: Qt.callLater(wordBox.layout)
            Text {
                id: wd
                required property string modelData
                required property int index
                renderType: Text.CurveRendering
                text: modelData
                color: lp.ink
                font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: lp.size
                onImplicitWidthChanged: Qt.callLater(wordBox.layout)
                // in once its moment comes (Lyrics.now moves on ten times a second). (Not before
                // it's made: the first word's moment has always come, and it just appeared)
                property bool made: false
                Component.onCompleted: made = true
                readonly property bool on: made && Lyrics.now >= lp.wordAt(index)
                opacity: on ? 1 : 0
                scale: on ? 1 : 0.85
                transform: Translate { y: wd.on ? 0 : lp.size * 0.55; Behavior on y { NumberAnimation { duration: lp.ms(380); easing.type: Easing.OutBack; easing.overshoot: 1.6 } } }
                Behavior on opacity { NumberAnimation { duration: lp.ms(240); easing.type: Easing.OutCubic } }
                Behavior on scale { NumberAnimation { duration: lp.ms(380); easing.type: Easing.OutBack } }
            }
        }
    }
}
