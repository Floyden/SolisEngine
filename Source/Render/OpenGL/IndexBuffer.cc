#include <iostream>
#include "IndexBuffer.hh"

SPtr<IndexBuffer> IndexBuffer::Create(const IndexBufferDesc& ib) 
{
    SPtr<IndexBuffer> res = std::make_shared<IndexBuffer>();
    res->mIndexCount = ib.indexCount;

    glGenBuffers(1, &res->mHandle);
    if(!res->mHandle){
        std::cout << "Failed to create an OpenGL buffer\n";
        return {};
    }

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, res->mHandle);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, ib.indexCount * sizeof(uint32_t), nullptr, GL_STATIC_DRAW);

    return res;
}

IndexBuffer::~IndexBuffer()
{
    glDeleteBuffers(1, &mHandle);
}

void IndexBuffer::ReadData(uint32_t offset, uint32_t length, void* dest) {
    std::cout << "Not implemented: VertexBuffer::ReadData\n";
}

void IndexBuffer::WriteData(uint32_t offset, uint32_t length, const void* src) {
    // TODO: Proper way with mapping the buffer
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, length, src, GL_STATIC_DRAW);

}