#pragma once
#include "IndexBuffer.hh"
#include "VertexData.hh"
#include "VertexAttributes.hh"
#include "Shapes.hh"

namespace Solis
{
    
class Mesh {
public:
    static SPtr<Mesh> FromShape(const Shapes::Shape& shape);

    SPtr<IndexBuffer> mIndexBuffer;
    SPtr<VertexData> mVertexData;
    SPtr<VertexAttributes> mAttributes;
};

} // namespace Solis