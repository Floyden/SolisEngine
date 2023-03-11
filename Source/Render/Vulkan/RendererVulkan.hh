#pragma once
#include "../Common/Renderer.hh"
#include <vulkan/vulkan.hpp>

namespace Solis::Render
{
    
class RendererVulkan : public Renderer
{
public:
    RendererVulkan();
    ~RendererVulkan();

    virtual void Initialize();
    virtual void Destroy();

    virtual void Clear(float r, float g, float b, float a) {};

    virtual void BindVertexAttributes(SPtr<VertexAttributes> attribs)  {};
    virtual void BindVertexBuffers(uint32_t index, const SPtr<VertexBuffer>* vbs, uint32_t bufferCount)  {};
    virtual void BindIndexBuffer(const SPtr<IndexBuffer>& ib)  {};

    virtual void BindProgram(const SPtr<Program>& program)  {};
    virtual void BindTexture(const Texture* texture)  {};

    virtual void Draw(uint32_t vertexCount)  {};
    virtual void DrawIndexed(uint32_t indexCount)  {};
private:
    vk::Instance mInstance;
};

} // namespace Solis::Render
