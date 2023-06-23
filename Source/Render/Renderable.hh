#pragma once
#include "Mesh.hh"
#include "Material.hh"

namespace Solis
{

class Renderable
{
public:
	Renderable() = default;
	Renderable(const HMesh& mesh, const HMaterial& material) :
		mMesh(mesh), mMaterial(material) {};

	void SetMesh(const HMesh& mesh) { mMesh = mesh; }
	HMesh GetMesh() const { return mMesh; }

	void SetMaterial(const HMaterial& material) { mMaterial = material; }
	HMaterial GetMaterial() const { return mMaterial; }

private:
	HMesh mMesh;
	HMaterial mMaterial;

};
}// namespace Solis