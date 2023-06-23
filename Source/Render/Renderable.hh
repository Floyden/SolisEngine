#pragma once
#include "Mesh.hh"
#include "Material.hh"
#include "Math.hh"

namespace Solis
{

class Renderable
{
public:
	Renderable() = default;
	Renderable(HMesh mesh, HMaterial material, const Transform& transform) :
		mMesh(mesh), mMaterial(material), mTransform(transform) {};

	void SetMesh(const HMesh& mesh) { mMesh = mesh; }
	HMesh GetMesh() const { return mMesh; }

	void SetMaterial(const HMaterial& material) { mMaterial = material; }
	HMaterial GetMaterial() const { return mMaterial; }

	void SetTransform(const Transform& transform) { mTransform = transform; }
	Transform& GetTransform() { return mTransform; }
	const Transform& GetTransform() const { return mTransform; }

private:
	HMesh mMesh;
	HMaterial mMaterial;
	Transform mTransform;
};
}// namespace Solis