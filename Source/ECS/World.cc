#include "World.hh"

namespace Solis::ECS
{

World::ComponentStorages& World::GetComponentStorages() { return mComponents; }
World::EntityComponentMap& World::GetEntityComponentMap() { return mEntityComponents; }

}
