#include "TestGame.hh"
#include "Render/Renderable.hh"
#include "RandomThings.hh"

namespace Solis
{

void TestGame::Init()
{
    LoadDefaultModules();
    mModules->Init();

    auto program = Program::Create();
    program->LoadFrom(gBasicVertexShaderSource, gBasicFragmentShaderSource);

    auto material = std::make_shared<DefaultMaterial>();
    material->SetProgram(program);

    auto triangleData = std::make_shared<VertexData>();
    triangleData->SetBuffer(0, VertexBuffer::Create(VertexBufferDesc{
        static_cast<uint32_t>(gTriangleData.size()),
        sizeof(float)
    }));
    triangleData->GetBuffer(0)->WriteData(0, gTriangleData.size() * sizeof(float), gTriangleData.data());

    std::vector<VertexAttribute> attributeList {
        VertexAttribute{
            0,
            3,
            GL_FLOAT,
            GL_FALSE,
            0
        }
    };
    auto attributes = VertexAttributes::Create(attributeList);

    auto mesh = std::make_shared<Mesh>();
    mesh->mVertexData = triangleData;
    mesh->mAttributes = attributes;
    
    mTriangle = std::make_shared<Renderable>();
    mTriangle->SetMaterial(material);
    mTriangle->SetMesh(mesh);
}

void TestGame::Update(float delta)
{
    mWindow->ProcessEvents();
    mRunMainLoop = !mWindow->CloseRequested();
}

void TestGame::Render()
{
    mRender->Clear(0.0f, 0.0f, 0.4f, 0.0f);

    auto material = mTriangle->GetMaterial();
    auto mesh = mTriangle->GetMesh();

    mRender->BindProgram(material->GetProgram());
    
    mRender->BindVertexAttributes(mesh->mAttributes);

    auto buffer = mesh->mVertexData->GetBuffer(0);
    mRender->BindVertexBuffers(0, &buffer, 1);
    
    mRender->Draw(3);

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
