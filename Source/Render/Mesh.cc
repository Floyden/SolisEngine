#include "Mesh.hh"

namespace Solis
{
HMesh Mesh::FromShape(const Shapes::Shape& shape)
{
    UPtr<Mesh> mesh = std::make_unique<Mesh>();


    auto positions = shape.GetPositions();
    auto normals = shape.GetNormals();
    auto uvs = shape.GetUVs();
    mesh->mVertexData = std::make_shared<VertexData>();
    mesh->mVertexData->SetBuffer(0, 
        VertexBuffer::Create(
            VertexBufferDesc{
                static_cast<uint32_t>(positions.size()),
                sizeof(float)
    }));
    mesh->mVertexData->SetBuffer(1, 
        VertexBuffer::Create(
            VertexBufferDesc{
                static_cast<uint32_t>(normals.size()),
                sizeof(float)
    }));
    mesh->mVertexData->SetBuffer(2, 
        VertexBuffer::Create(
            VertexBufferDesc{
                static_cast<uint32_t>(uvs.size()),
                sizeof(float)
    }));
    mesh->mVertexData->GetBuffer(0)->WriteData(0, positions.size() * sizeof(float), positions.data());
    mesh->mVertexData->GetBuffer(1)->WriteData(0, normals.size() * sizeof(float), normals.data());
    mesh->mVertexData->GetBuffer(2)->WriteData(0, uvs.size() * sizeof(float), uvs.data());

    auto indices = shape.GetIndices();
    mesh->mIndexBuffer = IndexBuffer::Create(IndexBufferDesc{static_cast<uint32_t>(indices.size())});
    mesh->mIndexBuffer->WriteData(0, indices.size() * sizeof(size_t), indices.data());

    std::vector<VertexAttribute> attributeList {
        VertexAttribute{
            0,
            3,
            GL_FLOAT,
            GL_FALSE,
            0
        },
        VertexAttribute{
            1,
            3,
            GL_FLOAT,
            GL_FALSE,
            0
        },
        VertexAttribute{
            2,
            2,
            GL_FLOAT,
            GL_FALSE,
            0
        },
    };
    mesh->mAttributes = VertexAttributes::Create(attributeList);

    return HMesh(std::move(mesh));
}

} // namespace Solis
