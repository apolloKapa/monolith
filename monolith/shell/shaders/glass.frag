#version 440
// Monolith's liquid glass (the Liquid glass style). A rounded pane modelled as a slab of glass
// whose edges curve down like a pebble's: across the bezel the surface tilts, and light coming
// through it bends (Snell's law, by the glass's index) so what's behind slides inward and the
// rim looks thick. The flat middle magnifies a touch; the glass is frosted by a disc of samples
// from the backdrop's mip levels; red and blue bend by different amounts near the edge (a faint
// prism). Light comes from the top left: the rim facing it shines, the far rim catches a dimmer
// bounce, the inside of the shaded side darkens, the bezel reflects what's just outside the pane
// (Fresnel) and a thin rainbow sits in the curve. Under the pointer the glass swells a little.
//
// The backdrop is the screen's wallpaper (one texture for the whole screen): `origin` is where
// the pane's top left is on the screen, `screen` the screen's size.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 paneSize;     // px
    vec4 corners;      // radii: top left, top right, bottom right, bottom left
    vec2 origin;       // the pane's top left on the screen, px
    vec2 screen;       // the screen, px
    float bezel;       // how wide the curved edge is, px
    float depth;       // how thick the glass is (how far light travels in it), px
    float index;       // refractive index (1.0 = air, ~1.5 = glass)
    float prism;       // colour split near the edge (0..0.3)
    float frost;       // blur radius, px
    float shine;       // rim light strength (0..1)
    float vivid;       // saturation of what's seen through it
    vec4 tint;         // a colour laid over it
    float tintMix;     // how much of it (0..1)
    vec2 pointer;      // the pointer, in the pane, px
    float swell;       // 0..1 while the pointer is over it
};
layout(binding = 1) uniform sampler2D backdrop;

const vec2 LIGHT = vec2(-0.6, -0.8);   // towards the light: up and to the left

float boxDist(vec2 p, vec2 halfSize, vec4 r) {
    // the radius of the corner p is nearest (y grows downwards)
    float rr = p.y < 0.0 ? (p.x < 0.0 ? r.x : r.y) : (p.x < 0.0 ? r.w : r.z);
    rr = min(rr, min(halfSize.x, halfSize.y));
    vec2 q = abs(p) - halfSize + rr;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - rr;
}

// the backdrop at a point given in pane pixels (relative to the pane's middle), at a mip level
vec3 seen(vec2 p, float level) {
    vec2 uv = (origin + p + paneSize * 0.5) / screen;
    return textureLod(backdrop, clamp(uv, vec2(0.001), vec2(0.999)), level).rgb;
}

// frosted: a few samples spread over a disc (Vogel spiral, turned per pixel so it doesn't band)
vec3 frosted(vec2 p, float radius) {
    if (radius < 0.6) return seen(p, 0.0);
    float level = clamp(log2(radius * 0.6), 0.0, 6.0);
    float turn = fract(sin(dot(gl_FragCoord.xy, vec2(12.9898, 78.233))) * 43758.5453) * 6.2831853;
    vec3 sum = vec3(0.0);
    float wsum = 0.0;
    for (int i = 0; i < 8; i++) {
        float k = (float(i) + 0.5) / 8.0;
        float a = float(i) * 2.3999632 + turn;
        vec2 o = vec2(cos(a), sin(a)) * sqrt(k) * radius;
        float w = 1.0 - 0.6 * k;
        sum += seen(p + o, level) * w;
        wsum += w;
    }
    return sum / wsum;
}

