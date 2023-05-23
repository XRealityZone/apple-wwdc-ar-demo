/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A surface shader that "dissolves" an entity using an image texture.
*/


#include <metal_stdlib>
#include <RealityKit/RealityKit.h>
#include "UVHelpers.h"
#include "CustomMaterialHelpers.h"

using namespace metal;

/// Implements a texture-driven dissolve effect for a custom material instance.
[[visible]]
void DissolveSurfaceShader(realitykit::surface_parameters params)
{
    // Get the first float in the custom vector, which contains the animation
    // progress for this entity as a value between 0.0 and 1.0.
    float animationProgress = params.uniforms().custom_parameter()[0];
    
    // If the value is greater than 1.0, the dissolve has completed, so there's
    // no reason to draw anything. Discard the fragment to ensure that
    // RealityKit draws nothing for this fragment.
    if (animationProgress >= 1.0) {
        discard_fragment();
        return;
    }
    
    // Replicate PhysicallyBasedMaterial's behavior for each of the physically
    // based rendering (PBR) attributes supported by CustomMaterial.
    baseColorPassThrough(params);
    normalPassThrough(params);
    roughnessPassThrough(params);
    metallicPassThrough(params);
    specularPassThrough(params);
    ambientOcclusionPassThrough(params);
    clearcoatPassThrough(params);
    emissiveColorPassThrough(params);
    
    
    // Use animationProgress to control the dissolving of the entity. The
    // higher the value (up to 1.0), the more dissolved the entity is.
    if (animationProgress > 0.0) {

        // Because the project loaded this entity from a USDZ file, get and
        // flip the UV coordinates. This is equivalent to:
        //
        //     float2 uv = params.geometry().uv0();
        //     uv.y = 1.0 - uv.y;
        auto uv = getFlippedUVs(params);

        // Sample the opacity texture value. The sampled value controls how
        // different parts of the entity dissolve. The lighter the color of the
        // texture the later in the dissolve it becomes invisible. Changing the
        // material's custom texture will yield different dissolve effects.
        float textureColor = params.textures().custom().sample(textureSampler, uv).r;

        // Implement the dissolve so that all pixels are either opaque or
        // dissolved (fully transparent). Render any value above the threshold
        // as transparent, and any value below the threshold as opaque.
        float threshold = 1.0 - animationProgress;
        if (textureColor < threshold) {
            params.surface().set_opacity(1.0);
        } else {
            // Setting the opacity to 0.0 using PBR (.lit or clearcoat) results
            // in a transparent glass-like object. This means that RealityKit
            // might render some value for this fragment due to specular
            // highlights or clearcoat. To render nothing for this fragment,
            // completely discard transparent fragments to avoid the possibility
            // of RealityKit rendering a value for this fragment.
            discard_fragment();
            
            // Once the fragment is discarded, there's no reason to continue.
            return;
        }
        
        // Define a red edge effect, which draws fragments right near the edge
        // between the transparent and opaque parts of the model. This
        // creates a red glow along the dissolving border.
        const float edgeHalfWidth = 0.04;
        if (textureColor >= threshold - edgeHalfWidth &&
            textureColor <= threshold + edgeHalfWidth) {
            params.surface().set_emissive_color(half3(1.0, 0.0, 0.0));
        }
        
        // Taper the roughness and metallic values during the dissolve to
        // progressively reduce specular highlghts during the dissolve.
        params.surface().set_roughness(animationProgress);
        params.surface().set_metallic(threshold);
    }
}
