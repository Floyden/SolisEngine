#include "Texture.hh"
#include "Image.hh"
#include "Core/ResourceManger.hh"

namespace Solis
{

GLint GetGLInternalFormat(ImageFormat format)
{
    switch (format) {
        case ImageFormat::eR8:
            return GL_R8;
        case ImageFormat::eRG8:
            return GL_RG8;
        case ImageFormat::eRGB8:
            return GL_RGB8;
        case ImageFormat::eRGBA8:
            return GL_RGBA8;
        case ImageFormat::eRF:
            return GL_R16F;
        case ImageFormat::eRGF:
            return GL_RG16F;
        case ImageFormat::eRGBF:
            return GL_RGB16F;
        case ImageFormat::eRGBAF:
            return GL_RGBA16F;
    }
    return 0;
} 

GLenum GetGLFormat(ImageFormat format)
{
    switch (format) {
        case ImageFormat::eR8:
        case ImageFormat::eRF:
            return GL_RED;
        case ImageFormat::eRG8:
        case ImageFormat::eRGF:
            return GL_RG;
        case ImageFormat::eRGB8:
        case ImageFormat::eRGBF:
            return GL_RGB;
        case ImageFormat::eRGBA8:
        case ImageFormat::eRGBAF:
            return GL_RGBA;
    }
    return 0;
} 


HTexture Texture::Create(ResourceHandle<Image> imageHandle)
{
    //auto res = std::make_unique<Texture>();
    auto resourceManager = ModuleManager::Get()->GetModule<ResourceManager>();
    Image* image =resourceManager->Get(imageHandle);

    Texture texture;
    glGenTextures(1, &texture.mHandle);
    glBindTexture(GL_TEXTURE_2D, texture.mHandle);

    auto internalFormat = GetGLInternalFormat(image->GetFormat());
    auto format = GetGLFormat(image->GetFormat());

    if(image) {
        glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, image->GetWidth(), image->GetHeight(), 0, format, GL_UNSIGNED_BYTE, image->GetData().data());
    } else {
        glTexImage2D(GL_TEXTURE_2D, 0, internalFormat, 0, 0, 0, format, GL_UNSIGNED_BYTE, nullptr);
    }

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);

    return resourceManager->Add<Texture>(std::move(texture));
}

Texture::~Texture()
{
    glDeleteTextures(1, &mHandle);
}

} // namespace Solis