#pragma once
#include "Defines.hh"
#include "../VertexAttributes.hh"
#include "../OpenGL/IndexBuffer.hh"
#include "../OpenGL/VertexBuffer.hh"
#include "../Program.hh"
#include "../Texture.hh"

namespace Solis::Render
{

class Renderer {
public:
    Renderer() {};
    virtual ~Renderer() {};

    virtual void Initialize() = 0;
    virtual void Destroy() = 0;

    virtual void Clear(float r, float g, float b, float a) = 0;

    virtual void BindVertexAttributes(SPtr<VertexAttributes> attribs) = 0;
    virtual void BindVertexBuffers(uint32_t index, const SPtr<VertexBuffer>* vbs, uint32_t bufferCount) = 0;
    virtual void BindIndexBuffer(const SPtr<IndexBuffer>& ib) = 0;

    virtual void BindProgram(const SPtr<Program>& program) = 0;
    virtual void BindTexture(const HTexture& texture) = 0;

    virtual void Draw(uint32_t vertexCount) = 0;
    virtual void DrawIndexed(uint32_t indexCount) = 0;
};

} // namespace Solis