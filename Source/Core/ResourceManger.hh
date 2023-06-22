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

    /**
     * Add a Resource to the ResourceManager, taking ownership of it. A ResourceHandle for the object is returned.
    */
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
    
    /**
     * Construct and add a Resource to the ResourceManager. A ResourceHandle for the object is returned.
    */
    template<class T, typename... Args>
    ResourceHandle<T> Add(Args&&... resource) 
    {   
        std::uniform_int_distribution<uint_fast64_t> dist;
        size_t rId = static_cast<size_t>(dist(rng));
        mResourceMap[rId] = std::make_unique<T>(std::forward<Args>(resource)...);

        ResourceHandle<T> handle;
        handle.mId = rId;

        return handle;
    }

    /**
     * Returns a non-owning pointer to the resource if it exists, otherwise a nullptr is returned
    */
    template<class T>
    T* Get(const ResourceHandle<T>& handle) 
    {   
        if(mResourceMap.count(handle.mId))
            return static_cast<T*>(mResourceMap[handle.mId].get());

        return nullptr;
    }

    /**
     * Remove the resource from the handler, returns an unique_ptr to the resource if it exists, otherwise a nullptr is returned
    */
    template<class T>
    UPtr<T> Remove(const ResourceHandle<T>& handle) 
    {  
        auto iter = mResourceMap.find(handle.mId);
        if(iter == mResourceMap.end()) 
            return nullptr;
        
        auto pointer = std::move(iter->second);
        mResourceMap.erase(iter);
        return UPtr<T>(static_cast<T*>(pointer.release()));
    }

private:
    // <ComponentType, List of components>
    Map<size_t, UPtr<Resource>> mResourceMap;
    std::mt19937 rng;
};

}
