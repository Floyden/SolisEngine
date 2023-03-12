#include "TestGame.hh"
#include "Render/Renderable.hh"
#include "RandomThings.hh"
#include "Core/ResourceManger.hh"

namespace Solis
{
void TestGame::Init()
{   
    LoadDefaultModules();
    mModules->Init();
    auto resourceManager = mModules->GetModule<ResourceManager>();
    
    mImageImporter = std::make_unique<SDL2ImgImporter>();
    mTexture = Texture::Create(mImageImporter->Import("Resources/Floor/bricks.png"));
    

    Program program;
    program.LoadFrom(gBasicVertexShaderSource, gBasicFragmentShaderSource);
    mProgram = resourceManager->Add(std::move(program));

    auto material = std::make_shared<DefaultMaterial>();
    material->SetProgram(mProgram);
    material->SetTexture(mTexture);

    Mesh mesh = Mesh::FromShape(Shapes::Square(0.5));
    HMesh quadHandle = resourceManager->Add(std::move(mesh));
    mRenderable = std::make_shared<Renderable>();
    mRenderable->SetMaterial(material);
    mRenderable->SetMesh(quadHandle);

}

void TestGame::Update(float delta)
{
    mWindow->ProcessEvents();
    mRunMainLoop = !mWindow->CloseRequested();
}

void checkError(const std::string& msg) {

    GLenum err;
    while((err = glGetError()) != GL_NO_ERROR)
    {
        std::cout << std::hex << msg << ": " << err << std::endl;
        exit(-1);
    }
}

void TestGame::Render()
{
    auto resourceManager = mModules->GetModule<ResourceManager>();
    mRender->Clear(0.0f, 0.0f, 0.4f, 0.0f);
    
    auto material = mRenderable->GetMaterial();
    auto meshHandle = mRenderable->GetMesh();

    Texture* texture = resourceManager->Get(material->GetTexture());
    Mesh* mesh = resourceManager->Get(meshHandle);
    Program* program = resourceManager->Get(mProgram);

    
    mRender->BindProgram(program);
    glActiveTexture(GL_TEXTURE0);
    mRender->BindTexture(texture);
    program->SetUniform1i("uAlbedo", 0);
    //glBindTexture(GL_TEXTURE_2D, mTexture->GetHandle());
    
    mRender->BindVertexAttributes(mesh->mAttributes);

    for(size_t i = 0; i < mesh->mVertexData->GetBufferCount(); i++) 
    {
        auto buffer = mesh->mVertexData->GetBuffer(i);
        mRender->BindVertexBuffers(i, &buffer, 1);
    }
    mRender->BindIndexBuffer(mesh->mIndexBuffer);
    mRender->DrawIndexed(mesh->mIndexBuffer->GetIndexCount());

    mWindow->SwapWindow();
}

void TestGame::RunMainLoop()
{
    mRunMainLoop = true;
    mLastFrame = std::chrono::steady_clock::now();

    while (mRunMainLoop) {

        // Update everything
        mNow = std::chrono::steady_clock::now();
        mDelta = mNow - mLastFrame;
        mLastFrame = mNow;
    
        Update(mDelta.count());
        Render();        
    }
}

} // namespace Solis
