#pragma once
#include "Defines.hh"
namespace Solis
{

struct VertexAttribute
{
    uint32_t location;
    uint32_t typeCount;
    uint32_t type;
    bool normalized;
    uint32_t stride;
};


class VertexAttributes
{
public:
    VertexAttributes(const Vector<VertexAttribute>& attributes) :
        mAttributes(attributes) {};

    const Vector<VertexAttribute>& GetAttributes() const { return mAttributes; };

    static SPtr<VertexAttributes> Create(const Vector<VertexAttribute>& attributes) {
        auto res = std::make_shared<VertexAttributes>(attributes);
        return res;
    }
private:

    Vector<VertexAttribute> mAttributes;
};

} // namespace Solis