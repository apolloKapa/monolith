#version 440

// Orbit's ink ripple: a soft disc spreading from the press point, clipped to the
// control's rounded shape (one corner radius for all four corners)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float shapeRadius;
    float shapeExpo;     // the corners' superellipse exponent (2: round; see SmoothRect)
    vec2 center;
    float rippleRadius;
    vec4 inkColor;
    float inkAlpha;
};

float sdRoundBox(vec2 p, vec2 b, float r, float n) {
    r = min(r, min(b.x, b.y));
    vec2 q = abs(p) - b + r;
    vec2 m = max(q, 0.0);
    float c = length(m);
    if (n > 2.01 && r > 0.0 && (m.x > 0.0 || m.y > 0.0)) {
        vec2 u = m / r;
        c = r * pow(pow(u.x, n) + pow(u.y, n), 1.0 / n);
    }
    return min(max(q.x, q.y), 0.0) + c - r;
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    float shape = sdRoundBox(px - itemSize * 0.5, itemSize * 0.5, shapeRadius, shapeExpo);
    float inside = 1.0 - smoothstep(-0.75, 0.75, shape);
    float d = length(px - center);
    // a soft rim so the edge of the ink isn't a hard line
    float disc = 1.0 - smoothstep(rippleRadius - 6.0, rippleRadius, d);
    float a = inkAlpha * disc * inside * qt_Opacity;
    fragColor = vec4(inkColor.rgb * a, a);
}
