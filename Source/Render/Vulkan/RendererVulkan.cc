#include "RendererVulkan.hh"

#include <iostream>
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
    std::vector<const char*> enabledExtensions;
    std::vector<vk::ExtensionProperties> extensionProperties = vk::enumerateInstanceExtensionProperties();
    auto it = std::find_if(
        extensionProperties.begin(), 
        extensionProperties.end(), 
        [](auto& a) { return std::strcmp(a.extensionName, VK_KHR_PORTABILITY_ENUMERATION_EXTENSION_NAME) == 0;}
    );
    
    if (it != extensionProperties.end()) {
        enabledExtensions.push_back(it->extensionName);
    }

    vk::ApplicationInfo applicationInfo( "AppName", 1, "EngineName", 1, VK_API_VERSION_1_1 );
    vk::InstanceCreateInfo instanceCreateInfo( 
        vk::InstanceCreateFlagBits::eEnumeratePortabilityKHR, 
        &applicationInfo,
        0, nullptr,
        enabledExtensions.size(), enabledExtensions.data()
    );
    mInstance = vk::createInstance( instanceCreateInfo );
}

void RendererVulkan::Destroy() 
{
    mInstance.destroy();
}

}