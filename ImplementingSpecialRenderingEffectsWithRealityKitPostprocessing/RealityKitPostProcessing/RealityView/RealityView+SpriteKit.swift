/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityView extension to hold methods related to SpriteKit postprocessing.
*/

import ARKit
import Foundation
import RealityKit
import SwiftUI
import SpriteKit

extension RealityView {
    func loadSpriteKit(device: MTLDevice) {
        self.spriteKitScene?.isPaused = false
        self.skRenderer = SKRenderer(device: device)
        self.skRenderer.scene = spriteKitScene
        self.skRenderer.scene?.scaleMode = .aspectFill
        self.skRenderer.scene?.backgroundColor = .clear
        self.skRenderer.showsNodeCount = true
    }
    
    func postEffectSpriteKit(context: ARView.PostProcessContext) {
        let blitEncoder = context.commandBuffer.makeBlitCommandEncoder()
        blitEncoder?.copy(from: context.sourceColorTexture, to: context.targetColorTexture)
        blitEncoder?.endEncoding()
        
        let desc = MTLRenderPassDescriptor()
        desc.colorAttachments[0].loadAction = .load
        desc.colorAttachments[0].storeAction = .store
        desc.colorAttachments[0].texture = context.targetColorTexture
        
        skRenderer.update(atTime: context.time)
        skRenderer.render(withViewport: CGRect(x: 0, y: 0, width: context.targetColorTexture.width, height: context.targetColorTexture.height),
                          commandBuffer: context.commandBuffer,
                          renderPassDescriptor: desc)
    }
}
