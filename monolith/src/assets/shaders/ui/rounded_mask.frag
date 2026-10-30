#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 radii;
    float fillAlpha;
    vec4 hole;
    float holeRadius;
    vec4 notch;
    vec2 notchRadii;
};

layout(binding = 1) uniform sampler2D src;

float sdRoundBox(vec2 p, vec2 b, float r) {
    r = min(r, min(b.x, b.y));
    vec2 q = abs(p) - b + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// the hole, less the notch (see liquid_glass.frag)
float sdHole(vec2 p) {
    float d = sdRoundBox(p - hole.xy, hole.zw, holeRadius);
    if (notch.z <= 0.0) return d;
    float n = -sdRoundBox(p - notch.xy, notch.zw, notchRadii.x);
    float r = notchRadii.y;
    return min(-r, max(d, n)) + length(max(vec2(d, n) + r, vec2(0.0)));
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize - itemSize * 0.5;
    vec2 h = itemSize * 0.5;
    float r = p.x < 0.0 ? (p.y < 0.0 ? radii.x : radii.w) : (p.y < 0.0 ? radii.y : radii.z);
    r = min(r, min(h.x, h.y));
    vec2 q = abs(p) - h + r;
    float d = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
    if (hole.z > 0.0) {
        // optional rounded hole (see liquid_glass.frag): the screen frame's inside edge
        d = max(d, -sdHole(p));
    }
    float c = clamp(0.5 - d, 0.0, 1.0);
    float cover = c * (1.0 - fillAlpha) / max(1.0 - c * fillAlpha, 0.0001);
    fragColor = texture(src, qt_TexCoord0) * (cover * qt_Opacity);
}
