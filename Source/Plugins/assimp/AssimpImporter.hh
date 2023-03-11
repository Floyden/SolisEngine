#pragma once
#include <assimp/LogStream.hpp>
#include <assimp/scene.h>
#include "Defines.hh"
#include "Scene/Node.hh"
#include "Render/Mesh.hh"

namespace Solis
{

class AssimpLogStream : public Assimp::LogStream
{
public:
    AssimpLogStream() {}
    ~AssimpLogStream() {}

    void write(const char* msg) {
        std::cout << msg << std::endl;
    }
};

class AssimpImporter
{
public:
    AssimpImporter();
    ~AssimpImporter();

    SPtr<Node> ImportScene(const String& path);

    /// Load the first found mesh
    UPtr<Mesh> ImportMesh(const String& path);
};

} //namespace Solis