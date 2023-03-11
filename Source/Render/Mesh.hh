#pragma once
#include "OpenGL/IndexBuffer.hh"
#include "VertexData.hh"
#include "VertexAttributes.hh"
#include "Shapes.hh"
#include "Core/ResourceHandle.hh"

namespace Solis
{
    
class Mesh;
using HMesh = ResourceHandle<Mesh>;

class Mesh : public Resource {
public:
    static Mesh FromShape(const Shapes::Shape& shape);

    SPtr<IndexBuffer> mIndexBuffer;
    SPtr<VertexData> mVertexData;
    SPtr<VertexAttributes> mAttributes;
};

} // namespace Solis