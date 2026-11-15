#version 440

// The Glitch workspace switch (island/WorkspaceFade.qml), over a picture of the wallpaper that
// covers the screen as the switch happens. A front sweeps down it (p 0 → 1), or up it when the
// switch goes up (dir -1: to a workspace above): above the front the
// cover is gone and the new workspace shows; just above the front, in a narrow torn band, rows of
// the cover slide sideways and split into red and cyan, fewer of them the further from the front;
// a thin neon line runs along the front with a soft glow under it; below it the cover is whole.
// Calm on purpose: the tear pattern is fixed for the whole switch (from `seed`), nothing blinks
// or flashes, and only the band moves. (Premultiplied colour, like Qt hands it over.)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float p;        // how far the front has gone (0 … 1)
    float seed;     // a fresh tear each switch
    float dir;      // 1: the front goes down, -1: up
    vec4 red;
    vec4 cyan;
};
layout(binding = 1) uniform sampler2D source;

float h21(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7)) + seed * 74.7) * 43758.5453); }

vec4 tex(vec2 uv) {
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
    return texture(source, uv);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * itemSize;
    float band = 0.16;                                    // the torn band's height (of the screen)
    float front = mix(-0.02, 1.0 + band, p);              // where the front is (it starts just above the top)
    float y = dir < 0.0 ? 1.0 - uv.y : uv.y;              // along the way the front goes
    float d = front - y;                                  // > 0: behind the front (already wiped)
    vec4 col = vec4(0.0);

    if (d <= 0.0) {
        // below the front: the cover, whole
        col = tex(uv);
    } else if (d < band) {
        // the torn band: rows 7 px tall, each with its own slide and its own moment to go
        float k = d / band;                               // 0 at the front … 1 at the band's top
        float row = floor(px.y / 7.0);
        float r1 = h21(vec2(row, 1.0));
        float r2 = h21(vec2(row, 2.0));
        float keep = step(k * 1.1, r1 * 0.9 + 0.1);       // rows drop out as the band passes
        float slide = (r2 - 0.5) * 0.09 * k * k;
        float split = (0.002 + 0.008 * k);
        vec2 q = uv + vec2(slide, 0.0);
        vec4 cr = tex(q + vec2(split, 0.0));
        vec4 cg = tex(q);
        vec4 cb = tex(q - vec2(split, 0.0));
        col = vec4(cr.r, cg.g, cb.b, cg.a) * keep * (1.0 - k * 0.6);
        // faint scanlines in it
        col.rgb *= 1.0 - 0.18 * step(0.5, fract(px.y / 3.0));
    }

    // the neon line along the front, and a soft glow under it on the cover
    float onFront = 1.0 - smoothstep(0.0, 2.0, abs(d * itemSize.y));
    float glow = (d <= 0.0) ? exp(d * itemSize.y / 28.0) * 0.35 : 0.0;
    vec3 neon = cyan.rgb;
    col.rgb = mix(col.rgb, neon * max(col.a, 0.9), onFront * 0.85);
    col.a = max(col.a, onFront * 0.85);
    col.rgb += neon * glow * col.a;
    fragColor = col * qt_Opacity;
}
