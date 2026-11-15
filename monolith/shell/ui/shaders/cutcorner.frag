#version 440

// A layer with its bottom-right corner cut straight across (the Cyberpunk style's cut, ui/CutCorner):
// for pictures in cards, which a cut drawn over them can't hide on a see-through panel.
// Antialiased along the cut. (Premultiplied colour, like Qt hands it over.)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float cut;      // how far the cut reaches along each side, in px
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    // distance (px) inside the cut line x + y = w + h - cut; 1 px of softening across it
    float d = ((itemSize.x - px.x) + (itemSize.y - px.y) - cut) * 0.70710678;
    fragColor = texture(source, qt_TexCoord0) * clamp(d + 0.5, 0.0, 1.0) * qt_Opacity;
}
