#version 440

// Two-colour gradient over an item (used as its layer.effect): every pixel's colour is multiplied
// by the gradient, so white text takes the gradient and black shadows stay black.
// direction: 0 = left to right, 1 = top to bottom.
// After editing, rebuild the .qsb next to it (qsb comes with qt6-shadertools):
// qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o gradient_tint.frag.qsb gradient_tint.frag

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 colorA;
    vec4 colorB;
    float direction;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 src = texture(source, qt_TexCoord0);
    float t = direction > 0.5 ? qt_TexCoord0.y : qt_TexCoord0.x;
    vec4 g = mix(colorA, colorB, t);
    // src is premultiplied: tint its colour, keep its coverage
    fragColor = vec4(src.rgb * g.rgb, src.a) * qt_Opacity;
}
