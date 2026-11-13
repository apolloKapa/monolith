#version 440

// Continuous corners: a rounded rectangle whose corners are superellipse arcs instead of
// quarter circles, so the curve eases out of the straight sides (no visible "kink" where the
// arc starts). `expo` 2 is an ordinary circular corner; the extent and exponent come from
// SmoothRect.qml, matched so the corner still looks as round as the theme's radius says.
// Fill and outline in one pass, antialiased. (Qt hands colours over premultiplied.)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float extent;      // how far along each side the corner curve reaches
    float expo;        // superellipse exponent (2: circle)
    float borderW;
    vec4 fillColor;
    vec4 borderColor;
};

// signed distance (close enough for antialiasing) to a box of half-size b with superellipse
// corners of extent r
float sdSmoothBox(vec2 p, vec2 b, float r, float n) {
    r = clamp(r, 0.0, min(b.x, b.y));
    vec2 q = abs(p) - b + r;
    vec2 m = max(q, 0.0);
    float corner = 0.0;
    if (r > 0.0 && (m.x > 0.0 || m.y > 0.0)) {
        vec2 u = m / r;
        corner = r * pow(pow(u.x, n) + pow(u.y, n), 1.0 / n);
    } else {
        corner = length(m);
    }
    return corner + min(max(q.x, q.y), 0.0) - r;
}

float cover(float d) {
    float w = max(fwidth(d), 1e-4);
    return clamp(0.5 - d / w, 0.0, 1.0);
}

void main() {
    vec2 half_ = itemSize * 0.5;
    vec2 p = qt_TexCoord0 * itemSize - half_;
    float outer = cover(sdSmoothBox(p, half_, extent, expo));
    float inner = outer;
    if (borderW > 0.0) {
        // the inside edge follows the outside one, a border-width in
        float ri = max(extent - borderW, 0.0);
        inner = cover(sdSmoothBox(p, max(half_ - borderW, vec2(0.0)), ri, expo));
    }
    vec4 f = fillColor * inner;
    vec4 s = borderColor * max(outer - inner, 0.0);
    fragColor = (f + s) * qt_Opacity;
}
