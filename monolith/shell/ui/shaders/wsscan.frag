#version 440

// The Glitch workspace switch (island/WorkspaceFade.qml): light laid over the compositor's own
// slide, nothing covering it. A neon line sweeps the way the workspaces move (dir 1 down, -1 up),
// split a little into red and cyan, with a glow trailing behind it, faint scanlines in its wake
// and a few short streaks of data crackling just around it; all of it fades as the slide settles.
// Nothing here hides a window or depends on a picture of the screen, so nothing can flash.
// (Premultiplied colour out.)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float p;        // 0 … 1 through the slide
    float dir;      // 1: down, -1: up
    float seed;
    vec4 cyan;      // the line and its glow (the accent)
    vec4 red;       // the other side of the split
};

float h21(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7)) + seed * 74.7) * 43758.5453); }

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    float y = dir < 0.0 ? itemSize.y - px.y : px.y;          // along the way it goes
    // the front eases out like the slide does, from just before the edge to just past the other
    float e = 1.0 - pow(1.0 - p, 3.0);
    float front = mix(-40.0, itemSize.y + 40.0, e);
    float d = y - front;                                       // < 0: behind it (already swept)
    float fade = 1.0 - smoothstep(0.7, 1.0, p);

    // the line, split: red a few px ahead, cyan a few behind, white-hot where they meet
    float core = exp(-abs(d) / 1.6);
    float rLine = exp(-abs(d - 3.0) / 1.8);
    float cLine = exp(-abs(d + 3.0) / 1.8);
    vec3 col = vec3(1.0) * core * 0.9 + red.rgb * rLine * 0.8 + cyan.rgb * cLine * 0.9;
    float a = max(core * 0.9, max(rLine, cLine) * 0.75);

    // the glow trailing behind it, with faint scanlines in it
    float trail = d < 0.0 ? exp(d / 70.0) : exp(-d / 6.0);
    float scan = 0.55 + 0.45 * step(0.5, fract(px.y / 3.0));
    col += cyan.rgb * trail * 0.22 * scan;
    a = max(a, trail * 0.22 * scan);

    // data streaks: short bright segments on 3 px rows within ~70 px of the line, sparser further
    float row = floor(px.y / 3.0);
    float near = exp(-abs(d) / 28.0);
    float r1 = h21(vec2(row, 1.0)), r2 = h21(vec2(row, 2.0)), r3 = h21(vec2(row, 3.0));
    float x0 = r1 * itemSize.x, len = 20.0 + r2 * 160.0;
    float onSeg = step(x0, px.x) * step(px.x, x0 + len) * step(0.72, r3);
    vec3 sc = r2 > 0.5 ? cyan.rgb : red.rgb;
    col += sc * onSeg * near * 0.7;
    a = max(a, onSeg * near * 0.6);

    a *= fade;
    fragColor = vec4(col * fade, a) * qt_Opacity;
}
