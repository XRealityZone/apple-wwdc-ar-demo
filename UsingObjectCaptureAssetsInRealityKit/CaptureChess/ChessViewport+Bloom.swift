/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Extensions that implement the bloom post-process effect using MPS.
*/

import RealityKit
import MetalPerformanceShaders

extension ChessViewport {
    /// Bloom effect
    func postEffectBloom(context: ARView.PostProcessContext) {
        context.prepareTexture(&self.bloomTexture)
        
        let brightness = MPSImageThresholdToZero(
            device: context.device,
            thresholdValue: 0.85,
            linearGrayColorTransform: nil
        )
        
        brightness.encode(
            commandBuffer: context.commandBuffer,
            sourceTexture: context.sourceColorTexture,
            destinationTexture: bloomTexture!
        )
        
        let gaussianBlur = MPSImageGaussianBlur(device: context.device, sigma: 20)
        gaussianBlur.encode(
            commandBuffer: context.commandBuffer,
            inPlaceTexture: &bloomTexture!
        )
        
        let add = MPSImageAdd(device: context.device)
        add.encode(
            commandBuffer: context.commandBuffer,
            primaryTexture: context.sourceColorTexture,
            secondaryTexture: bloomTexture!,
            destinationTexture: context.compatibleTargetTexture
        )
    }
}

extension ARView.PostProcessContext {
    /// Reallocates a new Metal output texture if the input and output textures don't match in size.
    fileprivate func prepareTexture(_ texture: inout MTLTexture?, format pixelFormat: MTLPixelFormat = .rgba8Unorm) {
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

extension RealityKit.ARView.PostProcessContext {
    /// Returns the output texture, ensuring that the pixel format is appropriate for the current device's
    /// GPU.
    fileprivate var compatibleTargetTexture: MTLTexture! {
        if self.device.supportsFamily(.apple2) {
            return targetColorTexture
        } else {
            return targetColorTexture.makeTextureView(pixelFormat: .bgra8Unorm)!
        }
    }
}
