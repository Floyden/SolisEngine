#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>

#include "Game/Shooter.hh"
#include "Game/TestGame.hh"


#ifdef _WIN32
int WINAPI WinMain(HINSTANCE hinstance,
    HINSTANCE hprevinstance,
    LPSTR lpcmdline,
    int ncmdshow) {
#elif __linux__ || __APPLE__
int main(int argc, char* argv[]) {
#endif
    SDL_Init(SDL_INIT_EVERYTHING);
    {

    Solis::TestGame game;
    game.Init();
    game.RunMainLoop();
    game.Destroy();

    }
    SDL_Quit();
    return 0;
}