#include "Game.hh"

namespace Solis
{
void Game::LoadDefaultModules() 
{
    mModules->AddModule<ComponentManager>();
    mModules->AddModule<Events>();
    mModules->AddModule<Input>();
    mModules->AddModule<Physics>();
}
} // namespace Solis
