#version 440

// A panel's material (ui/MaterialPane.qml; a style's `material`): the surface itself, in place of
// a flat fill, drawn from noise (no pictures). Each panel gets its own pattern (`seed`), and the
// texture keeps to the panel's shape (rounded corners, `radii`), softened by a pixel.
//   kind 0 concrete   cast cement: the pour's cloudy patches and stains, the board form's faint
//                     grain, sand, specks of aggregate, a few small air holes, and shading like a
//                     slab (see concrete() below)
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

// cast concrete, built up the way it looks up close:
//   the pour     big soft cloudy patches, the noise bent by itself so they swirl instead of
//                tiling; a few darker damp-looking stains
//   board form   the faintest horizontal grain of the planks it was cast against, wavering
//   sand         two scales of fine grain, so it reads matte, not flat
//   aggregate    specks of stone in the mix, a few lighter and a few darker, all sizes
//   pits         small air holes, irregular, a soft shadow at the top inside and a lit lip
//                below (light from above), rare and never in a pattern
//   shading      a touch lighter at the top, a soft shade into the edges, like a slab
vec3 concrete(vec2 px) {
    // the pour: warped fbm
    vec2 w = vec2(fbm(px / 160.0 + 3.1), fbm(px / 160.0 + 8.7));
    float pour = fbm(px / 120.0 + w * 1.6);
    float stain = smoothstep(0.58, 0.78, fbm(px / 260.0 + 21.0));
    // board form: wavering horizontal grain
    float grain = vnoise(vec2(px.x / 90.0, px.y / 2.2 + fbm(px / 70.0) * 3.0));
    // sand: fine and finer
    float sand = vnoise(px / 1.1) * 0.55 + vnoise(px / 2.7) * 0.45;
    float tone = 0.9 + 0.26 * (pour - 0.5) - 0.09 * stain + 0.03 * (grain - 0.5) + 0.08 * (sand - 0.5);
    vec3 c = base.rgb * tone;
    // aggregate: one speck at most per 5 px cell, about one in twelve cells
    vec2 cell = floor(px / 5.0);
    float pick = h21(cell + 7.3);
    if (pick > 0.92) {
        vec2 ctr = (cell + 0.2 + 0.6 * vec2(h21(cell + 1.7), h21(cell + 4.1))) * 5.0;
        float rad = 0.5 + 1.3 * h21(cell + 6.6);
        float m = smoothstep(rad + 0.6, rad - 0.3, length(px - ctr));
        c *= 1.0 + (pick > 0.965 ? 0.13 : -0.15) * m;
    }
    // pits: one at most per 22 px cell, rare, an uneven blob
    vec2 pc = floor(px / 22.0);
    if (h21(pc + 2.9) > 0.86) {
        vec2 ctr = (pc + 0.2 + 0.6 * vec2(h21(pc + 1.3), h21(pc + 5.5))) * 22.0;
        vec2 d = px - ctr;
        float ang = atan(d.y, d.x);
        float rad = (0.9 + 2.1 * h21(pc + 8.2)) * (0.8 + 0.35 * sin(ang * 3.0 + h21(pc) * 6.3));
        float r = length(d);
        float inside = smoothstep(rad + 0.5, rad - 0.5, r);
        // the shadow falls in from the top edge, the bottom lip catches the light
        float upper = clamp(-d.y / max(rad, 0.1) * 0.5 + 0.5, 0.0, 1.0);
        c *= 1.0 - inside * (0.22 + 0.3 * upper);
        float lip = smoothstep(rad + 1.4, rad + 0.3, r) * (1.0 - inside) * step(0.0, d.y);
        c *= 1.0 + 0.1 * lip;
    }
    // shading: lighter at the top, a soft shade into every edge
    vec2 uv = px / itemSize;
    vec2 e = min(px, itemSize - px);
    float edge = smoothstep(0.0, 18.0, min(e.x, e.y));
    c *= (1.03 - 0.06 * uv.y) * (0.94 + 0.06 * edge);
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
