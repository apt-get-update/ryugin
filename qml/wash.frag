#version 440
// The fullscreen player's backdrop, as SPlayer-Next's default ("blur"): the cover filling
// the window, scaled 1.5x, blur(45px) saturate(1.2) (made in Go), under 50% black.
// A new cover fades over the old one. Read in float, dithered: no steps.
// Compile: ./shaders.sh
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float aspect; // width / height
    float fade;   // 0: first cover, 1: second cover
};
layout(binding = 1) uniform sampler2D coverA;
layout(binding = 2) uniform sampler2D coverB;

float noise(vec2 p) { return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }

void main() {
    vec2 k = aspect > 1.0 ? vec2(1.0, 1.0 / aspect) : vec2(aspect, 1.0); // "cover" fit
    vec2 uv = vec2(0.5) + (qt_TexCoord0 - vec2(0.5)) * k / 1.5;
    vec3 col = mix(texture(coverA, uv).rgb, texture(coverB, uv).rgb, fade) * 0.5;
    col += (noise(gl_FragCoord.xy) + noise(gl_FragCoord.xy + vec2(47.0, 113.0)) - 1.0) / 255.0;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
