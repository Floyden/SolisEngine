#pragma once
#include <cstdint>
#include <vector>
#include "Math.hh"

namespace Solis
{

static const std::vector<float> gTriangleData = {
    -1.0f, -1.0f, 0.0f,
    1.0f, -1.0f, 0.0f,
    0.0f,  1.0f, 0.0f
};

static const std::vector<float> gTriangleData2 = {
    -1.0f, 1.0f,
    0.0f,  -1.0f,
    1.0f, 1.0f,
};

static const std::vector<uint32_t> gTriangleIdx = {
    1, 0, 2
};

static const std::vector<float> gQuadData = {
    -0.5f, 0.5f, 0.0f,
    0.5f, 0.5f, 0.0f,
    0.5f, -0.5f, 0.0f,
    -0.5f, -0.5f, 0.0f,
};

static const std::vector<float> gQuadData2 = {
    -1.0f, 1.0f, 0.0f,
    -1.0f, -1.0f, 0.0f,
    1.0f,  -1.0f, 0.0f,
    -1.0f,  1.0f, 0.0f,
    1.0f, -1.0f, 0.0f,
    1.0f,  1.0f, 0.0f,
};

static const std::vector<float> gQuadUV = {
    0.0f, 0.0f,
    1.0f, 0.0f,
    1.0f, 1.0f,
    0.0f, 1.0f, 
};

static const std::vector<float> gQuadColor = {
    0.0f, 0.0f, 1.0f,
    1.0f, 0.0f, 0.0f,
    1.0f, 1.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
};

static const std::vector<float> gQuadNormal = {
    0.0f, 1.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
    0.0f, 1.0f, 0.0f,
};

static const std::vector<uint32_t> gQuadDataIdx = {
    0, 1, 2,
    0, 2, 3 
};

static const std::vector<float> gCubeData = {
    0.0f, 0.0f, 0.0f, 
    1.0f, 0.0f, 0.0f, 
    0.0f, 1.0f, 0.0f, 
    1.0f, 1.0f, 0.0f, 
    0.0f, 0.0f, 1.0f, 
    1.0f, 0.0f, 1.0f, 
    0.0f, 1.0f, 1.0f, 
    1.0f, 1.0f, 1.0f, 

};

static const std::vector<uint32_t> gCubeDataIdx = {
    0, 1, 2, 
    0, 1, 2, 
    0, 1, 2, 
    0, 1, 2, 
    0, 1, 2, 
    0, 1, 2,
    0, 1, 2, 
    0, 1, 2, 
    0, 1, 2, 
    0, 1, 2, 
    0, 1, 2, 
    0, 1, 2, 
};

static const Vec3 gBlack(0.0f);
static const Vec3 gWhite(1.0f);
static const Vec3 gBrown(0.48f, 0.24f, 0.0f);
static const Vec3 gBeige(0.996f, 0.988f, 0.813f);

static std::vector<uint8_t> gLevel = {
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 1, 1, 1, 0, 1, 1, 0,
    0, 0, 0, 1, 0, 0, 1, 0,
    0, 0, 0, 1, 1, 1, 1, 0,
    0, 0, 1, 1, 0, 1, 0, 0,
    0, 1, 1, 0, 0, 1, 1, 0,
    0, 0, 1, 1, 0, 0, 1, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
};

static const char* gVertexShaderSource =
    "#version 410 core\n" 
    "uniform mat4 uMVP;\n"
    "layout(location = 0) in vec3 inPos;\n" 
    "layout(location = 1) in vec2 inUV;\n" 
    "layout(location = 2) in vec3 inNormal;\n" 
    "out vec2 uvs;\n"
    "out vec3 normal;\n"
    "void main() {\n"
    "   gl_Position = uMVP * vec4(inPos, 1.0);\n" 
    "   uvs = inUV;\n"
    "   normal = (inNormal + 1.0) / 2.0;\n"
    "}"; 

static const char* gFragmentShaderSource =
    "#version 410 core\n" 
    "uniform sampler2D uSampler;"
    "in vec2 uvs;"
    "in vec3 normal;\n"
    "layout(location = 0) out vec3 color;" 
    "layout(location = 1) out vec3 normalOut;" 
    "void main() {"
    "   vec4 tex = texture(uSampler, uvs);"
    "   color = tex.rgb;"
    "   normalOut = normal;"
    "}";

static const char* gBasicVertexShaderSource =
    "#version 330 core\n" 
    "layout(location = 0) in vec3 inPos;\n" 
    "void main() {\n"
    "   gl_Position = vec4(inPos, 1.0);\n" 
    "}"; 

static const char* gBasicFragmentShaderSource =
    "#version 330 core\n" 
    "out vec4 color;"
    "void main() {\n"
    "   color = vec4(1.0, 1.0, 1.0, 1.0);"
    "}"; 

//TODO: instance this
static const char* gLightVShaderSource =
    "#version 410 core\n" 
    "out vec3 uPos;\n"
    "void main() {\n"
    "   gl_Position = vec4(uPos, 1.0);\n" 
    "   uvs = inUV;\n"
    "   normal = (inNormal + 1.0) / 2.0;\n"
    "}"; 

static const char* gLightFShaderSource =
    "#version 410 core\n" 
    "uniform sampler2D uSampler;"
    "in vec2 uvs;"
    "in vec3 normal;\n"
    "layout(location = 0) out vec3 color;" 
    "layout(location = 1) out vec3 normalOut;" 
    "void main() {"
    "   vec4 tex = texture(uSampler, uvs);"
    "   color = tex.rgb;"
    "   normalOut = normal;"
    "}";
    
static const char* gPassthroughShaderSource = 
    "#version 410 core\n" 
    "layout(location = 0) in vec3 pos;"
    "out vec2 uv;"
    "void main() {"
    "   gl_Position = vec4(pos, 1);"
    "   uv = (pos.xy+vec2(1,1))/2.0;"
    "}";

static const char* gImageShaderSource = 
    "#version 410 core\n" 
    "in vec2 uv;"
    "out vec3 color;"
    "uniform sampler2D uAlbedo;" 
    "uniform sampler2D uNormal;" 
    "uniform sampler2D uDepth;"
    "" 
    "uniform mat4 uInvProj;"
    "uniform mat4 uInvView;"
    ""
    "uniform vec3 uLightPos;"
    "uniform vec4 uLightColor;"
    "uniform float uLightBrightness;"
    "uniform float uLightRadius;"
    ""
    "const float PI = 3.14159265358979323846;"
    ""
    "vec3 WorldPosFromDepth(float depth) {"
    "   float z = depth * 2.0 - 1.0;"
    "   vec4 clipSpace = vec4(uv * 2.0 - 1.0, z, 1.0);"
    "   vec4 viewSpace = uInvProj * clipSpace;"
    "   viewSpace /= viewSpace.w;"
    "   vec4 worldSpace = uInvView * viewSpace;"
    "   return worldSpace.xyz;"
    "}"
    ""
    "void main() {"
    "   vec3 pos = WorldPosFromDepth(texture(uDepth, uv).r);"
    "   float distance = length(uLightPos - pos.xyz);"
    "   float falloff = pow(clamp(1.0 - pow(distance / uLightRadius, 4.0), 0.0, 1.0), 2.0) / (pow(distance, 2) + 1.0);"
    //"   float falloff = 1 / pow(distance, 2);"
    ""
    "   vec3 N = (texture(uNormal, uv).xyz - 0.5) * 2.0;"
    "   vec3 L = normalize(uLightPos - pos.xyz);"
    "   vec3 E = normalize(-pos);"
    "   float NdotL = clamp(dot(N, L), 0.0, 1.0);"
    ""
    "   vec3 diffuse = texture(uAlbedo, uv).rgb * uLightBrightness * uLightColor.rgb * falloff * NdotL;"
    //"   color = texture2D(uAlbedo, uv).rgb * uLightBrightness * falloff * uLightColor.rgb;"
    "   float specularFactor = max(0.0, dot(normalize(L + E), N));"
    "   vec3 specular = max(pow(specularFactor, 0.8), 0.0) * falloff * vec3(0.0, 1.0, 0.0);"
    "   color = diffuse * 0.2 + specular * 5.0;"
    "}";
} // namespace Solis