#pragma once
#include "RendererGL.hh"
#include "../Program.hh"
#include "../VertexAttributes.hh"
#include "Module.hh"

namespace Solis
{

class VAOManager : public IModule
{
public:
    uint32_t GetVao(const Program* vertexProgram, const SPtr<VertexAttributes>& attr, 
                    const std::array<SPtr<VertexBuffer>, MAX_VB_COUNT>& buffers);
private:
    struct VAO {
        uint32_t mHandle;
        uint32_t mProgramHandle;
        VertexBuffer** mVertexBuffers;
        uint32_t mBufferCount;

        struct Hash
        {
            ::std::size_t operator()(const VAO& vao) const;
        };

        struct Equal
        {
            bool operator()(const VAO &a, const VAO &b) const { return a == b; }
        };

        bool operator==(const VAO& other) const;
        bool operator!=(const VAO& other) const;
    };

    UnorderedSet<VAO, VAO::Hash, VAO::Equal> mObjects;
};

} // namespace Solis