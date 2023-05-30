#include <iostream>
#include "UniformBuffer.hh"

SPtr<UniformBuffer> UniformBuffer::Create(uint32_t size) 
{
    SPtr<UniformBuffer> res = std::make_shared<UniformBuffer>();

    glGenBuffers(1, &res->mHandle);
    if(!res->mHandle){
        std::cout << "Failed to create an OpenGL buffer\n";
        return {};
    }
    res->mSize = size;

    glBindBuffer(GL_UNIFORM_BUFFER, res->mHandle);
    glBufferData(GL_UNIFORM_BUFFER, size, nullptr, GL_STATIC_DRAW);

    return res;
}

UniformBuffer::~UniformBuffer()
{
    glDeleteBuffers(1, &mHandle);
}

void UniformBuffer::ReadData(uint32_t offset, uint32_t length, void* dest) {
    std::cout << "Not implemented: UniformBuffer::ReadData\n";
}

void UniformBuffer::WriteData(uint32_t offset, uint32_t length, const void* src) {
    // TODO: Proper way with mapping the buffer
    glBindBuffer(GL_UNIFORM_BUFFER, mHandle);
    glBufferSubData(GL_UNIFORM_BUFFER, offset, length, src);

}