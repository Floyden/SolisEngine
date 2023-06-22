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

    Mesh mesh = Mesh::FromShape(Shapes::Cube(0.5));
    HMesh quadHandle = resourceManager->Add(std::move(mesh));
    mRenderable = std::make_shared<Renderable>();
    mRenderable->SetMaterial(materialHandle);
    mRenderable->SetMesh(quadHandle);

    grid.extends = Vec2i(3, 2);
    grid.renderable = mRenderable.get();
    //grid.transformations.resize(2*3, );
    for(size_t i = 0; i < 6; i++)
    {
        grid.transformations.emplace_back(UniformBuffer::Create(16 * sizeof(float)));
        Transform trans;
        trans.GetPosition().x = i%3 * 0.5;
        trans.GetPosition().y = i%2 * -0.5;
        auto matrix = trans.GetTransform();
        grid.transformations[i]->WriteData(0, 16 * sizeof(float), glm::value_ptr(trans.GetTransform()));
    }

    mUBO = UniformBuffer::Create(16 * sizeof(float));

    scheduler.AddTask(
        std::bind(
            &Window::ProcessEvents,
            mWindow.get()));

    scheduler.AddTask(Task<>(std::bind(
        [](float* time, Transform* transform, UniformBuffer* ubo) {
            transform->SetPosition(Vec3(
                glm::sin(*time * 2.0) * 0.5,
                glm::cos(*time * 2.0) * 1.0,
                0.0
            ));
            transform->Roatate(Vec3(
                0.0,
                1.0,
                0.0
            ), glm::sin(0.01));
            ubo->WriteData(0, ubo->Size(), glm::value_ptr(transform->GetTransform()));
        },
        &mTime, &mTransform, mUBO.get()
    )).After(&*windowTask));
}

void TestGame::Update(float delta)
{
    mTime += delta;
    scheduler.ExecuteAll();
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
    
    auto material = resourceManager->Get(mRenderable->GetMaterial());
    auto meshHandle = mRenderable->GetMesh();

    Texture* texture = resourceManager->Get(material->GetDiffusionTexture());
    Mesh* mesh = resourceManager->Get(meshHandle);
    Program* program = resourceManager->Get(mProgram);

    
    mRender->BindProgram(program);
    glActiveTexture(GL_TEXTURE0);
    mRender->BindTexture(texture);
    program->SetUniform1i("uAlbedo", 0);

    uint32_t index = glGetUniformBlockIndex(program->GetHandle(), "transform"); 
    glUniformBlockBinding(program->GetHandle(), index, 0);
/*    glBindBufferRange(GL_UNIFORM_BUFFER, 0, mUBO->GetHandle(), 0, mUBO->Size());

    //glBindTexture(GL_TEXTURE_2D, mTexture->GetHandle());
    
    mRender->BindVertexAttributes(mesh->mAttributes);

    for(size_t i = 0; i < mesh->mVertexData->GetBufferCount(); i++) 
    {
        auto buffer = mesh->mVertexData->GetBuffer(i);
        mRender->BindVertexBuffers(i, &buffer, 1);
    }
    mRender->BindIndexBuffer(mesh->mIndexBuffer);
    mRender->DrawIndexed(mesh->mIndexBuffer->GetIndexCount());
*/

    for(auto& buffer: grid.transformations) {
        glBindBufferRange(GL_UNIFORM_BUFFER, 0, buffer->GetHandle(), 0, buffer->Size());
        
        mRender->BindVertexAttributes(mesh->mAttributes);

        for(size_t i = 0; i < mesh->mVertexData->GetBufferCount(); i++) 
        {
            auto buffer = mesh->mVertexData->GetBuffer(i);
            mRender->BindVertexBuffers(i, &buffer, 1);
        }
        mRender->BindIndexBuffer(mesh->mIndexBuffer);
        mRender->DrawIndexed(mesh->mIndexBuffer->GetIndexCount());

    }

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
