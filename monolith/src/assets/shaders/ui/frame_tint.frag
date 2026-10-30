#version 440

// The screen frame's tint (see-through styles): a colour over the whole item except a
// rounded hole where the desktop shows (less a notch bar, if there is one), antialiased along
// the hole's edge.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 color;
    vec4 hole;
    float holeRadius;
    vec4 notch;
    vec2 notchRadii;
};

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
    float inside = sdHole(p);
    float cover = clamp(0.5 + inside, 0.0, 1.0);
    fragColor = color * (cover * qt_Opacity);
}
