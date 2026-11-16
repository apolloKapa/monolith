// Doodle (ui/CyberFx): drawn in by hand. Coming in, a pencil line runs round the edge, then the
// inside is scribbled in from the top left with a band of pencil hatching at the front; going, an
// eraser rubs it out the same way, crumbly at its edge.
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
};
layout(binding = 1) uniform sampler2D source;
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
// where a point is along the edge, clockwise from the top left (0 … 1), and how far in it is
float along(vec2 q, out float e) {
    float w = itemSize.x, h = itemSize.y;
    float dl = q.x, dr = w - q.x, dt = q.y, db = h - q.y;
    e = min(min(dl, dr), min(dt, db));
    float s;
    if (e == dt) s = q.x;
    else if (e == dr) s = w + q.y;
    else if (e == db) s = w + h + (w - q.x);
    else s = 2.0 * w + h + (h - q.y);
    return s / (2.0 * (w + h));
}
void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * itemSize;
    vec4 c = tex(uv);
    // the diagonal the scribbling (and the eraser) follows, a little uneven
    float d = (px.x * 0.8 + px.y) / (0.8 * itemSize.x + itemSize.y) + (vnoise(px * 0.035) - 0.5) * 0.1;
    float hatch = step(0.55, fract((px.x - px.y + vnoise(px * 0.2) * 2.0) / 6.0));
    if (mode < 0.5) {
        float e;
        float s = along(px, e);
        float wob = (vnoise(px * 0.045 + seed) - 0.5) * 3.0;
        float drawn = smoothstep(0.0, 0.5, p);                          // the outline so far
        float f = smoothstep(0.3, 1.0, p) * 1.2;                         // the fill's front
        float inside = 1.0 - smoothstep(f - 0.035, f, d);
        float front = smoothstep(f - 0.12, f - 0.04, d) * (1.0 - smoothstep(f - 0.01, f + 0.02, d));
        float done = 1.0 - smoothstep(0.9, 1.0, p);                     // the pencil fades as it's whole
        float line = (1.0 - smoothstep(0.7, 1.7, abs(e - 2.0 - wob))) * step(s, drawn) * done;
        float ink = max(line * 0.9, hatch * front * 0.55 * done) * step(0.001, c.a + line);
        vec4 body = c * inside;
        fragColor = (body * (1.0 - ink) + vec4(red.rgb, 1.0) * ink) * qt_Opacity;
    } else {
        float f = p * 1.2;
        float keep = smoothstep(f - 0.01, f + 0.035, d + (vnoise(px * 0.12) - 0.5) * 0.04);
        // smudged just behind the eraser
        float smudge = (1.0 - smoothstep(f, f + 0.08, d)) * keep;
        vec4 body = c * keep;
        body.rgb = mix(body.rgb, vec3(body.a) * 0.75, smudge * 0.5);
        fragColor = body * qt_Opacity;
    }
}
