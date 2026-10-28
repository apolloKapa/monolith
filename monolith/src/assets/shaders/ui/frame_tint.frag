#version 440

// The screen frame's tint (see-through styles): a colour over the whole item except a
// rounded hole where the desktop shows, antialiased along the hole's edge.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec4 color;
    vec4 hole;
    float holeRadius;
};

void main() {
    vec2 p = qt_TexCoord0 * itemSize - itemSize * 0.5;
    vec2 q = abs(p - hole.xy) - hole.zw + holeRadius;
    float inside = min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - holeRadius;
    float cover = clamp(0.5 + inside, 0.0, 1.0);
    fragColor = color * (cover * qt_Opacity);
}
