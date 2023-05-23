/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RealityKit SwiftUI view.
*/

import Foundation
import SwiftUI
import RealityKit
import MetalKit
import ARKit

@available(iOS 15.0, *)
class RealityView: ARView {
    
    /// The main view for the app.
    var arView: ARView { return self }
    
    /// A view that guides the user through capturing the scene.
    var coachingView: ARCoachingOverlayView?
    
    /// The Metal device loads Metal libraries.
    var device: MTLDevice?
    
    /// The Metal library loads shader functions.
    var library: MTLLibrary?
    
    /// RealityComposer scene. Use this as a template for creating targets.
    var robotScene: AnchorEntity?
    
    /// An array that keeps a reference to the robot entities in the scene.
    var robots = [Entity]()
    
    /// Resizes the coaching view when the view size changes.
    override var frame: CGRect {
        didSet {
            coachingView?.frame = self.frame
        }
    }
    
    required init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    /// Setup behavior called when the RealityView is created.
    func setup() {
        initializeMetal()
        configureWorldTracking()
        setUpCoachingOverlay()
        setupRobots()
        ApplicationActions.shared.realityView = self
    }

    /// Called when the user taps on the app's main view.
    public func userTapped(at point: CGPoint) {
        if let tappedEntity = arView.entity(at: point) {

            guard let entity = tappedEntity.ancestorWithName(name: "Robot") else {
                print("Tapped entity is not a robot.")
                return
            }
            Task {
                await incrementPopProgress(entity: entity)
            }
        }
    }
    
    public func resetRobots() {
        for robot in robots {
            // Setting custom vector back to all zeros resets the robot to
            // visible.
            robot.setCustomVector(vector: SIMD4<Float>(x: 0.0, y: 0.0, z: 0.0, w: 0.0))
            
            // Enabling the entity causes collision and hit testing to work again.
            robot.isEnabled = true
        }
        ApplicationActions.shared.playWhoosh()
    }
    
    // MARK: - Private
    
    /// Handles increasing the progress for an entity over time by setting a custom vector that RealityKit
    /// passes to the material's shader functions.
    ///
    private func incrementPopProgress(entity: Entity) async {
        let popDuration = 0.18
        let start = Date.now.timeIntervalSince1970
        var done = false
        
        while !done {
            let progress = (Date.now.timeIntervalSince1970 - start) / popDuration
            if progress > 1.0 {
                done = true
            }
            await Task { @MainActor in
                entity.setCustomVector(vector: SIMD4<Float>(x: Float(progress), y: 0.0, z: 0.0, w: 0.0))
            }.value
        }
        
        await Task { @MainActor in
            // The entity is invisible at this point, but it still responds to
            // taps unless it's disabled.
            entity.isEnabled = false
            
            // Play a fun sound as the robot pops.
            ApplicationActions.shared.playPop()
        }.value
    }
    
    /// Creates references to the Metal device and Metal library, which are needed to load shader functions.
    private func initializeMetal() {
        guard let maybeDevice = MTLCreateSystemDefaultDevice() else {
            fatalError("Error creating default metal device.")
        }
        device = maybeDevice
        guard let maybeLibrary = maybeDevice.makeDefaultLibrary() else {
            fatalError("Error creating default metal library")
        }
        library = maybeLibrary
    }
    
    /// Sets up world tracking behavior.
    private func configureWorldTracking() {
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
        session.run(configuration)
        
        arView.renderOptions.insert(.disableMotionBlur)
    }
    
    /// Sets up the coaching overlay, which guides users through scene setup.
    private func setUpCoachingOverlay() {
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.coachingView = ARCoachingOverlayView(frame: self.frame)
            self.addSubview(self.coachingView!)
            self.coachingView?.session = self.arView.session
            self.coachingView?.goal = .horizontalPlane
            self.coachingView?.activatesAutomatically = true
            self.coachingView?.setActive(true, animated: true)
        }
    }
    
    /// Clones the template robot multiple times and lays out the copies in rows.
    private func layoutRobots(template robotTemplate: Entity) {
        let rows = 2
        let columns = 5
        let inBetweenSpace = Float(0.2)
        for rowIndex in 0..<rows {
            for columnIndex in 0..<columns {
                let robot = robotTemplate.clone(recursive: true)
                let x = Float(columnIndex) * inBetweenSpace - ( (Float(columns) * inBetweenSpace) / 2.0)
                let xOffset = (rowIndex % 2 == 0) ? -(inBetweenSpace / 2.0) : 0.0
                let z = Float(rowIndex) * inBetweenSpace - ((Float(rows) * inBetweenSpace) / 2.0)
                let location = SIMD3<Float>(x: x + xOffset, y: 0, z: z)
                robot.transform.translation = location
                robot.generateCollisionShapes(recursive: true)
                robot.name = "Robot"
                robots.append(robot)
                robotScene?.addChild(robot)
            }
        }
    }
    
    /// Loads the robot entity and creates a custom material based on its existing material.
    private func setupRobots() {
        guard let library = library else { fatalError("No Metal library available.") }
        do {
            robotScene = AnchorEntity(plane: .horizontal,
                                      classification: .any,
                                      minimumBounds: [0.1, 0.1])
            
            let surfaceShader = CustomMaterial.SurfaceShader(
                named: "DissolveSurfaceShader",
                in: library
            )
            
            let geometryModifier = CustomMaterial.GeometryModifier(
                named: "ExpandGeometryModifier",
                in: library
            )
            
            guard let robotTemplate = try? Entity.load(named: "toy_robot_vintage.usdz") else {
                fatalError("Unable to load robot model.")
            }
            
            do {
                try robotTemplate.modifyMaterials {
                    
                    // Create a custom material based on the material ($0) that
                    // RealityKit created automatically when loading the Reality
                    // Composer file, and assign it.
                    var customMaterial = try CustomMaterial(from: $0,
                                                            surfaceShader: surfaceShader,
                                                            geometryModifier: geometryModifier)
                    
                    // Use the first value of the custom vector to pass the
                    // progress value to the shader functions.
                    customMaterial.custom.value[0] = 0.0
                    
                    // Load the texture to pass to the shader functions, using
                    // the custom texture slot.
                    if let textureResource = try? TextureResource.load(named: "texture.jpg") {
                        let texture = CustomMaterial.Texture(textureResource)
                        customMaterial.custom.texture = .init(texture)
                    }
                    
                    return customMaterial
                }
            } catch {
                fatalError("Error creating custom material.")
            }
            
            
            layoutRobots(template: robotTemplate)
            if let anchor = robotScene {
                self.scene.addAnchor(anchor)
            }
        }
    }
}
