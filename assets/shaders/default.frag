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
layout(set = 2, binding = 3) uniform samplerCube enviromentSampler; 
layout(std430, set = 2, binding = 4) buffer Lights {
   Light lights[];
};

layout(set = 3, binding = 0) uniform MaterialValues {
   vec4 color;
   float metallic;
   float roughness;
} material; 

layout(location = 0) in vec4 in_color;
layout(location = 1) in vec4 in_world_position;
layout(location = 2) in vec4 in_view_position;
layout(location = 3) in vec2 in_uv;
layout(location = 4) in mat3 in_tbn;

layout(location = 0) out vec4 out_color; 

const float PI = 3.141592653589793;
const vec3 F0 = vec3(0.04);

struct LightParameters {
   vec3 diffuse_color;
   vec3 specular_color;
   vec3 normal;
   vec3 view_dir;
   float roughness;
   float n_dot_vdir;
};

vec3 specularReflection(float cos_theta, vec3 f0) {
   //Fresnel-Schlick approximation
   return f0 + (vec3(1.0) - f0) * pow(1.0 - cos_theta, 5.0);
}

vec3 specularReflectionRoughness(float cos_theta, vec3 f0, float roughness) {
   //Fresnel-Schlick approximation
   return f0 + (vec3(1.0 - roughness) - f0) * pow(1.0 - cos_theta, 5.0);
}

// Returns (dir, distance)
vec4 lightDirection(Light light) {
   vec4 light_dir = vec4(0);
   if (light.type == LIGHT_TYPE_POINT) {
      vec3 dir = (light.position - in_world_position).xyz;
      light_dir = vec4(normalize(dir), length(dir.xyz));
   } else if (light.type == LIGHT_TYPE_DIRECTIONAL) {
      light_dir = vec4(normalize(-light.direction.xyz), 0.0);
   }

   return light_dir;
}

vec3 calculateLight(Light light, LightParameters parameters) {
   vec3 result;
   vec4 light_dir = lightDirection(light);
   float attenuation = light.intensity;
   if(light_dir.w > 1.0)
      attenuation *= (1.0 / (light_dir.w * light_dir.w));

   vec3 half_dir = normalize(light_dir.xyz + parameters.view_dir);
   float n_dot_ldir = clamp(dot(parameters.normal, light_dir.xyz), 0.0, 1.0);
   float vdir_dot_hdir = clamp(dot(parameters.view_dir, half_dir), 0.0, 1.0);

   vec3 diffuse_contrib = parameters.diffuse_color * (1.0 / PI);
   vec3 specular_contrib = specularReflection(vdir_dot_hdir, parameters.specular_color);

   result = light.color.xyz * (diffuse_contrib + specular_contrib) * n_dot_ldir * attenuation;
   return result;
}

void main() {
   vec4 base_color = texture(textureSampler, in_uv) * material.color * in_color;
   float metallic = texture(metallicSampler, in_uv).g * material.metallic;
   float roughness = texture(metallicSampler, in_uv).b * material.roughness;
   vec3 normal_tex = texture(normalSampler, in_uv).xyz * 2 - 1;
   vec3 diffuse_color = (base_color.rgb * (vec3(1.0) - F0)) * (1.0 - metallic);
   vec3 spec_color = mix(F0, base_color.rgb, metallic);

   vec3 normal = normalize(in_tbn * normal_tex);

   LightParameters parameters;
   parameters.diffuse_color = diffuse_color;
   parameters.specular_color = spec_color;
   parameters.normal = normal;
   parameters.view_dir = normalize(-in_view_position.xyz);
   parameters.roughness = roughness;
   parameters.n_dot_vdir = clamp(dot(parameters.normal, parameters.view_dir.xyz), 0.0, 1.0);

   vec3 light = vec3(0) ;
   for(int i = 0; i < lights.length(); ++i)
      light += calculateLight(lights[i], parameters);
   out_color = vec4(light, base_color.a);

   // Indirect
   vec3 id_specular = specularReflectionRoughness(parameters.n_dot_vdir, spec_color, roughness);
   vec3 envDir = normalize(reflect(parameters.view_dir, normal));
   envDir.xy *= -1.0; // Vulkan coordinate system 
   vec3 id_env_color = texture(enviromentSampler, envDir).rgb;

   vec3 id_kd = (1.0 - id_specular) * (1.0 - metallic);

   out_color.xyz += id_env_color * id_specular + id_kd * base_color.rgb * (1.0 / PI);
}
