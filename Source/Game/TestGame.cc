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

    DefaultMaterial material;
    material.SetProgram(mProgram);
    material.SetDiffusionTexture(mTexture);
    auto materialHandle = resourceManager->Add(std::move(material));

    Mesh mesh = Mesh::FromShape(Shapes::Square(0.5));
    HMesh quadHandle = resourceManager->Add(std::move(mesh));
    mRenderable = std::make_shared<Renderable>();
    mRenderable->SetMaterial(materialHandle);
    mRenderable->SetMesh(quadHandle);

    mUBO = UniformBuffer::Create(12);
    /*
    mRenderable = Renderable().withMaterial(material).withMesh(mesh);
    */
}

void TestGame::Update(float delta)
{
    mWindow->ProcessEvents();
    mRunMainLoop = !mWindow->CloseRequested();

    mTime += delta;
    mTransform.SetPosition(Vec3(
        glm::sin(mTime) * 1.0,
        glm::cos(mTime) * 1.0,
        0.0
    ));
    mUBO->WriteData(0, 12, glm::value_ptr(mTransform.GetPosition()));
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
    
    auto material = resourceManager->Get(mRenderable->GetMaterial());
    auto meshHandle = mRenderable->GetMesh();

    Texture* texture = resourceManager->Get(material->GetDiffusionTexture());
    Mesh* mesh = resourceManager->Get(meshHandle);
    Program* program = resourceManager->Get(mProgram);

    
    mRender->BindProgram(program);
    glActiveTexture(GL_TEXTURE0);
    mRender->BindTexture(texture);
    program->SetUniform1i("uAlbedo", 0);

    glBindBufferRange(GL_UNIFORM_BUFFER, 0, mUBO->GetHandle(), 0, mUBO->Size());
    uint32_t index = glGetUniformBlockIndex(program->GetHandle(), "transform"); 
    glUniformBlockBinding(program->GetHandle(), index, 0);

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
