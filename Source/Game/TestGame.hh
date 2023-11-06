#pragma once
#include "Defines.hh"
#include "Game.hh"
#include "Render/Renderable.hh"
#include "Render/OpenGL/UniformBuffer.hh"
#include "Plugins/SDL2_image/SDL2ImgImporter.hh"
#include "Plugins/assimp/AssimpImporter.hh"
#include "Core/Task.hh"
#include "Scene/Camera.hh"

namespace Solis
{

enum class CellType {
    eGround,
    eWall,
};

class Grid {
public:
    Vec2i extends;
    Vector<Renderable> renderables;
    Transform globalTransform;
    Vector<SPtr<UniformBuffer>> transformations;
    Vector<CellType> cells;
};

class TestGame : public Game
{
public:
    void Init() override;
    void Update(float delta) override;
    void Render() override;
    void RunMainLoop() override;
private:

    HProgram mProgram;
    SPtr<Renderable> mRenderable;
    //uint32_t mUBO;
    SPtr<UniformBuffer> mUBO;
    HTexture mTextureGround;
    HTexture mTextureWalls;
    float mTime = 0.0;

    UPtr<AssimpImporter> mSceneImporter;
    UPtr<SDL2ImgImporter> mImageImporter;
    TaskScheduler scheduler;
    Optional<Task> windowTask;
    Optional<Task> uniformTask;
    Grid grid;
    UPtr<Camera> mCamera;
    SPtr<UniformBuffer> mCameraUBO;

};

} // namespace Solis
