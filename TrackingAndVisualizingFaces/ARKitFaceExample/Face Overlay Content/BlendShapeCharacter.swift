/*
See LICENSE folder for this sample’s licensing information.

Abstract:
A simple cartoon character animated using ARKit blend shapes.
*/

import Foundation
import SceneKit
import ARKit

/// - Tag: BlendShapeCharacter
class BlendShapeCharacter: NSObject, VirtualContentController {
    
    var contentNode: SCNNode?
    
    private var originalJawY: Float = 0
    
    private lazy var jawNode = contentNode!.childNode(withName: "jaw", recursively: true)!
    private lazy var eyeLeftNode = contentNode!.childNode(withName: "eyeLeft", recursively: true)!
    private lazy var eyeRightNode = contentNode!.childNode(withName: "eyeRight", recursively: true)!
    
    private lazy var jawHeight: Float = {
        let (min, max) = jawNode.boundingBox
        return max.y - min.y
    }()

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard anchor is ARFaceAnchor else { return nil }

        contentNode = SCNReferenceNode(named: "robotHead")
        originalJawY = jawNode.position.y
        
        // Assign a random color to the eyes.
        let material = SCNMaterial.materialWithColor(anchor.identifier.toRandomColor())
        contentNode?.childNode(withName: "eyeLeft", recursively: true)?.geometry?.materials = [material]
        contentNode?.childNode(withName: "eyeRight", recursively: true)?.geometry?.materials = [material]
        
        return contentNode
    }
    
    /// - Tag: BlendShapeAnimation
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor
            else { return }
        
        let blendShapes = faceAnchor.blendShapes
        guard let eyeBlinkLeft = blendShapes[.eyeBlinkLeft] as? Float,
            let eyeBlinkRight = blendShapes[.eyeBlinkRight] as? Float,
            let jawOpen = blendShapes[.jawOpen] as? Float
            else { return }
        eyeLeftNode.scale.z = 1 - eyeBlinkLeft
        eyeRightNode.scale.z = 1 - eyeBlinkRight
        jawNode.position.y = originalJawY - jawHeight * jawOpen
    }
}
