#version 440
// corner_cutout.frag plus an optional line along the curve (outlined styles: the fill bar's edge line
// carries on round the screen corners)

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float cornerIndex;
    vec4 color;
    // outlined styles: a line of this width along the curve, continuing the bar's edge line
    // (0 = no line; items that don't set it get 0)
    float lineWidth;
    vec4 lineColor;
};

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float r = min(itemSize.x, itemSize.y);

    vec2 center;
    if (cornerIndex < 0.5) {
        // 0: top-left (center at width, height)
        center = vec2(r, r);
    } else if (cornerIndex < 1.5) {
        // 1: top-right (center at 0, height)
        center = vec2(0.0, r);
    } else if (cornerIndex < 2.5) {
        // 2: bottom-left (center at width, 0)
        center = vec2(r, 0.0);
    } else {
        // 3: bottom-right (center at 0, 0)
        center = vec2(0.0, 0.0);
    }

    float distToCenter = length(p - center);
    float d = r - distToCenter; // positive inside the cutout circle, negative outside (in the fill area)

    float fillCov = clamp(0.5 - d, 0.0, 1.0);
    vec4 c = color * fillCov;
    if (lineWidth > 0.0) {
        // the band just outside the circle (on the fill side), lineWidth wide
        float lineCov = clamp(0.5 - d, 0.0, 1.0) * clamp(d + lineWidth + 0.5, 0.0, 1.0);
        c = mix(c, lineColor, lineCov);
    }
    fragColor = c * qt_Opacity;
}
