#include "RendererVulkan.hh"

namespace Solis::Render
{
    
RendererVulkan::RendererVulkan()
{
}

RendererVulkan::~RendererVulkan()
{
}

void RendererVulkan::Initialize() 
{
    vk::ApplicationInfo applicationInfo( "AppName", 1, "EngineName", 1, VK_API_VERSION_1_1 );
    vk::InstanceCreateInfo instanceCreateInfo( {}, &applicationInfo );
    mInstance = vk::createInstance( instanceCreateInfo );
}

void RendererVulkan::Destroy() 
{
    mInstance.destroy();
}

}