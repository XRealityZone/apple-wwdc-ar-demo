/*
See LICENSE folder for this sample’s licensing information.

Abstract:
PaddleEntity
*/

import Foundation
import os.log
import RealityKit

struct PaddleComponent: Component {}

extension PaddleComponent: Codable {}

protocol HasPaddle where Self: HasStandUpright {}

extension HasPaddle {

    var paddleComponent: PaddleComponent {
        get { return components[PaddleComponent.self] ?? PaddleComponent() }
        set { components[PaddleComponent.self] = newValue }
    }

}

class PaddleEntity: ForceFieldOwnerEntity, HasPhysics, HasPaddle, HasStandUpright, HasCollisionSize {

    static let shape = ShapeResource.createCapsule(totalHeight: Constants.paddleHeight,
                                                     radius: Constants.paddleRadius)

    func configure(id: UUID) {
        name = "Paddle \(self.name)"
        collisionSize = CollisionSizeComponent(shape: .capsule(totalHeight: Constants.paddleHeight,
                                                               radius: Constants.paddleRadius,
                                                               mass: PhysicsConstants.paddleMass))
        collision = CollisionComponent(shapes: [PaddleEntity.shape], filter: CollisionFilter(group: .paddle, mask: [.ball]))
        physicsBody = createPhysicsBody()
        physicsMotion = .init()
        transform.translation.y = -Constants.pinHeight / 2
        paddleComponent = PaddleComponent()
        standUpright = StandUprightComponent()
        super.configure(id: id, data: CollisionData(totalHeight: Constants.paddleForceFieldHeight, radius: Constants.paddleForceFieldRadius,
                                      group: .forceField, mask: [.ball]))

        children.append(forceFieldEntity!)
        os_log(.default, log: GameLog.player, "PaddleEntity %s configured with child ForceFieldEntity", "\(id)")
    }

    func createPhysicsBody(
        mass: Float = PhysicsConstants.paddleMass,
        friction: Float = PhysicsConstants.paddleFriction,
        restitution: Float = PhysicsConstants.paddleRestitution
    ) -> PhysicsBodyComponent {
        var physicsBody = PhysicsBodyComponent(shapes: [PaddleEntity.shape], mass: mass)
        physicsBody.material = .generate(friction: friction, restitution: restitution)
        physicsBody.mode = .kinematic
        return physicsBody
    }

}
