/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RadiatingForceFieldComponent
*/

import Foundation
import os.log
import RealityKit

enum RadiatingForceFieldTunables {
    //could add this to debug switches pane for runtime enable/disable, or change default as needed and run
    static var logForceFileDetails = TunableBool("Log Force Field Details", def: false)

    /// leafBlowerEnable
    /// enable or disable the force field leaf blower effect
    static var leafBlowerEnable = TunableBool("ForceField Leaf Blower Enable", def: true)
    /// leafBlowerEnable
    /// enable or disable the force field leaf blower effect
    static var kickEnable = TunableBool("ForceField Kick Enable", def: true)
    /// applyLeafBlowerDisable
    /// enable or disable the application of the force of the leaf blower effect, but still compuation and logging
    static var applyLeafBlowerDisable = TunableBool("Apply Leaf Blower Disable", def: false)
}

struct RadiatingForceFieldComponent: Component {
    // dot product of facing with normalized velocity.
    // positive means facing and velocity in similar directions
    // i.e. within 90 degrees of each other
    // this is last frame's value for edge detection
    fileprivate var lastMovementForwards: Float = 0.0
    fileprivate var lastImpulseTime = NSDate.now
    fileprivate var lastForceTime = NSDate.now
}

extension RadiatingForceFieldComponent {
    static let applyKickNotification = Notification.Name(rawValue: "RadiatingForceFieldComponent.kick")
    static let applyForceNotification = Notification.Name(rawValue: "RadiatingForceFieldComponent.force")
    static let resetKickNotification = Notification.Name(rawValue: "RadiatingForceFieldComponent.resetKick")

    fileprivate static let logDetails = false
    fileprivate static let logForceDetails = false
}

protocol HasRadiatingForceField where Self: HasKinematicVelocity {}

private struct ForceFieldCollisionInfo {
    var forceFieldWs: SIMD3<Float>
    var intruderWs: SIMD3<Float>
    var deltaXZ: SIMD3<Float>
    var forceFieldRadius: Float
    var intruderRadius: Float
    var forceFieldCoreRadius: Float

    init?(intruderEntity: Entity & HasPhysics & HasCollisionSize,
          forceFieldEntity: Entity & HasKinematicVelocity & HasRadiatingForceField & HasCollisionSize,
          forceFieldCoreEntity: Entity & IsForceFieldOwner & HasCollisionSize) {
        let logFFDetails = RadiatingForceFieldTunables.logForceFileDetails.value

        forceFieldWs = forceFieldEntity.position(relativeTo: GamePlayManager.physicsOrigin)
        intruderWs = intruderEntity.position(relativeTo: GamePlayManager.physicsOrigin)
        // only interested in 2D X-Z distance for radius
        deltaXZ = (intruderWs - forceFieldWs) * [1, 0, 1]

        let forceTransform = forceFieldEntity.transformMatrix(relativeTo: GamePlayManager.physicsOrigin)
        let forceScaleX = forceTransform.scale.x
        forceFieldRadius = forceFieldEntity.radius * forceScaleX

        let intruderTransform = intruderEntity.transformMatrix(relativeTo: GamePlayManager.physicsOrigin)
        let intruderScaleX = intruderTransform.scale.x
        intruderRadius = intruderEntity.radius * intruderScaleX

        let distanceSq = length_squared(deltaXZ)
        let radiiSum: Float = forceFieldRadius + intruderRadius
        let radiiSumSq: Float = radiiSum * radiiSum
        if logFFDetails {
            os_log(.default, log: GameLog.collision,
                   "ForceFieldCollisionInfo: distance=%0.2f vs. radiiSum=%0.2f",
                   sqrt(distanceSq), radiiSum)
        }
        if distanceSq > radiiSumSq {
            os_log(.default, log: GameLog.collision,
                   "ForceFieldCollisionInfo: Update ignoring %s vs. %s, %0.2f > %0.2f",
                   "\(intruderEntity.name)", "\(forceFieldEntity.name)", sqrt(distanceSq), radiiSum)
            return nil
        }
        /// END BANDAID

        if logFFDetails {
            os_log(.default, log: GameLog.collision,
                   "ForceFieldCollisionInfo: intruder %s vs. force field %s",
                   "\(intruderEntity.name)", "\(forceFieldEntity.name)")
        }

        // Cylindrical caps for cylinder representing force fields:
        // we expect deltaY to almost always be equal to bowlingBallRadius,
        // except the cases when ball falls into the gutter and deltaY < bowlingBallRadius, and the rare cases where
        // the ball is lifted into the air where deltaY > bowlingBallRadius
        let deltaY = intruderWs.y - forceFieldWs.y
        let forceFieldHeight = UserSettings.isTableTop ? Constants.remoteWsForceFieldHeight : Constants.paddleWsForceFieldHeight
        let max = Constants.bowlingBallRadius + forceFieldHeight
        let min = -Constants.bowlingBallRadius
        if logFFDetails {
            os_log(.default, log: GameLog.collision,
                   "ForceFieldCollisionInfo: deltaY = %0.2f,%s",
                   deltaY, "\(deltaY < min ? "<" : deltaY > max ? ">" : "=")")
        }
        if deltaY > max {
            if logFFDetails {
                os_log(.default, log: GameLog.collision, "ForceFieldCollisionInfo: ball above striker, ignoring force field")
            }
            return nil
        }
        if deltaY < min {
            if logFFDetails {
                os_log(.default, log: GameLog.collision, "ForceFieldCollisionInfo: ball below floor, ignoring force field")
            }
            return nil
        }

        let ffCenterTransform = forceFieldCoreEntity.transformMatrix(relativeTo: GamePlayManager.physicsOrigin)
        forceFieldCoreRadius = forceFieldCoreEntity.radius * ffCenterTransform.scale.x
    }
}

