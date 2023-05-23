/*
See LICENSE folder for this sample’s licensing information.

Abstract:
game level
*/

import Combine
import Foundation
import os.log
import RealityKit

extension GameLog {
    static let ballEntity = OSLog(subsystem: subsystem, category: "ballEntity")
}

final class BallEntity: Entity, LoadedEntity, HasPhysics, HasGameAudioComponent, HasCollisionSize, HasOffScreenTracking, GameResettable {

    static let shape = ShapeResource.generateSphere(radius: Constants.bowlingBallRadius)

    private(set) static var ballEntity: BallEntity?

    static func loadAsync() -> AnyPublisher<BallEntity, Error> {
        return Entity.loadAsync(named: Asset.name(for: .ball))
            .tryMap { entity -> BallEntity in
                let pipeline = Pipeline()
                // must run ball entity through pipeline to fix glow materials for cosmic
                // there is no physics data or shouldn't be in the ball, and if so, it is dropped
                // on the floor anyway
                try pipeline.process(root: entity)
                let ballEntity = BallEntity()
                ballEntity.addChild(entity)
                ballEntity.configure()
                BallEntity.ballEntity = ballEntity
                return ballEntity
            }
            .eraseToAnyPublisher()
    }

    static let nameToEntity: [NameToEntityEntry] = [
        NameToEntityEntry(name: "floorcard") {
            let entity = FloorBillboardEntity()
            entity.floorBillboard.bias = 0.62        // cm
            entity.floorBillboard.cardOffset = 0.599 // cm
            return entity
        },
        NameToEntityEntry(name: "outlinecard") {
            let entity = CameraBillboardEntity()
            entity.cameraBillboard.rotateToMatchObjectUp = UserSettings.glowRotateWithBall
            return entity
        }
    ]

    private func configure() {
        name = "BowlingBall"
        collisionSize = CollisionSizeComponent(shape: .sphere(radius: Constants.bowlingBallRadius,
                                                              mass: PhysicsConstants.ballMass))
        collision = CollisionComponent(shapes: [BallEntity.shape],
                                       filter: CollisionFilter(group: .ball, mask: [.pin, .ground, .wall, .paddle, .forceField, .gutter, .remote]))
        physicsBody = createPhysicsBody()
        physicsMotion = .init()

        offScreenTracking = OffScreenTrackingComponent()

        // translate ball center up by ball radius so it sits on top of ground
        transform.translation = [0.0, Constants.bowlingBallRadius * PhysicsConstants.ballScale, 0.0]
        transform.scale = SIMD3(repeating: PhysicsConstants.ballScale)
        self.audio = GameAudioComponent.load(named: "ball-audio")
        _ = self.localAudioChildEntity()
        mapInNewParentEntities(map: BallEntity.nameToEntity)
    }

    func createPhysicsBody(mass: Float = PhysicsConstants.ballMass,
                           staticFriction: Float = PhysicsConstants.ballStaticFriction,
                           kineticFriction: Float = PhysicsConstants.ballKineticFriction,
                           restitution: Float = PhysicsConstants.ballRestitution) -> PhysicsBodyComponent {
        var physicsBody = PhysicsBodyComponent(shapes: [BallEntity.shape], mass: mass)
        physicsBody.material = .generate(staticFriction: staticFriction, dynamicFriction: kineticFriction, restitution: restitution)
        physicsBody.mode = .dynamic
        return physicsBody
    }

    // leave parameters with blank labels externally because this method
    // is stored in a dictionary and dereferenced without parameter
    // labels
    static func audioMotionFilter(_ entity: HasGameAudioComponent,
                                  _ config: GameAudioConfiguration.MotionEntry,
                                  _ deltaTime: TimeInterval) -> SFXCoordinator.MotionState {
        guard let ball = entity as? BallEntity,
            ball == BallEntity.ballEntity else {
            return SFXCoordinator.MotionState(active: false)
        }

        var velocity = ball.physicsMotion!.linearVelocity
        // ignore vertical part of movement: we are only interested in the ball's horizontal
        // speed.
        velocity.y = 0
        let speed = length(velocity)

        // if the ball's center is below the floor, don't play any rolling sounds anymore.
        let pos = ball.position
        if pos.y < 0 {
            return SFXCoordinator.MotionState(active: false, velocity: velocity)
        }

        var audioState = entity.localAudioChildEntity().audioState

        var smoothedSpeed: Float
        if speed > audioState.previousSpeed {
            // fast rise time
            // rise to 95% of velocity in 50ms. (Rise to 95% is same as fall to 5% from value of 1 to 0).
            let factor = pow((1.0 - 0.95), 1 / 50.0) // decay time in ms.
            let alpha = Float(pow(factor, deltaTime * 1000.0))
            smoothedSpeed = speed * (1.0 - alpha) + audioState.previousSpeed * alpha
            audioState.fastDecay = false
        } else if audioState.fastDecay {
            // after a collision, do a fast decay.
            // fall to 5% of velocity in 100ms.
            let factor = pow(0.05, 1 / 100.0) // decay time in ms.
            let alpha = Float(pow(factor, deltaTime * 1000.0))
            smoothedSpeed = speed * (1.0 - alpha) + audioState.previousSpeed * alpha
        } else {
            // slow release
            // fall to 0.500x of velocity in 350ms. <- numbers interpreted from analyzing physics in game
            let factor = pow(0.5, 1 / 250.0) // decay time in ms.
            let alpha = Float(pow(factor, deltaTime * 1000.0))
            smoothedSpeed = speed * (1.0 - alpha) + audioState.previousSpeed * alpha
        }
        audioState.previousSpeed = smoothedSpeed
        entity.localAudioChildEntity().audioState = audioState

        if smoothedSpeed > config.minimumVelocity {
            let gain = AudioPlaybackController.Decibel(config.gain.value(for: smoothedSpeed))
            let playbackSpeed = Double(config.speed.value(for: smoothedSpeed))
            return SFXCoordinator.MotionState(active: true,
                                              velocity: velocity,
                                              gain: gain,
                                              playbackSpeed: playbackSpeed,
                                              scalarVelocity: smoothedSpeed)
        }
        return SFXCoordinator.MotionState(active: false, velocity: velocity)
    }

    func gameReset() {
        self.isEnabled = false
    }

}
