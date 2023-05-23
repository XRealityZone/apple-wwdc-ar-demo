/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityView extension to hold methods related to Metal postprocessing.
*/

import Foundation
import MetalKit
import RealityKit
import SwiftUI

extension RealityView {
    
    func loadMetalPostprocessingShaders(device: MTLDevice) {
        guard let library = device.makeDefaultLibrary() else {
            fatalError()
        }
        
        if let pixelateKernel = library.makeFunction(name: "postProcessPixelate") {
            pixelatePipeline = try? device.makeComputePipelineState(function: pixelateKernel)
        }
        
        if let greyscaleKernel = library.makeFunction(name: "postProcessGreyScale") {
            grayscalePipeline = try? device.makeComputePipelineState(function: greyscaleKernel)
        }
        
        if let depthToAlphaKernel = library.makeFunction(name: "postProcessDepthToAlpha") {
            depthToAlphaPipeline = try? device.makeComputePipelineState(function: depthToAlphaKernel)
        }
        
        if let invertKernel = library.makeFunction(name: "postProcessInvert") {
            invertPipeline = try? device.makeComputePipelineState(function: invertKernel)
        }
        
        if let posterizeKernel = library.makeFunction(name: "postProcessPosterize") {
            posterizePipeline = try? device.makeComputePipelineState(function: posterizeKernel)
        }
        
        if let vignetteKernel = library.makeFunction(name: "postProcessVignette") {
            vignettePipeline = try? device.makeComputePipelineState(function: vignetteKernel)
        }
        
        if let scanlineKernel = library.makeFunction(name: "postProcessScanlines") {
            scanlinePipeline = try? device.makeComputePipelineState(function: scanlineKernel)
        }
        
        if let nightVisionKernel = library.makeFunction(name: "postProcessNightVision") {
            nightVisionPipeline = try? device.makeComputePipelineState(function: nightVisionKernel)
        }
    }
    
    func postProcessDepthToAlpha(context: ARView.PostProcessContext) {
        
        postProcessUsingMetalShader(context: context,
                                    pipeline: depthToAlphaPipeline) { encoder in
            context.prepareTexture(&self.alphaTexture, format: .r8Unorm)
            encoder.setTexture(context.sourceColorTexture, index: 0)
            encoder.setTexture(context.sourceDepthTexture, index: 1)
            encoder.setTexture(self.alphaTexture!, index: 2)
        }
    }
    
    func postProcessPixelateShader(context: ARView.PostProcessContext) {
        postProcessUsingMetalShader(context: context,
                                    pipeline: pixelatePipeline) { encoder in
            encoder.setTexture(context.sourceColorTexture, index: 0)
            encoder.setTexture(context.compatibleTargetTexture, index: 1)
            var args = self.pixelateArguments
            withUnsafeBytes(of: &args) {
                encoder.setBytes($0.baseAddress!, length: MemoryLayout<PixelateArguments>.stride, index: 0)
            }
        }
    }
    
    func postProcessNightVisionShader(context: ARView.PostProcessContext) {
        postProcessUsingMetalShader(context: context,
                                    pipeline: nightVisionPipeline) { encoder in
            encoder.setTexture(context.sourceColorTexture, index: 0)
            encoder.setTexture(context.compatibleTargetTexture, index: 1)
            var args = NightVisionArguments(seed: arc4random())
            encoder.setBytes(&args, length: MemoryLayout<NightVisionArguments>.stride, index: 0)
            
        }
    }
    
    /// Convenience method that handles postprocessing for Metal kernels that don't use a depth mask.
    func postProcessTextureOnly(context: ARView.PostProcessContext,
                                pipeline: MTLComputePipelineState) {
        postProcessUsingMetalShader(context: context,
                                    pipeline: pipeline ) { encoder in
            encoder.setTexture(context.sourceColorTexture, index: 0)
            encoder.setTexture(context.compatibleTargetTexture, index: 1)
        }
    }
    
    /// Closure used for setting input values for Metal shader postprocessing.
    public typealias MetalParameterSetup =
    (_ encoder: MTLComputeCommandEncoder) -> Void
    
    /// Private function that handles postprocessing using a Metal compute shader. The calling method can
    /// use the `parameterHandler` closure to set textures and buffers on the encoder so they're
    /// available as parameters in the shader.
    
    private func postProcessUsingMetalShader(context: ARView.PostProcessContext,
                                             pipeline: MTLComputePipelineState,
                                             parameterHandler: MetalParameterSetup?) {
        guard let encoder = context.commandBuffer.makeComputeCommandEncoder() else {
            return
        }
        
        encoder.setComputePipelineState(pipeline)
        parameterHandler?(encoder)
        
        let threadsPerGrid = MTLSize(width: context.sourceColorTexture.width,
                                     height: context.sourceColorTexture.height,
                                     depth: 1)
        
        let w = pixelatePipeline.threadExecutionWidth
        let h = pixelatePipeline.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
        
        encoder.dispatchThreads(threadsPerGrid,
                                threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
    }
}
