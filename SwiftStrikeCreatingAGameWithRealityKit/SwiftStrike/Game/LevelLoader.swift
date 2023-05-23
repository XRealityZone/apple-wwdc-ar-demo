/*
See LICENSE folder for this sample’s licensing information.

Abstract:
LevelLoader
*/

import ARKit
import Combine
import os.log
import RealityKit

protocol GameResettable {
    func gameReset()
}

class LevelLoader: LevelLoaderProtocol {

    var cancellable: AnyCancellable?
    var activeLevel: ActiveLevel?

    ///
    /// addDevicePlayerRepresentation()
    /// called for each device, client or host, that joins the game,
    /// to add any required device owned entities for the player,
    /// such as the PlayerLocationEntity, RemoteEntity (TableTop only), TargetEntity (TableTop only), etc.
    func addDevicePlayerRepresentation(scene: Scene, camera: ARCamera, named name: String, cameraTeam: Team)
        -> (AnchorEntity?, PlayerLocationEntity?, RemoteEntity?, TargetEntity?) {

        let playerLocationEntity = PlayerLocationEntity(named: name)
        playerLocationEntity.configure()
        playerLocationEntity.setTransformMatrix(camera.transform, relativeTo: nil)

        let anchorEntity = AnchorEntity()
        anchorEntity.addChild(playerLocationEntity)
        scene.anchors.append(anchorEntity)

        var remoteEntity: RemoteEntity?
        var targetEntity: TargetEntity?
        if UserSettings.isTableTop, !UserSettings.spectator {
            os_log(.default, log: GameLog.player, "playerLocationEntity %s", "\(cameraTeam)")
            remoteEntity = RemoteEntity(named: name)
            remoteEntity!.configure(team: .none,
                                    msToLsScale: Constants.remoteMsToLsScale,
                                    remoteData: CollisionData(totalHeight: Constants.remoteLsHeight,
                                                              radius: Constants.remoteLsRadius,
                                                              group: .remote,
                                                              mask: [.ball, .remote]))
            remoteEntity!.transform.translation.z = cameraTeam.zSign * Constants.remoteWsStartZ
            GamePlayManager.physicsOrigin?.addChild(remoteEntity!)

            targetEntity = TargetEntity(named: name)
            targetEntity!.configure(team: .none, msToLsScale: Constants.remoteMsToLsScale)
            GamePlayManager.physicsOrigin?.addChild(targetEntity!)
        }

        os_log(.default, log: GameLog.player, "added PlayerLocationEntity %sUUID %s",
               remoteEntity != nil ? "with RemoteEntity " : "", "\(playerLocationEntity.deviceUUID)")

        return (anchorEntity, playerLocationEntity, remoteEntity, targetEntity)
    }

    ///
    /// addHostPlayerRepresentation()
    /// host only call to add several entities required to play the game such as
    /// the PaddleEntity, ForceFieldEntity,  PlayerTeamEntity, etc.
    func addHostPlayerRepresentation(playerLocationEntity: PlayerLocationEntity, remoteEntity: RemoteEntity?) {
        let name = playerLocationEntity.name

        let playerTeamEntity = PlayerTeamEntity()
        if let remoteEntity = remoteEntity {
            // force field must be added and configured on the host, the remote was created on the device
            remoteEntity.configureForceField(id: playerLocationEntity.deviceUUID,
                                             forceFieldData: CollisionData(totalHeight: Constants.remoteLsForceFieldHeight,
                                                                           radius: Constants.remoteLsForceFieldRadius,
                                                                           group: .forceField,
                                                                           mask: [.ball]))
            playerTeamEntity.configure(named: name, id: playerLocationEntity.deviceUUID,
                                       capsuleHeight: Constants.remoteLsHeight, capsuleRadius: Constants.remoteLsRadius)
            remoteEntity.addChild(playerTeamEntity)
            os_log(.default, log: GameLog.player, "added PlayerTeamEntity UUID %s to RemoteEntity UUID %s",
                   "\(remoteEntity.deviceUUID)", "\(playerTeamEntity.deviceUUID)")
        } else {
            playerTeamEntity.configure(named: name, id: playerLocationEntity.deviceUUID,
                                       capsuleHeight: Constants.paddleHeight, capsuleRadius: Constants.paddleRadius)
            playerLocationEntity.addChild(playerTeamEntity)
            os_log(.default, log: GameLog.player, "added PlayerTeamEntity UUID %s to PlayerLocationEntity UUID %s",
                   "\(playerLocationEntity.deviceUUID)", "\(playerTeamEntity.deviceUUID)")

            let paddleEntity = PaddleEntity()
            paddleEntity.configure(id: playerLocationEntity.deviceUUID)
            playerLocationEntity.addChild(paddleEntity)
        }
    }

    var reckoning: GameLevel {
        let definition = GameLevel.Definition(key: "base", identifier: "reckoning")
        let level = GameLevel(definition: definition)
        level.targetSize = CGSize(width: CGFloat(Constants.groundWidth), height: CGFloat(Constants.groundLength))
        switch UserSettings.gameScale {
        case .fullCourt:
            let scale = UserSettings.fullCourtScale
            os_log(.default, log: GameLog.gameboard, "GameBoard: Full Court @%s%%", "\(Int(scale * 100))")
            level.isResizable = false
            level.defaultScale = scale
            level.minimumScale = scale
            level.maximumScale = scale
        case .tableTop:
            os_log(.default, log: GameLog.gameboard, "GameBoard: Table Top")
            level.isResizable = true
            level.defaultScale = Constants.tableTopGameScale
            level.minimumScale = Constants.tableTopMinimumScale
            level.maximumScale = Constants.tableTopMaximumScale
        }
        return level
    }

    func load(_ level: GameLevel, completion: @escaping (Result<ActiveLevel, Error>) -> Void) -> AnyCancellable? {
        guard let activeLevel = self.activeLevel else {
            cancellable = ReckoningLevel.loadAsync()
                .sink(receiveCompletion: { [weak self] result in
                    guard self != nil else { return }
                    if case let .failure(error) = result {
                        os_log("level load failed: %s", "\(error)")
                        os_log("search for \"Runtime Error\" (secondary thread) to find asset that failed to load.")
                        completion(.failure(error))
                    }
                }) { [weak self] reckoningLevel in
                    guard let self = self else { return }
                    self.activeLevel = ActiveLevel(content: reckoningLevel.field!)
                    completion(.success(self.activeLevel!))
                }
            return cancellable
        }
        guard let content = activeLevel.content as? GameResettable else {
            fatalError("Active level content does not implement hard reset protocol and cannot be reset")
        }
        content.gameReset()
        completion(.success(activeLevel))
        return cancellable
    }

    func level(for key: String) -> GameLevel? {
        return reckoning
    }

    var placementUILoader: AnyPublisher<Entity, Error> {
        return ReckoningLevel.loadPlacementUIAsync()
    }

    func loadLevel() {}

    func preLoad(_ level: GameLevel) {}

    func reset() {
        guard let content = self.activeLevel?.content as? GameResettable else { return }

        content.gameReset()
    }

}
