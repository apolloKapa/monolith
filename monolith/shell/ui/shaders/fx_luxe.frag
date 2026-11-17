// Luxe (ui/CyberFx): gold light. Coming in, a band of warm gold light glides across it on a slant,
// and the panel is there behind the light as it passes: unlit ahead of it, fully there behind,
// rising the last few pixels into place. Going, the light glides back the other way and takes it
// with it, the panel dimming to nothing behind the band.
#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float p;        // how far along (0 … 1)
    float mode;     // 0: coming in (whole at 1), 1: going (gone at 1)
    float t;        // seconds since it started
    float seed;     // a fresh pattern each time
    vec4 red;       // the effect's first colour (the ink)
    vec4 cyan;      // its second (the accent: Luxe's gold)
};
layout(binding = 1) uniform sampler2D source;

vec4 tex(vec2 uv) {
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) return vec4(0.0);
    return texture(source, uv);
}

float ease(float x) { x = clamp(x, 0.0, 1.0); return x * x * (3.0 - 2.0 * x); }

// (premultiplied colour in and out, as Qt hands it over)
void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * itemSize;
    // where along the slant this pixel is: 0 at the top left, 1 at the bottom right
    float slant = (px.x + px.y * 0.55) / (itemSize.x + itemSize.y * 0.55);
    // the band's centre sweeps a little past both ends so it enters and leaves fully
    float soft = 0.16;
    float front = mode < 0.5 ? mix(-soft, 1.0 + soft, ease(p)) : mix(1.0 + soft, -soft, ease(p));
    float d = slant - front;
    // shown on the near side of the light (d < 0): coming in, that's where it has passed (the
    // band moves on towards the bottom right); going, where it hasn't reached yet (it moves back
    // towards the top left, taking what it passes)
    float shown = 1.0 - smoothstep(-soft, 0.0, d);
    // rising into place as it's revealed
    float rise = (1.0 - shown) * 10.0;
    vec4 c = tex((px + vec2(0.0, rise)) / itemSize) * shown;
    // the band of light itself: warm gold, brightest at its centre, a thin bright core
    float band = exp(-pow(d / (soft * 0.55), 2.0));
    float core = exp(-pow(d / (soft * 0.12), 2.0));
    vec3 gold = mix(cyan.rgb, vec3(1.0, 0.92, 0.72), 0.45);
    float a = tex(uv).a;
    // (light only where the panel is, fading as the sweep ends)
    float strength = (mode < 0.5 ? 1.0 - smoothstep(0.75, 1.0, p) : 1.0 - smoothstep(0.8, 1.0, p)) * a;
    c.rgb += gold * (0.35 * band + 0.55 * core) * strength;
    c.a = max(c.a, (0.35 * band + 0.55 * core) * strength * 0.6);
    fragColor = c * qt_Opacity;
}
