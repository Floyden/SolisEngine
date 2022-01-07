#include "Framebuffer.hh"
#include <iostream>

namespace Solis
{
    
Framebuffer::Framebuffer()
{
    glGenFramebuffers(1, &mHandle);

    for(auto& attachment: mBoundTextures)
        attachment = 0;
}

Framebuffer::~Framebuffer()
{
    glDeleteFramebuffers(1, &mHandle);
}

void Framebuffer::Build()
{
    glBindFramebuffer(GL_FRAMEBUFFER, mHandle);
    
    GLenum drawBuffers[MAX_COLOR_ATTACHMENTS];
    GLuint count = 0;
    for (size_t i = 0; i < MAX_COLOR_ATTACHMENTS; i++)
    {
        glFramebufferTexture(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0 + i, mBoundTextures[i], 0);

        if(mBoundTextures[i])
        {
            drawBuffers[i] = GL_COLOR_ATTACHMENT0 + i;
            count = i + 1;
        }
        else
            drawBuffers[i] = GL_NONE;
    }

    if(mDepthbuffer)
        glFramebufferTexture(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, mDepthbuffer, 0);

    glDrawBuffers(count, drawBuffers);

    if(glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE)
        std::cout << "Framebuffer::Build: Error code: " << glGetError() << std::endl;

    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

void Framebuffer::Bind()
{
    glBindFramebuffer(GL_FRAMEBUFFER, mHandle);
}

void Framebuffer::BindTexture(uint32_t attachment, uint32_t texture)
{
    if  (attachment >= MAX_COLOR_ATTACHMENTS) {
        std::cout << "ERROR: Framebuffer::BindTexture: trying to bind to location " << attachment 
            << ".(Max: " << MAX_COLOR_ATTACHMENTS << ")" << std::endl;
        return;
    }
    mBoundTextures[attachment] = texture;
}

void Framebuffer::BindTexture(uint32_t attachment, SPtr<RenderTexture> texture)
{
    BindTexture(attachment, texture->GetHandle());
}

void Framebuffer::UnbindTexture(uint32_t attachment)
{
    if  (attachment >= MAX_COLOR_ATTACHMENTS) {
        std::cout << "ERROR: Framebuffer::BindTexture: trying to bind to location " << attachment 
            << ".(Max: " << MAX_COLOR_ATTACHMENTS << ")" << std::endl;
        return;
    }
    mBoundTextures[attachment] = 0;
}

void Framebuffer::BindDepthbuffer(uint32_t buffer)
{
    mDepthbuffer = buffer;
}

void Framebuffer::BindDepthbuffer(SPtr<RenderTexture> texture)
{
    BindDepthbuffer(texture->GetHandle());
}

void Framebuffer::UnbindDepthbuffer(uint32_t buffer)
{
    mDepthbuffer = 0;
}

} // namespace Solis
