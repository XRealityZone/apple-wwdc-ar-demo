/*
See LICENSE folder for this sample’s licensing information.

Abstract:
RemoteEntity
*/

import Combine
import Foundation
import os.log
import RealityKit

extension GameLog {
    static let remoteEntity = OSLog(subsystem: subsystem, category: "remoteEntity")
}

struct CollisionData {
    let cylinderHeight: Float
    let radius: Float
    let group: CollisionGroup
    let mask: CollisionGroup

    var totalHeight: Float { return cylinderHeight + (2.0 * radius) }

    init(totalHeight: Float, radius: Float, group: CollisionGroup, mask: CollisionGroup) {
        self.cylinderHeight = totalHeight - (2.0 * radius)
        if self.cylinderHeight < 0.0 {
            fatalError(String(format: "CollisionData() inited with illegal totalHeight (%0.4f) must be >= (2 * radius) (%0.4f)",
                              totalHeight, 2.0 * radius))
        }
        self.radius = radius
        self.group = group
        self.mask = mask
    }
}

enum RemoteTunables {
    /// maxSpeed
    /// is the maximum distance (meters) per second the Remote can move towards its target (reticle)
    static var maxSpeed = TunableScalar<Float>("Remote Max Speed", min: 1.0, max: 60.0, def: 4.5)
    /// easeInDistance
    /// if we are closer than this distance, we use deceleration to ease in to closeEnough distance
    /// if we are farther than this distance, we use the accel and maxSpeed to get up to maxSpeed and no higher
    static var easeInDistance = TunableScalar<Float>("Remote Ease-in Distance", min: 0.0, max: 1.0, def: 0.25)
    /// closeEnough
    /// if we are closer than this distance, we go directly to the target
    /// if we are farther than this distance, we use the deceleration to ease in to closeEnough
    static var closeEnough = TunableScalar<Float>("Remote Close Enough", min: 0.001, max: 1.0, def: 0.1)
    /// acceleration
    /// multiplied by distance to target and added to current speed to accelerate towards maxSpeed
    static var acceleration = TunableScalar<Float>("Remote Acceleration", min: 0.0, max: 100.0, def: 10.0)
    /// deceleration
    /// multiplied by `deltaTime` (the amount of time elapsed since the previous frame) and added to current speed to decelerate towards 0
    static var deceleration = TunableScalar<Float>("Remote Deceleration", min: 0.0, max: 200.0, def: 100.0)
    /// boundsEnable
    /// enable or disable bounds
    static var boundsEnable = TunableBool("Remote Enable Bounds", def: true)
    /// boundsBuffer
    /// distance to expand bounds beyond playfield physical bounds
    static var boundsBuffer = TunableScalar<Float>("Remote Bounds Buffer", min: 0.0, max: 15.0, def: 6.0)
    /// turnRate
    /// maximum angle change per second in radians
    static var turnRate = TunableScalar<Float>("Remote Turn Rate", min: 0.0, max: 60.0, def: 20.0 )
}

struct RemoteVelocityComponent: Component {
    var targetSpeed: Float = 0.0
    var velocity = SIMD3<Float>()
}

extension RemoteVelocityComponent: Codable {}

protocol HasRemoteVelocity where Self: Entity {}

extension HasRemoteVelocity {

    var remoteVelocity: RemoteVelocityComponent {
        get { return components[RemoteVelocityComponent.self] ?? RemoteVelocityComponent() }
        set { components[RemoteVelocityComponent.self] = newValue }
    }

    var targetSpeed: Float {
        get { return remoteVelocity.targetSpeed }
        set { remoteVelocity.targetSpeed = newValue }
    }

    // velocity in meters/second
    var velocity: SIMD3<Float> {
        get { return remoteVelocity.velocity }
        set { remoteVelocity.velocity = newValue }
    }

    func velocityReset() {
        velocity = .zero
    }
}

class RemoteEntity: ForceFieldOwnerEntity, HasPhysics, HasModel, HasCollisionSize, HasRemoteVelocity, HasChildEntitySwitch {

    static var strikerModelEntity: Entity!
    static var strikerModelEntityA: Entity!
    static var strikerModelEntityB: Entity!

