#pragma once

namespace Solis::ECS
{
    
class World;
struct QueryBase {};

template<typename... Args>
struct Query : public QueryBase
{
public:

    using Types = typename std::tuple<Args...>;
    static constexpr size_t TypeCount = sizeof...(Args);
    
    template<int N>
    using TypeOf = typename std::tuple_element<N, Types>::type;

    Query(World& world) : mWorld(world) {};

    std::tuple<Args...> GetSingle();

    void Test();

public:
    // Container functions


private:
    World& mWorld;
};

} // namespace Solis::ECS

#include "Query.cti"