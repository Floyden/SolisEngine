#version 450 core

layout(set = 2, binding = 0) uniform sampler2D textureSampler;
layout(set = 2, binding = 1) uniform sampler2D normalSampler;
layout(set = 2, binding = 2) uniform sampler2D metallicSampler; // contains (ao, metalic, roughness)

layout(set = 3, binding = 0) uniform MaterialValues {
   vec4 color;
   float metallic;
} material; 

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

layout(set = 3, binding = 1) uniform Lights {
   Light lights[256];
   int numLights;
};

layout(location = 0) in vec4 in_color;
layout(location = 1) in vec4 in_position;
layout(location = 2) in vec2 in_uv;
layout(location = 3) in mat3 in_tbn;

layout(location = 0) out vec4 out_color; 

const vec3 F0 = vec3(0.04);

vec3 calculateLight(Light light, vec3 normal) {
   vec4 result;
   if (light.type == LIGHT_TYPE_POINT) {
      vec4 light_dir = lights[0].position - in_position;
      float distance = length(light_dir);

      float diff = clamp(dot(normal, normalize(light_dir.xyz)), 0.0, 1.0);
      float attenuation = lights[0].intensity / (distance * distance);
      result = lights[0].color * attenuation * diff;
   } else if(light.type == LIGHT_TYPE_DIRECTIONAL) {
      vec4 light_dir = normalize(-lights[0].position);
      float diff = clamp(dot(normal, normalize(light_dir.xyz)), 0.0, 1.0);
      result = light.color * diff * light.intensity;
   }
   return result.xyz;
}

void main() {
   vec4 base_color = texture(textureSampler, in_uv) * material.color * in_color;
   float metallic = texture(metallicSampler, in_uv).g * material.metallic;
   vec3 diffuse_color = (base_color.rgb * (vec3(1.0) - F0)) * (1.0 - metallic);
   vec3 spec_color = mix(F0, base_color.rgb, metallic);
   vec3 ambient = 0.1 * (diffuse_color * spec_color);

   vec3 normal_tex = texture(normalSampler, in_uv).xyz * 2 - 1;
   vec3 normal = normalize(in_tbn * normal_tex);
 
   vec3 diffuse = diffuse_color * calculateLight(lights[0], normal).xyz;
   out_color = vec4(diffuse + ambient, base_color.a);
}
