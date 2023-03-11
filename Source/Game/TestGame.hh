#pragma once
#include "Defines.hh"
#include "Game.hh"
#include "Render/Renderable.hh"
#include "Plugins/SDL2_image/SDL2ImgImporter.hh"

namespace Solis
{

class TestGame : public Game
{
public:
    void Init() override;
    void Update(float delta) override;
    void Render() override;
    void RunMainLoop() override;
private:

    SPtr<Program> mProgram;
    SPtr<Renderable> mRenderable;
    HTexture mTexture;

    UPtr<SDL2ImgImporter> mImageImporter;

};

} // namespace Solis
