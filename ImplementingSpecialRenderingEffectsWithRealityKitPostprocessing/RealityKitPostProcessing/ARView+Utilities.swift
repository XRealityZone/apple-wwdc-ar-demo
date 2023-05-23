/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utility methods for ARView and its nested classes.
*/

import Foundation
import RealityKit
import Metal

extension RealityKit.ARView.PostProcessContext {
    
    /// Returns the output texture, ensuring that the pixel format is appropriate for the current device's
    /// GPU.
    var compatibleTargetTexture: MTLTexture! {
        if self.device.supportsFamily(.apple2) {
            return targetColorTexture
        } else {
            return targetColorTexture.makeTextureView(pixelFormat: .bgra8Unorm)!
        }
    }
}

extension ARView.PostProcessContext {
    /// Reallocates a new Metal output texture if the input and output textures don't match in size.
    func prepareTexture(_ texture: inout MTLTexture?, format pixelFormat: MTLPixelFormat = .rgba8Unorm) {
        if texture?.width != self.sourceColorTexture.width
            || texture?.height != self.sourceColorTexture.height {
            let descriptor = MTLTextureDescriptor()
            descriptor.width = self.sourceColorTexture.width
            descriptor.height = self.sourceColorTexture.height
            descriptor.pixelFormat = pixelFormat
            descriptor.usage = [.shaderRead, .shaderWrite]
            texture = self.device.makeTexture(descriptor: descriptor)
        }
    }
}
