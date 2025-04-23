#version 450 core

layout(set = 2, binding = 0) uniform sampler2D textureSampler;
layout(set = 2, binding = 1) uniform sampler2D metallicSampler;
layout(set = 3, binding = 0) uniform Light { 
   vec4 position; 
   vec4 color; 
   float intensity; 
} light;

layout(location = 0) in vec4 in_color;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec4 in_position;
layout(location = 3) in vec2 in_uv;

layout(location = 0) out vec4 out_color; 

void main() {
   vec4 texColor = texture(textureSampler, in_uv);
   vec4 lightDir = light.position - in_position;
   float distance = dot(lightDir, lightDir);
   float diff = clamp(dot(in_normal, normalize(-lightDir.xyz)), 0.1, 1.0);
   out_color = in_color * light.color * diff * light.intensity / distance * texColor;
}
