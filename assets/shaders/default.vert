#version 450 core

layout(set = 1, binding = 0) uniform UBO { 
   mat4 modelViewProj; 
   mat4 model; 
} ubo;

layout(location = 0) in vec3 in_position;
layout(location = 1) in vec3 in_color;
layout(location = 2) in vec3 in_normal;
layout(location = 3) in vec2 in_uv;
layout(location = 4) in vec4 in_tangent;

layout(location = 0) out vec4 out_color; 
layout(location = 1) out vec4 out_position;
layout(location = 2) out vec2 out_uv;
layout(location = 3) out mat3 out_tbn;

void main() {
   vec3 normal = normalize(mat3(ubo.model) * in_normal);
   vec3 tangent = normalize(mat3(ubo.model) * in_tangent.xyz);
   vec3 bitangent = cross(normal, tangent) * in_tangent.w;
   out_tbn = mat3(
      tangent,
      bitangent,
      normal
   );

   out_color = vec4(in_color, 1.0);
   out_position = ubo.model * vec4(in_position, 1.0);
   out_uv = in_uv;
   gl_Position = ubo.modelViewProj * vec4(in_position, 1.0);
}
