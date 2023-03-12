#pragma once
#include <array>
#include "Defines.hh"
#include "Game.hh"
#include "Scene/Node.hh"
#include "Scene/Camera.hh"
#include "Render/Mesh.hh"
#include "Render/Renderable.hh"
#include "Render/Framebuffer.hh"
#include "Render/RenderTexture.hh"
#include "Physics/Physics.hh"
#include "Event.hh"
#include "Math.hh"
#include "Input/InputEvent.hh"
#include "Plugins/assimp/AssimpImporter.hh"
#include "Plugins/SDL2_image/SDL2ImgImporter.hh"

namespace Solis
{
    
struct InputEvent;
struct RenderComponent;

class Shooter : public Game {
public:
    Shooter();
    ~Shooter();

    void Init() override;
    void Update(float delta) override;
    void Render() override;
    void RunMainLoop() override;

    void OnKeyEvent(InputKeyEvent*);
    void OnMouseMove(InputMouseMovementEvent*);
    void OnMouseButton(InputMouseButtonEvent*);
    void OnWindowEvent(WindowEvent*);

private:
    void UpdateInput(float delta);
    void LoadScene();

    Vector<RenderComponent*> mRenderComponents;
    int mSelectedTile;
    
    // Render Resources
    SPtr<Render::Renderer> mRender;
    
    HProgram mProgram;
    HProgram mDeferred;
    SPtr<Mesh> mRenderTarget;
    
    HTexture mTexture;
    Map<SPtr<Renderable>, Transform> mRenderables;
    SPtr<DefaultMaterial> mMaterial;

    SPtr<Camera> mCamera;
    SPtr<Node> mRoot;

    UPtr<AssimpImporter> mImporter;
    UPtr<SDL2ImgImporter> mImageImporter;

    SPtr<RenderTexture> mRenderTextures[4];
    SPtr<Framebuffer> mFrame;

    UPtr<btBoxShape> mShape;
    UPtr<btRigidBody> mBody;
};

} // namespace Solis