void main() {
    vec2 halfSize = paneSize * 0.5;
    vec2 p = qt_TexCoord0 * paneSize - halfSize;
    float d = boxDist(p, halfSize, corners);
    float cover = clamp(0.5 - d, 0.0, 1.0);
    if (cover <= 0.0) { fragColor = vec4(0.0); return; }

    float inset = max(-d, 0.0);                    // how far in from the edge
    float bz = max(bezel, 1.0);
    // the outward direction of the edge (from the distance field's slope)
    vec2 out2 = vec2(0.0, -1.0);
    if (inset < bz + 2.0) {
        vec2 e = vec2(0.8, 0.0);
        vec2 g = vec2(boxDist(p + e.xy, halfSize, corners) - boxDist(p - e.xy, halfSize, corners),
                      boxDist(p + e.yx, halfSize, corners) - boxDist(p - e.yx, halfSize, corners));
        if (dot(g, g) > 1e-8) out2 = normalize(g);
    }
    // the surface over the bezel: a quarter circle seen side on, flat from a bezel in
    float s = clamp(inset / bz, 0.0, 1.0);
    float rise = 1.0 - s;                          // 1 at the edge, 0 on the flat
    float tilt = min(rise / max(sqrt(1.0 - rise * rise), 0.12), 4.5);

    // the pointer: the glass swells under it, bending the light around that spot
    vec2 toPtr = (pointer - halfSize) - p;
    float reach = max(36.0, min(paneSize.x, paneSize.y) * 0.45);
    float bump = swell * exp(-dot(toPtr, toPtr) / (2.0 * reach * reach));
    vec3 n = normalize(vec3(out2 * tilt - toPtr / reach * bump * 0.6, 1.0));

    // light through the surface: where it lands on the backdrop, `depth` below
    vec3 ray = refract(vec3(0.0, 0.0, -1.0), n, 1.0 / max(index, 1.0001));
    vec2 bend = ray.xy / max(-ray.z, 0.25) * depth * (1.0 + 0.5 * bump);

    // the flat middle magnifies slightly (less on big panes, where it would swim)
    vec2 rel = p / max(halfSize, vec2(1.0));
    float big = clamp((max(halfSize.x, halfSize.y) - 160.0) / 300.0, 0.0, 1.0);
    vec2 look = p * (1.0 - 0.05 * (1.0 - big) * (1.0 - dot(rel, rel) * 0.5));

    // frost, a little lighter right at the rim so the bending stays crisp
    float fr = frost * mix(0.5, 1.0, s);
    vec3 col = frosted(look + bend, fr);
    // the prism: red bends a bit less, blue a bit more, where the glass curves
    if (rise > 0.02) {
        float split = prism * rise;
        float lv = clamp(log2(max(fr, 1.0) * 0.6), 0.0, 6.0);
        col.r = seen(look + bend * (1.0 - split), lv).r;
        col.b = seen(look + bend * (1.0 + split), lv).b;
    }
    // what's seen through it is a touch more vivid
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(luma), col, vivid);

    // lighting
    vec2 toLight = normalize(mix(normalize(LIGHT), length(toPtr) > 1.0 ? normalize(toPtr) : normalize(LIGHT), 0.35 * swell));
    float facing = dot(out2, toLight);              // 1: this edge faces the light
    float lit = pow(max(facing, 0.0), 1.4);
    float back = pow(max(-facing, 0.0), 2.0);
    // the bezel reflects what's just outside the pane (more at grazing angles)
    float fresnel = pow(1.0 - n.z, 1.6);
    if (fresnel > 0.002) {
        vec3 around = seen(p + out2 * (inset + bz * 1.2), 4.0) * 1.1 + 0.03;
        col = mix(col, around, clamp(fresnel * 0.5 * (0.45 + 0.55 * max(facing, 0.0)), 0.0, 0.55));
    }
    // the shaded side darkens just inside the rim
    col *= 1.0 - 0.14 * exp(-inset / (bz * 0.5)) * back;
    // the rim: a hair-thin bright line (strong facing the light, a dim bounce opposite) with a
    // softer glow inside it, and a broad sheen over the lit bezel
    float hair = exp(-inset / 1.0);
    float glow = exp(-inset / 4.5);
    float rimLight = (hair * (0.22 + 0.8 * lit + 0.35 * back) + glow * 0.12 * (0.3 + lit)) * shine;
    float sheen = exp(-inset / (bz * 0.5)) * lit * lit * 0.18 * shine;
    // a thin rainbow in the curve
    float band = (inset - bz * 0.45) / (bz * 0.2 + 1.0);
    vec3 rainbow = (0.5 + 0.5 * cos(6.2831853 * (dot(out2, vec2(0.6, 0.4)) + inset / (bz * 1.7) + vec3(0.0, 0.33, 0.67))) - 0.5)
                   * exp(-band * band) * (0.035 + 0.07 * lit) * shine;
    // the swell catches a soft highlight
    float spot = bump * 0.06;

    col = mix(col, tint.rgb, tintMix);
    col += vec3(rimLight + sheen + spot) + rainbow;
    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * cover * qt_Opacity;
}
