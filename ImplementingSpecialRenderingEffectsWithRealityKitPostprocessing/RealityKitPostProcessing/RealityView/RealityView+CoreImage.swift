/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityView extension to hold methods related to Core Image postprocessing.
*/

import ARKit
import CoreImage.CIFilterBuiltins
import Foundation
import RealityKit
import SwiftUI

extension RealityView {
    func loadCoreImage() {
        
        if let device = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: device)
        }
        
        guard let imageURL = Bundle.main.url(forResource: "noise",
                                             withExtension: "png") else {
            fatalError("Unable to create URL to noise texture.")
        }
        guard let texture = CIImage(contentsOf: imageURL) else {
            fatalError("Unable to load Musgrave.png.")
        }
        noiseTexture = texture
    }
    
    // MARK: -
    
    func postEffectDrost(context: ARView.PostProcessContext) {
        let filter = CIFilter.droste()
        filter.insetPoint0 = CGPoint(x: context.sourceColorTexture.width / 2,
                                     y: context.sourceColorTexture.height / 2)
        filter.periodicity = 2
        filter.rotation = 1
        postProcessCoreImage(context: context,
                             filter: filter)
    }
    
    func postEffectHoleDistortion(context: ARView.PostProcessContext) {
        let filter = CIFilter.holeDistortion()
        filter.center = CGPoint(x: context.sourceColorTexture.width / 2,
                                y: context.sourceColorTexture.height / 2)
        filter.radius = 300
        postProcessCoreImage(context: context,
                             filter: filter)
    }
    
    func postEffectFalseColor(context: ARView.PostProcessContext) {
        let filter = CIFilter.falseColor()
        filter.color0 = CIColor.blue
        filter.color1 = CIColor.yellow
        postProcessCoreImage(context: context,
                             filter: filter)
    }
    
    func postEffectHueAdjust(context: ARView.PostProcessContext) {
        let filter = CIFilter.hueAdjust()
        let time = Float(context.time / 3.0)
        filter.angle = sinf(time * Float.pi)
        postProcessCoreImage(context: context,
                             filter: filter)
    }
    
    func postEffectGlassDistortion(context: ARView.PostProcessContext) {
        guard let bump = noiseTexture else {
            fatalError("Unable to access noise texture.")
        }
        let filter = CIFilter.glassDistortion()
        let center = CGPoint(x: Double(context.sourceColorTexture.width) / 2.0,
                             y: Double(context.sourceColorTexture.height) / 2.0)
        filter.textureImage = bump
        filter.center = center
        postProcessCoreImage(context: context,
                             filter: filter)
    }
    
    func postProcessDepthMaskedCoreImage(context: ARView.PostProcessContext,
                                         filter: CIFilter) {
        postProcessDepthToAlpha(context: context)
        
        let sourceColor = CIImage(mtlTexture: context.sourceColorTexture)!
            .oriented(.downMirrored)
        
        let maskImage = CIImage(mtlTexture: self.alphaTexture!)!
            .oriented(.downMirrored)
        
        filter.setValue(sourceColor, forKey: kCIInputImageKey)
        guard let stylizedImage = filter.outputImage else {
            fatalError("Error applying filter to frame buffer.")
        }
        
        let blend = CIFilter.blendWithRedMask()
        blend.inputImage = stylizedImage
        blend.backgroundImage = sourceColor
        blend.maskImage = maskImage
        
        let output = blend.outputImage!.settingAlphaOne(in: sourceColor.extent)
        
        let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB) ?? CGColorSpaceCreateDeviceRGB()
        
        self.ciContext.render(output,
                              to: context.compatibleTargetTexture!,
                              commandBuffer: context.commandBuffer,
                              bounds: sourceColor.extent,
                              colorSpace: colorSpace)
    }
    
    /// Handles core image postprocessing when no custom options need to be set.
    func postProcessCoreImage(context: ARView.PostProcessContext,
                              filter: CIFilter) {
        
        guard let input = CIImage(mtlTexture: context.sourceColorTexture) else {
            fatalError("Unable to create CIImage from Metal texture.")
        }
        filter.setValue(input, forKey: kCIInputImageKey)
        guard let output = filter.outputImage else {
            fatalError("Error applying filter to frame buffer.")
        }
        
        let destination = CIRenderDestination(mtlTexture: context.compatibleTargetTexture,
                                              commandBuffer: context.commandBuffer)
        destination.isFlipped = false
        _ = try? self.ciContext.startTask(toRender: output, to: destination)
    }
}