extension HasRadiatingForceField {

    var forceField: RadiatingForceFieldComponent {
        get { return components[RadiatingForceFieldComponent.self] ?? RadiatingForceFieldComponent() }
        set { components[RadiatingForceFieldComponent.self] = newValue }
    }

    fileprivate func applyForceImpulse(to entity: HasPhysics, info: ForceFieldCollisionInfo) {
        guard RadiatingForceFieldTunables.leafBlowerEnable.value ||
        RadiatingForceFieldTunables.kickEnable.value else { return }

        // velocity is in physics origin (world) space
        let velocity = kinematicVelocity

        // transform "forward" into physics origin (world) space
        let facing = forward(relativeTo: GamePlayManager.physicsOrigin)

        if !entity.isActive {
            os_log(.default, log: GameLog.collision, "applyForceImpulse: entity is NOT active???")
        }

        // dot product of facing with normalized velocity.
        // if that is negative, post kick reset notification.
        let movementForwards = dot(facing, velocity)
        if movementForwards < -PhysicsConstants.kickSpeedResetThreshold
        && forceField.lastMovementForwards > -PhysicsConstants.kickSpeedResetThreshold {
            NotificationCenter.default.post(name: RadiatingForceFieldComponent.resetKickNotification,
                                            object: self,
                                            userInfo: [:])
        }
        forceField.lastMovementForwards = movementForwards

        // make sure that force field facing and
        // direction from force field center to other
        // are within 90 degrees to have any leaf
        // blower or kick effect
        let dotProduct = dot(facing, info.deltaXZ)
        if dotProduct <= 0.0 {
            NotificationCenter.default.post(name: RadiatingForceFieldComponent.applyForceNotification,
                                            object: self,
                                            userInfo: ["force": Float(0.0)])
            return
        }
        var distance = length(info.deltaXZ)

        let len = length(velocity)
        if len > PhysicsConstants.kickSpeedThreshold {
            guard RadiatingForceFieldTunables.kickEnable.value else { return }

            // scale kick based on how close facing is to delta pos
            // so that kick is stronger when ff is pointing at other
            let scalar = dotProduct / distance
            let force = velocity * PhysicsConstants.kickSpeedModifier * scalar
            // Impulse = dv * mass = F * dt
            entity.applyLinearImpulse(force, relativeTo: GamePlayManager.physicsOrigin)
            if RadiatingForceFieldComponent.logForceDetails {
                let now = NSDate.now
                let deltaTime = now.timeIntervalSince(forceField.lastImpulseTime)
                forceField.lastImpulseTime = now
                os_log(.default,
                       log: GameLog.collision,
                       "Radiate Impulse dt=%.04f, F=%s, vel.xyz=%s",
                       Float(deltaTime),
                       "\(force.terseDescription)",
                       "\(velocity.terseDescription)")
            }

            NotificationCenter.default.post(name: RadiatingForceFieldComponent.applyKickNotification,
                                            object: self,
                                            userInfo: ["force": force])
        } else {
            guard RadiatingForceFieldTunables.leafBlowerEnable.value else { return }

            // "distance" is the distance from center of force field (self, FF) to center
            // of ball (entity).
            // For SwiftStrike, the Paddle will be in the center of the FF, while it will be
            // the Remote for the Table Top game.  The RealityKit physics will collide the
            // paddle and ball or the Remote and ball, but the Remote has a larger radius for
            // collision.  We want a consistent range for the distance so the FF calculations
            // result in similar force generation.  Therefore we want to offset the distance
            // calculated so that the force field has as much distance to act over in both cases.
            // This also means the force field radius has to be larger by the same amount for the
            // Remote (Remote radius - Paddle radius).
            // Range of distance is:
            //     paddle radius + ball radius to paddle force field radius + ball radius
            //     0.06875 + 0.6 to 0.885 + 0.6
            //     0.66875 to 1.485 = 0.81625
            //     Remote radius + ball radius to Remote force field radius + ball radius
            //     1.05 + 0.6 to 1.86625 + 0.6
            //     1.65 to 2.46625 = 0.81625
            // We therefore need to subtract the paddle/Remote radius plus the ball radius
            // from the distance so that we have the same range in both full court and table top
            distance -= info.forceFieldCoreRadius + info.intruderRadius

            // to get distance > 1 for pow, maintain historical range for distance
            // historically 1 + 0.6(radius of ball) + 0.06875 (radius of paddle collision)
            distance += 1.66875
            let force = PhysicsConstants.leafBlowerForce / pow(distance, 3)
            let direction = normalize(info.deltaXZ)
            let directionalForce = direction * force

            // gameplay might be interesting with
            // directionalForce *= dotProduct // scale force based on how close facing and direction are
            if !RadiatingForceFieldTunables.applyLeafBlowerDisable.value {
                entity.addForce(directionalForce, relativeTo: GamePlayManager.physicsOrigin)
                if RadiatingForceFieldComponent.logForceDetails {
                    let now = NSDate.now
                    let deltaTime = now.timeIntervalSince(forceField.lastForceTime)
                    forceField.lastForceTime = now
                    os_log(.default,
                           log: GameLog.collision,
                           "Radiate Force dt=%.04f, F=%s, dxz=%s",
                           Float(deltaTime),
                           "\(directionalForce.terseDescription)",
                           "\(info.deltaXZ.terseDescription)")
                }
            }

            NotificationCenter.default.post(name: RadiatingForceFieldComponent.applyForceNotification,
                                            object: self,
                                            userInfo: ["force": force])

            if RadiatingForceFieldComponent.logForceDetails {
                os_log(.default, log: GameLog.collision, "  d=%.02f, F=%.04f, fac=%s, dir=%s",
                       distance, force, "\(facing.terseDescription)", "\(direction.terseDescription)")
            }
        }
    }

}

