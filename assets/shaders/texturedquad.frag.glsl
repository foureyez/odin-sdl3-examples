#version 460

layout(location = 0) out vec4 color;

layout(location = 0) in vec2 uv;
layout(binding = 0) uniform sampler2D tex;

void main() {
    color = texture(tex, uv);
}
