#version 440
// Fades an item out to the right (the "Full cover" layout's cover).
// Compile: ./shaders.sh
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    fragColor = texture(source, qt_TexCoord0) * (1.0 - smoothstep(0.0, 1.0, qt_TexCoord0.x)) * qt_Opacity;
}
