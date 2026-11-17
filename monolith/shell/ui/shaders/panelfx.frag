#version 440

// Theme → Effects and the Cyberpunk style's static on a panel (ui/PanelFx.qml), in one pass:
// scanlines (a light line every 3 px), film grain, and Cyberpunk's scan bar (a soft band of the
// accent with a bright leading edge sweeping down). Kept inside the panel's shape: its rounded
// corners, or Cyberpunk's one cut corner (bottom right). It used to be up to four offscreen
// layers and two MultiEffects per panel; this draws the same straight from the uniforms.
// (Premultiplied colour out, like Qt wants it.)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float radius;
    float cut;          // Cyberpunk's cut corner (px, bottom right); 0: rounded corners
    float scan;         // scanlines' opacity (0: none)
    float grain;        // grain's opacity (0: none)
    float drift;        // how far the scanlines and grain have crawled down (px)
    float sweep;        // the scan bar's leading edge (px from the top; 0: no bar)
    float barH;         // its height
    vec4 accent;
};

float hash(vec2 p) {
    p = fract(p * vec2(443.897, 441.423));
    p += dot(p, p.yx + 19.19);
    return fract((p.x + p.y) * p.x);
}

// inside the panel: 1, outside 0, a pixel of softening
float shape(vec2 px) {
    if (cut > 0.0) {
        float d = max(max(-px.x, px.x - itemSize.x), max(-px.y, px.y - itemSize.y));
        // the cut corner: the line x + y = w + h - cut
        d = max(d, (px.x + px.y - (itemSize.x + itemSize.y - cut)) * 0.7071);
        return clamp(0.5 - d, 0.0, 1.0);
    }
    // (a little rounder than the panel: continuous corners sit inside a plain arc of their radius
    // only once it's made a bit bigger, and this mustn't show past them)
    float r = min(radius * 1.2, min(itemSize.x, itemSize.y) * 0.5);
    vec2 q = abs(px - itemSize * 0.5) - itemSize * 0.5 + r;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    return clamp(0.5 - d, 0.0, 1.0);
}

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    float m = shape(px);
    if (m <= 0.0) { fragColor = vec4(0.0); return; }
    vec4 c = vec4(0.0);
    // scanlines: one light row in three, crawling down
    if (scan > 0.0) {
        float row = mod(floor(px.y) - drift, 3.0);
        c += vec4(1.0) * (row < 0.5 ? scan : 0.0);
    }
    // grain: a light grey speckle (what grain.png was), crawling with the scanlines
    if (grain > 0.0) {
        vec2 cell = floor(vec2(px.x, px.y - drift));
        float g = 0.62 + 0.3 * hash(mod(cell, 128.0) + 0.5);
        c = c * (1.0 - grain) + vec4(vec3(g), 1.0) * grain;
    }
    // the scan bar
    if (sweep > 0.0 && barH > 0.0) {
        float t = (px.y - (sweep - barH)) / barH;      // 0 at its top, 1 at its leading edge
        if (t > 0.0 && t < 1.0) {
            float a = t < 0.8 ? mix(0.0, 0.07, t / 0.8) : (t < 0.97 ? mix(0.07, 0.16, (t - 0.8) / 0.17) : mix(0.16, 0.35, (t - 0.97) / 0.03));
            c = c * (1.0 - a) + vec4(accent.rgb, 1.0) * a;
        }
    }
    fragColor = c * m * qt_Opacity;
}
