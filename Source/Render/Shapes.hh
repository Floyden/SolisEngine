#pragma once
#include "Defines.hh"
#include "Math.hh"

namespace Solis::Shapes
{
class Shape 
{
public:
    virtual ~Shape() {};
    virtual Vector<float> GetPositions() const = 0;
    virtual Vector<float> GetUVs() const = 0;
    virtual Vector<float> GetNormals() const = 0;
    virtual Vector<uint32_t> GetIndices() const = 0;
};

class Square : public Shape
{
public:
    Square(float size) : mSize(size) {}
    Vector<float> GetPositions() const override
    {
        auto halfSize = mSize / 2.0f;
        Vector<float> cube = 
        {
            -halfSize, -halfSize, 0.0,
             halfSize, -halfSize, 0.0,
            -halfSize,  halfSize, 0.0,
             halfSize,  halfSize, 0.0
        };

        return cube;
    }

    Vector<float> GetUVs() const override
    {
        Vector<float> cube = 
        {
            1.0, 1.0,
            1.0, 0.0,
            0.0, 0.0,
            0.0, 1.0,
        };

        return cube;
    }

    Vector<float> GetNormals() const override
    {
        Vector<float> cube = 
        {
            0.0, 0.0, 1.0,
            0.0, 0.0, 1.0,
            0.0, 0.0, 1.0,
            0.0, 0.0, 1.0,
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
