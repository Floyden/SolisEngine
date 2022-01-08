#pragma once
#include "Defines.hh"
#include "Game.hh"

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

    GLuint mVAO;
    GLuint mVB;
    SPtr<Program> mProgram;
};

} // namespace Solis
