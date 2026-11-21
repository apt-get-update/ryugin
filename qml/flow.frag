#version 440
// The "flow" backdrop, as AMLL's mesh.frag with SPlayer-Next's settings (flow speed 4, beat
// off: volume 0.1): the cover's 32x32 texture (made in Go) read 1:1 x 0.8, turning about
// the point 20% in from the corner, mirrored past its edges; dithered; darkened towards the
// sides. A new cover fades over the old.
// Compile: ./shaders.sh
layout(location = 0) in vec2 v_uv;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;   // seconds
    float aspect; // width / height
    float w;
    float h;
    float fade;   // 0: first cover, 1: second cover
};
layout(binding = 1) uniform sampler2D coverA;
layout(binding = 2) uniform sampler2D coverB;

float noise(vec2 p) { return fract(52.9829189 * fract(dot(p, vec2(0.06711056, 0.00583715)))); }

void main() {
    float angle = time * 0.8 + 0.2; // (frameTime / 10000 + volume) * 2, frameTime = ms x 4
    float s = sin(angle), c = cos(angle);
    vec2 d = v_uv - vec2(0.2);
    vec2 uv = vec2(c * d.x - s * d.y, s * d.x + c * d.y) * 0.8 + vec2(0.5); // x (1 - volume x 2)
    uv = 1.0 - abs(1.0 - mod(uv, 2.0)); // mirrored repeat
    vec3 col = mix(texture(coverA, uv).rgb, texture(coverB, uv).rgb, fade);
    col *= 0.9025; // x 0.95 (1 - volume / 2) in the shader, x 0.95 again as the canvas alpha
    col += (noise(gl_FragCoord.xy) + noise(gl_FragCoord.xy + vec2(47.0, 113.0)) - 1.0) / 255.0;
    col *= 0.6 + smoothstep(0.8, 0.3, distance(v_uv, vec2(0.5))) * 0.4;
    fragColor = vec4(col, 1.0) * qt_Opacity;
}
