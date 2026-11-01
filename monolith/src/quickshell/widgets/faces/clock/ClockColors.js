.pragma library

// Colours for the digital clock faces. A face has three settings:
//   clockColor  - one colour for the whole clock ("" = the face's own theme colours)
//   perDigit    - colour every digit on its own
//   digitColors - "a,b,c,d": the four digits (HH MM) left to right ("" = clockColor / the face's)
// A colour is a theme role ("mauve", "text", ...) so it follows the theme, or a "#rrggbb".

function list(face) {
    return String(face.digitColors || "").split(",");
}

function resolve(spec, theme, fallback) {
    if (!spec) return fallback;
    if (spec.charAt(0) === "#") return spec;
    const c = theme[spec];
    return c !== undefined ? c : fallback;
}

// the spec for digit i (0-3), or for the whole clock when i is past the four digits
function specFor(face, i) {
    if (face.perDigit && i >= 0 && i < 4) {
        const s = list(face)[i] || "";
        if (s) return s;
    }
    return face.clockColor || "";
}

function colorFor(face, i, theme, fallback) {
    return resolve(specFor(face, i), theme, fallback);
}

function isCustom(face) {
    return !!face.clockColor || (!!face.perDigit && list(face).some(s => !!s));
}

// text with every digit wrapped in its colour, for a StyledText Text; firstDigit is the index of
// the text's first digit (2 for a minutes-only text). Non-digits take the whole-clock colour.
function rich(text, face, theme, fallback, firstDigit) {
    let i = firstDigit || 0;
    let out = "";
    const s = String(text);
    for (let k = 0; k < s.length; k++) {
        const ch = s.charAt(k);
        const isDigit = ch >= "0" && ch <= "9";
        const c = isDigit ? colorFor(face, i++, theme, fallback) : resolve(face.clockColor, theme, fallback);
        const esc = ch === "<" ? "&lt;" : (ch === ">" ? "&gt;" : (ch === "&" ? "&amp;" : (ch === " " ? "&nbsp;" : ch)));
        out += '<font color="' + String(c) + '">' + esc + "</font>";
    }
    return out;
}
