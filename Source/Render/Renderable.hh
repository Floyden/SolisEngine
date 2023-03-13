#pragma once
#include "Mesh.hh"
#include "Material.hh"

namespace Solis
{
class Renderable
{
public:
	void SetMesh(const HMesh& mesh) { mMesh = mesh; }
	HMesh GetMesh() const { return mMesh; }

	void SetMaterial(const HDefaultMaterial& material) { mMaterial = material; }
	HDefaultMaterial GetMaterial() const { return mMaterial; }

private:
	HMesh mMesh;
	HDefaultMaterial mMaterial;

};
}// namespace Solis