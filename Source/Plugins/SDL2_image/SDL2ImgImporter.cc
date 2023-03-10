#include "SDL2ImgImporter.hh"
#include "Image.hh"
#include <SDL2/SDL_image.h>
#include <SDL2/SDL.h>
#include <iostream>

namespace Solis
{

ImageFormat GetFormat(uint32_t sdlFormat)
{
    switch (sdlFormat) {
        case SDL_PIXELFORMAT_RGBA32:
            return ImageFormat::eRGBA8;
        case SDL_PIXELFORMAT_RGB24:
            return ImageFormat::eRGB8;
        default:
            std::cout << "SDL2ImgImporter::GetFormat: unknown format: " << std::oct << sdlFormat << std::endl;
    }

    return ImageFormat::eRGB8;
}

SDL2ImgImporter::SDL2ImgImporter()
{
    IMG_Init(IMG_INIT_PNG | IMG_INIT_JPG);
}

SDL2ImgImporter::~SDL2ImgImporter()
{
    IMG_Quit();
}

SPtr<Image> SDL2ImgImporter::Import(const String& path)
{
    auto surface = IMG_Load(path.c_str());

    if(!surface) {
        std::cout << IMG_GetError() << std::endl;
        return nullptr;
    }
    
    SDL_LockSurface(surface);

    auto format = GetFormat(surface->format->format);
    uint32_t width = surface->w;
    uint32_t height = surface->h;
    Vector<uint8_t> data;
    for (int i = 0; i < height; i++)
    {
        data.insert(data.end(), 
            &reinterpret_cast<char*>(surface->pixels)[i * surface->pitch], 
            &reinterpret_cast<char*>(surface->pixels)[i * surface->pitch + surface->pitch]);
    }
        
    SDL_UnlockSurface(surface);
    //SDL_FreeSurface(surface);

    return std::make_shared<Image>(width, height, format, data);
}

} // namespace Solis