#pragma once
#include "Window.hh"
#include "Module.hh"
#include "Render/Common/Renderer.hh"
#include <chrono>

namespace Solis
{
    

class Game {
public:
    virtual ~Game() {};

    virtual void Init() {};
    virtual void Update(float deltaTime) {};
    virtual void Render() {};
    virtual void RunMainLoop() {};

    void LoadDefaultModules();
    void Destroy();

protected:

    UPtr<Solis::Window> mWindow;
    UPtr<ModuleManager> mModules;
    SPtr<Render::Renderer> mRender;

    bool mRunMainLoop;
    std::chrono::time_point<std::chrono::steady_clock> mNow;
    std::chrono::time_point<std::chrono::steady_clock> mLastFrame;
    std::chrono::duration<float> mDelta;
};

} // namespace Solis