#include "TestGame.hh"
#include "Render/Renderable.hh"
#include "RandomThings.hh"
#include "Core/ResourceManger.hh"
#include "Input/Input.hh"

namespace Solis
{
const String LEVEL[] = {
    "##########",
    "##......##",
    "##..##..##",
    "##......##",
    ".........."
    };
    //"##########";

const size_t WIDTH = 10;
const size_t HEIGHT = 5;


Grid GenerateGrid(HMesh cube, HMesh quad, HDefaultMaterial material) 
{
    Grid grid;

    grid.extends = Vec2i(WIDTH, HEIGHT);
    grid.globalTransform.Roatate(Vec3(1.0, 0.0, 0.0), -3.1415 * 0.5);
    grid.globalTransform.GetPosition().z -= 5.5;

    for(size_t h = 0; h < HEIGHT; h++)
    {
        for(size_t w = 0; w < WIDTH; w++)
        {
            grid.transformations.emplace_back(UniformBuffer::Create(16 * sizeof(float)));
            
            Transform trans;
            trans.GetPosition().x = w * 0.5;
            trans.GetPosition().y = h * -0.5;
            
            if(LEVEL[h][w] == '.') {
                grid.cells.emplace_back(CellType::eGround);
                grid.renderables.emplace_back(quad, material, trans);
            } else {
                grid.cells.emplace_back(CellType::eWall);
                trans.GetPosition().z = 0.25;
                grid.renderables.emplace_back(cube, material, trans);
            }

            grid.transformations.back()->WriteData(0, 16 * sizeof(float), glm::value_ptr(grid.globalTransform.GetTransform() * trans.GetTransform()));
        }
    }

    return grid;
}

void UpdateInput(std::chrono::duration<float>* delta, Camera* camera, UniformBuffer* ubo, Input* input) 
{
    bool moved = false;
    if(input->IsKeyPressed(SDLK_w)) 
    {
        camera->GetPosition() += (Vec3(0.0, 1.0, 0.0) * delta->count() * 1.0f);
        moved = true;
    }
    if(input->IsKeyPressed(SDLK_s)) 
    {
        camera->GetPosition() += (Vec3(0.0, -1.0, 0.0) * delta->count() * 1.0f);
        moved = true;
    }
    if(input->IsKeyPressed(SDLK_a)) 
    {
        camera->GetPosition() += (Vec3(-1.0, 0.0, 0.0) * delta->count() * 1.f);
        moved = true;
    }
    if(input->IsKeyPressed(SDLK_d)) 
    {
        camera->GetPosition() += (Vec3(1.0, 0.0, 0.0) * delta->count() * 1.f);
        moved = true;
    }

    if(!moved)
        return;
    
    ubo->WriteData(0, 64, glm::value_ptr(camera->GetView()));
}

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

    auto materialHandle = resourceManager->Add<DefaultMaterial>(DefaultMaterialDesc{
        .program = mProgram, 
        .diffusionTexture = mTexture
    });

    HMesh cubeHandle = resourceManager->Add(Mesh::FromShape(Shapes::Cube(0.5)));
    HMesh quadHandle = resourceManager->Add(Mesh::FromShape(Shapes::Square(0.5)));
    mRenderable = std::make_shared<Renderable>(cubeHandle, materialHandle, Transform());

    grid = GenerateGrid(cubeHandle, quadHandle, materialHandle);
    
    mUBO = UniformBuffer::Create(16 * sizeof(float));
    mCameraUBO = UniformBuffer::Create(2 * 16 * sizeof(float));

    mCamera = std::make_unique<Camera>(45.f, 800.0f/600.0f, 0.01f, 1000.f);
    mCamera->SetRotation(Quaternion(0.0, 0.0, 1.0, 0.0));
    mCameraUBO->WriteData(0, 64, glm::value_ptr(mCamera->GetView()));
    mCameraUBO->WriteData(64, 64, glm::value_ptr(mCamera->GetProjection()));

    scheduler.AddTask(
        std::bind(
            &Window::ProcessEvents,
            mWindow.get()));

