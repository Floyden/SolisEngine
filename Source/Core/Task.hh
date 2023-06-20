#pragma once
#include <functional>
#include <tuple>
#include <any>
#include <future>
#include <typeinfo>
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

class TaskScheduler
{
public:

    TaskScheduler* AddTask(TaskBase* task)
    {
        mTasks.emplace_back(task);
        return this;
    }

    void ExecuteNext() {

    }

    Vector<TaskBase*> mTasks;
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