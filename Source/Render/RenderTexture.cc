#include "RenderTexture.hh"

namespace Solis
{

RenderTexture::RenderTexture(uint32_t width, uint32_t height, RenderTextureFormat fmt) :
    mWidth(width), mHeight(height), mFormat(fmt)
{
    glGenTextures(1, &mHandle);
    glBindTexture(GL_TEXTURE_2D, mHandle);
    glTexImage2D(GL_TEXTURE_2D, 0,GetGLInternalFormat(mFormat), mWidth, mHeight, 0, GetGLFormat(mFormat), GetGLDataType(mFormat), 0);

	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST); 
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
	glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

}

RenderTexture::~RenderTexture()
{
}

uint32_t RenderTexture::GetGLInternalFormat(RenderTextureFormat format)
{
    switch (format)
    {
    case RenderTextureFormat::R8 :
        return GL_R8;
    case RenderTextureFormat::RG8 :
        return GL_RG8;
    case RenderTextureFormat::RGB8 :
        return GL_RGB8;
    case RenderTextureFormat::RGBA8 :
        return GL_RGBA8;
    case RenderTextureFormat::RGB10A2 :
        return GL_RGB10_A2;
    case RenderTextureFormat::D32 :
        return GL_DEPTH_COMPONENT32;
    case RenderTextureFormat::D24S8 :
        return GL_DEPTH24_STENCIL8;
    default:
        return 0;
    }
}

uint32_t RenderTexture::GetGLFormat(RenderTextureFormat format)
{
    switch (format)
    {
    case RenderTextureFormat::R8 :
        return GL_RED;
    case RenderTextureFormat::RG8 :
        return GL_RG;
    case RenderTextureFormat::RGB8 :
        return GL_RGB;
    case RenderTextureFormat::RGBA8 :
    case RenderTextureFormat::RGB10A2 :
        return GL_RGBA;
    case RenderTextureFormat::D32 :
        return GL_DEPTH_COMPONENT;
    case RenderTextureFormat::D24S8 :
        return GL_DEPTH_STENCIL;
    default:
        return 0;
    }
}

uint32_t RenderTexture::GetGLDataType(RenderTextureFormat format)
{
    switch (format)
    {
    case RenderTextureFormat::R8 :
    case RenderTextureFormat::RG8 :
    case RenderTextureFormat::RGB8 :
    case RenderTextureFormat::RGBA8 :
    case RenderTextureFormat::RGB10A2 :
    case RenderTextureFormat::D32 :
    case RenderTextureFormat::D24S8 :
        return GL_UNSIGNED_BYTE;
    default:
        return 0;
    }
}

} // namespace Solis
