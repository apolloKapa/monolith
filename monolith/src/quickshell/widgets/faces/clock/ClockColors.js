.pragma library

// Colours for the digital clock faces. A face has three settings:
//   clockColor  - one colour for the whole clock ("" = the face's own theme colours)
//   perDigit    - colour every digit on its own
//   digitColors - "a,b,c,d": the four digits (HH MM) left to right ("" = clockColor / the face's)
//   clockGradient / clockColor2 / gradientDirection - fade the whole clock from clockColor to
//                 clockColor2, "horizontal" or "vertical". The face then draws everything white and
//                 a gradient_tint layer colours it (face.gradientOn, set when the gradient is on and
//                 Each digit is off).
// A colour is a theme role ("mauve", "text", ...) so it follows the theme, or a "#rrggbb".
// The swatches are all theme roles. Before 1.21.3 most swatches were fixed hex codes; those read
// as the role that replaced them, so clocks set up back then follow the theme too.
const LEGACY = {
    "#ffffff": "text", "#000000": "crust", "#ff5c5c": "red", "#ff9f43": "peach", "#ffd43b": "yellow",
    "#51cf66": "green", "#22c7b8": "teal", "#4dabf7": "sapphire", "#5c7cfa": "blue", "#9775fa": "mauve",
    "#f06595": "pink"
};

function normalize(spec) {
    if (!spec) return "";
    const r = LEGACY[String(spec)];  // old swatches were saved lower case; typed codes are upper case
    return r !== undefined ? r : spec;
}

function list(face) {
    return String(face.digitColors || "").split(",");
}

function resolve(spec, theme, fallback) {
    spec = normalize(spec);
    if (!spec) return fallback;
    if (spec.charAt(0) === "#") return spec;
    const c = theme[spec];
    return c !== undefined ? c : fallback;
}

// the spec for digit i (0-3), or for the whole clock when i is past the four digits
function specFor(face, i) {
    if (face.gradientOn) return "#ffffff";
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
    if (face.gradientOn) return true;
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
        const c = isDigit ? colorFor(face, i++, theme, fallback) : resolve(specFor(face, 99), theme, fallback);
        const esc = ch === "<" ? "&lt;" : (ch === ">" ? "&gt;" : (ch === "&" ? "&amp;" : (ch === " " ? "&nbsp;" : ch)));
        out += '<font color="' + String(c) + '">' + esc + "</font>";
    }
    return out;
}
