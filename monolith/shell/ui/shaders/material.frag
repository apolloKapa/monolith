#version 440

// A panel's material (ui/MaterialPane.qml; a style's `material`): the surface itself, in place of
// a flat fill, drawn from noise (no pictures). Each panel gets its own pattern (`seed`), and the
// texture keeps to the panel's shape (rounded corners, `radii`), softened by a pixel.
//   kind 0 concrete   cast cement: big soft tonal patches (the pour), fine sand, scattered pores
//                     (little dark pits with a lit rim), and on big panels the formwork's marks:
//                     faint horizontal joints and the round tie holes along them
//   kind 1 paper      fibres running mostly one way, a fine tooth, a few darker flecks, and the
//                     edges a touch warmer, as paper gets
//   kind 2 steel      brushed metal: long streaks along x, finer ones on top, and a broad sheen
//                     running across it, lighter towards the top
// (Premultiplied colour out, like Qt wants it.)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 radii;     // top left, top right, bottom right, bottom left (px)
    vec4 base;      // the panel's colour
    float kind;
    float seed;
    float strength; // how much of the texture shows (1: as designed)
};

float h21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21) + seed * 0.137);
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
float vnoise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 5; i++) { v += a * vnoise(p); p = p * 2.03 + 17.1; a *= 0.5; }
    return v;
}

// inside the panel's rounded shape: 1 inside, 0 outside, a pixel of softening
float shape(vec2 px) {
    vec2 c = px - itemSize * 0.5;
    float r = c.x < 0.0 ? (c.y < 0.0 ? radii.x : radii.w) : (c.y < 0.0 ? radii.y : radii.z);
    vec2 q = abs(c) - itemSize * 0.5 + r;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    return clamp(0.5 - d, 0.0, 1.0);
}

vec3 concrete(vec2 px) {
    float pour = fbm(px / 90.0);                  // the big, soft tonal patches
    float sand = vnoise(px / 1.6) * 0.6 + vnoise(px / 3.5) * 0.4;
    float tone = 0.86 + 0.22 * pour + 0.08 * (sand - 0.5);
    vec3 c = base.rgb * tone;
    // pores: a few pits on a 9 px grid, dark with a lit lower rim
    vec2 cell = floor(px / 9.0);
    if (h21(cell + 3.7) > 0.93) {
        vec2 ctr = (cell + 0.25 + 0.5 * vec2(h21(cell + 1.1), h21(cell + 2.3))) * 9.0;
        float rad = 0.8 + 1.6 * h21(cell + 5.9);
        float d = length(px - ctr);
        c *= 1.0 - 0.45 * smoothstep(rad, rad * 0.4, d);
        c += base.rgb * 0.12 * smoothstep(rad + 0.8, rad, d) * step(ctr.y, px.y) * step(rad * 0.6, d);
    }
    // formwork: on panels bigger than a board, joints every 120 px and tie holes along them
    if (itemSize.y > 180.0 && itemSize.x > 240.0) {
        float row = mod(px.y + 40.0, 120.0);
        c *= 1.0 - 0.06 * smoothstep(1.5, 0.0, abs(row - 1.0));
        vec2 tie = vec2(mod(px.x + 60.0, 160.0) - 80.0, row - 60.0);
        float t = length(tie);
        c *= 1.0 - 0.28 * smoothstep(5.0, 3.5, t);
        c += base.rgb * 0.06 * smoothstep(6.5, 5.0, t) * step(3.5, t) * step(0.0, tie.y);
    }
    return c;
}

vec3 paper(vec2 px) {
    float fibres = fbm(vec2(px.x / 60.0, px.y / 5.0));
    float tooth = vnoise(px / 1.3);
    // (a rare, faint fleck: dense dark ones read as dirt)
    float flecks = step(0.9993, h21(floor(px / 2.0) + 9.1));
    vec3 c = base.rgb * (0.985 + 0.035 * (fibres - 0.5) + 0.02 * (tooth - 0.5)) - flecks * 0.05;
    // the edges a touch warmer and darker
    vec2 e = min(px, itemSize - px);
    float edge = smoothstep(26.0, 0.0, min(e.x, e.y));
    return mix(c, c * vec3(0.97, 0.94, 0.88), 0.4 * edge);
}

vec3 steel(vec2 px) {
    float streaks = fbm(vec2(px.x / 260.0, px.y / 1.2));
    float fine = vnoise(vec2(px.x / 40.0, px.y / 0.7));
    vec3 c = base.rgb * (0.88 + 0.2 * streaks + 0.06 * (fine - 0.5));
    // a broad sheen running across, lighter towards the top
    vec2 uv = px / itemSize;
    float sheen = exp(-pow((uv.x - uv.y * 0.6 - 0.25) * 2.4, 2.0));
    return c + vec3(0.09) * sheen * (1.0 - uv.y * 0.6) + vec3(0.03) * (1.0 - uv.y);
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    vec3 c = kind < 0.5 ? concrete(px) : (kind < 1.5 ? paper(px) : steel(px));
    c = mix(base.rgb, c, strength);
    float a = shape(px) * base.a;
    fragColor = vec4(clamp(c, 0.0, 1.0) * a, a) * qt_Opacity;
}
