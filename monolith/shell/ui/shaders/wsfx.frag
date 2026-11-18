#version 440

// A style's own workspace switch (island/WorkspaceFade.qml, Animations → Workspace switching →
// "<style>'s effect"): like Glitch (wsscan.frag), light and marks laid over the compositor's own
// slide, going the way the workspaces move (dir 1 down, -1 up), fading as the slide settles.
// Nothing here hides a window or depends on a picture of the screen, so nothing can flash.
// kind: 1 fjord (a band of frost), 2 doodle (a pencil line and its hatching), 3 terminal (a
// phosphor line typing a row of blocks), 4 paper (a fold: shadow ahead, light behind),
// 5 concrete (a heavy edge and its dust), 6 industrial (a hazard bar and the shutter's slats),
// 7 liquid (ripples), 8 luxe (a sheen of the accent, on a slant). (Premultiplied colour out.)
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float p;        // 0 … 1 through the slide
    float dir;      // 1: down, -1: up
    float seed;
    float kind;
    vec4 accent;
    vec4 ink;       // the text colour
};

float h21(vec2 v) { return fract(sin(dot(v, vec2(127.1, 311.7)) + seed * 74.7) * 43758.5453); }
float vnoise(vec2 v) {
    vec2 i = floor(v), f = fract(v);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), f.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), f.x), f.y);
}
// (colour, alpha) laid over what's there so far: the brighter of the two alphas
void lay(inout vec3 col, inout float a, vec3 c, float k) { col += c * k; a = max(a, k); }

