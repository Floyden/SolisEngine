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

public:

    operator bool() const { return this->mData != 0; }

private:

    size_t mId;
};
    
} // namespace Solis
