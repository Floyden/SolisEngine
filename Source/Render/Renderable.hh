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

	void SetMaterial(const SPtr<DefaultMaterial>& material) { mMaterial = material; }
	SPtr<DefaultMaterial> GetMaterial() const { return mMaterial; }

private:
	HMesh mMesh;
	SPtr<DefaultMaterial> mMaterial;

};
}// namespace Solis