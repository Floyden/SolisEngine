#include "Game.hh"
#include "Component.hh"
#include "Input/Input.hh"
#include "Physics/Physics.hh"
#include "Render/OpenGL/RendererGL.hh"
#include "Render/Vulkan/RendererVulkan.hh"
#include "Core/ResourceManger.hh"

namespace Solis
{
void ProcessWindowEvents(ECS::Query<Window&> windows)
{
    for(auto [window]: windows)
        window.ProcessEvents();
}


void Game::LoadDefaultModules() 
{
    auto windowEnt = mWorld.CreateEntity(*Solis::Window::Create());
    mWindow = mWorld.GetComponent<Window>(windowEnt);
    mWorld.AddPinnedTaskAtStage<PreUpdateStage>(ProcessWindowEvents);


    if(mModules == nullptr)
        mModules = std::make_unique<ModuleManager>();

    mModules->AddModule<ResourceManager>();
    mModules->AddModule<ComponentManager>();
    mModules->AddModule<Events>();
    mModules->AddModule<Input>();
    mModules->AddModule<Physics>();

    if(mRender == nullptr)
    {
        mRender = std::make_unique<RendererGL>();
        mRender->Initialize();
    }
}


void Game::Destroy()
{
    mRender->Destroy();
    if(mModules)
        mModules->Shutdown();
    if(mWindow)
        mWindow->Destroy();
}

} // namespace Solis
