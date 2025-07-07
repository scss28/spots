#version 430 core

in vec2 uv;

layout(location = 0) uniform vec4 uColor;
layout(location = 1) uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  fragColor = texture(uTexture, uv) * uColor;
}
