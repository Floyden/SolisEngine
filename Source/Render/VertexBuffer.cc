#include <iostream>
#include "VertexBuffer.hh"

SPtr<VertexBuffer> VertexBuffer::Create(const VertexBufferDesc& vb) 
{
    SPtr<VertexBuffer> res = std::make_shared<VertexBuffer>();
    res->mVertexCount = vb.vertexCount;
    res->mVertexSize = vb.vertexSize;

    glGenBuffers(1, &res->mHandle);
    if(!res->mHandle){
        std::cout << "Failed to create an OpenGL buffer\n";
        return {};
    }

    glBindBuffer(GL_ARRAY_BUFFER, res->mHandle);
    glBufferData(GL_ARRAY_BUFFER, vb.vertexCount * vb.vertexSize, nullptr, GL_STATIC_DRAW);

    return res;
}

VertexBuffer::~VertexBuffer()
{
    glDeleteBuffers(1, &mHandle);
}

void VertexBuffer::ReadData(uint32_t offset, uint32_t length, void* dest) {
    std::cout << "Not implemented: VertexBuffer::ReadData\n";
}

void VertexBuffer::WriteData(uint32_t offset, uint32_t length, const void* src) {
    // TODO: Proper way with mapping the buffer
    glBindBuffer(GL_ARRAY_BUFFER, mHandle);
    glBufferData(GL_ARRAY_BUFFER, length, src, GL_STATIC_DRAW);

}