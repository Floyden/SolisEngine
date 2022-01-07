#include "VAOManager.hh"

namespace Solis
{

template<typename T>
void hash_combine(std::size_t& seed, const T& v) 
{
    //Stole the hasher from boost
    std::hash<T> hasher;
    seed ^= hasher(v) + 0x9e3779b9 + (seed<<6) + (seed>>2);
}

::std::size_t VAOManager::VAO::Hash::operator()(const VAO& vao) const
{
    size_t seed = 0;
    hash_combine(seed, vao.mProgramHandle);

    for (size_t i = 0; i < vao.mBufferCount; i++)
        hash_combine(seed, vao.mVertexBuffers[i]);
    
    return seed;
}
/*
bool VAOManager::VAO::Equal::operator()(const VAO &a, const VAO &b) const
{
    if(a.mProgramHandle != b.mProgramHandle)
        return false;        

    if(a.mBufferCount != b.mBufferCount)
        return false;

    for (size_t i = 0; i < b.mBufferCount; i++)
    {
        if(a.mVertexBuffers[i]->GetHandle() != b.mVertexBuffers[i]->GetHandle())
            return false;
    }
    
    return true;
}*/

bool VAOManager::VAO::operator==(const VAO& other) const
{
    if(other.mProgramHandle != mProgramHandle)
        return false;        

    if(other.mBufferCount != mBufferCount)
        return false;

    for (size_t i = 0; i < mBufferCount; i++)
    {
        if(other.mVertexBuffers[i]->GetHandle() != mVertexBuffers[i]->GetHandle())
            return false;
    }
    
    return true;
}

bool VAOManager::VAO::operator!=(const VAO& other) const
{
    return !operator==(other);
}

uint32_t VAOManager::GetVao(const SPtr<Program>& vertexProgram, 
    const SPtr<VertexAttributes>& attributes, const std::array<SPtr<VertexBuffer>, MAX_VB_COUNT>& buffers) 
{
    // Try to find an existing VAO
    uint32_t numBuffersUsed = 0;
    int32_t indexer[MAX_VB_COUNT];
    VertexBuffer* usedBuffers[MAX_VB_COUNT];

    for (size_t i = 0; i < MAX_VB_COUNT; i++)
    {
        indexer[i] = -1;
        usedBuffers[i] = 0;
    }
    
    for(auto& attr: attributes->GetAttributes()) 
    {
        auto loc = attr.location;
        if(loc >= MAX_VB_COUNT) {
            std::cout << "VAOManager: Passed invalid location in attributes" << std::endl;
            continue;
        }

        // already visited
        if(indexer[loc] != -1)
            continue;

        indexer[loc] = numBuffersUsed;
        usedBuffers[numBuffersUsed] = buffers[loc].get();
        numBuffersUsed++;
    }

    VAOManager::VAO expectedVAO{0, vertexProgram->GetHandle(), usedBuffers, numBuffersUsed};

    auto iter = mObjects.find(expectedVAO);
    if(iter != mObjects.end()){
        return iter->mHandle;
    }

    // Create a new VAO

    glGenVertexArrays(1, &expectedVAO.mHandle);
    glBindVertexArray(expectedVAO.mHandle);

    for (auto& attr: attributes->GetAttributes())
    {
        glEnableVertexAttribArray(attr.location);
        glBindBuffer(GL_ARRAY_BUFFER, buffers[attr.location]->GetHandle());
        glVertexAttribPointer(attr.location, attr.typeCount, attr.type, attr.normalized, attr.stride, (void*)0);
    }

    auto it = mObjects.insert(expectedVAO);

    return it.first->mHandle;
}

} // namespace Solis