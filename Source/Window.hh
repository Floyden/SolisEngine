#pragma once 
#include <SDL2/SDL.h>
#include <SDL2/SDL_syswm.h>

#include "Defines.hh"
#include "ECS/ComponentStorage.hh"
#include "Input/InputEvent.hh"

namespace Solis {

enum class WindowEventType
{
    FocusLost,
    FocusGained,
    Enter,
    Resized,
    Leave
};

struct WindowEvent : public IEvent
{
    WindowEventType type; 
};

struct WindowResizedEvent : public IEvent
{
    WindowEventType type; 
    uint32_t width;
    uint32_t height;
};

class Window : public ECS::Component {
public:
    Window(Window&& other) noexcept;
    ~Window();

    Window& operator=(Window&& other) noexcept;

    static Optional<Window> Create();
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
    void SendWindowResizedEvent(WindowEventType type, uint32_t width, uint32_t height);

    explicit Window() : mWindow(nullptr) {};
private:
    Window(const Window&) = delete;
    Window& operator=(const Window&) = delete;
    SDL_Window* mWindow;
    SDL_GLContext mContext;

    uint32_t mLastTimestamp;
    bool mFocused;

    // tmp, get a better solution
    bool mCloseRequested = false;
};


}
