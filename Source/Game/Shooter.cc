#include "Shooter.hh"
#include "Plugins/SDL2_image/SDL2ImgImporter.hh"
#include "Plugins/assimp/AssimpImporter.hh"
#include "RandomThings.hh"
#include "Image.hh"
#include "Input/Input.hh"
#include "Render/OpenGL/RendererGL.hh"

namespace Solis
{

struct TransformComponent : public IComponent {
    Vec2 pos;
};

struct RenderComponent : public IComponent {
};

Shooter::Shooter()
{
}

Shooter::~Shooter()
{
    Events::Get()->Unsubscribe(this, &Shooter::OnWindowEvent);
    Events::Get()->Unsubscribe(this, &Shooter::OnMouseButton);
    Events::Get()->Unsubscribe(this, &Shooter::OnMouseMove);
    Events::Get()->Unsubscribe(this, &Shooter::OnKeyEvent);
}

void Shooter::Init()
{
    //Init Modules
    LoadDefaultModules();
    mModules->Init();
    
    auto events = mModules->GetModule<Events>();
    events->Subscribe(this, &Shooter::OnKeyEvent);
    events->Subscribe(this, &Shooter::OnMouseMove);
    events->Subscribe(this, &Shooter::OnMouseButton);
    events->Subscribe(this, &Shooter::OnWindowEvent);

    mImporter = std::make_unique<AssimpImporter>();
    mImageImporter = std::make_unique<SDL2ImgImporter>();

    // Init Shooter
    mRoot = Node::Create("Root");
    mCamera = std::make_shared<Camera>(1.0f, mWindow->GetAspectRatio(), 0.1f, 100.0f);
    mCamera->SetPosition(Vec3(0.0, 0.0, -1.0));


    // Init Render Stuff
    mRender = std::make_shared<RendererGL>();

    mProgram = Program::Create();
    mProgram->LoadFrom(gVertexShaderSource, gFragmentShaderSource);

    mDeferred = Program::Create();
    mDeferred->LoadFrom(gPassthroughShaderSource, gImageShaderSource);

    auto img = mImageImporter->Import("Resources/Floor/bricks.png");
    mTexture = Texture::Create(img);

    mMaterial = std::make_shared<DefaultMaterial>();
    mMaterial->SetTexture(mTexture);
    mMaterial->SetProgram(mProgram);
    
    auto quadData = VertexBuffer::Create({static_cast<uint32_t>(gQuadData.size()), sizeof(float)});
    quadData->WriteData(0, gQuadData.size() * sizeof(float), gQuadData.data());
    auto quadData2 = VertexBuffer::Create({static_cast<uint32_t>(gQuadData2.size()), sizeof(float)});
    quadData2->WriteData(0, gQuadData2.size() * sizeof(float), gQuadData2.data());
    auto quadUV = VertexBuffer::Create({static_cast<uint32_t>(gQuadUV.size()), sizeof(float)});
    quadUV->WriteData(0, gQuadUV.size() * sizeof(float), gQuadUV.data());
    auto quadNormal = VertexBuffer::Create({static_cast<uint32_t>(gQuadNormal.size()), sizeof(float)});
    quadNormal->WriteData(0, gQuadNormal.size() * sizeof(float), gQuadNormal.data());

    for (size_t i = 0; i < 1; i++)
    {
        auto mesh = std::make_shared<Mesh>();
        //mMeshes.emplace_back(std::make_shared<Mesh>());
        mesh->mAttributes = VertexAttributes::Create({
            VertexAttribute{0, 3, GL_FLOAT, GL_FALSE, 0},
            VertexAttribute{1, 2, GL_FLOAT, GL_FALSE, 0},
            VertexAttribute{2, 3, GL_FLOAT, GL_FALSE, 0}});

        mesh->mVertexData = std::make_shared<VertexData>();
        mesh->mVertexData->SetBuffer(0, quadData);

        mesh->mVertexData->SetBuffer(1, quadUV);
        mesh->mVertexData->SetBuffer(2, quadNormal);

        mesh->mIndexBuffer = IndexBuffer::Create({static_cast<uint32_t>(gQuadDataIdx.size())});
        mesh->mIndexBuffer->WriteData(0, gQuadDataIdx.size() * sizeof(uint32_t), gQuadDataIdx.data());

        auto renderable = std::make_shared<Renderable>();

        renderable->SetMaterial(mMaterial);
        renderable->SetMesh(mesh);
        Transform trans;
        trans.SetPosition(Vec3(0.0f, 0.0f, 1.0f));
        trans.SetScale(Vec3(0.1f));
        mRenderables[renderable] = trans;
    }



    auto mesh = mImporter->ImportMesh("Resources/Floor/Floor.gltf");
    auto renderableFloor = std::make_shared<Renderable>();
    renderableFloor->SetMaterial(mMaterial);
    renderableFloor->SetMesh(mesh);

    mRenderables[renderableFloor] = Transform();
    //mMeshes.push_back(mesh);

    //mRenderable = std::make_shared<Renderable>();
    //mRenderable->SetMesh(mesh);
    //mRenderable->SetMaterial(mMaterial);

    LoadScene();

    // TODO: MOVE THIS

    mRenderTextures[0] = std::make_shared<RenderTexture>(mWindow->GetWidth(), mWindow->GetHeight(), RenderTextureFormat::RGB8);
    mRenderTextures[1] = std::make_shared<RenderTexture>(mWindow->GetWidth(), mWindow->GetHeight(), RenderTextureFormat::RGB10A2);
    mRenderTextures[2] = std::make_shared<RenderTexture>(mWindow->GetWidth(), mWindow->GetHeight(), RenderTextureFormat::RGBA8);
    mRenderTextures[3] = std::make_shared<RenderTexture>(mWindow->GetWidth(), mWindow->GetHeight(), RenderTextureFormat::D32);
    
    mRenderTarget = std::make_shared<Mesh>();
    mRenderTarget->mAttributes = VertexAttributes::Create({
        VertexAttribute{0, 3, GL_FLOAT, GL_FALSE, 0}});

    mRenderTarget->mVertexData = std::make_shared<VertexData>();
    mRenderTarget->mVertexData->SetBuffer(0, quadData2);

    mFrame = std::make_shared<Framebuffer>();
    mFrame->BindTexture(0, mRenderTextures[0]);
    mFrame->BindTexture(1, mRenderTextures[1]);
    mFrame->BindTexture(2, mRenderTextures[2]);
    mFrame->BindDepthbuffer(mRenderTextures[3]);
    mFrame->Build();

    // Load Physics stuff
    auto physics = mModules->GetModule<Physics>();
    mShape = std::make_unique<btBoxShape>(btVector3(0.5f, 0.5f, 0.5f));
    mBody = std::make_unique<btRigidBody>(0.0f, nullptr, nullptr);
    mBody->setCollisionShape(mShape.get());
    physics->GetDynamicsWorld()->addRigidBody(mBody.get());
}

void Shooter::LoadScene()
{
}

void Shooter::OnMouseMove(InputMouseMovementEvent* event)
{
    // Looking around
    static float MOUSE_SENS = 0.008f;
    auto quatY = glm::normalize(glm::angleAxis(MOUSE_SENS * event->GetRelative().y, Vec3{1, 0, 0}));
    auto quatX = glm::normalize(glm::angleAxis(-MOUSE_SENS * event->GetRelative().x, Vec3{0, 1, 0}));
    auto res = glm::normalize(mCamera->GetRotation() * quatY * quatX);
    mCamera->SetRotation(res);
}
void Shooter::OnMouseButton(InputMouseButtonEvent* event)
{
    if(event->GetButton() != SDL_BUTTON_LEFT || !event->GetPressed())
        return;
    
    Vec2i viewport(mWindow->GetWidth(), mWindow->GetHeight());
    auto from = mCamera->ProjectRayOrigin(event->GetPosition(), viewport);
    
    btVector3 btFrom(from.x, from.y, from.z);
    btVector3 btTo(0.0f, 0.0f, 1.0f);
    btCollisionWorld::ClosestRayResultCallback result(btFrom, btTo);

    mModules->GetModule<Physics>()->GetDynamicsWorld()->rayTest(btFrom, btTo, result);

    if(result.hasHit())
    {
        std::cout << "Nice" << std::endl;
    }
}

void Shooter::OnWindowEvent(WindowEvent* event)
{/*
    switch (event->type)
    {
    case WindowEventType::Enter:
        SDL_ShowCursor(SDL_FALSE);
        break;
    case WindowEventType::Leave:
        SDL_ShowCursor(SDL_TRUE);
        break;
    default:
        break;
    }*/
}

void Shooter::OnKeyEvent(InputKeyEvent* event)
{
    static bool isToggled = false;
    if(event->GetKeycode() == SDLK_ESCAPE && !event->IsEcho())
    {
        if(isToggled) {
            SDL_ShowCursor(SDL_FALSE);
            SDL_CaptureMouse(SDL_TRUE);
        } else {
            SDL_ShowCursor(SDL_TRUE);
            SDL_CaptureMouse(SDL_FALSE);
        }
    }
}

void Shooter::Update(float delta)
{
    mWindow->ProcessEvents();
    mRunMainLoop = !mWindow->CloseRequested();

    UpdateInput(delta);
}

void Shooter::UpdateInput(float delta)
{
    static const float MOVEMENT_SPEED = 10.f;
    auto input = Input::Get();

    Vec2i movVec(0);
    if(input->IsKeyPressed(SDLK_w))
        movVec.y += 1;
    if(input->IsKeyPressed(SDLK_s))
        movVec.y -= 1;
    if(input->IsKeyPressed(SDLK_a))
        movVec.x += 1;
    if(input->IsKeyPressed(SDLK_d))
        movVec.x -= 1;

    Vec3 dir(0);
    dir += glm::normalize(mCamera->GetRotation() * Vec3(0, 0, 1)) * static_cast<float>(movVec.y);
    dir += glm::normalize(mCamera->GetRotation() * Vec3(1, 0, 0)) * static_cast<float>(movVec.x);
    dir.y = 0;

    mCamera->GetPosition() += dir * delta * MOVEMENT_SPEED;

    float up = .0f;
    if(input->IsKeyPressed(SDLK_SPACE))
        up += 1.f;
    if(input->IsKeyPressed(SDLK_LSHIFT))
        up -= 1.0f;

    mCamera->GetPosition().y += up * delta * MOVEMENT_SPEED;

}

void Shooter::Render()
{
    mFrame->Bind();
    glViewport(0,0,mWindow->GetWidth(), mWindow->GetHeight());

    mRender->Clear(0.f, 0.5f, 1.f, 1.0f);
    glEnable(GL_DEPTH_TEST);

    mRender->BindProgram(mMaterial->GetProgram());
    glActiveTexture(GL_TEXTURE0);
    mRender->BindTexture(mMaterial->GetTexture());

    auto vp = mCamera->GetProjection() * mCamera->GetView();

    for(auto& p : mRenderables)
    {
        auto& renderable = p.first;
        auto mesh = renderable->GetMesh();

        mRender->BindVertexAttributes(mesh->mAttributes);
        for (auto& attr: mesh->mAttributes->GetAttributes())
        {
            auto loc = attr.location;
            auto buffer = mesh->mVertexData->GetBuffer(loc);
            mRender->BindVertexBuffers(loc, &buffer, 1);
        }

        mRender->BindIndexBuffer(mesh->mIndexBuffer);
        

        static double counter = 0;
        mProgram->SetUniform1i("uSampler", 0);
        if(counter <= 0) 
            counter -= mDelta.count() * 1.0f;
        else 
            counter += mDelta.count() * 1.0f;

        counter *= -1.0f;

        mProgram->SetUniformMat4f("uMVP", vp * p.second.GetTransform());
        mRender->DrawIndexed(mesh->mIndexBuffer->GetIndexCount());
    }

    // Begin deferred stage
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    glViewport(0,0,mWindow->GetWidth(), mWindow->GetHeight());
    mRender->Clear(0.0f, 0.0f, 0.0f, 1.0f);

    mRender->BindProgram(mDeferred);
    //glDisable(GL_DEPTH_TEST);

    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, mRenderTextures[0]->GetHandle());
    mDeferred->SetUniform1i("uAlbedo", 0);

