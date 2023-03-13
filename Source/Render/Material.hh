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

	const HTexture& GetTexture() const { return mTexture; }
	void SetTexture(const HTexture& texture) { mTexture = texture; }

	HProgram GetProgram() const { return mProgram; }
	void SetProgram(const HProgram& program) { mProgram = program; }

private:
	HTexture mTexture;
	HProgram mProgram;
};


class DefaultMaterial : public Material
{
public:
	DefaultMaterial() = default;
	DefaultMaterial(DefaultMaterial&& material) = default;
	virtual ~DefaultMaterial() = default;
/*
	SPtr<Texture> GetTexture() const { return mTexture; }
	void SetTexture(const SPtr<Texture> texture) { mTexture = texture; }

	SPtr<Program> GetProgram() const { return mProgram; }
	void SetProgram(const SPtr<Program> program) { mProgram = program; }*/

	void Bind() {  };
private:
};

using HDefaultMaterial = ResourceHandle<DefaultMaterial>;

} // namespace Solis
