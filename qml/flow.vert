#version 440
// The "flow" backdrop, SPlayer-Next's fluid one (AMLL's MeshGradientRenderer): a 5x5
// bicubic Hermite mesh that bends the cover. It is AMLL's fourth control-point preset: the
// first folds over itself and shows a hard arc (main_test.go checks for folds). The grid's
// texture coordinate is the mesh parameter; the vertex lands where the patch puts it,
// stretched by the window's aspect like AMLL's mesh.vert.
// Compile: make shaders
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 v_uv;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;   // seconds
    float aspect; // width / height
    float w;
    float h;
    float fade;   // 0: first cover, 1: second cover
};
out gl_PerVertex { vec4 gl_Position; };

const vec2 P[25] = vec2[25](
    vec2(-1.000000, -1.000000),
    vec2(-0.450195, -1.000000),
    vec2(0.195312, -1.000000),
    vec2(0.458008, -1.000000),
    vec2(1.000000, -1.000000),
    vec2(-1.000000, -0.251448),
    vec2(-0.558594, -0.660933),
    vec2(0.232422, -0.524438),
    vec2(0.685547, -0.375371),
    vec2(1.000000, -0.669913),
    vec2(-1.000000, 0.035910),
    vec2(-0.492188, 0.005379),
    vec2(0.021484, -0.136504),
    vec2(0.476562, 0.059258),
    vec2(1.000000, 0.251429),
    vec2(-1.000000, 0.696834),
    vec2(-0.690430, 0.589074),
    vec2(0.184570, 0.387924),
    vec2(0.605469, 0.463355),
    vec2(1.000000, 0.621402),
    vec2(-1.000000, 1.000000),
    vec2(-0.500000, 1.000000),
    vec2(-0.327148, 1.000000),
    vec2(0.500000, 1.000000),
    vec2(1.000000, 1.000000));
const vec2 U[25] = vec2[25](
    vec2(0.500000, 0.000000),
    vec2(0.500000, 0.000000),
    vec2(0.500000, 0.000000),
    vec2(0.500000, 0.000000),
    vec2(0.500000, 0.000000),
    vec2(1.118428, -0.320704),
    vec2(0.804076, 0.862266),
    vec2(0.377248, -0.847313),
    vec2(0.500000, 0.000000),
    vec2(0.500000, 0.000000),
    vec2(0.500000, 0.000000),
    vec2(0.000000, 0.500000),
    vec2(0.500000, 0.000000),
    vec2(0.844375, -0.487500),
    vec2(0.500000, 0.000000),
    vec2(0.187303, -0.463592),
    vec2(0.187303, -0.463592),
    vec2(0.242405, 0.437310),
    vec2(0.289508, -0.310460),
    vec2(0.158089, -0.102664),
    vec2(0.500000, 0.000000),
    vec2(0.500000, 0.000000),
    vec2(0.157000, 0.000000),
    vec2(0.500000, 0.000000),
    vec2(0.500000, 0.000000));
const vec2 V[25] = vec2[25](
    vec2(-0.000000, 0.500000),
    vec2(-0.849870, 0.595086),
    vec2(-0.000000, 0.500000),
    vec2(0.211309, 0.453154),
    vec2(-0.000000, 0.500000),
    vec2(-0.000000, 0.471500),
    vec2(-0.000000, 0.188500),
    vec2(0.245964, 0.527471),
    vec2(-0.000000, 0.500000),
    vec2(-0.000000, 0.500000),
    vec2(-0.000000, 0.500000),
    vec2(-0.387019, 0.911760),
    vec2(-0.334565, 0.371572),
    vec2(-0.000000, 0.220000),
    vec2(-0.000000, 0.500000),
    vec2(-0.000000, 0.393000),
    vec2(-0.000000, 0.500000),
    vec2(-0.000000, 0.500000),
    vec2(0.741450, 0.445508),
    vec2(-0.000000, 0.802000),
    vec2(-0.000000, 0.500000),
    vec2(0.478152, 0.146186),
    vec2(0.549908, 1.235113),
    vec2(-0.000000, 0.500000),
    vec2(-0.000000, 0.500000));

vec4 hermite(float t) {
    float t2 = t * t, t3 = t2 * t;
    return vec4(2.0 * t3 - 3.0 * t2 + 1.0, -2.0 * t3 + 3.0 * t2, t3 - 2.0 * t2 + t, t3 - t2);
}

void main() {
    vec2 q = qt_MultiTexCoord0 * 4.0;
    vec2 cell = min(floor(q), vec2(3.0));
    vec2 st = q - cell;
    int i00 = int(cell.y) * 5 + int(cell.x);
    int i10 = i00 + 1, i01 = i00 + 5, i11 = i00 + 6;
    vec4 a = hermite(st.x), b = hermite(st.y);
    vec2 pos = a.x * (b.x * P[i00] + b.y * P[i01] + b.z * V[i00] + b.w * V[i01])
             + a.y * (b.x * P[i10] + b.y * P[i11] + b.z * V[i10] + b.w * V[i11])
             + a.z * (b.x * U[i00] + b.y * U[i01])
             + a.w * (b.x * U[i10] + b.y * U[i11]);
    v_uv = vec2((cell.x + st.x) / 4.0, 1.0 - (cell.y + st.y) / 4.0);
    if (aspect > 1.0)
        pos.y *= aspect;
    else
        pos.x /= aspect;
    gl_Position = qt_Matrix * vec4((pos.x + 1.0) * 0.5 * w, (1.0 - pos.y) * 0.5 * h, 0.0, 1.0);
}
