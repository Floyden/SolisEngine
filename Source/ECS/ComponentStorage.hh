#pragma once
#include <iostream>
#include <typeinfo>
#include <vector>

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

    bool HasComponent(T const* component)
    {
        auto it = std::find(mComponents.begin(), mComponents.end(), *component);
        return it != mComponents.end();
    }
//private:
    std::vector<T> mComponents;
};

} // namespace Solis::ECS