    static func loadAsync() -> AnyPublisher<Void, Error> {
        var toLoad = [AssetToLoad]()

        toLoad.append(AssetToLoad(for: .striker, options: .none))
        toLoad.append(AssetToLoad(for: .striker, options: .teamA))
        toLoad.append(AssetToLoad(for: .striker, options: .teamB))

        return loadEntitiesAsync(toLoad)
        .map { entitiesLoaded -> Void in
            RemoteEntity.strikerModelEntity = entitiesLoaded[[.none]]
            RemoteEntity.strikerModelEntityA = entitiesLoaded[[.teamA]]
            RemoteEntity.strikerModelEntityB = entitiesLoaded[[.teamB]]
            RemoteEntity.strikerModelEntity.name = Team.none.rawValue
            RemoteEntity.strikerModelEntityA.name = Team.teamA.rawValue
            RemoteEntity.strikerModelEntityB.name = Team.teamB.rawValue
        }
        .tryMap { $0 }  // Never -> Error
        .eraseToAnyPublisher()
    }

    private var remoteRadiusLs: Float = 0.0
    private var remoteHeight: Float = 0.0
    private var remoteGroup = CollisionGroup.all
    private var remoteMask = CollisionGroup.all
    private var framesWithNoCollision: Int = 0

    required init() {}

    private func configurePhysics() {
        collisionSize = CollisionSizeComponent(shape: .capsule(totalHeight: remoteHeight,
                                               radius: remoteRadiusLs,
                                               mass: PhysicsConstants.remoteMass))
        let shape = ShapeResource.createCapsule(totalHeight: collisionSize.shape.totalHeight, radius: remoteRadiusLs)
        collision = CollisionComponent(shapes: [shape], mode: .default, filter: CollisionFilter(group: remoteGroup, mask: remoteMask))
        physicsBody = createPhysicsBody(shape)
        physicsMotion = .init()
    }

    func configure(team: Team,
                   msToLsScale: Float,
                   remoteData: CollisionData) {
        name = "Remote \(self.name)"
        remoteVelocity = RemoteVelocityComponent()
        deviceIdentifier = DeviceIdentifierComponent()
        childEntitySwitch = ChildEntitySwitchComponent()
        remoteHeight = remoteData.totalHeight
        remoteGroup = remoteData.group
        remoteMask = remoteData.mask
        remoteRadiusLs = PhysicsConstants.remoteStrikerRadiusLs
        configurePhysics()

        transform.translation.y = PhysicsConstants.remoteStrikerAboveGroundLs / msToLsScale
        transform.scale = SIMD3<Float>(repeating: msToLsScale)

        childEntitySwitch.childEntityNamesList = [Team.none.rawValue,
                                                  Team.teamA.rawValue,
                                                  Team.teamB.rawValue]
        let modelNone = RemoteEntity.strikerModelEntity.clone(recursive: true)
        let modelTeamA = RemoteEntity.strikerModelEntityA.clone(recursive: true)
        let modelTeamB = RemoteEntity.strikerModelEntityB.clone(recursive: true)
        children.append(contentsOf: [modelNone, modelTeamA, modelTeamB])

        newTeam(team)
    }

    func configureForceField(id: UUID, forceFieldData: CollisionData) {
        super.configure(id: id, data: forceFieldData)
    }

    func newTeam(_ team: Team) {
        guard isOwner else { return }
        // only need to do this on the device that owns
        // the entity since network transport will get
        // the change to the other devices
        // remove old model if there was one
        // we should only have one other entity child (ForceFieldEnitty)
        enableChildrenEntities(named: team.rawValue)
        os_log(.default, log: GameLog.remoteEntity, "UUID %s %s set to model %s", "\(deviceUUID)", "\(team)", "\(team.rawValue)")
    }

    private func createPhysicsBody(_ shape: ShapeResource,
                                   mass: Float = PhysicsConstants.remoteMass,
                                   friction: Float = PhysicsConstants.remoteFriction,
                                   restitution: Float = PhysicsConstants.remoteRestitution) -> PhysicsBodyComponent {
        var physicsBody = PhysicsBodyComponent(shapes: [shape], mass: mass, mode: .kinematic)
        physicsBody.material = .generate(friction: friction, restitution: restitution)
        physicsBody.isRotationLocked = (x: true, y: false, z: true)
        return physicsBody
    }

