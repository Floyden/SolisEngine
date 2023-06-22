#pragma once
#include "Defines.hh"
#include "Game.hh"
#include "Render/Renderable.hh"
#include "Render/OpenGL/UniformBuffer.hh"
#include "Plugins/SDL2_image/SDL2ImgImporter.hh"
#include "Core/Task.hh"
#include "Scene/Camera.hh"

namespace Solis
{

class Grid {
public:
    Vec2i extends;
    Renderable* renderable;
    Transform globalTransform;
    Vector<SPtr<UniformBuffer>> transformations;
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
    Transform mTransform;
    HTexture mTexture;
    float mTime = 0.0;

    UPtr<SDL2ImgImporter> mImageImporter;
    TaskScheduler scheduler;
    Optional<Task<>> windowTask;
    Optional<Task<>> uniformTask;
    Grid grid;
};

} // namespace Solis
