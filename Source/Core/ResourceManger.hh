#pragma once
#include "Resource.hh"
#include "ResourceHandle.hh"
#include "Module.hh"
#include <random>


namespace Solis 
{

class ResourceManager : public IModule 
{
public:
    ResourceManager() : rng(std::random_device()())  {}

    template<class T>
    ResourceHandle<T> Add(T&& resource) 
    {   
        std::uniform_int_distribution<uint_fast64_t> dist;
        size_t rId = static_cast<size_t>(dist(rng));
        mResourceMap[rId] = std::make_unique<T>(std::forward<T>(resource));

        ResourceHandle<T> handle;
        handle.mId = rId;

        return handle;
    }

    template<class T>
    T* Get(const ResourceHandle<T>& handle) 
    {   
        if(mResourceMap.count(handle.mId))
            return static_cast<T*>(mResourceMap[handle.mId].get());

        return nullptr;
    }

private:
    // <ComponentType, List of components>
    Map<size_t, UPtr<Resource>> mResourceMap;
    std::mt19937 rng;
};

}
