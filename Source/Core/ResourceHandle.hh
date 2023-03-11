#pragma once
#include "Defines.hh"
#include "Resource.hh"
#include <atomic>

#include <typeindex>
#include <typeinfo>
namespace Solis
{
struct ResourceId {
    size_t id;
    //std::type_index typeId;
};    

template<typename T>
class ResourceHandle
{
    friend class ResourceManager;
    struct ResourceHandleData
    {
        UPtr<Resource> mResource;
        std::atomic<uint32_t> mRefCount{0};
    };

public:
    /// Default Constructor 
    ResourceHandle() = default;

    /// Move Constructor 
    ResourceHandle(ResourceHandle&& other) = default;

    /// Copy Constructor 
    ResourceHandle(const ResourceHandle& other)
    {
        this->mId = other.mId;
        this->mData = other.mData;
        this->Reference();
    }

    ~ResourceHandle() 
    {
        Unreference();
    }

    ResourceHandle(UPtr<T>&& resource) : 
        mId(0)
    {
        this->mData = std::make_unique<ResourceHandleData>();
        this->mData->mResource = std::move(resource);
        this->Reference();
    }


    T* operator->() { return reinterpret_cast<T*>(mData->mResource.get()); }
    T& operator*() { return *reinterpret_cast<T*>(mData->mResource.get()); }
    const T* operator->() const { return reinterpret_cast<T*>(mData->mResource.get()); }
    const T& operator*() const { return *reinterpret_cast<T*>(mData->mResource.get()); }
    operator bool() const { return this->mData != 0; }

    ResourceHandle& operator=(ResourceHandle&& other) 
    {
        if(this == &other)
            return *this;
        
        this->Unreference();
        this->mData = std::exchange(other.mData, nullptr);
        this->mId = other.mId;

        return *this;
    }

    ResourceHandle& operator=(const ResourceHandle& other)
    {
        this->Unreference();
        this->mData = other.mData;
        this->mId = other.mId;
        this->Reference();

        return *this;
    }
private:

    size_t mId;
    SPtr<ResourceHandleData> mData;

    void Reference()
    {
        if(mData)
            mData->mRefCount.fetch_add(1, std::memory_order_relaxed);
    }

    void Unreference()
    {
        if(mData)
            mData->mRefCount.fetch_sub(1, std::memory_order_release);
    }
};
    
} // namespace Solis
