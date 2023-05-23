/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityView extension to hold methods related to Metal Performance Shader postprocessing.
*/

import Foundation
import MetalKit
import RealityKit
import SwiftUI
import MetalPerformanceShaders

extension RealityView {
    func postEffectMPSGaussianBlur(context: ARView.PostProcessContext) {
        let gaussianBlur = MPSImageGaussianBlur(device: context.device, sigma: 4)
        gaussianBlur.encode(commandBuffer: context.commandBuffer,
                            sourceTexture: context.sourceColorTexture,
                            destinationTexture: context.compatibleTargetTexture)
    }
    
    func postEffectMPSSobel(context: ARView.PostProcessContext) {
        let sobel = MPSImageSobel(device: context.device)
        sobel.encode(commandBuffer: context.commandBuffer,
                     sourceTexture: context.sourceColorTexture,
                     destinationTexture: context.compatibleTargetTexture)
    }
    
    func postEffectMPSBloom(context: ARView.PostProcessContext) {
        context.prepareTexture(&self.bloomTexture)
        
        let brightness = MPSImageThresholdToZero(device: context.device,
                                                 thresholdValue: 0.2,
                                                 linearGrayColorTransform: nil)
        brightness.encode(commandBuffer: context.commandBuffer,
                          sourceTexture: context.sourceColorTexture,
                          destinationTexture: bloomTexture!)
        
        let gaussianBlur = MPSImageGaussianBlur(device: context.device, sigma: 9.0)
        gaussianBlur.encode(commandBuffer: context.commandBuffer,
                            inPlaceTexture: &bloomTexture!)
        
        let add = MPSImageAdd(device: context.device)
        add.encode(commandBuffer: context.commandBuffer,
                   primaryTexture: context.sourceColorTexture,
                   secondaryTexture: bloomTexture!,
                   destinationTexture: context.compatibleTargetTexture)
    }
    func postEffectLaPlacian(context: ARView.PostProcessContext) {
        let filter = MPSImageLaplacian()
        filter.encode(commandBuffer: context.commandBuffer,
                      sourceTexture: context.sourceColorTexture,
                      destinationTexture: context.compatibleTargetTexture)
    }
    
}
