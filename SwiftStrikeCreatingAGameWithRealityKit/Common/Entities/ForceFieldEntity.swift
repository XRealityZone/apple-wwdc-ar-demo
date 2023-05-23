/*
See LICENSE folder for this sample’s licensing information.

Abstract:
ForceFieldEntity
*/

import Foundation
import os.log
import RealityKit

protocol IsForceFieldOwner where Self: Entity {
    var forceFieldEntity: ForceFieldEntity? { get }
}

open class ForceFieldOwnerEntity: Entity, HasDeviceIdentifier, IsForceFieldOwner, HasGameAudioComponent {

    func configure(id: UUID, data: CollisionData) {
        deviceIdentifier = DeviceIdentifierComponent(id)
        let forceFieldEntity = ForceFieldEntity(named: self.name)
        addChild(forceFieldEntity)
        forceFieldEntity.configure(data)
    }

    var forceFieldEntity: ForceFieldEntity? {
        return self.findFirstChild(ofType: ForceFieldEntity.self)
    }

}

class ForceFieldEntity: Entity, HasCollision, HasPhysics, HasKinematicVelocity,
    HasRadiatingForceField, HasGameAudioComponent, HasCollisionSize {

    func configure(_ data: CollisionData) {
        guard let parent = parent else {
            fatalError("ForceFieldEntity requires parent before configuring")
        }
        name = "ForceField \(self.name)"
        let scaleFactor = parent.transformMatrix(relativeTo: GamePlayManager.physicsOrigin).scale.x
        let radius = data.radius / scaleFactor
        let totalHeight = data.totalHeight / scaleFactor
        collisionSize = CollisionSizeComponent(shape: .capsule(totalHeight: totalHeight, radius: radius, mass: 0.0))
        let forceFieldShape = ShapeResource.createCapsule(totalHeight: collisionSize.shape.totalHeight, radius: radius)
        collision = CollisionComponent(shapes: [forceFieldShape], mode: .trigger, filter: CollisionFilter(group: data.group, mask: data.mask))
        kinematicVelocityComponent = KinematicVelocityComponent(self)
        forceField = RadiatingForceFieldComponent()

        // force fields are disabled by default so they
        // don't affect the ball until we want them to
        isEnabled = false
    }

}
