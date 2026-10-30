#version 440

// Hard offset shadow (Brutal, Arcade, Doodle): the surface's own rounded shape moved down and
// right by `offset`, minus the part the surface covers, so round pills get round shadows.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    vec2 surfaceSize;
    float offset;
    vec4 radii;
    vec4 shadowColor;
};

float roundedBox(vec2 p, vec2 h) {
    float r = p.x < 0.0 ? (p.y < 0.0 ? radii.x : radii.w) : (p.y < 0.0 ? radii.y : radii.z);
    r = min(r, min(h.x, h.y));
    vec2 q = abs(p) - h + r;
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    vec2 h = surfaceSize * 0.5;
    float shadow = clamp(0.5 - roundedBox(p - h - vec2(offset), h), 0.0, 1.0);
    float surface = clamp(0.5 - roundedBox(p - h, h), 0.0, 1.0);
    fragColor = shadowColor * (shadow * (1.0 - surface) * qt_Opacity);
}
