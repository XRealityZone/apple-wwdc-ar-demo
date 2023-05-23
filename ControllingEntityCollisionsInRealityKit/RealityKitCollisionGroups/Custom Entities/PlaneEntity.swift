/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Defines the plane shape entity.
*/

import UIKit
import RealityKit

/// Defines a plane entity to be used as a ground plane, providing a stable platform for the movable
/// entities, regardless of the size or shape of detected surfaces in the scene.
class PlaneEntity: Entity, HasModel, HasPhysics, HasCollision {
    
    required init() {
        super.init()
        
        let mesh = MeshResource.generatePlane(width: 2, depth: 2)
        let materials = [UnlitMaterial(color: .clear)]
        model = ModelComponent(mesh: mesh, materials: materials)
        generateCollisionShapes(recursive: true)
        physicsBody = PhysicsBodyComponent()
        physicsBody?.mode = .static
    }
    
}
