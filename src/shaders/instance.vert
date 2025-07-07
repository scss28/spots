#version 430 core

layout(location = 0) in float iIndex;
layout(location = 1) in vec4 iColor;
layout(location = 2) in vec4 iSource;
layout(location = 3) in mat4 iMatrix;
 
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

out float index;
out vec2 uv;
out vec4 color;

void main() {
    uint id = gl_VertexID % 4;
    gl_Position = vec4(positions[id], 0, 1.0) * iMatrix;

    vec4 uvx = iSource * sources[id * 2];
    vec4 uvy = iSource * sources[id * 2 + 1];
    uv = vec2(
        uvx.x + uvx.y + uvx.z + uvx.w,
        uvy.x + uvy.y + uvy.z + uvy.w
    );

    index = iIndex;
    color = iColor;
}
