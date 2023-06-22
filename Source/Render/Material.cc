#include "Material.hh"

namespace Solis
{

DefaultMaterial::DefaultMaterial(const DefaultMaterialDesc& desc):
    mProgram(desc.program), mDiffusionTexture(desc.diffusionTexture), mNormalTexture(desc.normalTexture){};
} // namespace Solis
