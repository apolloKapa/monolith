// Concrete (ui/CyberFx): slams down, crumbles. Coming in, it drops from above and lands hard,
// shudders and kicks up dust along its foot; going, cracks run between blocks and the blocks
// break off and fall, the lower ones first.
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
    if (mode < 0.5) {
        float fall = smoothstep(0.0, 0.5, p);
        float dy = -(1.0 - fall * fall) * 70.0;
        float after = clamp((p - 0.5) / 0.4, 0.0, 1.0);
        float shake = p > 0.5 ? sin(after * 40.0) * (1.0 - after) * 4.0 : 0.0;
        vec4 c = tex((px - vec2(shake * 0.6, dy + shake)) / itemSize);
        c *= smoothstep(0.0, 0.12, p);
        // dust puffing out along the bottom after it lands
        float foot = itemSize.y - px.y;
        float dust = p > 0.5 ? (1.0 - after) * smoothstep(34.0, 0.0, foot) * smoothstep(0.45, 0.8, vnoise(px * 0.09 + vec2(after * 6.0, -after * 3.0))) : 0.0;
        c = c * (1.0 - dust * 0.6) + vec4(vec3(0.62), 1.0) * dust * 0.6;
        fragColor = c * qt_Opacity;
    } else {
        // blocks, laid like bricks; each one, its time come, cracks free and falls (tipping a
        // little sideways), the lower ones first. A pixel shows whichever block is over it now:
        // its own, or one falling past from a row above.
        vec2 bs = vec2(56.0, 34.0);
        float row0 = floor(px.y / bs.y);
        vec4 c = vec4(0.0);
        for (int k = 0; k < 12; k++) {
            float r = row0 - float(k);
            if (r < 0.0) break;
            float off = mod(r, 2.0) * bs.x * 0.5;
            float cx = floor((px.x + off) / bs.x);
            vec2 cell = vec2(cx, r);
            float lower = (r + 1.0) * bs.y / max(itemSize.y, 1.0);
            float ts = (1.0 - clamp(lower, 0.0, 1.0)) * 0.42 + h21(cell) * 0.16;   // when it breaks off
            float go = max(0.0, p - ts);
            float drop = go * go * 2600.0;
            float dx = (h21(cell + 3.3) - 0.5) * go * 90.0;
            vec2 src = vec2(px.x - dx, px.y - drop);
            // still inside this block (its own row and column, at the source)?
            if (floor(src.y / bs.y) != r || floor((src.x + off) / bs.x) != cx) continue;
            vec4 b = tex(src / itemSize);
            vec2 inCell = vec2(mod(src.x + off, bs.x), mod(src.y, bs.y));
            float border = min(min(inCell.x, bs.x - inCell.x), min(inCell.y, bs.y - inCell.y));
            // a crack round it only just before it goes, then its broken edge shaded as it falls
            float crack = (1.0 - smoothstep(0.5, 1.6, border)) * smoothstep(ts - 0.08, ts, p);
            b.rgb *= 1.0 - 0.5 * crack;
            // a falling block darkens a little (out of the light) and fades out on its way down
            b.rgb *= 1.0 - 0.18 * smoothstep(0.0, 0.2, go);
            b *= 1.0 - smoothstep(0.16, 0.32, go);
            if (b.a > 0.002) { c = b; break; }
        }
        fragColor = c * qt_Opacity;
    }
}