extension CollisionEvent {

    func applyRadiatingForceOnColliders() {
        switch self {
        case .updated(let event):
            guard let forceEntity = event.entityA as? HasKinematicVelocity & HasRadiatingForceField & HasCollisionSize,
            let ffCenterEntity = forceEntity.parent as? IsForceFieldOwner & HasCollisionSize,
            let intruderEntity = event.entityB as? HasPhysics & HasCollisionSize else {
                return
            }

            guard let info = ForceFieldCollisionInfo(intruderEntity: intruderEntity,
                                                     forceFieldEntity: forceEntity,
                                                     forceFieldCoreEntity: ffCenterEntity) else {
                return
            }

            if RadiatingForceFieldComponent.logDetails {
                let distanceIntruder = length(event.position - info.intruderWs)
                os_log(.default, log: GameLog.collision, "ForceField:    %s, r=%0.2f, p=(%s) - dEI=%0.2f)",
                       "\(intruderEntity.name)", info.intruderRadius, "\(info.intruderWs.terseDescription)", distanceIntruder)

                let distanceForce = length(event.position - info.forceFieldWs)
                os_log(.default, log: GameLog.collision, "ForceField:    %s, r=%0.2f, p=(%s) - dEF=%0.2f)",
                       "\(forceEntity.name)", info.forceFieldRadius, "\(info.forceFieldWs.terseDescription)", distanceForce)

                os_log(.default, log: GameLog.collision, "ForceField:    e=(%s), impulse %s",
                       "\(event.position.terseDescription)", "\(event.impulse)")
            }

            forceEntity.applyForceImpulse(to: intruderEntity, info: info)
        default:
            return
        }
    }

}
