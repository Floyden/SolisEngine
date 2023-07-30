#pragma once
#include "Defines.hh"
#include "Core/Task.hh"
#include "ComponentStorage.hh"
#include "Entity.hh"
#include "Query.hh"
#include <typeindex>
#include <typeinfo>
#include <type_traits>
#include <concepts>

namespace Solis::ECS
{

template<class>
inline constexpr bool false_type_v = false;

template <typename T>
concept CComponent = std::is_base_of<Component, T>::value;

class World
{
public:
    World() = default;

    Entity CreateEntity()
    {
        static ssize_t G_ENTITYID = 0;
        return Entity(++G_ENTITYID);
    }

    template<CComponent... Args>
    Entity CreateEntity(Args&&... values)
    {
        Entity entity = CreateEntity();
        AddComponent(entity, std::forward<Args>(values)...);
        return entity;
    }

    template<CComponent... Args>
    World* AddComponent(Entity entity, Args&&... values)
    {
        ([&]
        {
            auto index = std::type_index(typeid(Args));
            ComponentStorageBase* storageBase = mComponents.emplace(
                index, std::make_unique<ComponentStorage<Args>>()
                ).first->second.get();
            ComponentStorage<Args>* storage = reinterpret_cast<ComponentStorage<Args>*>(storageBase);
            auto* component = &storage->AddComponent(std::forward<Args>(values));

            mEntityComponents[entity].emplace(index, component);
        }(), ...);

        return this;
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
            } else if  constexpr (std::derived_from<Args, QueryBase>) {
                std::cout << "Query" << std::endl;
                BindQuery<Args>(std::make_integer_sequence<size_t, Args::TypeCount>{});
            } else if  constexpr (std::derived_from<Args, Component>) {
                std::cout << "Component" << std::endl;
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

    using ComponentStorages = UnorderedMap<std::type_index, UPtr<ComponentStorageBase>>;
    using EntityComponentMap = UnorderedMap<Entity, std::unordered_map<std::type_index, Component*>>;


    template<CComponent T>
    ComponentStorage<T>* GetComponentStorage() 
    { 
        return reinterpret_cast<ComponentStorage<T>*>(mComponents[std::type_index(typeid(T))]);
    }
    ComponentStorages& GetComponentStorages();
    EntityComponentMap& GetEntityComponentMap();

private:
    ComponentStorages mComponents;
    EntityComponentMap mEntityComponents;
    TaskScheduler mTaskScheduler;
};

} // namespace Solis

#include "Query.cti"