#version 440

// A gradient laid over a layer by multiplying (ui/GradientTint): white turns into the gradient,
// black (a text's drop shadow) stays black. The clocks' Gradient colouring.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 from;      // at the start of the way it goes
    vec4 to;        // at the end
    vec2 dir;       // the way it goes: (0, 1) top to bottom, (1, 1) top left to bottom right…
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 c = qt_TexCoord0 - 0.5;
    float reach = 0.5 * (abs(dir.x) + abs(dir.y));
    float t = clamp(dot(c, dir) / max(reach, 0.0001) * 0.5 + 0.5, 0.0, 1.0);
    vec4 s = texture(source, qt_TexCoord0);
    fragColor = vec4(s.rgb * mix(from.rgb, to.rgb, t), s.a) * qt_Opacity;
}
