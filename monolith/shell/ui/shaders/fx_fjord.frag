// Fjord (ui/CyberFx): frost. Coming in, it clears out of a crust of ice: crystals melt back from
// the middle outwards, glinting at their edges; going, it frosts over and fades.
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float p;        // how far along (0 … 1)
    float mode;     // 0: coming in (whole at 1), 1: going (gone at 1)
    float t;        // seconds since it started
    float seed;     // a fresh pattern each time
    vec4 red;       // the effect's first colour (ui/CyberFx: the ink, mostly)
    vec4 cyan;      // its second (the accent, mostly)
    vec4 panel;     // the panel's own colour (what the style paints it), solid
    float radius;   // its corner radius in px (0: square, or loose content)
    float base;     // how solid the panels are (Theme.see: below 1 when they're see-through)
    float loose;    // 1: loose content (a menu's page), 0: a panel
};
layout(binding = 1) uniform sampler2D source;
// inside the panel's own shape (its round corners): 1 inside, 0 outside, a pixel of softening
float inShape(vec2 px) {
    float r = min(radius, min(itemSize.x, itemSize.y) * 0.5);
    vec2 q = abs(px - itemSize * 0.5) - itemSize * 0.5 + r;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    return clamp(0.5 - d, 0.0, 1.0);
}
float h21(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7)) + seed * 74.7) * 43758.5453); }
float vnoise(vec2 q) {
    vec2 i = floor(q), f = fract(q);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1, 0)), u.x), mix(h21(i + vec2(0, 1)), h21(i + vec2(1, 1)), u.x), u.y);
}
vec4 tex(vec2 uv) {
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
    return texture(source, uv);
}
// (premultiplied colour in and out, as Qt hands it over)
void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * itemSize;
    vec4 c = tex(uv);
    // the frost's pattern: fine crystals over broad drifts, thawing from the middle first
    // (mostly from the middle out, the crystals only roughening the edge: a threshold on noise
    // alone broke it into black and white blotches)
    float n = length(uv - 0.5) * 1.1 + vnoise(px / 15.0) * 0.1 + vnoise(px / 40.0) * 0.16;
    float f = (mode < 0.5 ? p : 1.0 - p) * 1.25 - 0.08;
    float clear = 1.0 - smoothstep(f - 0.14, f, n);
    float edge = smoothstep(f - 0.16, f - 0.07, n) * (1.0 - smoothstep(f - 0.05, f + 0.01, n));
    // the ice: pale, a touch of the accent, frosted beneath. Frosted glass scatters, so this
    // gathers a dozen points in a spiral out to about 6 px, turned a different way for each
    // pixel: a soft, slightly grainy blur. (It was four copies shifted 3 px left, right, up and
    // down and averaged, and on icons and text that read as each one drawn twice, not frosted)
    vec4 soft = vec4(0.0);
    // A page (loose content): two dozen points spread evenly, no turning, so its words and shapes
    // go smoothly soft. A whole panel: more points over a wide reach, turned by a fine, even
    // dither (interleaved gradient noise) so the few points don't show as copies. (Turned at
    // random per pixel with 16 points, words broke up into speckles and edges went ragged.)
    float cnt = loose > 0.5 ? 24.0 : 32.0;
    float reach = loose > 0.5 ? 7.0 : 26.0;
    float turn = loose > 0.5 ? 0.0 : fract(52.9829189 * fract(dot(px, vec2(0.06711056, 0.00583715)))) * 6.2831853;
    float got = 0.0;
    for (int i = 0; i < 32; i++) {
        float fi = float(i);
        if (fi >= cnt) break;
        float r = 1.0 + reach * sqrt((fi + 0.5) / cnt);
        float a = turn + fi * 2.3999632;
        vec2 q = uv + vec2(cos(a), sin(a)) * r / itemSize;
        // (a point off the panel, or on its outline, is left out and the rest averaged: counted
        // as empty the frost faded out round the edges; pulled onto the edge, the outline was
        // counted over and over and a light band ran round it)
        vec2 m = (loose > 0.5 ? 0.0 : 2.0) / itemSize;
        if (q.x < m.x || q.x > 1.0 - m.x || q.y < m.y || q.y > 1.0 - m.y) continue;
        soft += texture(source, q);
        got += 1.0;
    }
    soft /= max(got, 1.0);
    // (ice made from the panel's own colour, lightened and touched with the accent: a fixed pale
    // blue-white ignored the palette)
    vec3 ice = mix(mix(panel.rgb, vec3(1.0), 0.62), cyan.rgb, 0.15);
    // one even sheet of ice over the whole panel, as solid as the panel is, what's under it only
    // tinting it. (Ice laid on as thick as each pixel was solid made it far brighter over the
    // icons and words than over a see-through panel's background: each icon came out as a white
    // copy of itself over its blurred colours)
    vec3 under = soft.a > 0.001 ? soft.rgb / soft.a : vec3(0.0);
    // (its edge is the panel's own, sharp, rounded corners and all: taken from the blurred one it
    // was a fuzzy rim)
    // (loose content keeps the blurred shape: cut to the sharp one, each letter came out as a
    // sharp pale copy of itself)
    // (a panel: inside its own rounded outline only. Anything not quite see-through counted as
    // panel before, and the panel's shadow reaches into its corners: the frost filled them in
    // square)
    float sheet = (loose > 0.5 ? smoothstep(0.0, 0.08, soft.a) : smoothstep(0.0, 0.06, c.a) * inShape(px)) * clamp(base > 0.0 ? base : 1.0, 0.0, 1.0);
    // (on a see-through panel, less of the pale ice: with nothing blurred behind it (over a
    // fullscreen game) a pale sheet that see-through just looked milky)
    float iceK = 0.6 * pow(clamp(base > 0.0 ? base : 1.0, 0.0, 1.0), 3.0);
    vec4 frost = vec4(mix(under, ice, iceK) * sheet, sheet) * 0.92;
    // Loose content (a page of a menu, switching to another): no sheet at all. A page has nothing
    // behind it, so a sheet as solid as a panel wherever something was in reach came out as
    // blotchy rectangles with ragged edges and holes. Its frost is just what's on it, softened
    // and paled a little, as see-through as it was.
    if (loose > 0.5) frost = vec4(mix(soft.rgb, ice * soft.a, 0.22), soft.a) * 0.95;
    vec4 o = mix(frost, c, clear);
    // (outside the outline, the panel's shadow stays as it is)
    if (loose < 0.5) o = mix(c, o, inShape(px));
    o.rgb += vec3(0.22) * edge * c.a;                 // a soft shine at the thawing edge
    if (mode > 0.5) o *= 1.0 - smoothstep(0.72, 1.0, p);
    // (in quickly: the blur behind the menu comes on once it's whole, at 8 %, and before that it
    // was a blurred box with nothing on it, its edges showing as a band)
    else o *= smoothstep(0.0, 0.08, p);
    fragColor = o * qt_Opacity;
}
