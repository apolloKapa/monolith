#version 440
// Monolith surface grain: faint film noise over a panel, clipped to its rounded corners.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float radius;
    float amount;   // 0..1, how strong the grain is
    float seed;     // changes slowly so the grain lives a little
};

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

float roundedBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    float d = roundedBox(px - itemSize * 0.5, itemSize * 0.5, min(radius, min(itemSize.x, itemSize.y) * 0.5));
    float inside = clamp(0.5 - d, 0.0, 1.0);
    float n = hash(floor(px) + seed);
    // light and dark specks around mid grey
    float v = n > 0.5 ? 1.0 : 0.0;
    float a = abs(n - 0.5) * 2.0 * amount * inside * qt_Opacity;
    fragColor = vec4(vec3(v) * a, a);
}
