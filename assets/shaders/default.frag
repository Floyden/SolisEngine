#version 450 core

layout(set = 2, binding = 0) uniform sampler2D textureSampler;
layout(set = 2, binding = 1) uniform sampler2D normalSampler;
layout(set = 2, binding = 2) uniform sampler2D metallicSampler;

layout(set = 3, binding = 0) uniform MaterialValues {
   vec4 color;
   float metallic;
} material; 

layout(set = 3, binding = 1) uniform Light { 
   vec4 position; 
   vec4 color; 
   float intensity; 
} light;

layout(location = 0) in vec4 in_color;
layout(location = 1) in vec3 in_normal;
layout(location = 2) in vec4 in_position;
layout(location = 3) in vec2 in_uv;

layout(location = 0) out vec4 out_color; 

const vec3 F0 = vec3(0.04);

void main() {
   vec4 base_color = texture(textureSampler, in_uv) * material.color * in_color;
   float metallic = texture(metallicSampler, in_uv).g * material.metallic;
   vec3 diffuse_color = (base_color.rgb * (vec3(1.0) - F0)) * (1.0 - metallic);
   vec3 spec_color = mix(F0, base_color.rgb, metallic);
   vec4 ambient = vec4(diffuse_color + spec_color, 1.0);


   vec4 light_dir = light.position - in_position;
   float distance = dot(light_dir, light_dir);
   vec3 normal = texture(normalSampler, in_uv).rgb * in_normal;
   float diff = clamp(dot(normal, normalize(-light_dir.xyz)), 0.1, 1.0);
   out_color = base_color * ambient * light.color * diff * light.intensity / distance;
}
