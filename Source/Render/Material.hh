#pragma once
#include "Defines.hh"
#include "Program.hh"
#include "Math.hh"
#include "Texture.hh"
#include "Core/ResourceHandle.hh"

namespace Solis
{

class Material : public Resource
{
public:
	Material() = default;
	Material(Material&& material) = default;
	virtual ~Material() = default;
	virtual void Bind() = 0;
};


struct DefaultMaterialDesc{
	HProgram program;
	HTexture diffusionTexture;
	HTexture normalTexture;
};

class DefaultMaterial : public Material
{
public:
	DefaultMaterial() = default;
	DefaultMaterial(const DefaultMaterialDesc& desc);
	DefaultMaterial(DefaultMaterial&& material) = default;
	virtual ~DefaultMaterial() = default;

	const HTexture& GetDiffusionTexture() const { return mDiffusionTexture; }
	void SetDiffusionTexture(const HTexture& texture) { mDiffusionTexture = texture; }

	const HTexture& GetNormalTexture() const { return mNormalTexture; }
	void SetNormalTexture(const HTexture& texture) { mNormalTexture = texture; }

	HProgram GetProgram() const { return mProgram; }
	void SetProgram(const HProgram& program) { mProgram = program; }

	void Bind() {  };
private:
	HProgram mProgram;
	HTexture mDiffusionTexture;
	HTexture mNormalTexture;
};

using HDefaultMaterial = ResourceHandle<DefaultMaterial>;

} // namespace Solis
