#pragma once
#include "OpenGL/VertexBuffer.hh"

class VertexData {
public:
    VertexData() = default;
    ~VertexData() = default;

    void SetBuffer(uint32_t index, SPtr<VertexBuffer> buffer);
    SPtr<VertexBuffer> GetBuffer(uint32_t index) const;

    uint32_t GetBufferCount() const;

private:
    UnorderedMap<uint32_t, SPtr<VertexBuffer>> mVertexBuffers;
};
