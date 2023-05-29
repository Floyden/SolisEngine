#pragma once
#include "Defines.hh"
#include "Core/ResourceHandle.hh"
#include "Core/Resource.hh"
#include "Image.hh"

namespace Solis
{

class Texture;
using HTexture = ResourceHandle<Texture>;

class Texture : public Resource {
public:
    Texture(Texture&& other) {
        mHandle = other.mHandle;
        other.mHandle = 0;
    }
    ~Texture();

    static HTexture Create(ResourceHandle<Image> image);

    uint32_t GetHandle() const { return mHandle; }
private:
    Texture() = default;

    uint32_t mHandle;
};


} // namespace Solis