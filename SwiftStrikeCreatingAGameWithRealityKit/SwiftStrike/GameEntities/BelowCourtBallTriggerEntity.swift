/*
See LICENSE folder for this sample’s licensing information.

Abstract:
BelowCourtBallTriggerEntity
*/

import RealityKit

class BelowCourtBallTriggerEntity: Entity, HasCollision, HasGameAudioComponent {

    init(size: SIMD3<Float>) {
        super.init()
        let shape = ShapeResource.generateBox(size: size)
        components.set(CollisionComponent(shapes: [shape], mode: .trigger, filter: .sensor))
    }

    required init() {
        super.init()
    }
}

// This probably belongs somewhere else
extension CollisionEvents.Began {
    func isBallInGutterCollision() -> Bool {
        let hasBall = (entityA is BallEntity) || (entityB is BallEntity)
        let hasBelowCourtCollisionEntity = (entityB is BelowCourtBallTriggerEntity) || (entityA is BelowCourtBallTriggerEntity)
        return hasBall && hasBelowCourtCollisionEntity
    }
}
