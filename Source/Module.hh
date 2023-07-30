#pragma once
#include <typeinfo>
#include <iostream>
#include <ranges>
#include <algorithm>
#include "Defines.hh"
#include "Util.hh"

/**
 * Represent a module. 
 * There can be only one module for each class inhereting from IModule
 */
class IModule{
public:
    virtual ~IModule() = default;
    virtual void Init() {};
    virtual void Shutdown() {};
    virtual void Update() {};
};

class ModuleManager {
    static ModuleManager* sSingleton;
public:
    ModuleManager() 
    {
        sSingleton = this;
    }

    /// Add a module to the manager. Does not initialize the module.
    template<class T>
    T* AddModule() 
    {
        auto mod = std::make_unique<T>();
        auto ptr = mod.get();
        mModules.emplace(std::move(mod));
        mOrder.push_back(ptr);
        return ptr;
    }

    /// Shutdown and remove the module if it exists
    template<class T>
    void RemoveModule() 
    {
        std::remove_if(mModules.begin(), mModules.end(), [&](auto& mod){
            auto res = dynamic_cast<T*>(mod.get());
            if (!res) 
                return false;

            res->Shutdown();
            mOrder.erase(res);
            return true;
        });
    }

    /// Get the module T. Return nullptr if none exists.
    template<class T>
    T* GetModule() 
    {
        for (auto& mod : mModules)
        {
            auto res = dynamic_cast<T*>(mod.get());
            if(res != nullptr) 
                return res;
        }

        std::cout << "Warning: could not find module " << typeid(T).name() << std::endl;
        return nullptr;
    }

    /// Initialize all modules in the order they were added
    void Init() {
        for (auto& mod : mOrder)
            mod->Init();
        
    }

    /// Shutdown all modules in the reverse order they were added
    void Shutdown() {
        for (auto& mod : Solis::Util::Reverse(mOrder))
            mod->Shutdown();
    }

    /// Static function to get a module.
    /// Do not call this function before calling Init or after calling Shutdown.
    /*template<class T>
    static T* Get() {
        return sSingleton->GetModule<T>();
    }*/

    static ModuleManager* Get() {
        return sSingleton;
    }

private:
    UnorderedSet<UPtr<IModule>> mModules;
    Deque<IModule*> mOrder;
};