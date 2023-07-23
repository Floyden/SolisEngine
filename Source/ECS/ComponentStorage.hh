#pragma once
#include <iostream>
#include <typeinfo>

namespace Solis::ECS
{
struct Component{};

class ComponentStorageBase {};

template<typename T>
class ComponentStorage : public ComponentStorageBase
{
public:
    T& AddComponent(T&& component)
    {
        return mComponents.emplace_back(std::forward<T>(component));
    }
//private:
    std::vector<T> mComponents;
};

} // namespace Solis::ECS
