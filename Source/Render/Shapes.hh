#pragma once
#include "Defines.hh"
#include "Math.hh"

namespace Solis::Shapes
{
class Shape 
{
public:
    virtual ~Shape() {};
    virtual Vector<float> GetVertices() const = 0;
    virtual Vector<uint32_t> GetIndices() const = 0;
};

class Cube : public Shape
{
public:
    Cube(float size) : mSize(size) {}
    Vector<float> GetVertices() const override
    {
        auto halfSize = mSize / 2.0f;
        Vector<float> cube = 
        {
            -halfSize, -halfSize, -halfSize,
             halfSize, -halfSize, -halfSize,
            -halfSize,  halfSize, -halfSize,
             halfSize,  halfSize, -halfSize,
            -halfSize, -halfSize,  halfSize,
             halfSize, -halfSize,  halfSize,
            -halfSize,  halfSize,  halfSize,
             halfSize,  halfSize,  halfSize
        };

        return cube;
    }

    Vector<uint32_t> GetIndices() const override
    {
        Vector<uint32_t> indices = 
        {
            0, 1, 2,
            3, 2, 1
        };

        return indices;
    }
private:
    float mSize;
};

} // namespace Solis