    func playerTeamEntity() -> PlayerTeamEntity? {
        // one of RemoteEntity's children is PlayerTeamEntity
        for child in children where child is PlayerTeamEntity {
            guard let playerTeamEntity = child as? PlayerTeamEntity else { continue }

            return playerTeamEntity
        }
        return nil
    }

}

extension RemoteEntity {

    static func limitToBounds(_ position: SIMD3<Float>) -> SIMD3<Float> {
        guard RemoteTunables.boundsEnable.value else { return position }

        return GameBoard.pinToGameBoardBounds(position, buffer: RemoteTunables.boundsBuffer.value)
    }

    private func calcCurrentForward() -> SIMD3<Float> {
        let rotation = orientation(relativeTo: GamePlayManager.physicsOrigin)
        let basis = float3x3.init(rotation.normalized)
        return -basis.columns.2
    }

    private func turn(from currentAngle: Angle, deltaAngle: Angle, _ fDt: Float) {
        let deltaFrameAngle = min(RemoteTunables.turnRate.value * fDt, abs(deltaAngle))
        let moveAngle = (deltaAngle >= 0.0 ? 1.0 : -1.0) * deltaFrameAngle
        let newAngle = Angle.legalAngle(currentAngle + moveAngle)

        let newQuat = simd_quatf(angle: newAngle, axis: SIMD3<Float>(0, 1, 0))
        setOrientation(newQuat, relativeTo: GamePlayManager.physicsOrigin)
    }

   private func moveTowards(current: Float, target: Float, maxDelta: Float) -> Float {
        var delta = target - current
        if delta >= 0 {
            delta = min(maxDelta, delta)
        } else {
            delta = -min(maxDelta, -delta)
        }
        return current + delta
    }

    // move()
    // The goal of this move code is to have the Remote follow the Target.
    // The Target forward is always a vector from the Remote to the Target.
    // The Remote forward rotates in time towards the Target forward.
    // The Remote accelerates to a max speed in the forward direction.
    // The Remote decelerates to a stop when close to the Target position.
    private func move(toTarget targetEntity: TargetEntity, _ deltaTime: Float) {
        let remotePosition = position(relativeTo: GamePlayManager.physicsOrigin)
        let targetPosition = targetEntity.position(relativeTo: GamePlayManager.physicsOrigin)

        let delta = (targetPosition - remotePosition) * [1, 0, 1]
        let dir = normalize(delta)
        let distance = length(delta)

        var currentForward = calcCurrentForward() * [1, 0, 1]
        if distance > RemoteTunables.closeEnough.value {

            let targetAngle = Angle.xzQuaternionAngle(from: dir)
            let currentAngle = Angle.xzQuaternionAngle(from: currentForward)
            let deltaAngle = Angle.subtractAngle(from: targetAngle, subtract: currentAngle)

            if UserSettings.enableVelocityKinematic {
                // for RealityKit, angular velocity is a vector.  The magnitude of the vector
                // is the rate of rotation.  The direction of the vector is perpendicular to the
                // rotation plane
                let perpendicular = cross(currentForward, dir)
                let deltaAngleMin = min(RemoteTunables.turnRate.value, abs(deltaAngle / deltaTime))
                let angularVelocity = perpendicular * deltaAngleMin
                physicsMotion?.angularVelocity = angularVelocity
            } else {
                turn(from: currentAngle, deltaAngle: deltaAngle, deltaTime)
            }

            // update current forward since we turned
            currentForward = calcCurrentForward() * [1, 0, 1]

            if distance > RemoteTunables.easeInDistance.value {
                let useAcceleration = min(RemoteTunables.acceleration.value,
                                          RemoteTunables.acceleration.value * distance)
                targetSpeed = min(targetSpeed + (useAcceleration * deltaTime), RemoteTunables.maxSpeed.value)
            } else {
                targetSpeed = moveTowards(current: targetSpeed, target: 0.0,
                                          maxDelta: RemoteTunables.deceleration.value * deltaTime)
            }
        } else {
            targetSpeed = moveTowards(current: targetSpeed, target: 0.0,
                                      maxDelta: RemoteTunables.deceleration.value * deltaTime)
        }

        velocity = currentForward * targetSpeed
    }

