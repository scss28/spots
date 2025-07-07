#version 430 core

out vec2 uv;

const vec2 positions[3] = vec2[3](
    vec2(0, 0),
    vec2(3, 0),
    vec2(0, 3)
);

void main() {
    gl_Position = vec4(positions[gl_VertexID], 0, 1.0);
    uv = positions[gl_VertexID];
}
