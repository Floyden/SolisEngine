#pragma once
#include <vector>
#include <functional>

class Void{};

template<typename T>
class TaskTraits;

template<typename T>
class TaskBase
{
    friend T;
public:
    using Out = typename TaskTraits<T>::Out;
    using In = typename TaskTraits<T>::In;

    virtual ~TaskBase() = default;

    virtual Out Execute(In in) = 0;
};

class Task;

template<>
class TaskTraits<Task>
{
public:
    using Out = void;
    using In = Void;
};

class Task : public TaskBase<Task>
{
public:
    using Out = typename TaskTraits<Task>::Out;
    using In = typename TaskTraits<Task>::In;
    typedef Out(*FunctionPtr)(In);
    typedef Out(*VoidFunctionPtr)();

    Task(std::function<Out(In)> function) : mCallMeMaybe(function) {};
    Task(FunctionPtr function) : mCallMeMaybe(function) {};
    Task(VoidFunctionPtr function) : mCallMeMaybe([function](Void){return function();}) {};

    Out Execute() {
        return Execute(Void{});
    }

    Out Execute(In in) override {
        return mCallMeMaybe(in);
    }

    std::function<Out(In)> mCallMeMaybe;
};