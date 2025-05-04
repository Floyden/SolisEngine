#version 450 core

const int LIGHT_TYPE_POINT = 0;
const int LIGHT_TYPE_DIRECTIONAL = 1;
const int LIGHT_TYPE_SPOT = 2;

struct Light {
   vec4 position;
   vec4 direction;
   vec4 color;
   int type;
   float intensity;
   vec2 _pad;
};

layout(set = 2, binding = 0) uniform sampler2D textureSampler;
layout(set = 2, binding = 1) uniform sampler2D normalSampler;
layout(set = 2, binding = 2) uniform sampler2D metallicSampler; // contains (ao, metalic, roughness)
layout(std430, set = 2, binding = 3) buffer Lights {
   Light lights[];
};

layout(set = 3, binding = 0) uniform MaterialValues {
   vec4 color;
   float metallic;
} material; 

layout(location = 0) in vec4 in_color;
layout(location = 1) in vec4 in_position;
layout(location = 2) in vec2 in_uv;
layout(location = 3) in mat3 in_tbn;

layout(location = 0) out vec4 out_color; 

const vec3 F0 = vec3(0.04);

vec3 calculateLight(Light light, vec3 normal) {
   vec4 result;
   if (light.type == LIGHT_TYPE_POINT) {
      vec4 light_dir = light.position - in_position;
      float distance = length(light_dir);

      float diff = clamp(dot(normal, normalize(light_dir.xyz)), 0.0, 1.0);
      float attenuation = light.intensity / (distance * distance);
      result = light.color * attenuation * diff;
   } else 
      if(light.type == LIGHT_TYPE_DIRECTIONAL) {
      vec3 light_dir = normalize(-light.direction.xyz);
      float diff = clamp(dot(normal, light_dir), 0.0, 1.0);
      result = light.color * diff * light.intensity;
   } 
   return result.xyz;
}

void main() {
   vec4 base_color = texture(textureSampler, in_uv) * material.color * in_color;
   float metallic = texture(metallicSampler, in_uv).g * material.metallic;
   vec3 normal_tex = texture(normalSampler, in_uv).xyz * 2 - 1;
   vec3 diffuse_color = (base_color.rgb * (vec3(1.0) - F0)) * (1.0 - metallic);
   vec3 spec_color = mix(F0, base_color.rgb, metallic);
   vec3 ambient = 0.1 * (diffuse_color * spec_color);

   vec3 normal = normalize(in_tbn * normal_tex);

   vec3 light = vec3(0) ;
   for(int i = 0; i < lights.length(); ++i)
      light += calculateLight(lights[i], normal).xyz;
   vec3 diffuse = diffuse_color * light;
   out_color = vec4(diffuse + ambient, base_color.a);
}
