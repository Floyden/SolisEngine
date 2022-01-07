project('Solis', 'cpp',
    default_options : 'cpp_std=c++17')

libsdl = dependency('SDL2')
libsdl_image = dependency('SDL2_image')
libgl = dependency('GL')
libglew = dependency('GLEW')
libassimp = dependency('assimp')
libbullet = dependency('bullet')

incdir = include_directories('./Source')
brew_includes = include_directories('/opt/homebrew/include')
bullet_includes = include_directories('/opt/homebrew/include/bullet')

source = [
    'Source/Main.cc',
    'Source/Image.cc',
    'Source/Window.cc',
    'Source/Module.cc',
    'Source/Game/LevelGenerator.cc',
    'Source/Game/Shooter.cc',
    'Source/Input/Input.cc',
    'Source/Input/InputEvent.cc',
    'Source/Physics/Physics.cc',
    'Source/Plugins/assimp/AssimpImporter.cc',
    'Source/Plugins/SDL2_image/SDL2ImgImporter.cc',
    'Source/Render/Framebuffer.cc',
    'Source/Render/RenderTexture.cc',
    'Source/Render/VAOManager.cc',
    'Source/Render/VertexData.cc',
    'Source/Render/VertexBuffer.cc',
    'Source/Render/IndexBuffer.cc',
    'Source/Render/Program.cc',
    'Source/Render/Texture.cc',
    'Source/Render/Renderer.cc',
]
executable('demo', source, 
    include_directories : [incdir, brew_includes, bullet_includes], 
    dependencies : [libgl, libsdl, libsdl_image, libassimp, libbullet])