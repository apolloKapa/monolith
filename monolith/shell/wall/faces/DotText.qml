import QtQuick

// Text drawn as a grid of round dots: a 5×7 dot-matrix font of our own (digits, A–Z, a few
// signs), for the Dot looks. `cell` is one dot's box in pixels; set it from the room there is
// (fitCell() gives the biggest that fits), or leave it. Unknown characters are left blank.
Canvas {
    id: dt
    property string text: ""
    property real cell: 8
    property color color: "#ffffff"
    // the dots that are off, faintly (a lit-panel look); transparent hides them
    property color offColor: "transparent"
    property real dotSize: 0.78          // a dot's share of its cell
    property int gap: 1                  // empty columns between characters

    // the font: each character's rows, '#' a dot, '.' none (5 wide unless noted)
    readonly property var glyphs: ({
        "0": [".###.", "#...#", "#..##", "#.#.#", "##..#", "#...#", ".###."],
        "1": ["..#..", ".##..", "..#..", "..#..", "..#..", "..#..", ".###."],
        "2": [".###.", "#...#", "....#", "...#.", "..#..", ".#...", "#####"],
        "3": ["#####", "...#.", "..#..", "...#.", "....#", "#...#", ".###."],
        "4": ["...#.", "..##.", ".#.#.", "#..#.", "#####", "...#.", "...#."],
        "5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
        "6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
        "7": ["#####", "....#", "...#.", "..#..", ".#...", ".#...", ".#..."],
        "8": [".###.", "#...#", "#...#", ".###.", "#...#", "#...#", ".###."],
        "9": [".###.", "#...#", "#...#", ".####", "....#", "...#.", ".##.."],
        ":": [".", ".", "#", ".", "#", ".", "."],
        ".": [".", ".", ".", ".", ".", ".", "#"],
        "-": ["...", "...", "...", "###", "...", "...", "..."],
        "°": [".#.", "#.#", ".#.", "...", "...", "...", "..."],
        "%": ["##...", "##..#", "...#.", "..#..", ".#...", "#..##", "...##"],
        "/": ["....#", "....#", "...#.", "..#..", ".#...", "#....", "#...."],
        " ": ["..", "..", "..", "..", "..", "..", ".."],
        "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "B": ["####.", "#...#", "#...#", "####.", "#...#", "#...#", "####."],
        "C": [".###.", "#...#", "#....", "#....", "#....", "#...#", ".###."],
        "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
        "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
        "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
        "G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".####"],
        "H": ["#...#", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
        "I": ["###", ".#.", ".#.", ".#.", ".#.", ".#.", "###"],
        "J": ["..###", "...#.", "...#.", "...#.", "...#.", "#..#.", ".##.."],
        "K": ["#...#", "#..#.", "#.#..", "##...", "#.#..", "#..#.", "#...#"],
        "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
        "M": ["#...#", "##.##", "#.#.#", "#.#.#", "#...#", "#...#", "#...#"],
        "N": ["#...#", "#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#"],
        "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
        "Q": [".###.", "#...#", "#...#", "#...#", "#.#.#", "#..#.", ".##.#"],
        "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
        "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
        "T": ["#####", "..#..", "..#..", "..#..", "..#..", "..#..", "..#.."],
        "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
        "V": ["#...#", "#...#", "#...#", "#...#", "#...#", ".#.#.", "..#.."],
        "W": ["#...#", "#...#", "#...#", "#.#.#", "#.#.#", "#.#.#", ".#.#."],
        "X": ["#...#", "#...#", ".#.#.", "..#..", ".#.#.", "#...#", "#...#"],
        "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
        "Z": ["#####", "....#", "...#.", "..#..", ".#...", "#....", "#####"]
    })
    function glyph(c) { return glyphs[c] || glyphs[c.toUpperCase()] || null; }
    // how many dot columns the text takes
    readonly property int columns: {
        let n = 0;
        const s = String(text);
        for (let i = 0; i < s.length; i++) { const g = glyph(s[i]); if (g) n += g[0].length + (i < s.length - 1 ? gap : 0); }
        return n;
    }
    // the biggest cell that fits w × h
    function fitCell(w, h) { return Math.max(1, Math.min(w / Math.max(1, columns), h / 7)); }

    implicitWidth: Math.ceil(columns * cell)
    implicitHeight: Math.ceil(7 * cell)
    width: implicitWidth
    height: implicitHeight

    onTextChanged: requestPaint()
    onCellChanged: requestPaint()
    onColorChanged: requestPaint()
    onOffColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const g2 = getContext("2d");
        g2.reset();
        const s = String(text);
        const r = cell * dotSize / 2;
        let x0 = 0;
        for (let i = 0; i < s.length; i++) {
            const g = glyph(s[i]);
            if (!g) continue;
            for (let row = 0; row < 7; row++) {
                for (let col = 0; col < g[row].length; col++) {
                    const on = g[row][col] === "#";
                    if (!on && dt.offColor.a === 0) continue;
                    g2.fillStyle = on ? dt.color : dt.offColor;
                    g2.beginPath();
                    g2.arc((x0 + col + 0.5) * cell, (row + 0.5) * cell, r, 0, 2 * Math.PI);
                    g2.fill();
                }
            }
            x0 += g[0].length + gap;
        }
    }
}
