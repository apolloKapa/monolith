#version 440

// The Cyberpunk style's motion (ui/CyberFx.qml), over a layer of whatever is moving.
//   mode 0, glitch in (p 0 → 1): it comes in band by band; the bands jump sideways and split into
//   red and cyan, blocks of corrupted colour flash, scanlines flicker; all of it settles as p
//   reaches 1, where the picture is untouched.
//   mode 1, the Blackwall (p 0 → 1): it drains to the wall's red and tears sideways, then red-hot
//   crystalline shards eat it to black crackling with red static, until nothing is left.
// Time moves in steps (30 a second) so it jumps like a broken signal instead of flowing.
// (Qt hands colours and the layer over premultiplied; everything here stays premultiplied.)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float p;        // how far along (0 … 1)
    float mode;     // 0: glitch in, 1: Blackwall out
    float t;        // seconds since it started
    float seed;     // a fresh pattern each time
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
    float tick = floor(t * 30.0);

    if (mode < 0.5) {
        // ── glitch in ──
        if (p <= 0.0) { fragColor = vec4(0.0); return; }
        float k = 1.0 - p;                                  // how much glitch is left
        float bands = 6.0 + floor(h21(vec2(tick, 3.0)) * 18.0);
        float bi = floor(uv.y * bands);
        float r1 = h21(vec2(bi, tick));
        float r2 = h21(vec2(bi + 17.0, tick));
        float shown = step(r1, p * 1.3);                    // a band is there once p passes its number
        float jump = (r2 - 0.5) * 0.2 * k * step(0.5, h21(vec2(bi, tick + 3.0)));
        vec2 q = uv + vec2(jump, 0.0);
        float split = (0.006 + 0.03 * step(0.75, r2)) * k;
        vec4 cr = tex(q + vec2(split, 0.0));
        vec4 cg = tex(q);
        vec4 cb = tex(q - vec2(split, 0.0));
        // red from one side, green and blue from the other: red and cyan fringes
        vec4 col = vec4(cr.r, cg.g, cb.b, max(max(cr.a, cg.a), cb.a));
        // blocks of corrupted colour, mostly at the start
        vec2 cell = floor(px / vec2(28.0, 7.0));
        if (h21(cell + tick * 1.37) > 1.0 - 0.16 * k * k) {
            vec4 tint = h21(cell * 1.7 + tick) > 0.5 ? cyan : red;
            col = vec4(tint.rgb, 1.0) * max(cg.a, 0.7);
        }
        // scanlines, flickering, and the first glimpses dimmer
        col.rgb *= 1.0 - 0.3 * k * step(0.5, fract(px.y / 3.0));
        col *= shown * mix(1.0, 0.55 + 0.45 * h21(vec2(bi, tick + 9.0)), k);
        fragColor = col * qt_Opacity;
        return;
    }

    // ── the Blackwall ──
    if (p >= 1.0) { fragColor = vec4(0.0); return; }
    // crystalline shards: a slanted grid cut into triangles, each with its own number; bigger
    // patches and a red front rolling in from one side, so it doesn't eat evenly
    vec2 sg = vec2(px.x + px.y * 0.55, px.y) / 22.0;
    vec2 f = fract(sg);
    float tri = step(f.x, f.y);
    float n = h21(floor(sg) * 2.0 + tri) * 0.55 + h21(floor(px / vec2(96.0, 64.0)) + 41.0) * 0.2
            + (1.0 - uv.x) * 0.25 + 0.04 * sin(uv.y * 23.0 + t * 9.0);
    float d = (p * 1.45 - 0.25) - n;                        // > 0: eaten
    // tearing: rows jump sideways, more as it goes
    float row = floor(px.y / 5.0);
    float tear = (h21(vec2(row, tick)) - 0.5) * 0.16 * p * step(0.72, h21(vec2(row + 5.0, tick)));
    vec4 src = tex(uv + vec2(tear, 0.0));
    float a = src.a;
    // what's left drains to the wall's red
    float lum = dot(src.rgb, vec3(0.299, 0.587, 0.114));
    vec3 c = mix(src.rgb, red.rgb * (lum * 1.7 + 0.1 * a), smoothstep(0.0, 0.55, p));
    vec4 col = vec4(c, a);
    if (d > 0.0) {
        // eaten: black, with red static crackling in it, then gone
        float fade = clamp(1.0 - d * 3.5, 0.0, 1.0);
        float crackle = step(0.9, h21(floor(px / 2.0) + tick));
        col = vec4(red.rgb * crackle, 1.0) * a * fade;
    } else {
        // the shard edge just ahead of it, red-hot
        float edge = smoothstep(-0.09, 0.0, d);
        col.rgb = mix(col.rgb, (red.rgb + vec3(0.12) * edge) * a, edge);
    }
    // red static over all of it
    float speck = step(1.0 - 0.18 * p, h21(floor(px / 3.0) + tick * 1.3));
    col.rgb += red.rgb * speck * 0.7 * col.a;
    fragColor = col * qt_Opacity;
}
