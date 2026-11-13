#version 440

// A BlurHash, drawn: the sum of its 4x3 cosine components (colours in linear light, turned back
// into sRGB here), so it is smooth at any size. Mixed a little towards the theme's surface
// (`tint`) so it sits in the palette, with a soft sheen sweeping across while it's loading, and
// cut to continuous corners like SmoothRect (extent/expo; 0 extent: square).
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 c0; vec4 c1; vec4 c2; vec4 c3;
    vec4 c4; vec4 c5; vec4 c6; vec4 c7;
    vec4 c8; vec4 c9; vec4 c10; vec4 c11;
    vec4 tint;          // the theme's colour to lean towards (premultiplied by Qt)
    float tintAmount;
    float sheen;        // 0..1 position of the loading sheen (<0: none)
    vec4 sheenColor;
    vec2 itemSize;
    float extent;
    float expo;
};

const float PI = 3.14159265;

vec3 toSrgb(vec3 v) {
    v = clamp(v, 0.0, 1.0);
    return mix(v * 12.92, 1.055 * pow(v, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), v));
}

float sdSmoothBox(vec2 p, vec2 b, float r, float n) {
    r = clamp(r, 0.0, min(b.x, b.y));
    vec2 q = abs(p) - b + r;
    vec2 m = max(q, 0.0);
    float c = length(m);
    if (n > 2.01 && r > 0.0 && (m.x > 0.0 || m.y > 0.0)) {
        vec2 u = m / r;
        c = r * pow(pow(u.x, n) + pow(u.y, n), 1.0 / n);
    }
    return c + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 uv = qt_TexCoord0;
    float x0 = 1.0, x1 = cos(PI * uv.x), x2 = cos(2.0 * PI * uv.x), x3 = cos(3.0 * PI * uv.x);
    float y0 = 1.0, y1 = cos(PI * uv.y), y2 = cos(2.0 * PI * uv.y);
    vec3 lin = c0.rgb * x0 * y0 + c1.rgb * x1 * y0 + c2.rgb * x2 * y0 + c3.rgb * x3 * y0
             + c4.rgb * x0 * y1 + c5.rgb * x1 * y1 + c6.rgb * x2 * y1 + c7.rgb * x3 * y1
             + c8.rgb * x0 * y2 + c9.rgb * x1 * y2 + c10.rgb * x2 * y2 + c11.rgb * x3 * y2;
    vec3 col = toSrgb(lin);
    vec3 t = tint.a > 0.0 ? tint.rgb / tint.a : tint.rgb;
    col = mix(col, t, tintAmount);
    if (sheen >= 0.0) {
        // a soft diagonal band moving left to right
        float d = (uv.x + uv.y * 0.35) - (sheen * 1.7 - 0.35);
        float band = exp(-d * d * 60.0);
        col = mix(col, sheenColor.rgb / max(sheenColor.a, 0.001), band * sheenColor.a);
    }
    float a = 1.0;
    if (extent > 0.0) {
        vec2 half_ = itemSize * 0.5;
        float d = sdSmoothBox(uv * itemSize - half_, half_, extent, expo);
        a = clamp(0.5 - d / max(fwidth(d), 1e-4), 0.0, 1.0);
    }
    fragColor = vec4(col * a, a) * qt_Opacity;
}
