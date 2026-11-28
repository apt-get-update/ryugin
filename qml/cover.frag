#version 440
// A cover: the picture cropped to fill (as Image.PreserveAspectCrop), its corners rounded
// with a pixel of smoothing. One pass, no layer nor mask (they took two pictures of the
// cover's size each). Compile: make shaders
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 area;    // the cover's size, in device pixels
    vec2 crop;    // the part of the picture shown, each way (1: all of it)
    float corner; // the corners' radius, in device pixels
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * area; // from the centre
    vec2 q = abs(p) - 0.5 * area + corner;
    float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - corner; // out of the edge
    fragColor = texture(source, 0.5 + (qt_TexCoord0 - 0.5) * crop) * clamp(0.5 - d, 0.0, 1.0) * qt_Opacity;
}
