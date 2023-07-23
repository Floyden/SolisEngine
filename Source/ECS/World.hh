#pragma once
#include "Defines.hh"
#include "Core/Task.hh"
#include <typeindex>
#include <typeinfo>
#include <concepts>

namespace Solis::ECS
{
struct Entity{ ssize_t id; };
struct Component{};

struct IQuery {};
template<typename... Args>
struct Query : public IQuery 
{
public:
    using Types = typename std::tuple<Args...>;
    static constexpr size_t TypeCount = sizeof...(Args);
    
    template<int N>
    using TypeOf = typename std::tuple_element<N, Types>::type;

    Query(World& world) : mWorld(world) {};

private:
    World& mWorld;
};

template<class>
inline constexpr bool false_type_v = false;




class World
{
public:
    Entity CreateEntity()
    {
        static ssize_t G_ENTITYID = 0;
        return Entity{.id = ++G_ENTITYID};
    }

    template<typename... Args>
    Entity CreateEntity(Args&&... values)
    {
        Entity entity = CreateEntity();
        AddComponent(entity, std::forward<Args>(values)...);
        return entity;
    }

    template<typename... Args>
    World* AddComponent(Entity entity, Args&&... values)
    {
        // [TODO]
        return this;
    }
    
    template<typename... Args>
    Query<Args...> Query()
    {
        // [TODO]
        return Query<Args...>();
    }

    template<typename Q, size_t... Is>
    void BindQuery(std::integer_sequence<size_t, Is...> const &)
    {
        ([&]
        {
            using T = typename Q::template TypeOf<Is>;
            std::cout << typeid(T).name() << std::endl;
        }(), ...);
    }

    template<typename... Args>
    void Bind()
    {
        ([&]
        {
            if constexpr (std::is_same_v<Args, size_t>) {
                std::cout << "size_t" << std::endl;
            } else if  constexpr (std::is_same_v<Args, std::string>) {
                std::cout << "string" << std::endl;
            } else if  constexpr (std::derived_from<Args, IQuery>) {
                std::cout << "Query" << std::endl;
                BindQuery<Args>(std::make_integer_sequence<size_t, Args::TypeCount>{});
            } else {
                static_assert(false_type_v<Args>, "Argument is invalid");
            }
        }(), ...);
    }

    template<typename... Args>
    void AddTask(Task<Args...>&& task)
    {
    }

    template<typename Stage, typename... Args>
    void AddTaskAtStage(Task<Args...>&& task)
    {
        
    }

private:
    using EntityComponentMap = UnorderedMap<Entity, UnorderedMap<std::type_index, SPtr<Component>>>;
    //EntityComponentMap mEntityComponents;
};

} // namespace Solis
