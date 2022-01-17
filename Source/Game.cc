#include "Game.hh"
#include "Component.hh"
#include "Input/Input.hh"
#include "Physics/Physics.hh"

namespace Solis
{
void Game::LoadDefaultModules() 
{
    if(mWindow == nullptr)
        mWindow = Solis::Window::Create();
    if(mModules == nullptr)
        mModules = std::make_unique<ModuleManager>();

    mModules->AddModule<ComponentManager>();
    mModules->AddModule<Events>();
    mModules->AddModule<Input>();
    mModules->AddModule<Physics>();

    if(mRender == nullptr)
        mRender = std::make_unique<Renderer>();
}
} // namespace Solis
