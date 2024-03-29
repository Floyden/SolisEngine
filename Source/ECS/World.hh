#pragma once
#include "Defines.hh"
#include "Core/Task.hh"
#include "ComponentStorage.hh"
#include "Entity.hh"
#include "Event.hh"
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
    

    // Get the component C which corresponds to Entity e
    template<CComponent C>
    C* GetComponent(Entity e)
    {
        return static_cast<C*>(mEntityComponents[e][std::type_index(typeid(C))]);
    }

    template<CEvent T>
    World* RegisterEvent()
    {
        mEventStorages[typeid(T)] = std::make_unique<EventStorage<T>>();
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
            } else if  constexpr (std::derived_from<Args, EventWriterBase>) {
                std::cout << "EventWriter" << std::endl;
            } else if  constexpr (std::derived_from<Args, EventReaderBase>) {
                std::cout << "EventReader" << std::endl;
            }  else if  constexpr (std::derived_from<Args, Component>) {
                std::cout << "Component" << std::endl;
            } else {
                static_assert(false_type_v<Args>, "Argument is invalid");
            }
        }(), ...);

    }

    template<typename... Args>
    World& AddTask(void(*task)(Args...))
    {
        return AddTaskAtStage<UpdateStage>(task);
    }

    template<typename... Args>
    World& AddStartupTask(void(*task)(Args...))
    {
        return AddTaskAtStage<StartUpStage>(task);
    }

    template<typename T>
    auto BindEventReader()
    {
        return EventReader(static_cast<T&>(*mEventStorages[typeid(typename T::EventType)].get()));
    }
    
    template<typename T>
    auto BindEventWriter()
    {
        return EventWriter(static_cast<T&>(*mEventStorages[typeid(typename T::EventType)].get()));
    }

    template<typename... Args>
    auto _BindTasks(void(*task)(Args...)) {
        return std::bind(task,
            ([&]
            {   if  constexpr (std::derived_from<Args, QueryBase>) {
                    return Args(*this); // Returns a Query<Components&...>
                } else if  constexpr (std::derived_from<Args, EventWriterBase>) {
                    std::cout << "EventWriter" << std::endl;
                    return BindEventWriter<typename Args::StorageType>();
                } else if  constexpr (std::derived_from<Args, EventReaderBase>) {
                    std::cout << "EventReader" << std::endl;
                    return BindEventReader<typename Args::StorageType>();
                }  else {
                    static_assert(false_type_v<Args>, "Argument is invalid");
                }
            }(), ...));
    }

    template<typename Stage, typename... Args>
    World& AddTaskAtStage(void(*task)(Args...))
    {
        mTaskScheduler.AddTask<Stage>(_BindTasks(task));
        return *this;
    }

    template<typename Stage, typename... Args>
    World& AddPinnedTaskAtStage(void(*task)(Args...))
    {
        auto t = _BindTasks(task);
        mTaskScheduler.AddPinnedTask<Stage>(t);
        return *this;
    }

    void Update()
    {
        mTaskScheduler.ExecuteAll();
        for(auto& [key, events]: mEventStorages) 
            events->Update();
    }

    using ComponentStorages = UnorderedMap<std::type_index, UPtr<ComponentStorageBase>>;
    using EntityComponentMap = UnorderedMap<Entity, UnorderedMap<std::type_index, Component*>>;
    using EventStorageMap = UnorderedMap<std::type_index, UPtr<EventStorageBase>>;


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
    EventStorageMap mEventStorages;
    TaskScheduler mTaskScheduler;
};

} // namespace Solis

#include "Query.cti"
