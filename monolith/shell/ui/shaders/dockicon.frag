#version 440

// An app icon recoloured for the dock's icon looks (dock/DockIcon). Qt hands colours over
// premultiplied; the icon's own colour is taken out of that, worked on, and put back.
//   look 1, tinted: the icon in shades of the tint, by its brightness: its dark parts a deep
//           shade of the tint, its light parts a pale one (white glyphs come out pale tint)
//   look 2, clear:  pale greys by brightness, a little see-through
//   look 3, dark:   a touch dimmer and less saturated
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tint;
    float look;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec4 px = texture(source, qt_TexCoord0);
    float a = px.a;
    vec3 rgb = a > 0.0 ? px.rgb / a : vec3(0.0);
    float lum = dot(rgb, vec3(0.2126, 0.7152, 0.0722));
    vec3 outc = rgb;
    float outa = a;
    if (look < 1.5) {
        vec3 deep = tint.rgb * 0.32;
        vec3 pale = mix(tint.rgb, vec3(1.0), 0.38);
        outc = mix(deep, pale, smoothstep(0.0, 1.0, lum));
    } else if (look < 2.5) {
        outc = vec3(mix(0.62, 1.0, lum));
        outa = a * 0.86;
    } else {
        outc = mix(rgb, vec3(lum), 0.15) * 0.84;
    }
    fragColor = vec4(outc * outa, outa) * qt_Opacity;
}
