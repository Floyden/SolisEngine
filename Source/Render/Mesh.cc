#include "Mesh.hh"

namespace Solis
{
SPtr<Mesh> Mesh::FromShape(const Shapes::Shape& shape)
{
    SPtr<Mesh> mesh = std::make_shared<Mesh>();


    auto positions = shape.GetPositions();
    mesh->mVertexData = std::make_shared<VertexData>();
    mesh->mVertexData->SetBuffer(0, 
        VertexBuffer::Create(
            VertexBufferDesc{
                static_cast<uint32_t>(positions.size()),
                sizeof(float)
    }));
    mesh->mVertexData->GetBuffer(0)->WriteData(0, positions.size() * sizeof(float), positions.data());

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
        }
    };
    mesh->mAttributes = VertexAttributes::Create(attributeList);

    return mesh;
}

} // namespace Solis
