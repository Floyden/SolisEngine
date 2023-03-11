#include "RendererGL.hh"
#include <iostream>
#include "VAOManager.hh"

namespace Solis
{

// TODO: This is a whacky workaround because of modules
static UPtr<VAOManager> sVaoManager;

RendererGL::RendererGL() : mBoundProgram(nullptr), mBoundAttributes(nullptr), mBoundBuffers({nullptr}), mBoundIndexBuffer(nullptr) {
}

RendererGL::~RendererGL() {
    sVaoManager = nullptr;
    //S_MODULE_MANAGER->RemoveModule<VAOManager>();
}

void RendererGL::Initialize()
{
    sVaoManager = std::make_unique<VAOManager>();
    //S_MODULE_MANAGER->AddModule<VAOManager>();

    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
}

void RendererGL::Destroy()
{
    sVaoManager = nullptr;
    //S_MODULE_MANAGER->RemoveModule<VAOManager>();
}

void RendererGL::Clear(float r, float g, float b, float a) 
{
    glClearColor(r, g, b, a);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

void RendererGL::BindVertexAttributes(SPtr<VertexAttributes> attribs)
{
    mBoundAttributes = attribs;
}

void RendererGL::BindVertexBuffers(uint32_t index, const SPtr<VertexBuffer>* vbs, uint32_t bufferCount)
{
    if(index >= MAX_VB_COUNT) {
        std::cout << "BindVertexBuffer index out of bounds\n";
        return;
    }

    if(bufferCount + index > MAX_VB_COUNT) {
        std::cout << "BindVertexBuffer too many buffers\n";
        return;

    }

    for(size_t i = 0; i < bufferCount; i++) {
        mBoundBuffers[i + index] = vbs[i];
    }
}

void RendererGL::BindIndexBuffer(const SPtr<IndexBuffer>& ib)
{
    mBoundIndexBuffer = ib;
}

void RendererGL::BindTexture(const HTexture& texture)
{
    glBindTexture(GL_TEXTURE_2D, texture->GetHandle());
}

void RendererGL::BindProgram(const SPtr<Program>& program)
{
    if(mBoundProgram != program)
    {
        mBoundProgram = program;
        glUseProgram(mBoundProgram->GetHandle());
    }
}

void RendererGL::Draw(uint32_t vertexCount) 
{
    //Begin
    if(mBoundAttributes == nullptr){
        std::cout << "BoundAttributes not set\n";
        return;
    }

    auto vao = sVaoManager->GetVao(mBoundProgram, mBoundAttributes, mBoundBuffers);
    glBindVertexArray(vao);


    glDrawArrays(GL_TRIANGLES, 0, vertexCount);

}

void RendererGL::DrawIndexed(uint32_t indexCount) 
{
    //Begin
    if(mBoundAttributes == nullptr){
        std::cout << "BoundAttributes not set\n";
        return;
    }

    if(mBoundIndexBuffer == nullptr){
        std::cout << "IndexBuffer not bound\n";
        return;
    }
    
    auto vao = sVaoManager->GetVao(mBoundProgram, mBoundAttributes, mBoundBuffers);
    glBindVertexArray(vao);

    auto& attributes = mBoundAttributes->GetAttributes();
    for (auto& attr: attributes)
    {
        if(!mBoundBuffers[attr.location]) {
            std::cout << "Not enough buffers bound\n";
            return;
        }

        glEnableVertexAttribArray(attr.location);
        glBindBuffer(GL_ARRAY_BUFFER, mBoundBuffers[attr.location]->GetHandle());
        glVertexAttribPointer(attr.location, attr.typeCount, attr.type, attr.normalized, attr.stride, (void*)0);
    }

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mBoundIndexBuffer->GetHandle());
    glDrawElements(GL_TRIANGLES, indexCount, GL_UNSIGNED_INT, (void*)0);
}


} // namespace Solis