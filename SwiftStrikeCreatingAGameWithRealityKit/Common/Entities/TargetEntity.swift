/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Target Entity
*/

import Combine
import Foundation
import os.log
import RealityKit

extension GameLog {
    static let targetEntity = OSLog(subsystem: subsystem, category: "targetEntity")
}

enum TargetTunables {
    /// closeEnough
    /// if we are closer than this distance, we go directly to the target
    /// if we are farther than this distance, we use the deceleration to ease in to closeEnough
    static var closeEnoughToTurn = TunableScalar<Float>("Target Close Enough", min: 0.001, max: 1.0, def: 0.02)
}

class TargetEntity: Entity, HasModel, HasDeviceIdentifier, HasChildEntitySwitch {

    static var floorModelEntity: Entity!
    static var floorModelEntityA: Entity!
    static var floorModelEntityB: Entity!

    static func loadAsync() -> AnyPublisher<Void, Error> {
        var toLoad = [AssetToLoad]()

        toLoad.append(AssetToLoad(for: .target, options: .none))
        toLoad.append(AssetToLoad(for: .target, options: .teamA))
        toLoad.append(AssetToLoad(for: .target, options: .teamB))

        return loadEntitiesAsync(toLoad)
        .map { entitiesLoaded -> Void in
            TargetEntity.floorModelEntity = entitiesLoaded[[.none]]
            TargetEntity.floorModelEntityA = entitiesLoaded[[.teamA]]
            TargetEntity.floorModelEntityB = entitiesLoaded[[.teamB]]
            TargetEntity.floorModelEntity.name = Team.none.rawValue
            TargetEntity.floorModelEntityA.name = Team.teamA.rawValue
            TargetEntity.floorModelEntityB.name = Team.teamB.rawValue
        }
        .tryMap { $0 }  // Never -> Error
        .eraseToAnyPublisher()
    }

    private var msToLsScale: Float = 0.0

    func configure(team: Team, msToLsScale: Float) {
        name = "Target \(self.name)"
        deviceIdentifier = DeviceIdentifierComponent()
        childEntitySwitch = ChildEntitySwitchComponent()
        self.msToLsScale = msToLsScale

        transform.translation.y = PhysicsConstants.remoteIndicatorAboveGroundLs / msToLsScale
        transform.scale = SIMD3<Float>(repeating: msToLsScale)

        childEntitySwitch.childEntityNamesList = [Team.none.rawValue,
                                                  Team.teamA.rawValue,
                                                  Team.teamB.rawValue]
        let modelNone = TargetEntity.floorModelEntity.clone(recursive: true)
        let modelTeamA = TargetEntity.floorModelEntityA.clone(recursive: true)
        let modelTeamB = TargetEntity.floorModelEntityB.clone(recursive: true)
        children.append(contentsOf: [modelNone, modelTeamA, modelTeamB])

        newTeam(team)
    }

    func newTeam(_ team: Team) {
        guard isOwner else { return }
        // only need to do this on the device that owns
        // the entity since network transport will get
        // the change to the other devices
        // remove old model if there was one
        // we should only have one other entity child (ForceFieldEnitty)
        enableChildrenEntities(named: team.rawValue)
        os_log(.default, log: GameLog.targetEntity, "UUID %s %s set to model %s", "\(deviceUUID)", "\(team)", "\(team.rawValue)")
    }

    // POS stands for Physics Origin Space
    private func updateTargetPosition(from targetPositionPOS: SIMD3<Float>, using playerLocation: Entity) {
        // get player location entity local to world transform
        let playerLocationLSToPOSMatrix = playerLocation.transformMatrix(relativeTo: GamePlayManager.physicsOrigin)
        let playerLocationLSToPOSTransform = Transform(matrix: playerLocationLSToPOSMatrix)

        // get world space positions of player location entity and remote entity
        let playerLocationPositionPOS = playerLocationLSToPOSTransform.translation

        // get camera look at direction (player location entity forward in world space)
        let playerLocationRotationPOS = playerLocationLSToPOSTransform.rotation
        let playerLocationMatrixPOS = float3x3(playerLocationRotationPOS.normalized)
        let playerLocationForwardPOS = -playerLocationMatrixPOS.columns.2

        // now ray intersect from the player location entity to a plane at the remote's
        // height above the board to determine the x,z location the character should be at
        let plane = Plane(point: SIMD3<Float>(0, targetPositionPOS.y, 0), normal: SIMD3<Float>(0, 1, 0))
        if let newPositionPOS = plane.rayIntersect(rayStart: playerLocationPositionPOS, rayDirection: playerLocationForwardPOS) {
            setPosition(RemoteEntity.limitToBounds(newPositionPOS), relativeTo: GamePlayManager.physicsOrigin)
        }
    }

    func updateTargetAngle(from targetPositionPOS: SIMD3<Float>) {
        guard let remoteEntity = findFirstSibling(ofType: RemoteEntity.self, { [weak self] remoteEntity in
            return remoteEntity.deviceUUID == self?.deviceUUID
        }) else { return }

        let remotePosition = remoteEntity.position(relativeTo: GamePlayManager.physicsOrigin)
        let delta = (targetPositionPOS - remotePosition) * [1, 0, 1]
        let distance = length(delta)

        if distance > TargetTunables.closeEnoughToTurn.value {
            let dir = normalize(delta)
            let angle = Angle.xzQuaternionAngle(from: dir)
            let newQuat = simd_quatf(angle: angle, axis: [0, 1, 0])
            setOrientation(newQuat, relativeTo: GamePlayManager.physicsOrigin)
        }
    }

    func update(_ timeDelta: TimeInterval, scene: Scene) {
        guard let playerLocationEntity = scene.playerLocationEntity(for: deviceUUID) else { return }

        // get target entity local to world transform
        let targetPositionPOS = position(relativeTo: GamePlayManager.physicsOrigin)
        updateTargetPosition(from: targetPositionPOS, using: playerLocationEntity)
        updateTargetAngle(from: targetPositionPOS)
    }

}

