/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Demonstrates using video imagery to texture and modify the face mesh.
*/

import ARKit
import SceneKit

/// - Tag: VideoTexturedFace
class VideoTexturedFace: TexturedFace {
    
    override func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let sceneView = renderer as? ARSCNView,
            let frame = sceneView.session.currentFrame,
            anchor is ARFaceAnchor
            else { return nil }
        
        #if targetEnvironment(simulator)
        #error("ARKit is not supported in iOS Simulator. Connect a physical iOS device and select it as your Xcode run destination, or select Generic iOS Device as a build-only destination.")
        #else
        // Show video texture as the diffuse material and disable lighting.
        let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!, fillMesh: true)!
        let material = faceGeometry.firstMaterial!
        material.diffuse.contents = sceneView.scene.background.contents
        material.lightingModel = .constant

        guard let shaderURL = Bundle.main.url(forResource: "VideoTexturedFace", withExtension: "shader"),
            let modifier = try? String(contentsOf: shaderURL)
            else { fatalError("Can't load shader modifier from bundle.") }
        faceGeometry.shaderModifiers = [ .geometry: modifier]

        // Pass view-appropriate image transform to the shader modifier so
        // that the mapped video lines up correctly with the background video.
        let affineTransform = frame.displayTransform(for: .portrait, viewportSize: sceneView.bounds.size)
        let transform = SCNMatrix4(affineTransform)
        faceGeometry.setValue(SCNMatrix4Invert(transform), forKey: "displayTransform")

        contentNode = SCNNode(geometry: faceGeometry)
        #endif
        return contentNode
    }
    
}
