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
    // the ice: pale, a touch of the accent, a little blurred beneath
    vec4 soft = (tex(uv + vec2(3.0, 0.0) / itemSize) + tex(uv - vec2(3.0, 0.0) / itemSize) + tex(uv + vec2(0.0, 3.0) / itemSize) + tex(uv - vec2(0.0, 3.0) / itemSize)) * 0.25;
    vec3 ice = mix(vec3(0.86, 0.92, 0.97), cyan.rgb, 0.15);
    vec4 frost = vec4(mix(soft.rgb, ice * soft.a, 0.6), soft.a) * 0.92;
    vec4 o = mix(frost, c, clear);
    o.rgb += vec3(0.22) * edge * c.a;                 // a soft shine at the thawing edge
    if (mode > 0.5) o *= 1.0 - smoothstep(0.72, 1.0, p);
    else o *= smoothstep(0.0, 0.15, p);
    fragColor = o * qt_Opacity;
}
