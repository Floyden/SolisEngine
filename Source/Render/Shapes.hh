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
            0.0, 1.0,
            1.0, 1.0,
            0.0, 0.0,
            1.0, 0.0,
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

class Cube : public Shape
{
public:
    Cube(float size) : mSize(size) {}
    Vector<float> GetPositions() const override
    {
        auto halfSize = mSize / 2.0f;
        Vector<float> cube = 
        {
            -halfSize, -halfSize, -halfSize,
             halfSize, -halfSize, -halfSize,
            -halfSize,  halfSize, -halfSize,
             halfSize,  halfSize, -halfSize,
            -halfSize, -halfSize, halfSize,
             halfSize, -halfSize, halfSize,
            -halfSize,  halfSize, halfSize,
             halfSize,  halfSize, halfSize,
        };

        return cube;
    }

    Vector<float> GetUVs() const override
    {
        Vector<float> cube = 
        {
            0.0, 0.0,
            1.0, 0.0,
            0.0, 1.0,
            1.0, 1.0,
            0.0, 0.0,
            1.0, 0.0,
            0.0, 1.0,
            1.0, 1.0,
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
            0, 1, 3,
            3, 2, 0,

            4, 5, 7,
            7, 6, 4,

            6, 2, 0,
            0, 4, 6,

            7, 3, 1,
            1, 5, 7,

            0, 1, 5,
            5, 4, 0,

            2, 3, 7,
            7, 6, 2,
        };

        return indices;
    }
private:
    float mSize;
};


} // namespace Solis
