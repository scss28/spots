#version 430 core

in float index;
in vec2 uv;
in vec4 color;

layout(location = 7) uniform sampler2DArray uTexture;

out vec4 fragColor;

void main() {
    fragColor = color * texture(uTexture, vec3(uv, index)).r;
}
