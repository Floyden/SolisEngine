#pragma once
#include "Defines.hh"

struct IndexBufferDesc {
    uint32_t indexCount;
};

class IndexBuffer {
public:
    static SPtr<IndexBuffer> Create(const IndexBufferDesc& vb);

    ~IndexBuffer();

    void ReadData(uint32_t offset, uint32_t length, void* dest);
    void WriteData(uint32_t offset, uint32_t length, const void* src);
    
    uint32_t GetHandle() const { return mHandle; };
    uint32_t GetIndexCount() const { return mIndexCount; }

private:

    uint32_t mIndexCount;
    uint32_t mHandle;
};