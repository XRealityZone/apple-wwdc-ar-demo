/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Defines different shape entities.
*/

import UIKit
import RealityKit
import Combine

/// Defines the common traits for all of the sample project's movable entities.
class MovableEntity: Entity, HasModel, HasCollision, HasPhysics {
  
    var size: Float!
    var color: UIColor!
    var roughness: MaterialScalarParameter!
    
    init(size: Float, color: UIColor, roughness: Float) {
        super.init()
        
        self.size = size
        self.color = color
        self.roughness = MaterialScalarParameter(floatLiteral: roughness)
        
        let mesh = generateMeshResource()
        let materials = [generateMaterial()]
        model = ModelComponent(mesh: mesh, materials: materials)
        generateCollisionShapes(recursive: true)
        physicsBody = PhysicsBodyComponent()
        physicsBody?.mode = .dynamic
    }
    
    required init() {
        fatalError("init() has not been implemented")
    }
    
    func setPhysicsBodyMode(to mode: PhysicsBodyMode) {
        physicsBody?.mode = mode
    }
    
    func generateMeshResource() -> MeshResource {
        return MeshResource.generateBox(size: size)
    }
    
    func generateMaterial() -> Material {
        return SimpleMaterial(color: color, roughness: roughness, isMetallic: true)
    }
}

/// Defines a movable entity in the shape of a box.
class BoxEntity: MovableEntity {
    override func generateMeshResource() -> MeshResource {
        return MeshResource.generateBox(size: size)
    }
}

/// Defines a movable entity in the shape of a beveled box.
class BeveledBoxEntity: MovableEntity {
    override func generateMeshResource() -> MeshResource {
        return MeshResource.generateBox(size: size, cornerRadius: size / 5.0)
    }
}

/// Defines a movable entity in the shape of a sphere
class SphereEntity: MovableEntity {
    override func generateMeshResource() -> MeshResource {
        /// spheres are specified with radius, not diameter, so the project divides the size in half
        return MeshResource.generateSphere(radius: size / 2 )
    }
}

