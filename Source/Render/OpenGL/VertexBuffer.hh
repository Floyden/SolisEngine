#pragma once
#include "Defines.hh"

struct VertexBufferDesc {
    uint32_t vertexCount;
    uint32_t vertexSize;
};

class VertexBuffer {
public:
    static SPtr<VertexBuffer> Create(const VertexBufferDesc& vb);

    ~VertexBuffer();

    void ReadData(uint32_t offset, uint32_t length, void* dest);
    void WriteData(uint32_t offset, uint32_t length, const void* src);
    
    uint32_t GetHandle() const { return mHandle; };

private:

    uint32_t mVertexCount;
    uint32_t mVertexSize;
    uint32_t mHandle;
};