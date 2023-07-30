#pragma once
#include <functional>
#include <tuple>
#include <any>
#include <future>
#include <typeinfo>
#include <typeindex>
#include "Defines.hh"

class TaskBase
{
public:
    virtual ~TaskBase() = default;

    virtual void Execute() = 0;
    virtual bool HasCompleted() = 0;
    virtual bool CanExecute() = 0;
    virtual TaskBase& Before(TaskBase* other) = 0;
    virtual TaskBase& After(TaskBase* other) = 0;

};

template<typename Out = void>
class Task : public TaskBase
{
    typedef Out(*FnPtr)();
    using PackagedTask = std::packaged_task<Out()>;
public:
    Task(FnPtr fn) : mFn(fn) {};
    Task(std::function<Out()>&& fn) : mFn(std::move(fn)) {};

    Task(const Task<Out>& other) = delete;
    Task<Out>& operator=(const Task<Out>& other) = delete;
    Task(Task<Out>&& other) = default;
    Task<Out>& operator=(Task<Out>&& other) = default;

    void Execute() override 
    {
        mFn();
        mHasCompleted = true;
    }

    bool HasCompleted() override
    {
        return mHasCompleted;
    }

    bool CanExecute() override
    {
        return std::all_of(mDependencies.begin(), mDependencies.end(), [](TaskBase* task){ return task->HasCompleted();});
    }

    Task<Out>& Before(TaskBase* other) override 
    {
        other->After(this);
        return *this;
    }

    Task<Out>& After(TaskBase* other) override
    {
        mDependencies.emplace_back(other);
        return *this;
    }

private:
    std::function<Out()> mFn;
    Vector<TaskBase*> mDependencies;
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
struct UpdateStage : public ScheduleStage<UpdateStage>{};

class TaskScheduler
{
public:
    template<typename Stage = UpdateStage>
    TaskScheduler* AddTask(std::function<void()>&& fn)
    {
        mTasks.emplace_back(new Task<void>(std::move(fn)));
        mStages[Stage::GetTypeIndex()] += 1;
        return this;
    }

    TaskScheduler* AddTask(Task<>& task)
    {
        mTasks.push_back(std::make_unique<Task<>>(std::forward<Task<>>(task)));
        return this;
    }

    void ExecuteAll() 
    {
        for(auto& task: mTasks)
            task->Execute();
    }

    Vector<UPtr<TaskBase>> mTasks;
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