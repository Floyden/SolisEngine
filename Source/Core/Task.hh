#pragma once
#include <lockfree.hpp>
#include <cstddef>
#include <chrono>
#include <functional>
#include <tuple>
#include <any>
#include <future>
#include <typeinfo>
#include <typeindex>
#include <utility>
#include "Defines.hh"

enum class TaskStatus
{
    Idle,
    Queued,
    Running,
    Finished,
};

class Task
{
    typedef void(*FnPtr)();
public:
    Task(FnPtr fn) : mFn(fn), mDependencyCount(0), mStatus(TaskStatus::Idle) {};
    Task(std::function<void()>&& fn) : mFn(std::move(fn)), mDependencyCount(0), mStatus(TaskStatus::Idle) {};
   
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
        mStatus = other.mStatus;
        return *this;
    }

    void Execute()  
    {
        mStatus = TaskStatus::Running;
        mFn();
        mStatus = TaskStatus::Finished;
        for (auto * dependant: mDependants) {
            // [TODO][MAYBE] Remove dependant from vector
            dependant->mDependencyCount.fetch_sub(1);
        }
    }

    TaskStatus GetStatus() 
    {
        return mStatus;
    }

    // Checks if all the dependencies are completed
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
    friend class TaskScheduler;

    std::function<void()> mFn;
    Vector<Task*> mDependants;
    std::atomic_size_t mDependencyCount;
    TaskStatus mStatus;
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
    TaskScheduler(size_t numThreads = 4) : 
        mThreadCount(numThreads) 
    {
        for (size_t i = 0; i < mThreadCount; i++) {
            mWorkers.emplace_back([pipeline = &mTaskPipelines, shutdown = &mShutdown](){
                    using namespace std::chrono_literals;
                while (!shutdown){
                    Task* task = nullptr;
                    if (!pipeline->Pop(task)){
                        std::this_thread::yield();
                        continue;
                    }
                    task->Execute();
                }
            });
        }
    }

    ~TaskScheduler() {
        mShutdown = true;
        for (auto& worker: mWorkers)
            worker.join();
    }

    template<typename Stage = UpdateStage>
    Task& AddTask(std::function<void()>&& fn)
    {
        mStages[Stage::GetTypeIndex()] += 1;
        return mTasks.emplace_back(std::move(fn));
    }

    template<typename Stage = UpdateStage>
    Task& AddPinnedTask(std::function<void()>&& fn)
    {
        mStages[Stage::GetTypeIndex()] += 1;
        return mPinnedTasks.emplace_back(std::move(fn));
    }

    template<typename Stage = UpdateStage>
    Task& AddTask(Task&& task)
    {
        return mTasks.emplace_back(std::forward<Task>(task));
    }
    
    template<typename Stage = UpdateStage>
    Task& AddPinnedTask(Task&& task)
    {
        return mPinnedTasks.emplace_back(std::forward<Task>(task));
    }

    void ExecuteAll() 
    {
        if(mThreadCount)
            for(auto& task: mTasks)
                mTaskPipelines.Push(&task);
        else 
            for(auto& task: mTasks)
                task.Execute();

        for(auto& task: mPinnedTasks)
            task.Execute();
    }

    size_t mThreadCount;

    Vector<Thread> mWorkers;
    bool mShutdown;
    lockfree::mpmc::Queue<Task*, 64> mTaskPipelines;

    Vector<Task> mTasks;
    Vector<Task> mPinnedTasks;
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
