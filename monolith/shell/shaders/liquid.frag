#version 440
// Liquid glass: what's behind a rounded pane, bent near its edges like the rim of a lens
// (pulled in from further inside, a little more for blue than for red: a faint rainbow
// fringe), and cut to the pane's rounded shape with a smooth edge.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;        // the pane, in pixels
    float radius;     // its corner radius
    float bezel;      // how wide the bending rim is, in pixels
    float strength;   // how far it bends (0..1)
    float aberration; // the colour fringe, in pixels
};
layout(binding = 1) uniform sampler2D source;

float sdRound(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 px = qt_TexCoord0 * size;
    vec2 half_ = size * 0.5;
    vec2 p = px - half_;
    float r = min(radius, min(half_.x, half_.y));
    float d = sdRound(p, half_, r);                 // < 0 inside
    // the outward direction of the nearest edge
    vec2 e = vec2(1.0, 0.0);
    vec2 n = vec2(sdRound(p + e.xy, half_, r) - sdRound(p - e.xy, half_, r),
                  sdRound(p + e.yx, half_, r) - sdRound(p - e.yx, half_, r));
    n = n / max(length(n), 1e-4);
    // 1 at the edge, 0 once a bezel in; curved like the side of a lens
    float t = 1.0 - clamp(-d / max(bezel, 1.0), 0.0, 1.0);
    float bend = t * t * strength * bezel;
    vec2 uv = (px - n * bend) / size;
    vec2 ca = n * aberration * t / size;
    vec4 col;
    col.r = texture(source, uv + ca).r;
    col.g = texture(source, uv).g;
    col.b = texture(source, uv - ca).b;
    col.a = 1.0;
    // a touch brighter in the rim, where real glass catches the light
    col.rgb += vec3(0.06) * t * t;
    float aa = clamp(0.5 - d, 0.0, 1.0);
    fragColor = col * aa * qt_Opacity;
}
