/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityKit SwiftUI view.
*/

import ARKit
import Foundation
import RealityKit
import SwiftUI

@available(iOS 15.0, *)
class RealityView: ARView {
    
    /// The main view for the app.
    var arView: ARView { return self }
    
    /// A view that guides the user through capturing the scene.
    var coachingView: ARCoachingOverlayView?
    
    // MARK: - Metal Shader Postprocessing Properties
    
    /// Compute pipeline state for doing postprocessing with Metal shaders. Each Metal kernel uses
    /// its own pipeline state.
    var pixelatePipeline: MTLComputePipelineState!
    var grayscalePipeline: MTLComputePipelineState!
    var depthToAlphaPipeline: MTLComputePipelineState!
    var invertPipeline: MTLComputePipelineState!
    var posterizePipeline: MTLComputePipelineState!
    var vignettePipeline: MTLComputePipelineState!
    var scanlinePipeline: MTLComputePipelineState!
    var nightVisionPipeline: MTLComputePipelineState!
    var pixelateArguments = PixelateArguments(cellSizeWidth: 30, cellSizeHeight: 40)
    
    // MARK: - CoreImage Postprocessing Properties
    /// A context for doing postprocessing using Core Image.
    var ciContext: CIContext!
    var alphaTexture: MTLTexture?
    var bloomTexture: MTLTexture?
    var noiseTexture: CIImage?
    
    // MARK: - SpriteKit Renderer Properties
    
    /// The SpriteKit scene to render.
    var spriteKitScene = SKScene(fileNamed: "GameScene")
    
    /// A renderer for doing postprocessing with SpriteKit.
    var skRenderer: SKRenderer!
    
    // MARK: - Initializers
    
    required init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Setup and Configuration
    
    /// RealityKit calls this function before it renders the first frame. This method handles any
    /// setup work that has to be done after the ARView finishes its setup.
    func postProcessSetupCallback(device: MTLDevice) {
        setUpCoachingOverlay()
        loadScene()
        configureWorldTracking()
        loadMetalPostprocessingShaders(device: device)
        loadCoreImage()
        loadSpriteKit(device: device)
    }
    
    // MARK: - Private Functions
    
    /// Sets up world tracking behavior.
    private func configureWorldTracking() {
        arView.automaticallyConfigureSession = false
        let configuration = ARWorldTrackingConfiguration()
        
        let sceneReconstruction: ARWorldTrackingConfiguration.SceneReconstruction = .mesh
        if ARWorldTrackingConfiguration.supportsSceneReconstruction(sceneReconstruction) {
            configuration.sceneReconstruction = sceneReconstruction
        }
        
        let frameSemantics: ARConfiguration.FrameSemantics = [.smoothedSceneDepth, .sceneDepth]
        if ARWorldTrackingConfiguration.supportsFrameSemantics(frameSemantics) {
            configuration.frameSemantics.insert(frameSemantics)
        }
        
        configuration.planeDetection.insert(.horizontal)
        arView.session.run(configuration)
        
        arView.renderOptions.insert(.disableMotionBlur)
    }
    
    /// Sets up the coaching overlay, which guides users through scene setup.
    private func setUpCoachingOverlay() {
        self.coachingView = ARCoachingOverlayView(frame: self.frame)
        self.addSubview(self.coachingView!)
        self.coachingView?.session = self.arView.session
        self.coachingView?.delegate = self
        self.coachingView?.goal = .horizontalPlane
        self.coachingView?.activatesAutomatically = true
        self.coachingView?.setActive(true, animated: true)
    }
    
    private func loadScene() {
        let boxAnchor = try! Experience.loadBox()
        arView.scene.anchors.append(boxAnchor)
    }
}

// MARK: - Postprocessing -

@available(iOS 15.0, *)
extension RealityView {
    
    func setupPostProcessing() {
        arView.renderCallbacks.prepareWithDevice = self.postProcessSetupCallback
        arView.renderCallbacks.postProcess = self.postProcess
        arView.cameraMode = .ar
        arView.environment.background = .cameraFeed()
    }
    
    // MARK: -
    func postProcess(context: ARView.PostProcessContext) {
        switch ApplicationState.shared.mode {
            case .noPostProcessing:
                postEffectNone(context: context)
                
                // Metal Shader Postprocessing
            case .metalPixelate:
                postProcessPixelateShader(context: context)
            case .metalGreyscale:
                postProcessTextureOnly(context: context,
                                       pipeline: grayscalePipeline)
            case .metalInvert:
                postProcessTextureOnly(context: context,
                                       pipeline: invertPipeline)
            case .metalPosterize:
                postProcessTextureOnly(context: context,
                                       pipeline: posterizePipeline)
            case .metalVignette:
                postProcessTextureOnly(context: context,
                                       pipeline: vignettePipeline)
            case .metalScanlines:
                postProcessTextureOnly(context: context,
                                       pipeline: scanlinePipeline)
            case .metalNightVision:
                postProcessNightVisionShader(context: context)
                
                // Metal Performance Shader Postprocessing
            case .mpsGaussianBlur:
                postEffectMPSGaussianBlur(context: context)
            case .mpsSobel:
                postEffectMPSSobel(context: context)
            case .mpsBloom:
                postEffectMPSBloom(context: context)
            case .mpsLaplacian:
                postEffectLaPlacian(context: context)
                
                // Core Image Postprocessing
            case .ciComicEffect:
                postProcessCoreImage(context: context,
                                     filter: CIFilter.comicEffect())
            case .ciVintageTransfer:
                postProcessCoreImage(context: context,
                                     filter: CIFilter.photoEffectTransfer())
            case .ciGlassDistortion:
                postEffectGlassDistortion(context: context)
            case .ciDotScreen:
                postProcessCoreImage(context: context,
                                     filter: CIFilter.dotScreen())
            case .ciLineScreen:
                postProcessCoreImage(context: context,
                                     filter: CIFilter.lineScreen())
            case .ciCrystallize:
                postProcessCoreImage(context: context,
                                     filter: CIFilter.crystallize())
            case .ciZoomBlur:
                postProcessCoreImage(context: context,
                                     filter: CIFilter.zoomBlur())
            case .ciHueAdjust:
                postEffectHueAdjust(context: context)
            case .ciVibrance:
                postProcessCoreImage(context: context,
                                     filter: CIFilter.vibrance())
            case .ciFalseColor:
                postEffectFalseColor(context: context)
            case .ciNoir:
                postProcessCoreImage(context: context,
                                     filter: CIFilter.photoEffectNoir())
            case .ciDrost:
                postEffectDrost(context: context)
            case .ciHoleDistortion:
                postEffectHoleDistortion(context: context)
                
                // Spritekit Rendering Postprocessing
            case .spriteKit:
                postEffectSpriteKit(context: context)
                
                // Multiple Technologies
            case .mPointillize:
                postProcessDepthMaskedCoreImage(context: context,
                                                filter: CIFilter.pointillize())
        }
    }
    
    /// This postprocess method is a simple pass-through that doesn't change what RealityKit renders.
    /// When an app has a postprocess render callback function registered, the callback must encode to
    /// `targetColorTexture` or nothing renders. This method uses a blit encoder to copy the
    /// rendered RealityKit scene contained in`sourceColorTexture` to the render output
    /// (`targetColorTexture`).
    func postEffectNone(context: ARView.PostProcessContext) {
        let blitEncoder = context.commandBuffer.makeBlitCommandEncoder()
        blitEncoder?.copy(from: context.sourceColorTexture, to: context.targetColorTexture)
        blitEncoder?.endEncoding()
    }
}
