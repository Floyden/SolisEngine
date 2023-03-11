#include "AssimpImporter.hh"
#include "Defines.hh"
#include <assimp/Importer.hpp> 
#include <assimp/scene.h> 
#include <assimp/postprocess.h> 
#include <assimp/DefaultLogger.hpp> 
#include <cstddef>
#include "Render/OpenGL/IndexBuffer.hh"
#include "Render/VertexAttributes.hh"
#include "Render/OpenGL/VertexBuffer.hh"
#include "Render/VertexData.hh"
#include "Core/ResourceManger.hh"

namespace Solis
{
using namespace Assimp;

AssimpImporter::AssimpImporter()
{
    DefaultLogger::create("", Logger::VERBOSE);
    DefaultLogger::get()
        ->attachStream(new AssimpLogStream(), /*Assimp::Logger::Info |*/ Assimp::Logger::Err | Assimp::Logger::Warn);
}

AssimpImporter::~AssimpImporter()
{
    DefaultLogger::kill();
}

SPtr<Node> AssimpImporter::ImportScene(const String& path)
{
    Importer importer;
    const aiScene* scene = importer.ReadFile(path, 
        aiProcess_CalcTangentSpace);

/*
    std::cout 
        << "num animations: " << scene->mNumAnimations
        << ", num cameras: " << scene->mNumCameras
        << ", num lights: " << scene->mNumLights
        << ", num materials: " << scene->mNumMaterials
        << ", num meshes: " << scene->mNumMeshes
        << ", num textures: " << scene->mNumTextures << std::endl;
*/
    return nullptr;
}

HMesh AssimpImporter::ImportMesh(const String& path)
{
    Importer importer;
    const aiScene* scene = importer.ReadFile(path, 
        aiProcess_CalcTangentSpace | aiProcess_GenNormals);
    
    if(!scene->mNumMeshes)
        return HMesh();

    const aiMesh* ai_mesh = scene->mMeshes[0];

    Vector<uint32_t> indices(ai_mesh->mNumFaces * ai_mesh->mFaces[0].mNumIndices);
    Vector<Vec3> positions(ai_mesh->mNumVertices);
    Vector<Vec2> uvs(ai_mesh->mNumVertices);
    //std::vector<Vec3> colors(ai_mesh->mNumVertices);
    std::vector<Vec3> normals(ai_mesh->mNumVertices);

    bool hasUVs = ai_mesh->HasTextureCoords(0);
    //bool hasColor = ai_mesh->HasVertexColors(0);
    bool hasNormals = ai_mesh->HasNormals();
    
    for(size_t i = 0; i < ai_mesh->mNumVertices; i++)
    {
        auto pos = ai_mesh->mVertices[i];
        // TODO:  z and y are somehow flipped
        positions[i] = Vec3(pos.x, pos.z, pos.y);

        if(hasUVs)
        {
            auto& uv = ai_mesh->mTextureCoords[0][i];
            uvs[i] = Vec2(uv.x, uv.y);
        }
        if(hasNormals)
        {
            auto& normal = ai_mesh->mNormals[i];
            normals[i] = Vec3(normal.x, normal.y, normal.z);
        }
    }

    //TODO: this only works if mNumIndices stays the same
    for(size_t i = 0; i < ai_mesh->mNumFaces; i++)
    {
        auto& face = ai_mesh->mFaces[i];
        for(size_t j = 0; j < face.mNumIndices; j++)
        {
            indices[i * face.mNumIndices + j] = face.mIndices[j];
        }
    }

    Mesh mesh;

    Vector<VertexAttribute> attributes;
    attributes.push_back(VertexAttribute{0, 3, 0x1406, 0, 0});
    if(hasUVs)
        attributes.push_back(VertexAttribute{1, 2, 0x1406, 0, 0});
    if(hasNormals)
        attributes.push_back(VertexAttribute{2, 3, 0x1406, 0, 0});

    mesh.mAttributes = VertexAttributes::Create(attributes);
    mesh.mVertexData = std::make_shared<VertexData>();

    auto posBuffer = VertexBuffer::Create({ai_mesh->mNumVertices * 3, sizeof(float)});
    posBuffer->WriteData(0, positions.size() * sizeof(positions[0]), positions.data());
    mesh.mVertexData->SetBuffer(0, posBuffer);

    if (hasUVs) 
    {
        auto uvBuffer = VertexBuffer::Create({ai_mesh->mNumVertices * 2, sizeof(float)});
        uvBuffer->WriteData(0, uvs.size() * sizeof(uvs[0]), uvs.data());
        mesh.mVertexData->SetBuffer(1, uvBuffer);
    }
    if (hasNormals)
    {
        auto normalBuffer = VertexBuffer::Create({ai_mesh->mNumVertices * 3, sizeof(float)});
        normalBuffer->WriteData(0, normals.size() * sizeof(normals[0]), normals.data());
        mesh.mVertexData->SetBuffer(2, normalBuffer);
    }

    mesh.mIndexBuffer = IndexBuffer::Create({static_cast<uint32_t>(indices.size())});
    mesh.mIndexBuffer->WriteData(0, indices.size() * sizeof(uint32_t), indices.data());

    HMesh handle = ModuleManager::Get()->GetModule<ResourceManager>()->Add<Mesh>(mesh);
    return handle;
}

} //namespace Solis
