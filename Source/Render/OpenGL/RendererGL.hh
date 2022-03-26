#pragma once
#include <array>
#include "../Common/Renderer.hh"
#include "VertexBuffer.hh"
#include "IndexBuffer.hh"
#include "../VertexAttributes.hh"
#include "../Program.hh"
#include "../Texture.hh"

namespace Solis
{

static const uint32_t MAX_VB_COUNT = 8;

class RendererGL : public Render::Renderer {
public:
    RendererGL();
    ~RendererGL();

    virtual void Initialize();
    virtual void Destroy();

    void Clear(float r, float g, float b, float a);

    void BindVertexAttributes(SPtr<VertexAttributes> attribs);
    void BindVertexBuffers(uint32_t index, const SPtr<VertexBuffer>* vbs, uint32_t bufferCount);
    void BindIndexBuffer(const SPtr<IndexBuffer>& ib);

    void BindProgram(const SPtr<Program>& program);
    void BindTexture(const HTexture& texture);

    void Draw(uint32_t vertexCount);
    void DrawIndexed(uint32_t indexCount);

private:

    SPtr<Program> mBoundProgram;
    SPtr<VertexAttributes> mBoundAttributes;
    std::array<SPtr<VertexBuffer>, MAX_VB_COUNT> mBoundBuffers;
    SPtr<IndexBuffer> mBoundIndexBuffer;

};

} // namespace Solis