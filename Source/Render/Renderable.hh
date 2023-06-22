#pragma once
#include "Mesh.hh"
#include "Material.hh"

namespace Solis
{

class Renderable
{
public:
	Renderable() = default;
	Renderable(const HMesh& mesh, const HDefaultMaterial& material) :
		mMesh(mesh), mMaterial(material) {};

	void SetMesh(const HMesh& mesh) { mMesh = mesh; }
	HMesh GetMesh() const { return mMesh; }

	void SetMaterial(const HDefaultMaterial& material) { mMaterial = material; }
	HDefaultMaterial GetMaterial() const { return mMaterial; }

private:
	HMesh mMesh;
	HDefaultMaterial mMaterial;

};
}// namespace Solis