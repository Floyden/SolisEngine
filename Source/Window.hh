#pragma once 
#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>

#include "Defines.hh"
#include "Input/InputEvent.hh"

namespace Solis {

enum class WindowEventType
{
    FocusLost,
    FocusGained,
    Enter,
    Leave
};

struct WindowEvent : public IEvent
{
    WindowEventType type;
};

class Window {
public:
    ~Window();

    static UPtr<Window> Create();
    void Destroy();

    void SwapWindow();

    uint32_t GetWidth() const;
    uint32_t GetHeight() const;
    float GetAspectRatio() const;

    void ProcessEvents();

    bool CloseRequested() const { return mCloseRequested; }
    bool IsFocused() const { return mFocused; }

private:
    void _HandleKeyEvents(SDL_KeyboardEvent event);
    void _HandleMouseMotionEvents(SDL_MouseMotionEvent event);
    void _HandleMouseButtonEvents(SDL_MouseButtonEvent event);
    void _HandleWindowEvents(SDL_WindowEvent event);

    void SendWindowEvent(WindowEventType);

private:
    Window() : mWindow(nullptr) {};
    Window(const Window&) = delete;
    SDL_Window* mWindow;
    SDL_GLContext mContext;

    uint32_t mLastTimestamp;
    bool mFocused;

    // tmp, get a better solution
    bool mCloseRequested = false;
};


}