#pragma once
#include "Core/ResourceHandle.hh"
#include "Image.hh"


namespace Solis
{

class SDL2ImgImporter
{
public:
    SDL2ImgImporter();
    ~SDL2ImgImporter();
    ResourceHandle<Image> Import(const String& path);
private:
};

} // namespace Solis