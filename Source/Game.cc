#include "Game.hh"
#include "Component.hh"
#include "Input/Input.hh"
#include "Physics/Physics.hh"
#include "Render/OpenGL/RendererGL.hh"
#include "Render/Vulkan/RendererVulkan.hh"
#include "Core/ResourceManger.hh"

namespace Solis
{

void Game::LoadDefaultModules() 
{
    /*
    if(mWindow == nullptr)
        mWindow = Solis::Window::Create();
    */
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
