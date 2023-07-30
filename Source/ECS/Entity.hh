#pragma once
#include <functional>

namespace Solis::ECS
{
struct Entity 
{ 
    Entity(ssize_t id = 0) : id(id) {};

    ssize_t id; 
    bool operator==(const Entity&) const = default;
};
}

template<>
struct std::hash<Solis::ECS::Entity>
{
    std::size_t operator()(Solis::ECS::Entity const& s) const noexcept
    {
        std::size_t h1 = std::hash<ssize_t>{}(s.id);
        return h1;
    }
};