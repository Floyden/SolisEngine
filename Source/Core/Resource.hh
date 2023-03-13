#pragma once
#include "CoreObject.hh"
#include "Defines.hh"

class Resource : public CoreObject
{
public:
    Resource() = default;
    Resource(const Resource& other) = delete;
    Resource(Resource&& other) = default;

//    const String& GetName() const { return mName; }
//    void SetName(const String& name) { mName = name; }

private:
//    String mName;
};