/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A RealityKit entity representing an animatable robot head.
*/

import RealityKit
import ARKit

class RobotHead: Entity, HasModel {
    
    // Default color values
    private let inactiveColor: SimpleMaterial.Color = .gray
    private let eyeColor: SimpleMaterial.Color = .blue
    private let eyebrowColor: SimpleMaterial.Color = .brown
    private let headColor: SimpleMaterial.Color = .green
    private let lipColor: SimpleMaterial.Color = .lightGray
    private let mouthColor: SimpleMaterial.Color = .gray
    private let tongueColor: SimpleMaterial.Color = .red
    private let clearColor: SimpleMaterial.Color = .clear
    private let notTrackedColor: SimpleMaterial.Color = UIColor.lightGray.withAlphaComponent(0.3)
    
    private var originalJawY: Float = 0
    private var originalUpperLipY: Float = 0
    private var originalEyebrowY: Float = 0
    
    private lazy var eyeLeftEntity = findEntity(named: "eyeLeft")!
    private lazy var eyeRightEntity = findEntity(named: "eyeRight")!
    private lazy var eyebrowLeftEntity = findEntity(named: "eyebrowLeft")!
    private lazy var eyebrowRightEntity = findEntity(named: "eyebrowRight")!
    private lazy var jawEntity = findEntity(named: "jaw")!
    private lazy var upperLipEntity = findEntity(named: "upperLip")!
    private lazy var headEntity = findEntity(named: "head")!
    private lazy var tongueEntity = findEntity(named: "tongue")!
    private lazy var mouthEntity = findEntity(named: "mouth")!
    
    private lazy var jawHeight: Float = {
        let bounds = jawEntity.visualBounds(relativeTo: jawEntity)
        return (bounds.max.y - bounds.min.y)
    }()
    
    private lazy var height: Float = {
        let bounds = headEntity.visualBounds(relativeTo: nil)
        return (bounds.max.y - bounds.min.y)
    }()
    
    required init() {
        super.init()
        
        if let robotHead = try? Entity.load(named: "robotHead") {
            addChild(robotHead)
        } else {
            fatalError("Error: Unable to load model.")
        }
        
        originalJawY = jawEntity.position.y
        originalUpperLipY = upperLipEntity.position.y
        originalEyebrowY = eyebrowLeftEntity.position.y
    }
    
    // MARK: - Appearance
    
    enum Appearance {
        case tracked
        case notTracked
        case intersecting
        case anchored
    }
    
    var appearance: Appearance = .notTracked {
        didSet {
            // Assign the default colors and then modify individual entities
            // for the requested appearance.
            headEntity.color = headColor
            eyeLeftEntity.color = eyeColor
            eyeRightEntity.color = eyeColor
            eyebrowLeftEntity.color = eyebrowColor
            eyebrowRightEntity.color = eyebrowColor
            upperLipEntity.color = lipColor
            jawEntity.color = lipColor
            mouthEntity.color = mouthColor
            tongueEntity.color = tongueColor
            
            switch appearance {
            case .anchored:
                headEntity.color = inactiveColor
            case .intersecting:
                headEntity.color = notTrackedColor
                fallthrough
            case .notTracked:
                eyeLeftEntity.color = notTrackedColor
                eyeRightEntity.color = notTrackedColor
                eyebrowLeftEntity.color = notTrackedColor
                eyebrowRightEntity.color = notTrackedColor
                upperLipEntity.color = notTrackedColor
                jawEntity.color = notTrackedColor
                mouthEntity.color = clearColor
                tongueEntity.color = clearColor
            default: break
            }
        }
    }
    
    // MARK: - Animations
    
    /// - Tag: InterpretBlendShapes
    func update(with faceAnchor: ARFaceAnchor) {
        // Update eyes and jaw transforms based on blend shapes.
        let blendShapes = faceAnchor.blendShapes
        guard let eyeBlinkLeft = blendShapes[.eyeBlinkLeft] as? Float,
            let eyeBlinkRight = blendShapes[.eyeBlinkRight] as? Float,
            let eyeBrowLeft = blendShapes[.browOuterUpLeft] as? Float,
            let eyeBrowRight = blendShapes[.browOuterUpRight] as? Float,
            let jawOpen = blendShapes[.jawOpen] as? Float,
            let upperLip = blendShapes[.mouthUpperUpLeft] as? Float,
            let tongueOut = blendShapes[.tongueOut] as? Float
            else { return }
        
        eyebrowLeftEntity.position.y = originalEyebrowY + 0.03 * eyeBrowLeft
        eyebrowRightEntity.position.y = originalEyebrowY + 0.03 * eyeBrowRight
        tongueEntity.position.z = 0.1 * tongueOut
        jawEntity.position.y = originalJawY - jawHeight * jawOpen
        upperLipEntity.position.y = originalUpperLipY + 0.05 * upperLip
        eyeLeftEntity.scale.z = 1 - eyeBlinkLeft
        eyeRightEntity.scale.z = 1 - eyeBlinkRight

        // Create a mirror effect:
        // Update this head's transform to be a mirror of the face anchor's position relative
        // to the camera (this entity's parent).
        guard let parent = parent else {
            // Abort updating the entity's transform if it has no parent.
            return
        }

        // Place the robot head at the same distance from the camera as the face anchor.
        let cameraTransform = parent.transformMatrix(relativeTo: nil)
        let faceTransformFromCamera = simd_mul(simd_inverse(cameraTransform), faceAnchor.transform)
        self.position.z = -faceTransformFromCamera.columns.3.z

        // Mirror the face anchor's rotation.
        let rotationEulers = faceTransformFromCamera.eulerAngles
        let mirroredRotation = Transform(pitch: rotationEulers.x, yaw: -rotationEulers.y + .pi, roll: rotationEulers.z)
        self.orientation = mirroredRotation.rotation
    }
    
    // MARK: - Proximity check to other entities
        
    func isTooCloseToAnchoredHeads(in scene: Scene) -> Bool {
        let worldPosition = position(relativeTo: nil)
        
        let anchoredHeads = scene.anchors.filter { $0.isAnchored && $0.anchoring != .init(.camera) }
        let anchoredHeadPositions = anchoredHeads.compactMap { $0.children.first?.position(relativeTo: nil) }
        for anchoredPosition in anchoredHeadPositions {
            if distance(worldPosition, anchoredPosition) < height {
                return true
            }
        }
        return false
    }
}
