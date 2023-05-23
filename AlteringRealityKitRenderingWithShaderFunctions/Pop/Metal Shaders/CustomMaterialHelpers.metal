/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Metal functions that replicate the behavior of RealityKit's PhysicallyBasedMaterial.
*/

#include "CustomMaterialHelpers.h"
#include "UVHelpers.h"

using namespace realitykit;

/// Emulates the base color behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void baseColorPassThrough(realitykit::surface_parameters params)
{
    // Retrieve the base color tint from the material.
    half3 baseColorTint = (half3)params.material_constants().base_color_tint();
    
    // Retrieve the sampled value from the material's base color texture.
    auto uv = getFlippedUVs(params);
    auto tex = params.textures();
    half3 color = tex.base_color().sample(textureSampler, uv).rgb;
    
    // Multiply the tint and the sampled value from the texture and assign the
    // result to the shader's base color property.
    color *= baseColorTint;
    params.surface().set_base_color(color);
}

/// Emulates the emissive color behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void emissiveColorPassThrough(realitykit::surface_parameters params)
{
    // Retrieve the emissive color tint.
    half3 emissiveTint = (half3)params.material_constants().emissive_color();
    
    // Sample a value from the material's emissive color texture.
    auto uv = getFlippedUVs(params);
    auto tex = params.textures();
    half3 emissiveColor = (half3)tex.emissive_color().sample(textureSampler, uv).rgb;
    
    // Multiply the tint and the sampled value and assign the result to the
    // shader's base color property.
    emissiveColor *= emissiveTint;
    params.surface().set_emissive_color(emissiveColor);
}

/// Emulates the clearcoat and clearcoat roughness behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void clearcoatPassThrough(realitykit::surface_parameters params)
{
    // Retrieve the clearcoat and clearcoat roughness from the material.
    float clearcoatScale = params.material_constants().clearcoat_scale();
    float clearcoatRoughnessScale = params.material_constants().clearcoat_roughness_scale();
    
    // Sampled values from the clearcoat and clearcoat roughness textures.
    auto uv = getFlippedUVs(params);
    auto tex = params.textures();
    half clearcoat = tex.clearcoat().sample(textureSampler, uv).r;
    half clearcoatRoughess = tex.clearcoat_roughness().sample(textureSampler, uv).r;
    
    // Multiply the scale and the sampled clearcoat value, and assign the result
    // to the shader's clearcoat properties.
    clearcoat *= clearcoatScale;
    clearcoatRoughess *= clearcoatRoughnessScale;
    params.surface().set_clearcoat(clearcoat);
    params.surface().set_clearcoat_roughness(clearcoatRoughess);
}

/// Emulates the roughness behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void roughnessPassThrough(realitykit::surface_parameters params)
{
    // Retrieve the roughness scale from the material.
    float roughnessScale = params.material_constants().roughness_scale();
    
    // Sample a value from the CustomMaterial's roughness texture.
    auto uv = getFlippedUVs(params);
    auto tex = params.textures();
    half roughness = tex.roughness().sample(textureSampler, uv).r;
    
    // Multiply the scale and the sampled value and assign the result
    // to the shader's base color property.
    roughness *= roughnessScale;
    
    // Set the final roughness value.
    params.surface().set_roughness(roughness);
}

/// Emulates the metallic behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void metallicPassThrough(realitykit::surface_parameters params)
{
    // Retrieve the metallic scale from the material.
    float metallicScale = params.material_constants().metallic_scale();
    
    // Sampled a value from the metallic texture.
    auto uv = getFlippedUVs(params);
    auto tex = params.textures();
    half metallic = tex.metallic().sample(textureSampler, uv).r;
    
    // Multiply the scale and the sampled value, and assign the result
    // to the shader's metallic property.
    metallic *= metallicScale;
    params.surface().set_metallic(metallic);
}

/// Emulates the opacity behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void blendingPassThrough(realitykit::surface_parameters params)
{
    // Retrieve the opacity scale from the material.
    float opacityScale = params.material_constants().opacity_scale();
    float opacityThreshold = params.material_constants().opacity_threshold();
    
    // Sample a value from the material's alpha map texture.
    auto uv = getFlippedUVs(params);
    auto tex = params.textures();
    half opacity = tex.opacity().sample(textureSampler, uv).r;
    
    if (opacityThreshold > 0.0) {
        // If opacity threshold is greater than 0, use masking behavior.
        // Opacity scale is ignored when using a mask.
        if (opacity > opacityThreshold) {
            params.surface().set_opacity(1.0);
        } else {
            // Setting opacity to 0.0 using PBR rendering (.lit or .clearcoat)
            // results in a transparent (but not completely invisible)
            // glass-like object. RealityKit may render some value for this
            // fragment even with an opacity of 0.0 due to specular highlights
            // or clearcoat. For masking behavior, completely discarding the
            // fragment removes the possibility that RealityKit renders anything.
            discard_fragment();
        }
    } else {
        // If opacity threshold is 0, then mutiply opacity by scale before
        // assigning.
        opacity *= opacityScale;
    }
    params.surface().set_opacity(opacity);
}

/// Emulates the specular behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void specularPassThrough(realitykit::surface_parameters params)
{
    // Retrieve the specular scale from the material.
    float specularScale = params.material_constants().specular_scale();
    
    // Sample a value from the specular texture.
    auto uv = getFlippedUVs(params);
    auto tex = params.textures();
    half specular = tex.specular().sample(textureSampler, uv).r;
    
    // Multiply the scale and the sampled value, and assign the result to the
    // shader's specular property.
    specular *= specularScale;
    params.surface().set_specular(specular);
}

/// Emulates the ambient occlusion behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void ambientOcclusionPassThrough(realitykit::surface_parameters params)
{
    // Sample a value from the material's AO texture and assign it.
    auto uv = getFlippedUVs(params);
    auto tex = params.textures();
    half ao = tex.ambient_occlusion().sample(textureSampler, uv).r;
    params.surface().set_ambient_occlusion(ao);
}

/// Emulates the normal behavior of RealityKit's `PhysicallyBasedMaterial` shader.
void normalPassThrough(realitykit::surface_parameters params)
{
    // Retrieve the sampled value from the material's normal texture.
    auto uv = getFlippedUVs(params);
    auto tex = params.textures();
    half3 color = (half3)tex.normal().sample(textureSampler, uv).rgb;
    float3 normal = (float3)unpack_normal(color);
    params.surface().set_normal(normal);
}
