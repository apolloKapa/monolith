// Terminal (ui/CyberFx): typed in, switched off. Coming in, it appears line by line, each line
// typed out left to right behind a block cursor, faintly green and scanlined until it settles;
// going, it collapses like an old CRT: squashed to a bright line, then to a dot, then dark.
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
    if (mode < 0.5) {
        float rowH = 16.0;
        float rows = ceil(itemSize.y / rowH);
        float rp = p * (rows + 3.0);
        float r = floor(px.y / rowH);
        float k = clamp(rp - r, 0.0, 1.0);
        float shown = step(uv.x, k) * step(r, rp);
        vec4 c = tex(uv) * shown;
        // the cursor at the typing head
        float head = k * itemSize.x;
        float cur = step(r, floor(rp)) * step(floor(rp), r) * step(head, px.x) * step(px.x, head + 9.0) * step(0.001, tex(vec2(clamp(uv.x, 0.0, 1.0), uv.y)).a);
        float settle = 1.0 - p;
        c.rgb = mix(c.rgb, red.rgb * c.a, 0.3 * settle);
        c.rgb *= 1.0 - 0.18 * settle * step(0.5, fract(px.y / 3.0));
        c = c * (1.0 - cur) + vec4(red.rgb, 1.0) * cur * 0.9;
        fragColor = c * qt_Opacity;
    } else {
        float sy = mix(1.0, 0.006, smoothstep(0.0, 0.55, p));
        float sx = mix(1.0, 0.0, smoothstep(0.55, 0.92, p));
        vec2 q = vec2((uv.x - 0.5) / max(sx, 0.002) + 0.5, (uv.y - 0.5) / sy + 0.5);
        vec4 c = tex(q);
        float glow = smoothstep(0.1, 0.55, p);
        c.rgb = mix(c.rgb, mix(vec3(1.0), red.rgb, 0.35) * c.a, glow * 0.8);   // brightening to the phosphor's white
        c *= 1.0 - smoothstep(0.88, 1.0, p);
        fragColor = c * qt_Opacity;
    }
}
