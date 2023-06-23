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
    std::type_index typeId;

    auto operator<=>(const ResourceId& other) const { return id <=> other.id; }
};    

template<typename T>
class ResourceHandle
{
    friend class ResourceManager;

public:
    ResourceHandle(size_t id = 0) : mId({id, std::type_index(typeid(T))}) {};

    operator bool() const { return this->mData != 0; }

    template <typename Other>
    operator ResourceHandle<Other>() const {
        return ResourceHandle<Other>(mId.id);
    }

private:
    ResourceId mId;
};
    
} // namespace Solis