    glActiveTexture(GL_TEXTURE1);
    glBindTexture(GL_TEXTURE_2D, mRenderTextures[1]->GetHandle());
    mDeferred->SetUniform1i("uNormal", 1);

    glActiveTexture(GL_TEXTURE2);
    glBindTexture(GL_TEXTURE_2D, mRenderTextures[3]->GetHandle());
    mDeferred->SetUniform1i("uDepth", 2);

    mDeferred->SetUniformMat4f("uInvView", mCamera->GetInvView());
    mDeferred->SetUniformMat4f("uInvProj", mCamera->GetInvProjection());
    

    mDeferred->SetUniform3f("uLightPos", Vec3(0.1, 2.5, 5.5));
    mDeferred->SetUniform4f("uLightColor", Vec4(1.0, 0.2, 0.4, 1.0));
    mDeferred->SetUniform1f("uLightBrightness", 100.0f);
    mDeferred->SetUniform1f("uLightRadius", 20.5f);

    mRender->BindVertexAttributes(mRenderTarget->mAttributes);
    auto buffer = mRenderTarget->mVertexData->GetBuffer(0);
    mRender->BindVertexBuffers(0, &buffer, 1);
    mRender->Draw(6);

    mWindow->SwapWindow(); 
}

void Shooter::RunMainLoop()
{
    std::cout << mWindow->GetAspectRatio() << std::endl;
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