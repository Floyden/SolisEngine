#pragma once
#include <functional>
#include <tuple>
#include <any>
#include <future>
#include <typeinfo>
#include <typeindex>
#include <utility>
#include "Defines.hh"

class Task
{
    typedef void(*FnPtr)();
public:
    Task(FnPtr fn) : mFn(fn), mDependencyCount(0), mHasCompleted(false) {};
    Task(std::function<void()>&& fn) : mFn(std::move(fn)), mDependencyCount(0), mHasCompleted(false) {};
   
    Task(Task&& other) 
    {
        (void) Emplace(std::forward<Task>(other));
    }

    Task& operator=(Task&& other) 
    {
        return Emplace(std::forward<Task>(other));
    };

    Task(const Task& other) = delete;
    Task& operator=(const Task& other) = delete;

    Task& Emplace(Task&& other) 
    {
        mFn.swap(other.mFn);
        mDependants.swap(other.mDependants);
        mDependencyCount.exchange(other.mDependencyCount);
        mHasCompleted = other.mHasCompleted;
        return *this;
    }

    void Execute()  
    {
        mFn();
        mHasCompleted = true;
        for (auto * dependant: mDependants) {
            // [TODO][MAYBE] Remove dependant from vector
            dependant->mDependencyCount.fetch_sub(1);
        }
    }

    bool HasCompleted() 
    {
        return mHasCompleted;
    }

    bool CanExecute() 
    {
        return mDependencyCount.load() == 0;
    }

    Task& Before(Task* other)  
    {
        mDependants.emplace_back(other);
        other->mDependencyCount.fetch_add(1);
        return *this;
    }

    Task& After(Task* other) 
    {
        other->Before(this);
        return *this;
    }

private:
    std::function<void()> mFn;
    Vector<Task*> mDependants;
    std::atomic_size_t mDependencyCount;
    bool mHasCompleted;
};


template<typename T>
struct ScheduleStage 
{
    static std::type_index GetTypeIndex()
    {
        return std::type_index(typeid(T));
    }
};

struct StartUpStage : public ScheduleStage<StartUpStage>{};
struct PreUpdateStage : public ScheduleStage<PreUpdateStage>{};
struct UpdateStage : public ScheduleStage<UpdateStage>{};

class TaskScheduler
{
public:
    template<typename Stage = UpdateStage>
    Task& AddTask(std::function<void()>&& fn)
    {
        mStages[Stage::GetTypeIndex()] += 1;
        return mTasks.emplace_back(std::move(fn));
    }

    template<typename Stage = UpdateStage>
    Task AddTask(Task&& task)
    {
        return mTasks.emplace_back(std::forward<Task>(task));
    }

    void ExecuteAll() 
    {
        for(auto& task: mTasks)
            task.Execute();
    }

    Vector<Task> mTasks;
    UnorderedMap<std::type_index, size_t> mStages;

    // Store which Stages depend on other stages
    UnorderedMap<std::type_index, Vector<std::type_index>> mStageDependencies;
};


// Task scheduler uses void() tasks
// Add functions through app interface and bind commands/querys/resources before passing them to the scheduler

/*
    class Foo {
        Task t1;
        Task t2;
    };

    TaskScheduler sched;
    Task t();


    sched.AddTask()
*/