    scheduler.AddTask(Task<>(std::bind(
        [](float* time, Transform* transform, UniformBuffer* ubo) {
            transform->SetPosition(Vec3(
                glm::sin(*time * 2.0) * 0.5,
                glm::cos(*time * 2.0) * 1.0,
                -2.0
            ));
            transform->Roatate(Vec3(
                0.0,
                1.0,
                0.0
            ), glm::sin(0.01));
            ubo->WriteData(0, ubo->Size(), glm::value_ptr(transform->GetTransform()));
        },
        &mTime, &mRenderable->GetTransform(), mUBO.get()
    )).After(&*windowTask));

    scheduler.AddTask(Task<>(std::bind(
        UpdateInput,
        &mDelta, mCamera.get(), mCameraUBO.get(), mModules->GetModule<Input>()
    )).After(&*windowTask));
}

void TestGame::Update(float delta)
{
    mTime += delta;
    scheduler.ExecuteAll();
    mRunMainLoop = !mWindow->CloseRequested();
}

void checkError(const std::string& msg) 
{
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
    
    auto material = resourceManager->Get<DefaultMaterial>(mRenderable->GetMaterial());
    auto meshHandle = mRenderable->GetMesh();

    Texture* texture = resourceManager->Get(material->GetDiffusionTexture());
    Mesh* mesh = resourceManager->Get(meshHandle);
    Program* program = resourceManager->Get(mProgram);

    
    mRender->BindProgram(program);
    glActiveTexture(GL_TEXTURE0);
    mRender->BindTexture(texture);
    program->SetUniform1i("uAlbedo", 0);

    uint32_t index = glGetUniformBlockIndex(program->GetHandle(), "viewProjection"); 
    glUniformBlockBinding(program->GetHandle(), index, 1);
    glBindBufferRange(GL_UNIFORM_BUFFER, 1, mCameraUBO->GetHandle(), 0, mCameraUBO->Size());

    index = glGetUniformBlockIndex(program->GetHandle(), "transform"); 
    glUniformBlockBinding(program->GetHandle(), index, 0);
    glBindBufferRange(GL_UNIFORM_BUFFER, 0, mUBO->GetHandle(), 0, mUBO->Size());


    //glBindTexture(GL_TEXTURE_2D, mTexture->GetHandle());
    
    mRender->BindVertexAttributes(mesh->mAttributes);

    for(size_t i = 0; i < mesh->mVertexData->GetBufferCount(); i++) 
    {
        auto buffer = mesh->mVertexData->GetBuffer(i);
        mRender->BindVertexBuffers(i, &buffer, 1);
    }
    mRender->BindIndexBuffer(mesh->mIndexBuffer);
    mRender->DrawIndexed(mesh->mIndexBuffer->GetIndexCount());

    for(size_t i = 0; i < WIDTH * HEIGHT; i++) 
    {
        auto& buffer = grid.transformations[i];
        Mesh* cellMesh = resourceManager->Get(grid.renderables[i].GetMesh());

        glBindBufferRange(GL_UNIFORM_BUFFER, 0, buffer->GetHandle(), 0, buffer->Size());
        

        mRender->BindVertexAttributes(cellMesh->mAttributes);

        for(size_t i = 0; i < cellMesh->mVertexData->GetBufferCount(); i++) 
        {
            auto buffer = cellMesh->mVertexData->GetBuffer(i);
            mRender->BindVertexBuffers(i, &buffer, 1);
        }
        mRender->BindIndexBuffer(cellMesh->mIndexBuffer);
        mRender->DrawIndexed(cellMesh->mIndexBuffer->GetIndexCount());

    }

    mWindow->SwapWindow();
}

void TestGame::RunMainLoop()
{
    mRunMainLoop = true;
    mLastFrame = std::chrono::steady_clock::now();

    while (mRunMainLoop) 
    {
        // Update everything
        mNow = std::chrono::steady_clock::now();
        mDelta = mNow - mLastFrame;
        mLastFrame = mNow;

        Update(mDelta.count());
        Render();
    }
}

} // namespace Solis