void main() {
    vec2 px = qt_TexCoord0 * itemSize;
    float y = dir < 0.0 ? itemSize.y - px.y : px.y;          // along the way it goes
    float e = 1.0 - pow(1.0 - p, 3.0);                        // the front eases out like the slide
    float fade = 1.0 - smoothstep(0.7, 1.0, p);
    float span = itemSize.y + 80.0;
    vec3 col = vec3(0.0);
    float a = 0.0;
    int k = int(kind + 0.5);

    if (k == 1) {
        // fjord: a wide band of frost with a bright rim, ice glinting in it
        float d = y - mix(-40.0, span - 40.0, e);
        vec3 ice = mix(vec3(1.0), accent.rgb, 0.35);
        float band = d < 0.0 ? exp(d / 130.0) : exp(-d / 26.0);
        float haze = band * (0.16 + 0.10 * vnoise(px / 46.0));
        lay(col, a, ice, haze);
        lay(col, a, vec3(1.0), exp(-abs(d) / 1.4) * 0.55);
        vec2 cell = floor(px / 9.0);
        float dot_ = smoothstep(2.2, 0.6, length(px - (cell + 0.5) * 9.0));
        float glint = step(0.975, h21(cell)) * dot_ * band * (0.5 + 0.5 * sin(p * 40.0 + h21(cell + 3.0) * 6.28));
        lay(col, a, vec3(1.0), glint * 0.85);
    } else if (k == 2) {
        // doodle: a wobbly pencil line drawn twice, and hatching rubbed in behind it
        float wob = sin(px.x / 37.0 + seed) * 6.0 + sin(px.x / 11.0 + seed * 2.0) * 2.0;
        float d = y - mix(-40.0, span - 40.0, e) - wob;
        float rough = 0.55 + 0.45 * vnoise(px / 2.5);
        float line = smoothstep(2.4, 0.8, abs(d)) * rough;
        float line2 = smoothstep(1.8, 0.5, abs(d + 6.0 + sin(px.x / 23.0) * 2.0)) * rough * 0.5;
        lay(col, a, ink.rgb, max(line, line2) * 0.85);
        float hatch = step(mod(px.x + px.y + wob, 13.0), 1.4) * step(0.3, vnoise(vec2(px.x - px.y, px.x + px.y) / 50.0));
        float trail = d < 0.0 ? exp(d / 80.0) : 0.0;
        lay(col, a, ink.rgb, hatch * trail * 0.32 * rough);
    } else if (k == 3) {
        // terminal: a phosphor line, the row of blocks it has just typed, scanlines glowing behind
        float d = y - mix(-40.0, span - 40.0, e);
        lay(col, a, mix(accent.rgb, vec3(1.0), 0.5), exp(-abs(d) / 1.3) * 0.9);
        float scan = step(0.5, fract(px.y / 2.0));
        float trail = d < 0.0 ? exp(d / 60.0) : exp(-d / 5.0);
        lay(col, a, accent.rgb, trail * 0.20 * (0.4 + 0.6 * scan));
        float inRow = step(-22.0, d) * step(d, -4.0);
        vec2 cell = vec2(floor(px.x / 11.0), floor(seed));
        float block = step(0.45, h21(cell)) * step(1.5, mod(px.x, 11.0));
        lay(col, a, accent.rgb, inRow * block * 0.55);
    } else if (k == 4) {
        // paper: a fold going down the sheet, its shadow ahead of the crease and light behind it
        float d = y - mix(-60.0, span - 20.0, e);
        float shadow = d > 0.0 ? exp(-d / 34.0) * 0.26 : 0.0;
        float light = d < 0.0 ? exp(d / 44.0) * 0.20 : 0.0;
        a = max(shadow, light);
        col = vec3(1.0) * light;                                // (the shadow is black: alpha only)
        lay(col, a, vec3(1.0), exp(-abs(d) / 1.1) * 0.35);
    } else if (k == 5) {
        // concrete: a heavy edge coming down, dust thrown off it and hanging behind
        float d = y - mix(-40.0, span - 40.0, e);
        vec3 grey = mix(ink.rgb, vec3(0.5), 0.5);
        float edge = smoothstep(5.0, 3.0, abs(d));
        a = max(a, edge * 0.5);                                 // (the edge is dark: alpha only)
        col += grey * edge * 0.12;
        float near = d < 0.0 ? exp(d / 110.0) : exp(-d / 16.0);
        float grit = step(0.91, h21(floor(px / 2.0) + floor(p * 24.0))) * near;
        lay(col, a, grey, grit * 0.38);
        lay(col, a, grey, near * 0.10 * vnoise(px / 60.0 + p * 3.0));
    } else if (k == 6) {
        // industrial: a hazard bar leading, the shutter's slats behind it
        float d = y - mix(-40.0, span - 40.0, e);
        float bar = step(abs(d), 7.0);
        float stripe = step(0.5, fract((px.x + px.y) / 28.0));
        col += accent.rgb * bar * stripe * 0.9;
        a = max(a, bar * 0.9);                                  // (between the stripes: black)
        float trail = d < -7.0 ? exp((d + 7.0) / 150.0) : 0.0;
        float slat = step(mod(-d, 24.0), 1.5);
        lay(col, a, ink.rgb, slat * trail * 0.30);
        lay(col, a, accent.rgb, trail * 0.05);
    } else if (k == 7) {
        // liquid: ripples running ahead of a soft swell, bending with the surface
        float wave = sin(px.x / 70.0 + p * 9.0 + seed) * 9.0 + sin(px.x / 23.0 - p * 6.0) * 3.0;
        float d = y - mix(-60.0, span - 20.0, e) - wave;
        vec3 w = mix(vec3(1.0), accent.rgb, 0.25);
        lay(col, a, w, exp(-abs(d) / 2.2) * 0.50);
        lay(col, a, w, exp(-abs(d + 20.0) / 3.5) * 0.26);
        lay(col, a, w, exp(-abs(d + 46.0) / 5.0) * 0.14);
        lay(col, a, w, exp(-abs(d + 78.0) / 7.0) * 0.07);
        float swell = d < 0.0 ? exp(d / 90.0) : exp(-d / 10.0);
        lay(col, a, w, swell * 0.10);
    } else {
        // luxe: a sheen of the accent crossing on a slant, a fine bright line in it, a few glints
        float ys = y + px.x * 0.22;
        float d = ys - mix(-80.0, span + itemSize.x * 0.22, e);
        float band = exp(-d * d / (2.0 * 70.0 * 70.0));
        lay(col, a, accent.rgb, band * 0.20);
        lay(col, a, mix(accent.rgb, vec3(1.0), 0.6), exp(-abs(d) / 1.3) * 0.6);
        vec2 cell = floor(px / 9.0);
        float dot_ = smoothstep(2.0, 0.5, length(px - (cell + 0.5) * 9.0));
        lay(col, a, vec3(1.0), step(0.985, h21(cell)) * dot_ * band * 0.9);
    }

    fragColor = vec4(col, a) * fade * qt_Opacity;
}
