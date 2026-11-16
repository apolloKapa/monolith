// Paper (ui/CyberFx): unfolds, folds away. Coming in, the sheet opens down from a crease: what is
// still folded hangs under it foreshortened and shaded, flattening as it opens; going, it folds
// back up the same way and is gone.
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
    float h = itemSize.y;
    float e = mode < 0.5 ? 1.0 - pow(1.0 - p, 3.0) : 1.0 - p * p * (3.0 - 2.0 * p);
    float R = e * h;                                  // opened down to here
    float flap = (1.0 - e) * h * 0.32;                // the rest, folded under the crease
    float y = uv.y * h;
    vec4 c;
    if (y <= R) c = tex(uv);
    else if (y <= R + flap) {
        float k = (y - R) / max(flap, 0.001);
        c = tex(vec2(uv.x, (R + k * (h - R)) / h));
        c.rgb *= 0.55 + 0.4 * e + 0.15 * k;           // turned away from the light
    } else c = vec4(0.0);
    // the crease: a fine dark line, gone once it's flat
    float crease = (1.0 - smoothstep(0.0, 2.0, abs(y - R))) * (1.0 - e);
    c.rgb *= 1.0 - 0.35 * crease;
    if (mode > 0.5) c *= 1.0 - smoothstep(0.85, 1.0, p);
    fragColor = c * qt_Opacity;
}
