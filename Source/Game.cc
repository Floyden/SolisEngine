#include "Game.hh"

namespace Solis
{
void Game::LoadDefaultModules() 
{
    if(mWindow == nullptr)
        mWindow = Solis::Window::Create();
    if(mModules == nullptr)
        mModules = std::make_shared<ModuleManager>();

    mModules->AddModule<ComponentManager>();
    mModules->AddModule<Events>();
    mModules->AddModule<Input>();
    mModules->AddModule<Physics>();
}
} // namespace Solis
