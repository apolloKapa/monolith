// Industrial (ui/CyberFx): a steel roller shutter. Coming in, a shutter in the shape of the panel
// rolls up and shows it; going, it rolls down over it, then the shutter goes. Slats shaded like
// pressed steel, a hazard-striped bar along its bottom edge in the accent.
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
vec3 shutter(vec2 px) {
    float slat = mod(px.y, 18.0) / 18.0;
    float shade = 0.36 + 0.16 * sin(slat * 3.14159) - 0.08 * step(0.9, slat);
    float grain = (vnoise(vec2(px.x / 90.0, px.y / 1.5)) - 0.5) * 0.05;
    // (pressed steel in the panel's own colour, lifted a little towards the ink)
    vec3 steel = mix(panel.rgb, red.rgb, 0.22);
    return steel * ((shade + grain) / 0.44);
}
void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * itemSize;
    vec4 c = tex(uv);
    float e = mode < 0.5 ? 1.0 - pow(1.0 - p, 3.0) : p * p * (3.0 - 2.0 * p);
    float B = mode < 0.5 ? itemSize.y * (1.0 - e) : itemSize.y * e;    // the shutter's bottom edge
    // the panel's own shape, so the shutter fits it (round corners included)
    float shape = c.a;
    if (px.y < B) {
        vec3 s = shutter(px);
        float bar = B - px.y;
        if (bar < 10.0) {
            float stripe = step(0.5, fract((px.x + px.y) / 16.0));
            s = mix(panel.rgb * 0.45, cyan.rgb, stripe);
        }
        float a = shape * (mode < 0.5 ? smoothstep(0.0, 0.1, p) : 1.0);
        c = vec4(s * a, a);
    }
    if (mode > 0.5) c *= 1.0 - smoothstep(0.78, 1.0, p);
    fragColor = c * qt_Opacity;
}
