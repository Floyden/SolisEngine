#version 450 core

layout(set = 2, binding = 0) uniform sampler2D textureSampler;
layout(set = 2, binding = 1) uniform sampler2D normalSampler;
layout(set = 2, binding = 2) uniform sampler2D metallicSampler; // contains (ao, metalic, roughness)

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
layout(location = 1) in vec4 in_position;
layout(location = 2) in vec2 in_uv;
layout(location = 3) in mat3 in_tbn;

layout(location = 0) out vec4 out_color; 

const vec3 F0 = vec3(0.04);

void main() {
   vec4 base_color = texture(textureSampler, in_uv) * material.color * in_color;
   float metallic = texture(metallicSampler, in_uv).g * material.metallic;
   vec3 diffuse_color = (base_color.rgb * (vec3(1.0) - F0)) * (1.0 - metallic);
   vec3 spec_color = mix(F0, base_color.rgb, metallic);
   vec3 ambient = 0.1 * (diffuse_color * spec_color);

   vec4 light_dir = light.position - in_position;
   float distance = length(light_dir);

   vec3 normal_tex = texture(normalSampler, in_uv).xyz * 2 - 1;
   vec3 normal = normalize(in_tbn * normal_tex);
 
   float diff = clamp(dot(normal, normalize(light_dir.xyz)), 0.1, 1.0);
   float attenuation = light.intensity / (distance * distance);

   vec3 diffuse = diffuse_color * light.color.rgb * attenuation * diff;
   out_color = vec4(diffuse + ambient, base_color.a);
}
