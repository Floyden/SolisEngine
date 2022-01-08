#include "TestGame.hh"
#include "RandomThings.hh"

namespace Solis
{

void TestGame::Init()
{
    LoadDefaultModules();
    mModules->Init();

    glGenVertexArrays(1, &mVAO);
    glBindVertexArray(mVAO);

    glGenBuffers(1, &mVB);
    glBindBuffer(GL_ARRAY_BUFFER, mVB);
    glBufferData(GL_ARRAY_BUFFER, gTriangleData.size() * sizeof(float), gTriangleData.data(), GL_STATIC_DRAW);

    glVertexAttribPointer(
        0,                  
        3,                  
        GL_FLOAT,           // type
        GL_FALSE,           // normalized?
        0,                  // stride
        (void*)0            // array buffer offset
    );
    glEnableVertexAttribArray(0);

    mProgram = Program::Create();
    mProgram->LoadFrom(gBasicVertexShaderSource, gBasicFragmentShaderSource);
}

void TestGame::Update(float delta)
{
    mWindow->ProcessEvents();
    mRunMainLoop = !mWindow->CloseRequested();

}

void TestGame::Render()
{
    glClearColor(0.0f, 0.0f, 0.4f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glEnableVertexAttribArray(0);
    glUseProgram(mProgram->GetHandle());
    glBindVertexArray(mVAO);

    glBindBuffer(GL_ARRAY_BUFFER, mVB);

    glDrawArrays(GL_TRIANGLES, 0, 3);
    glDisableVertexAttribArray(0);

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
