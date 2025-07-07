#version 430 core

layout(location = 0) uniform vec4 uSource;
layout(location = 1) uniform mat4 uMatrix;
 
const vec2 positions[4] = vec2[4](
    vec2(1, 0),
    vec2(1, 1),
    vec2(0, 0),
    vec2(0, 1)
);

const vec4 sources[8] = vec4[8](
    vec4(1, 0, 1, 0), vec4(0, 1, 0, 1),
    vec4(1, 0, 1, 0), vec4(0, 1, 0, 0),
    vec4(1, 0, 0, 0), vec4(0, 1, 0, 1),
    vec4(1, 0, 0, 0), vec4(0, 1, 0, 0)
);

out vec2 uv;

void main() {
    gl_Position = vec4(positions[gl_VertexID], 0, 1.0) * uMatrix;

    vec4 uvx = uSource * sources[gl_VertexID * 2];
    vec4 uvy = uSource * sources[gl_VertexID * 2 + 1];
    uv = vec2(
        uvx.x + uvx.y + uvx.z + uvx.w,
        uvy.x + uvy.y + uvy.z + uvy.w
    );
}
