#pragma once
#include "Defines.hh"

class UniformBuffer {
public:
    static SPtr<UniformBuffer> Create(uint32_t size);

    ~UniformBuffer();

    void ReadData(uint32_t offset, uint32_t length, void* dest);
    void WriteData(uint32_t offset, uint32_t length, const void* src);
    
    uint32_t GetHandle() const { return mHandle; };

private:

    uint32_t mHandle;
};