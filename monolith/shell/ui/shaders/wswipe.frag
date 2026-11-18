#version 440

// niri's "Slide sideways" workspace switch (island/WorkspaceFade.qml). niri itself only slides
// workspaces up and down, so it switches at once and this draws the wallpaper over the new
// workspace, then takes it away from one side to the other with a soft edge: the new workspace
// comes in sideways. The picture stays where it is (it's the wallpaper that's under the windows
// anyway); only the edge moves. p 0: all covered … 1: all clear. dir 1: the edge runs to the left
// (the new workspace comes in from the right), -1 the other way.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float p;
    float dir;
    float soft;     // the edge's softness, as a part of the width
};
layout(binding = 1) uniform sampler2D source;

void main() {
    float x = dir > 0.0 ? 1.0 - qt_TexCoord0.x : qt_TexCoord0.x;   // 0 where the clearing starts
    float front = mix(-soft, 1.0 + soft, p);
    float cover = smoothstep(front - soft, front + soft, x);
    fragColor = texture(source, qt_TexCoord0) * cover * qt_Opacity;
}