    private func update(_ deltaTime: Float) {
        guard let targetEntity = findFirstSibling(ofType: TargetEntity.self, { [weak self] targetEntity in
            return targetEntity.deviceUUID == self?.deviceUUID
        }) else { return }

        move(toTarget: targetEntity, deltaTime)
    }

}

struct RemoteCollisionEvent {
    var entity0: RemoteEntity
    var impulse0: SIMD2<Float>
    var entity1: RemoteEntity
    var impulse1: SIMD2<Float>
}

extension RemoteEntity {

    static let remoteCollisionNotification = Notification.Name(rawValue: "RemoteEntity.remoteCollision")

    static func moveWithCollision(_ timeDelta: TimeInterval, _ remotes: [RemoteEntity]) {
        guard !remotes.isEmpty else { return }

        let deltaTime = Float(timeDelta)
        remotes.forEach { remote in
            remote.update(deltaTime)
        }

        if !UserSettings.enableStrikerMotion {
            return
        }

        let remote0 = remotes[0]
        if remotes.count > 1 {
            let remote1 = remotes[1]
            var position0 = remote0.position(relativeTo: GamePlayManager.physicsOrigin)
            let velocity0 = SIMD2<Float>(remote0.velocity.x, remote0.velocity.z)
            var sc0 = SweptCircle(origin: SIMD2<Float>(position0.x, position0.z),
                                  velocity: velocity0,
                                  radius: remote0.remoteRadiusLs, mass: remote0.mass)
            var position1 = remote1.position(relativeTo: GamePlayManager.physicsOrigin)
            let velocity1 = SIMD2<Float>(remote1.velocity.x, remote1.velocity.z)
            var sc1 = SweptCircle(origin: SIMD2<Float>(position1.x, position1.z),
                                  velocity: velocity1,
                                  radius: remote1.remoteRadiusLs, mass: remote1.mass)
            let (_, collisions) = SweptCircle.iterateUntilDone(&sc0, &sc1, deltaTime)
            if UserSettings.enableVelocityKinematic {
                var actualVelocity = (sc0.newPosition - sc0.position) / deltaTime
                remote0.physicsMotion?.linearVelocity = SIMD3<Float>(actualVelocity.x, 0.0, actualVelocity.y)
                sc0.newVelocity = actualVelocity
                actualVelocity = (sc1.newPosition - sc1.position) / deltaTime
                remote1.physicsMotion?.linearVelocity = SIMD3<Float>(actualVelocity.x, 0.0, actualVelocity.y)
                sc1.newVelocity = actualVelocity
            } else {
                position0.x = sc0.newPosition.x
                position0.z = sc0.newPosition.y
                remote0.setPosition(position0, relativeTo: GamePlayManager.physicsOrigin)
                position1.x = sc1.newPosition.x
                position1.z = sc1.newPosition.y
                remote1.setPosition(position1, relativeTo: GamePlayManager.physicsOrigin)
            }
            if collisions > 0 {
                if remote0.framesWithNoCollision > 3, remote1.framesWithNoCollision > 3 {
                    let event = RemoteCollisionEvent(entity0: remote0, impulse0: sc0.impulse(velocity0),
                                                     entity1: remote1, impulse1: sc1.impulse(velocity1))
                    NotificationCenter.default.post(name: RemoteEntity.remoteCollisionNotification,
                                                    object: nil,
                                                    userInfo: ["event": event])
                }
                remote0.velocity.x = sc0.newVelocity.x
                remote0.velocity.z = sc0.newVelocity.y
                remote1.velocity.x = sc1.newVelocity.x
                remote1.velocity.z = sc1.newVelocity.y
                remote0.framesWithNoCollision = 0
                remote1.framesWithNoCollision = 0
            } else {
                remote0.framesWithNoCollision += 1
                remote1.framesWithNoCollision += 1
            }
        } else {
            if UserSettings.enableVelocityKinematic {
                remote0.physicsMotion?.linearVelocity = remote0.velocity
            } else {
                var position = remote0.position(relativeTo: GamePlayManager.physicsOrigin)
                position += remote0.velocity * deltaTime
                position = RemoteEntity.limitToBounds(position)
                remote0.setPosition(position, relativeTo: GamePlayManager.physicsOrigin)
            }
        }
    }

}
