#version 440

// App icons on light tiles: icon packs made of plain white glyphs (YAMIS etc.) vanish there.
// When the whole icon averages out light and grey (read from the smallest mip level), it is
// drawn in the style's ink colour instead; colourful icons are left as they are.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 ink;
    float strength;
};

layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 c = texture(source, qt_TexCoord0);
    vec4 avg = textureLod(source, vec2(0.5), 16.0);
    vec3 rgb = avg.rgb / max(avg.a, 0.001);
    float lum = dot(rgb, vec3(0.299, 0.587, 0.114));
    float sat = max(rgb.r, max(rgb.g, rgb.b)) - min(rgb.r, min(rgb.g, rgb.b));
    float glyph = strength * smoothstep(0.6, 0.8, lum) * (1.0 - smoothstep(0.12, 0.25, sat));
    fragColor = mix(c, vec4(ink.rgb, 1.0) * c.a, glyph) * qt_Opacity;
}
