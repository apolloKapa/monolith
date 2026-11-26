#version 440

// The Lumen clock's disc (wall/faces/ClockLumen.qml): round, with a lobe towards every hour that
// swells as a hand comes near it, lit from the top left, edged with a faint rim. The same shape and
// light the clock painted in software (a Canvas, up to 30 times a second with the sweeping second
// hand), drawn here instead.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 lit0;      // how lit each hour is (0–1): 12, 1, 2, 3
    vec4 lit1;      // 4 … 7
    vec4 lit2;      // 8 … 11
    vec2 px;        // the item's size in pixels
    float baseR;    // the disc's radius between lobes
    float swellR;   // how far a fully lit lobe reaches out
    vec2 lightAt;   // where the light comes from, from the middle (pixels)
    vec4 inkLight;  // the gradient: at the light,
    vec4 ink;       // most of the way,
    vec4 inkDark;   // and at the far edge
    vec4 rim;       // the rim's colour (rgb), its strength in a
    float rimW;     // the rim's width (pixels)
};

float litAt(int h) {
    if (h < 4) return lit0[h];
    if (h < 8) return lit1[h - 4];
    return lit2[h - 8];
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * px;
    float dist = length(p);
    // degrees from twelve, clockwise
    float deg = degrees(atan(p.x, -p.y));
    if (deg < 0.0) deg += 360.0;
    int hour = int(floor(deg / 30.0 + 0.5)) % 12;
    float off = abs(deg - float(hour) * 30.0);
    off = min(off, 360.0 - off);
    float r = baseR + swellR * (0.28 + 0.72 * litAt(hour)) * (1.0 + cos(off / 15.0 * 3.14159265)) * 0.5;

    // the light: a radial gradient from a point (radius 0) at `lightAt` out to the circle round the
    // middle as big as a full lobe (like the canvas's createRadialGradient)
    float R = baseR + swellR;
    vec2 d = p - lightAt;
    float a = dot(lightAt, lightAt) - R * R;
    float b = 2.0 * dot(d, lightAt);
    float c = dot(d, d);
    float disc = max(b * b - 4.0 * a * c, 0.0);
    float t = (-b - sqrt(disc)) / (2.0 * a);
    t = clamp(t, 0.0, 1.0);
    vec3 col = t < 0.6 ? mix(inkLight.rgb, ink.rgb, t / 0.6) : mix(ink.rgb, inkDark.rgb, (t - 0.6) / 0.4);

    // filled up to the edge (a pixel's softening), the rim across it
    float fillA = clamp(r - dist + 0.5, 0.0, 1.0);
    float rimA = rimW > 0.0 ? clamp(rimW * 0.5 - abs(dist - r) + 0.5, 0.0, 1.0) * rim.a : 0.0;
    // (the rim over the fill, as the canvas stroked it after filling)
    vec3 pre = rim.rgb * rimA + col * fillA * (1.0 - rimA);
    float outA = rimA + fillA * (1.0 - rimA);
    fragColor = vec4(pre, outA) * qt_Opacity;
}
