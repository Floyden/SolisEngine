project('Solis', 'cpp',
    default_options : 'cpp_std=c++20')

libsdl = dependency('SDL2')
libsdl_image = dependency('SDL2_image')
libgl = dependency('GL')
libglew = dependency('GLEW')
libassimp = dependency('assimp')
libbullet = dependency('bullet')
libvulkan = dependency('vulkan')

incdir = include_directories('./Source')
#brew_includes = include_directories('/opt/homebrew/include')
#bullet_includes = include_directories('C:/msys64/mingw64/include/bullet')

source = [
    'Source/Main.cc',
    'Source/Image.cc',
    'Source/Window.cc',
    'Source/Module.cc',
    'Source/Game.cc',
    'Source/Game/LevelGenerator.cc',
    'Source/Game/Shooter.cc',
    'Source/Game/TestGame.cc',
    'Source/Input/Input.cc',
    'Source/Input/InputEvent.cc',
    'Source/Physics/Physics.cc',
    'Source/Plugins/assimp/AssimpImporter.cc',
    'Source/Plugins/SDL2_image/SDL2ImgImporter.cc',
    'Source/Render/Framebuffer.cc',
    'Source/Render/RenderTexture.cc',
    'Source/Render/VertexData.cc',
    'Source/Render/Mesh.cc',
    'Source/Render/Material.cc',
    'Source/Render/Program.cc',
    'Source/Render/Texture.cc',
    'Source/Render/OpenGL/VAOManager.cc',
    'Source/Render/OpenGL/UniformBuffer.cc',
    'Source/Render/OpenGL/VertexBuffer.cc',
    'Source/Render/OpenGL/IndexBuffer.cc',
    'Source/Render/OpenGL/RendererGL.cc',
    'Source/Render/Vulkan/RendererVulkan.cc',
]
executable('demo', source, 
    include_directories : [incdir], 
    dependencies : [libgl, libsdl, libglew, libsdl_image, libvulkan, libassimp, libbullet])