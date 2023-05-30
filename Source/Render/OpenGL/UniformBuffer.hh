#pragma once
#include "Defines.hh"

class UniformBuffer {
public:
    static SPtr<UniformBuffer> Create(uint32_t size);

    ~UniformBuffer();

    void ReadData(uint32_t offset, uint32_t length, void* dest);
    void WriteData(uint32_t offset, uint32_t length, const void* src);
    
    uint32_t GetHandle() const { return mHandle; };
    uint32_t Size() const { return mSize; };

private:
    uint32_t mHandle;
    uint32_t mSize;
};