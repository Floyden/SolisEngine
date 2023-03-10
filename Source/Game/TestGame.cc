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

    auto quad = Mesh::FromShape(Shapes::Square(0.5));    
    mRenderable = std::make_shared<Renderable>();
    mRenderable->SetMaterial(material);
    mRenderable->SetMesh(quad);

}

void TestGame::Update(float delta)
{
    mWindow->ProcessEvents();
    mRunMainLoop = !mWindow->CloseRequested();
}

void TestGame::Render()
{
    mRender->Clear(0.0f, 0.0f, 0.4f, 0.0f);

    auto material = mRenderable->GetMaterial();
    auto mesh = mRenderable->GetMesh();

    mRender->BindProgram(material->GetProgram());
    
    mRender->BindVertexAttributes(mesh->mAttributes);

    auto buffer = mesh->mVertexData->GetBuffer(0);
    mRender->BindVertexBuffers(0, &buffer, 1);
    mRender->BindIndexBuffer(mRenderable->GetMesh()->mIndexBuffer);
    
    mRender->DrawIndexed(mRenderable->GetMesh()->mIndexBuffer->GetIndexCount());

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
